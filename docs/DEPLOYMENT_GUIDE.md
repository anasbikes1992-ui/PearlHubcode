# 🚀 Deployment Guide - PearlHub Production

**Last Updated**: March 25, 2026  
**Status**: Ready for Phase 1 Launch

---

## Quick Start

### For D:\fath1 (Production-Hardening Branch)

```bash
git clone https://github.com/anasbikes1992-ui/PearlHubcode.git
cd PearlHubcode
git checkout production-hardening

# Frontend setup
cd web
npm install --legacy-peer-deps
npm run dev

# Edge Functions setup (separate terminal)
cd supabase
npx supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy
supabase db push
```

---

## 1. Prerequisites

| Component | Version | Purpose |
| --- | --- | --- |
| Node.js | 20+ | Runtime |
| npm | 10+ | Package manager |
| Git | Latest | Version control |
| Supabase CLI | `v1.200+` | Local development & deployment |
| Docker | Latest | Supabase local emulation |

**Installation**:

```bash
# Node.js (from nodejs.org or nvm)
nvm install 20

# Supabase CLI
npm install -g supabase
```

---

## 2. Environment Setup

### Step 1: Provision Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note the **Project ID** and **Anon Key** from Settings → API
4. Set **Region** to Asia-Pacific (Singapore recommended for Sri Lankan users)

### Step 2: Create Local Environment Files

**D:\fath1\web\.env.local** (browser-safe):

```env
# Browser-safe values ONLY (will be visible in client bundle)
VITE_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_SUPABASE_PROJECT_ID=YOUR_PROJECT_ID
VITE_PUBLIC_SITE_URL=http://localhost:5173
VITE_PLATFORM_COMMISSION_PERCENT=10
```

**D:\fath1\supabase\.env.local** (server secrets, NEVER commit):

```env
# Server-only secrets (NOT in Vite env)
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# PayHere (Sandbox)
PAYHERE_MERCHANT_ID=MERCHANT_ID
PAYHERE_MERCHANT_SECRET=MERCHANT_SECRET
PAYHERE_SANDBOX=true

# Payment config
PUBLIC_SITE_URL=http://localhost:5173
PLATFORM_COMMISSION_PERCENT=10
ESCROW_HOLD_DAYS=2

# Future payment gateways (WebXPay, LankaPay)
WEBXPAY_MERCHANT_ID=...
WEBXPAY_SECRET=...
WEBXPAY_SANDBOX=true
```

### Step 3: Authenticate Supabase CLI

```bash
cd D:\fath1
npx supabase login
# Opens browser for authentication, paste key back into terminal
```

---

## 3. Database Deployment

### Step 1: Link Your Project

```bash
cd D:\fath1
supabase link --project-ref YOUR_PROJECT_REF
```

### Step 2: Push Migrations

```bash
supabase db push
```

**What gets created**:
- Tables: `bookings`, `payment_transactions`, `wallet_transactions`, `notifications`, `disputes`, `kyc_documents`, `payouts`, `platform_config`, `favorites`, `messages`, `availability_slots`
- Functions: `public.is_admin()` for role checking
- Extensions: `pgcrypto`, `postgis`, `vector`
- RLS policies: Block direct client writes; only allow Edge Functions

### Step 3: Verify Schema

```bash
supabase db pull  # Downloads schema to local
cat supabase/schema.sql | grep "CREATE TABLE"
```

---

## 4. Edge Functions Deployment

### Step 1: Deploy Payment Functions

```bash
cd D:\fath1

# Deploy create-payhere-session
supabase functions deploy create-payhere-session

# Deploy payment webhook
supabase functions deploy payment-webhook
```

### Step 2: Retrieve Function URLs

```bash
supabase functions list
```

**Output example**:
```
create-payhere-session  https://YOUR_PROJECT_ID.supabase.co/functions/v1/create-payhere-session
payment-webhook         https://YOUR_PROJECT_ID.supabase.co/functions/v1/payment-webhook
```

### Step 3: Configure PayHere Webhook

