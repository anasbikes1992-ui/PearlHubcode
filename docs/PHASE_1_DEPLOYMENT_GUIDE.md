# 🚀 Phase 1 Completion & Deployment Guide

**Status**: Implementation Complete, Ready for Testing  
**Date**: March 25, 2026  
**Critical Path**: ✅ All components implemented with corrected PayHere MD5 verification  

---

## 📋 Phase 1 Implementation Summary

### ✅ What Has Been Completed

#### 1. **Database Schema** (3 Migration Files)
- **0000_production_foundation.sql**: 8 core tables + 2 utility functions
  - ✅ bookings (booking history & payment tracking)
  - ✅ payment_transactions (payment gateway integration)
  - ✅ wallet_transactions (escrow & commission tracking)
  - ✅ notifications (real-time alerts)
  - ✅ disputes (customer support tracking)
  - ✅ kyc_documents (identity verification)
  - ✅ payouts (provider payouts)
  - ✅ platform_config (admin settings)
  - ✅ Extensions: PostGIS, pgvector, pgcrypto

- **0001_rls_policies.sql**: Row-Level Security
  - ✅ All 8 tables have RLS policies enabled
  - ✅ Users can only read/modify their own data
  - ✅ Admin bypass via `is_admin()` function

- **0002_payment_webhook_fields.sql**: Webhook Verification Fields (NEW)
  - ✅ payhere_order_id (unique, indexed)
  - ✅ webhook_received (idempotency flag)
  - ✅ webhook_received_at (audit timestamp)
  - ✅ webhook_signature_valid (verification result)
  - ✅ md5_signature (stored signature for audit)
  - ✅ completed_at (payment completion time)

#### 2. **Edge Functions** (2 Functions)

**A. create-payhere-session** (`supabase/functions/create-payhere-session/index.ts`)

✅ Features:
- Bearer token authentication via Authorization header
- Idempotency key checking (prevents duplicate payment sessions)
- Creates booking + payment_transaction atomically
- Calculates commission (10%) and escrow amounts
- Generates PayHere session payload with MD5 hash
- Returns checkout URL for frontend redirect

✅ Changes Made:
- Now stores `payhere_order_id` alongside `payment_ref` for webhook lookups

**B. payment-webhook** (`supabase/functions/payment-webhook/index.ts`)

✅ Features:
- ✅ **CORRECTED MD5 SIGNATURE VERIFICATION**
  - Pattern: `merchant_id + order_id + amount + currency + status_code + upper(md5(merchant_secret))`
  - Case-insensitive comparison
  - Signature validation BEFORE any database changes

- ✅ Merchant ID verification from environment (not payload)
- ✅ Idempotency pattern: checks `webhook_received` flag
- ✅ Creates/updates payment_transaction with verification metadata
- ✅ Updates booking status to "confirmed" on success
- ✅ Creates wallet transaction for commission tracking
- ✅ Sends payment_success notification to user
- ✅ Full audit trail: stores MD5 signature and verification result

#### 3. **Security Hardening**
- ✅ Service role key ONLY used inside Edge Functions
- ✅ Bearer token auth on all payment endpoints
- ✅ MD5 signature verification on all webhooks
- ✅ Idempotency prevents duplicate charges
- ✅ RLS policies enforce user data isolation
- ✅ All sensitive tables require authentication
- ✅ No public access to bookings, payments, or wallet

---

## 🔧 Local Testing Setup

### Prerequisites

```bash
# 1. Ensure Supabase CLI is installed
supabase --version
# Expected: Supabase CLI 1.186.0 or higher

# 2. Ensure local Docker is running
docker version

# 3. Ensure environment files exist
ls -la supabase/.env.local
ls -la web/.env.local
```

### Step 1: Start Local Supabase

```bash
cd d:\fath1

# Start local Supabase (starts Docker container with PostgreSQL, auth, functions)
supabase start
```

**Expected Output**:
```
Started supabase local development setup.

API URL: http://127.0.0.1:54321
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Service Role Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 2: Apply Database Migrations

```bash
# Supabase CLI automatically applies migrations in order
# Just run:
supabase db push

# Verify migrations applied:
supabase db remote:diff  # Should show no differences
```

**Expected Result**: All 3 migration files applied successfully with 0 errors.

### Step 3: Deploy Edge Functions Locally

```bash
# Functions are deployed automatically in local mode
# Verify:
supabase functions list

