# 🏗️ Architecture Guide - PearlHub Production

**Version**: 1.0  
**Date**: March 25, 2026  
**Author**: PearlHub Engineering Team

---

## 1. System Overview

### Monorepo Structure

```
D:\fath1\
├── web/                    # React 19 + TypeScript frontend
├── flutter/                # Flutter mobile apps (customer, provider, admin)
├── sdk-ts/                 # TypeScript SDK for third-party integrations
├── sdk-dart/               # Dart SDK
├── supabase/               # PostgreSQL database, RLS, Edge Functions
│   ├── config.toml         # Project configuration
│   ├── migrations/         # SQL migrations (schema + RLS)
│   └── functions/          # Edge Functions (TypeScript)
├── .github/
│   └── workflows/          # CI/CD pipelines
└── docs/                   # Documentation (this folder)
```

### Technology Stack

| Layer | Technology | Purpose |
| --- | --- | --- |
| **Frontend** | React 19 | UI framework |
| **Type Safety** | TypeScript 5.7 | Type checking |
| **Build** | Vite 8 | Fast bundler |
| **Styling** | Tailwind CSS | Utility-first CSS |
| **Components** | shadcn/ui | Accessible UI components |
| **State** | Zustand + Supabase | State management |
| **Data Fetching** | TanStack Query 5 | Server state management |
| **Backend** | Supabase (PostgreSQL + Auth) | Database + authentication |
| **Compute** | Edge Functions (Deno) | Serverless TypeScript |
| **Storage** | Supabase Storage | File uploads |
| **Deployment** | Vercel | Frontend hosting |
| **CI/CD** | GitHub Actions | Automated testing/deployment |

---

## 2. Payment Architecture

### Request Flow Diagram

```
Browser (React)
    ↓
    │ [1] User submits checkout form
    │ Generate idempotency_key
    ↓
create-payhere-session Edge Function
    ↓
    │ [2] Verify bearer token (user auth)
    │ [3] Check idempotency (payment_transactions.idempotency_key)
    │ [4] Insert pending booking in bookings table
    │ [5] Calculate commission & escrow server-side
    │ [6] Generate PayHere signature (MD5)
    │ [7] Return signed POST payload
    ↓
Browser Submits Hidden Form
    ↓ HTTP POST to PayHere
PayHere (Payment Gateway)
    ↓
    │ [8] User completes payment
    │ [9] PayHere verifies & processes
    │ [10] Webhook callback to payment-webhook Edge Function
    ↓
payment-webhook Edge Function
    ↓
    │ [11] Parse webhook body
    │ [12] Verify MD5 signature against PayHere secret
    │ [13] Upsert payment_transactions (idempotent via order_id)
    │ [14] Update bookings.payment_status = 'paid'
    │ [15] Create wallet_transactions for commission + escrow
    ↓
Database (Supabase)
    ├── bookings (payment_status = 'paid')
    ├── payment_transactions (status = 'paid')
    └── wallet_transactions (commission + escrow entries)
```

### Idempotency Pattern

**Problem**: Webhook may be delivered multiple times or user may retry payment.

**Solution**: Server deduplicates via `payment_transactions.idempotency_key`:

```sql
CREATE TABLE payment_transactions (
  id UUID PRIMARY KEY,
  idempotency_key UUID NOT NULL UNIQUE,  -- Unique per payment attempt
  order_id TEXT NOT NULL UNIQUE,
  amount INTEGER,
  status text ('pending', 'processing', 'paid', 'failed'),
  ...
);

-- In payment-webhook:
-- If order_id already exists, return early (don't double-process)
-- If idempotency_key exists, return early
```

**Flow**:
1. Browser generates `idempotency_key` (UUID)
2. Sends to `create-payhere-session`
3. Server records in `payment_transactions` with `status='processing'`
4. Webhook called (possibly multiple times)
5. Webhook checks `order_id` UNIQUE constraint
6. If already processed, returns silently (idempotent)
7. Booking state updated exactly once

---

## 3. Authentication & Authorization

### User Roles

```
public user (unauthenticated)
    ↓ signup via Supabase Auth
authenticated user (no role)
    ↓ (most users, stays here)
├─ provider (can list properties/vehicles/events)
├─ admin (can moderate, manage payments)
└─ sme (seller of events/social listings)
```

### Role Assignment

**On signup**:
```sql
-- handle_new_user() trigger
INSERT INTO user_roles (user_id, role)
VALUES (NEW.id, 'authenticated');
-- Blocks 'admin' role assignment from JWT metadata
```