1. Go to [PayHere Dashboard](https://dashboard.payhere.lk)
2. Settings → Webhooks
3. Add webhook URL: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/payment-webhook`
4. Select events: `PAYMENT_SUCCESS`, `PAYMENT_FAILED`, `PAYMENT_CANCELLED`

---

## 5. Frontend Build & Deployment

### Local Development

```bash
cd D:\fath1\web
npm install --legacy-peer-deps
npm run dev
```

Open http://localhost:5173

### Production Build

```bash
npm run build
```

**Build output**: `dist/` folder ready to deploy

### Deploy to Vercel

**Option A: Using Vercel CLI**

```bash
npm install -g vercel
vercel deploy --prod --scope YOUR_ORG
```

**Option B: GitHub Integration**

1. Push to GitHub
2. Connect repo to Vercel in [vercel.com](https://vercel.com)
3. Set env vars:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
   - `VITE_SUPABASE_PROJECT_ID`
   - `VITE_PUBLIC_SITE_URL`
   - `VITE_PLATFORM_COMMISSION_PERCENT`

---

## 6. Verification Checklist

### Database & Auth

- [ ] Supabase project created
- [ ] Migrations deployed successfully
- [ ] RLS policies active (check Supabase dashboard → Auth → Policies)
- [ ] Can create test user via signup

### Payment Flow

- [ ] `create-payhere-session` function callable
- [ ] `payment-webhook` function receives test payloads
- [ ] PayHere merchant account verified
- [ ] Webhook URL configured in PayHere dashboard
- [ ] Test payment (sandbox mode) completes successfully
- [ ] `payment_transactions` table updated with payment result

### Frontend

- [ ] Production build completes without errors
- [ ] Deployed app loads at https://YOUR_VERCEL_URL
- [ ] Can sign up / log in
- [ ] Checkout modal appears and redirects to PayHere (sandbox)
- [ ] After PayHere redirect, booking created in database

### Monitoring

- [ ] Edge Function logs visible in Supabase dashboard
- [ ] No errors in browser console (DevTools)
- [ ] Payment success rate > 95% (sandbox)

---

## 7. Go-Live Checklist

### Before Flipping Switch to Production

- [ ] All verification checks passed
- [ ] Test payment with real PayHere production credentials
- [ ] Security audit completed:
  - [ ] No .env files or secrets in Git
  - [ ] CORS configured correctly
  - [ ] CSP headers enforced
  - [ ] Rate limiting on Edge Functions
- [ ] Monitoring and alerting set up
- [ ] Database backup automated
- [ ] Support/operations runbook written
- [ ] Team trained on payment troubleshooting

### Production Credentials

1. Move from sandbox to production:
   - Update `PAYHERE_SANDBOX=false` in Supabase secrets
   - Update merchant credentials
   - Update webhook URL (if changed)

2. Scale infrastructure:
   ```bash
   # Increase Supabase database compute
   supabase projects update --compute-size large
   ```

3. Enable additional payment gateways (WebXPay, LankaPay) via Environment Flags

---

## 8. Troubleshooting

### Build Fails: "Missing ESM File"

**Cause**: Package advertises ESM export that doesn't exist on disk.

**Fix**: Already handled in `web/vite.config.ts` with fallback resolver.

**If issue persists**:
```bash
rm -rf node_modules package-lock.json
npm install --legacy-peer-deps
```

### Payment Webhook Not Triggering

**Check**:
1. Is webhook URL correct in PayHere dashboard?
2. Is payment-webhook Edge Function deployed?
3. Test with curl:
   ```bash
   curl -X POST https://YOUR_PROJECT_ID.supabase.co/functions/v1/payment-webhook \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "merchant_id=YOUR_MERCHANT_ID&order_id=TEST123&status_code=2"
   ```

### Supabase Connection Fails

**Check**:
1. Is `.env.local` created in project root?
2. Are `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` correct?
3. Is Supabase project active? (Check dashboard)

**Fix**:
```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db pull  # Sync schema
```

### TypeScript/Build Errors

```bash
# Clear all caches
rm -rf dist .next node_modules
npm install --legacy-peer-deps
npm run build
```

---

## 9. Monitoring & Operations

### Key Metrics to Track

| Metric | Target | Tool |
| --- | --- | --- |
| Payment success rate | > 98% | Supabase dashboard |
| Edge Function latency | < 500ms | Supabase logs |
| Booking creation latency | < 1s  | Browser DevTools |
| Auth failure rate | < 1% | Supabase Auth logs |

### Daily Checks

```bash
# SSH into Supabase and run:
SELECT COUNT(*) as total_payments FROM payment_transactions WHERE created_at > NOW() - INTERVAL '24 hour';
SELECT COUNT(*) FILTER (WHERE status='paid') as paid FROM payment_transactions WHERE created_at > NOW() - INTERVAL '24 hour';
```

### Emergency: Disable Payments

If critical issue found:
1. Set feature flag: `payment_gateway_enabled = false`
2. Update app to show "Maintenance" message
3. Investigate logs
4. Re-enable after fix

---

## 10. Contact & Support

For production issues:

- **Supabase Support**: https://supabase.com/support
- **PayHere Support**: https://payhere.lk/support
- **Vercel Support**: https://vercel.com/help

---

## Phase 2 Roadmap (Future)

- [ ] WebXPay payment integration
- [ ] LankaPay payment integration
- [ ] Dispute resolution Edge Functions
- [ ] KYC document verification
- [ ] Multi-party escrow implementation
- [ ] Analytics Edge Functions

---