# Should show:
# create-payhere-session (deployed)
# payment-webhook (deployed)
```

### Step 4: Start Frontend Dev Server

In another terminal:

```bash
cd d:\fath1\web

npm run dev
```

**Expected Output**:
```
  ➜  Local:   http://localhost:5173/
```

---

## 🧪 Phase 1 Testing Checklist

Before moving to Phase 2, verify each of these:

### A. Database Tests

```sql
-- Test 1: Verify all tables created
SELECT tablename FROM pg_tables WHERE schemaname = 'public' 
ORDER BY tablename;
-- Expected: bookings, disputes, kyc_documents, notifications, 
--           payment_transactions, payouts, platform_config, 
--           wallet_transactions

-- Test 2: Verify RLS enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND rowsecurity = true
ORDER BY tablename;
-- Expected: All 8 tables shown

-- Test 3: Check webhook verification fields exist
\d payment_transactions
-- Expected: payhere_order_id, webhook_received, webhook_signature_valid, md5_signature columns
```

### B. Function Tests

#### Test create-payhere-session Locally

```bash
# 1. Get auth token (manually)
# Go to http://localhost:5173/auth → Sign up → Get token from browser console

# 2. Call function with curl
curl -X POST http://localhost:54321/functions/v1/create-payhere-session \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "listingId": "test-listing-1",
    "title": "Luxury Villa in Colombo",
    "amount": 10000,
    "currency": "LKR",
    "type": "stay",
    "checkIn": "2026-04-01",
    "checkOut": "2026-04-05"
  }'

# Expected Response:
{
  "checkoutUrl": "https://sandbox.payhere.lk/pay/checkout",
  "bookingId": "uuid-here",
  "paymentRef": "uuid-here",
  "gateway": "payhere",
  "payload": {
    "merchant_id": "1211145",
    "order_id": "uuid-here",
    "amount": "10000.00",
    ...
  }
}
```

**Verification**:
- ✅ Response contains checkoutUrl
- ✅ Payment transaction created in DB
- ✅ Booking status = "pending_payment"

#### Test payment-webhook Signature Verification

```bash
# 1. Manually verify MD5 signature format
# Given:
MERCHANT_ID=1211145
ORDER_ID=test-order-123
AMOUNT=10000.00
CURRENCY=LKR
STATUS_CODE=2
MERCHANT_SECRET=demo_secret_key_123

# Correct pattern (as implemented):
# merchant_id + order_id + amount + currency + status_code + upper(md5(merchant_secret))
# = "1211145test-order-12310000.00LKR2" + upper(md5("demo_secret_key_123"))
# = "1211145test-order-12310000.00LKR2" + "ABCDEF0123456789ABCDEF0123456789"

# Then MD5 that entire string to get final signature

# 2. Send test webhook
curl -X POST http://localhost:54321/functions/v1/payment-webhook \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'merchant_id=1211145&order_id=test-order-123&payhere_amount=10000.00&payhere_currency=LKR&status_code=2&md5sig=CALCULATED_SIGNATURE_HERE&custom_1=USER_ID_HERE&custom_2=BOOKING_ID_HERE'

# Expected Response (200 OK):
{
  "success": true,
  "message": "Webhook processed",
  "status": "success"
}
```

**Verification**:
- ✅ Signature verification passes
- ✅ payment_transaction.webhook_received = true
- ✅ booking.status = "confirmed"
- ✅ wallet_transaction created
- ✅ notification created

### C. Security Tests

```javascript
// Test 1: Verify RLS - Anonymous user cannot read bookings
const { data, error } = supabase
  .from('bookings')
  .select('*');
// Expected: Error (not authenticated)

// Test 2: Verify bearer token requirement
fetch('http://localhost:54321/functions/v1/create-payhere-session', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ listingId: 'test', amount: 1000 })
});
// Expected: 401 Unauthorized (missing bearer token)

// Test 3: Verify admin function
const { data: isAdmin } = supabase.rpc('is_admin', { p_user_id: 'some-uuid' });
// Expected: boolean
```

### D. Integration Tests

```bash
# Test full payment flow:
# 1. User signs up
# 2. User creates booking
# 3. User initiates payment (create-payhere-session)
# 4. Simulated PayHere webhook callback (payment-webhook)
# 5. Verify booking confirmed + notification sent

# This will be automated in Phase 5 (Vitest + Playwright)
```

---

## 🚀 Deploying Phase 1 to Production

### Prerequisites

✅ All Phase 1 tests pass locally  
✅ MD5 signature verification confirmed working  
✅ No TypeScript errors: `npm run build` passes  

### Deployment Steps

#### 1. Link to Remote Supabase Project

```bash
supabase link --project-ref pxuydclxnnfgzpzccfoa