**On signup with metadata**:
```javascript
// Browser
const { data, error } = await supabase.auth.signUp({
  email,
  password,
  options: {
    data: { user_type: 'provider' }  // Metadata (user can set this)
  }
});
// But trigger ignores it; only 'authenticated' assigned
// Admin role must be granted via private admin API
```

**Grant admin role** (admin-only):
```sql
UPDATE user_roles SET role = 'admin' WHERE user_id = '...'
-- Verified via RLS policy: public.is_admin(auth.uid())
```

### RLS (Row-Level Security)

**Pattern**:
```sql
-- Example: Users can only read own bookings
CREATE POLICY "Users can read own bookings" ON bookings
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- Only admins can read all bookings
CREATE POLICY "Admins see all bookings" ON bookings
FOR SELECT TO authenticated
USING (public.is_admin(auth.uid()));
```

**Special case: Payment functions bypass RLS**:
```sql
-- Edge Functions use service role (not bounded by RLS)
-- This allows payment-webhook to update bookings without user context
supabase.rpc("verify_payment", ..., { headers: { Authorization: `Bearer ${SERVICE_ROLE_KEY}` } })
```

---

## 4. Data Models

### Core Tables

#### `bookings`
```sql
CREATE TABLE bookings (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  listing_id UUID NOT NULL,  -- Property, vehicle, event, stay, etc.
  listing_type VARCHAR,      -- 'property', 'vehicle', 'event', 'stay'
  quantity INTEGER,
  check_in DATE,
  check_out DATE,
  status VARCHAR ('pending', 'confirmed', 'completed', 'cancelled', 'payment_failed'),
  payment_status VARCHAR ('unpaid', 'paid', 'refunded'),
  amount_lkr INTEGER,        -- In cents
  commission_lkr INTEGER,    -- Platform take
  escrow_lkr INTEGER,        -- Held until completion
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  
  -- RLS: Each user sees own bookings; admins see all
  -- Computed: amount_lkr = unit_price * quantity * days
  -- Computed: commission_lkr = FLOOR(amount_lkr * PLATFORM_COMMISSION_PERCENT / 100)
  -- Computed: escrow_lkr = amount_lkr - commission_lkr
};
```

#### `payment_transactions`
```sql
CREATE TABLE payment_transactions (
  id UUID PRIMARY KEY,
  booking_id UUID REFERENCES bookings(id),
  order_id TEXT UNIQUE,      -- PayHere order ID
  idempotency_key UUID UNIQUE,  -- Prevents double-processing
  amount INTEGER,
  payment_method VARCHAR ('payhere', 'webxpay', 'lankapay'),
  status VARCHAR ('pending', 'processing', 'paid', 'failed'),
  merchant_id VARCHAR,
  external_transaction_id VARCHAR,  -- PayHere internal ID
  verified_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  
  -- RLS: Users see own; admins see all
  -- Webhook updates this table via ORDER_ID lookup
};
```

#### `wallet_transactions`
```sql
CREATE TABLE wallet_transactions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  booking_id UUID REFERENCES bookings(id),
  transaction_type VARCHAR ('payment', 'commission', 'escrow_release', 'refund'),
  amount INTEGER,  -- Can be negative (refund)
  balance_after INTEGER,  -- Running balance
  description TEXT,
  status VARCHAR ('pending', 'completed', 'failed'),
  created_at TIMESTAMP,
  
  -- Schema: User can only see own; payment-webhook writes via service role
};
```