# Verify credentials:
supabase status --remote
```

#### 2. Push Database Migrations

```bash
supabase db push --remote

# Verify:
supabase db remote:diff --remote
# Should show: "No differences found"
```

#### 3. Deploy Edge Functions

```bash
# Automatic: Just push to GitHub (CI/CD handles deployment)
# Or manual:
supabase functions deploy create-payhere-session --remote
supabase functions deploy payment-webhook --remote

# Verify:
supabase functions list --remote
```

#### 4. Configure Production Secrets

Go to Supabase Dashboard → Settings → Edge Functions → Secrets

Add:
```
PAYHERE_MERCHANT_ID = 1211145
PAYHERE_MERCHANT_SECRET = demo_secret_key_123  (replace with live secret for production)
PAYHERE_SANDBOX = true  (set to false for live payments)
PUBLIC_SITE_URL = http://localhost:5173  (or your production domain)
PLATFORM_COMMISSION_PERCENT = 10
```

#### 5. Test Remote Deployment

```bash
# Get auth token from production
# Call create-payhere-session with remote URL
curl -X POST https://pxuydclxnnfgzpzccfoa.supabase.co/functions/v1/create-payhere-session \
  -H "Authorization: Bearer YOUR_PRODUCTION_JWT" \
  ...
```

---

## 📊 Phase 1 Success Criteria

Before Phase 2 Approval ✅

- [ ] **Database**: All 3 migrations applied with 0 errors
- [ ] **RLS**: All 8 tables have RLS enabled + verified
- [ ] **Create-PayHere-Session**: 
  - [ ] Accepts bearer token
  - [ ] Creates booking + payment_transaction atomically
  - [ ] Returns valid PayHere checkout payload
- [ ] **Payment-Webhook**:
  - [ ] MD5 signature verification passes (correct pattern)
  - [ ] Idempotency flag prevents double-processing
  - [ ] Updates booking, wallet, notification on success
  - [ ] Stores verification metadata (md5_signature, webhook_received_at, etc.)
- [ ] **Security**:
  - [ ] Service role key ONLY in Edge Functions
  - [ ] No secrets in frontend env files
  - [ ] Bearer token required for payment functions
  - [ ] RLS prevents cross-user data access
- [ ] **Testing**:
  - [ ] Local payment flow works end-to-end
  - [ ] Webhook signature verification confirmed
  - [ ] No TypeScript errors in build
- [ ] **Documentation**:
  - [ ] MASTER_EXECUTION_PLAN.md created
  - [ ] PHASE_1_IMPLEMENTATION.md with full SQL + code
  - [ ] This deployment guide complete
- [ ] **Git**:
  - [ ] All changes committed to production-hardening branch
  - [ ] Clean git status (no uncommitted changes)
  - [ ] Pushed to GitHub (https://github.com/anasbikes1992-ui/PearlHubcode)

---

## 🆘 Troubleshooting

### Issue: "MD5 signature mismatch"

**Cause**: Signature calculation incorrect  
**Solution**:
1. Verify pattern: `merchant_id + order_id + amount + currency + status_code + upper(md5(merchant_secret))`
2. Verify `md5(merchant_secret)` is uppercase before concatenation
3. Test locally with hardcoded values to confirm calculation

### Issue: "Webhook already processed"

**Cause**: Duplicate webhook from PayHere  
**Solution**: This is normal! Idempotency flag should trigger response 200 OK with "already processed" message

### Issue: "Invalid merchant"

**Cause**: Merchant ID in payload doesn't match environment variable  
**Solution**: Check Supabase Edge Function secrets → PAYHERE_MERCHANT_ID matches payload

### Issue: "Payment transaction not found"

**Cause**: Webhook called before create-payhere-session completes  
**Solution**: PayHere retries webhook automatically; check function logs for timing issues

---

## 📝 Next Steps (Phase 2)

Once Phase 1 is approved (all checkboxes above checked ✅):

1. **Phase 2: Complete Marketplace Flows**
   - PostGIS geosearch
   - Pagination + infinite scroll
   - Availability slots
   - Flutter SDK integration
   - Realtime bookings

2. Create `PHASE_2_MARKETPLACE.md` with detailed implementation

3. Create Phase 2 migration file(s) as needed

---