#### `notifications`
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  booking_id UUID REFERENCES bookings(id),
  type VARCHAR ('booking_confirmed', 'payment_success', 'dispute_filed', ...),
  message TEXT,
  read_at TIMESTAMP,
  created_at TIMESTAMP,
  
  -- Edge Function: notification-sender creates these
  -- Client: React Query subscription
};
```

---

## 5. Security Boundaries

### Trust Levels

```
┌─────────────────────────────────────────────┐
│ BROWSER (Untrusted)                         │
│ • Limited to client-safe values             │
│ • ANON KEY only (public/auth)               │
│ • Submits user input                        │
├─────────────────────────────────────────────┤
│ EDGE FUNCTIONS (Trusted)                    │
│ • SERVICE ROLE KEY (full DB access)         │
│ • Verifies bearer token (user auth)         │
│ • Validates signatures (PayHere)            │
│ • Enforces business logic                   │
├─────────────────────────────────────────────┤
│ DATABASE (Trusted)                          │
│ • RLS policies enforce row-level access     │
│ • Schema constraints (NOT NULL, UNIQUE)     │
│ • Ledger tables (wallet_transactions)       │
│ • Audit tables (admin_actions, request_logs)│
└─────────────────────────────────────────────┘
```

### .env Separation

**Browser-safe** (in `web/.env.local` and Vercel):
```env
VITE_SUPABASE_URL
VITE_SUPABASE_ANON_KEY
VITE_SUPABASE_PROJECT_ID
VITE_PUBLIC_SITE_URL
VITE_PLATFORM_COMMISSION_PERCENT
```

**Server secrets** (Supabase secrets or `supabase/.env.local`):
```env
SUPABASE_SERVICE_ROLE_KEY
PAYHERE_MERCHANT_ID
PAYHERE_MERCHANT_SECRET
WEBXPAY_MERCHANT_ID
WEBXPAY_SECRET
ANTHROPIC_API_KEY
```

### CORS & CSP

**CORS allowed**:
- Frontend domain (Vercel URL)
- PayHere webhook submitter

**Content Security Policy** (in `vercel.json`):
```json
{
  "headers": [
    {
      "key": "Content-Security-Policy",
      "value": "
        default-src 'self';
        script-src 'self' 'unsafe-inline' cdn.jsdelivr.net;
        connect-src 'self' supabase.co payhere.lk webxpay.com;
        form-action 'self' sandbox.payhere.lk www.payhere.lk;
      "
    }
  ]
}
```

---

## 6. Edge Functions

### Shared Utilities

**`_shared/payhere.ts`** - Pure MD5 implementation:
```typescript
export function buildPayHereSignature(
  merchantId: string,
  orderId: string,
  amount: string,
  currency: string,
  merchantSecret: string
): string {
  const msg = `${merchantId}${orderId}${amount}${currency}${merchantSecret}`;
  return md5(msg).toUpperCase();
}
```

### Function: `create-payhere-session`

**Purpose**: Generate signed PayHere form data server-side

**Inputs**:
- Bearer token (user auth)
- Booking details (listing ID, qty, dates)
- Idempotency key

**Outputs**:
- Signed PayHere POST payload

**Security**:
- Verifies bearer token
- Generates fresh order ID
- Calculates amounts server-side (no JS math in browser)
- Returns ready-to-submit form

### Function: `payment-webhook`

**Purpose**: Confirm PayHere payments and update bookings

**Inputs**:
- Webhook POST from PayHere (form-encoded)
- Fields: merchant_id, order_id, amount, status_code, md5sig, ...

**Outputs**:
- Updated bookings.payment_status = 'paid'
- Updated payment_transactions.status
- New wallet_transactions for commission

**Security**:
- Verifies MD5 signature against merchant secret
- Idempotent (order_id UNIQUE constraint)
- Marks as verified only if signature valid

---

## 7. CI/CD Pipeline

### GitHub Actions Workflows

**`.github/workflows/web-deploy.yml`**:
```yaml
On: push to main on D:\fath1 GitHub mirror
1. npm install
2. npm run build (fails if TypeScript errors)
3. Deploy to Vercel (if build passes)
```

**`.github/workflows/supabase-deploy.yml`** (future):
```yaml
On: push to D:\fath1/supabase/migrations
1. Run migrations locally
2. Test SQL syntax
3. Deploy to staging (if tests pass)
4. Await manual approval
5. Deploy to production
```

---

## 8. Error Handling & Monitoring

### Request Logging

All requests logged to `request_logs` table:
```sql
INSERT INTO request_logs (
  method, path, user_id, status, error_message, created_at
) VALUES (
  'POST', '/functions/v1/payment-webhook', NULL, 500, 'Signature mismatch', NOW()
);
```

### Alert Rules

| Condition | Severity | Action |
| --- | --- | --- |
| Payment success < 90% (1 hour) | 🔴 Critical | Page on-call |
| Edge Function error rate > 5% | 🟠 High | Message Slack |
| Database CPU > 80% | 🟠 High | Scale compute |
| TypeScript build fails | 🔴 Critical | Block PR |

---

## 9. Scalability Notes

### Horizontal Scaling

- **Frontend**: Vercel auto-scales
- **Database**: Supabase auto-scales reads; manual scale for write-heavy
- **Edge Functions**: Deno Deploy auto-scales globally

### Vertical Scaling

If single database becomes bottleneck:

1. **Read replicas**: Create read-only replicas for analytics
2. **Sharding**: Partition bookings by user_id ranges
3. **Caching**: Redis layer for frequent queries

---

## 10. Future Phases

### Phase 2: Multi-Payment Gateways
- WebXPay integration
- LankaPay integration
- Dispute resolution via merchant dashboard

### Phase 3:  Multi-Party Escrow
- Booking completion flow
- Automatic escrow release
- Dispute arbitration

### Phase 4: Advanced Analytics
- Revenue by merchant/category
- User retention metrics
- Churn prediction

---

