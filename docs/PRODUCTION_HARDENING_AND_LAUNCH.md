# PearlHub Production Hardening And Launch Guide

## Scope

This document captures the production-hardening changes implemented in `D:\fath1` on the `production-hardening` branch and the exact operational steps to continue from here.

## What changed in this branch

1. Added Supabase project scaffolding:
   - `supabase/config.toml`
   - `supabase/.env.example`
2. Added additive production schema and RLS migrations:
   - `supabase/migrations/0000_production_foundation.sql`
   - `supabase/migrations/0001_rls_policies.sql`
3. Added secure PayHere backend flow:
   - `supabase/functions/create-payhere-session/index.ts`
   - `supabase/functions/payment-webhook/index.ts`
   - `supabase/functions/_shared/payhere.ts`
4. Refactored browser checkout to call the Edge Function instead of inserting bookings directly:
   - `web/src/components/CheckoutModal.tsx`
5. Strengthened deploy CSP for payment gateways in `vercel.json`.
6. Split configuration by trust boundary:
   - `web/.env.example` for client-safe values only
   - ignored `web/.env.local` for local browser-safe config
   - ignored `supabase/.env.local` for local server secrets

## Security model

### Browser-safe config

Use `web/.env.local` for:

```env
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
VITE_SUPABASE_PROJECT_ID=...
VITE_PUBLIC_SITE_URL=http://localhost:5173
VITE_PLATFORM_COMMISSION_PERCENT=10
```

### Server-only secrets

Do not place merchant secrets or service-role keys in any Vite env file.

Use Supabase secrets or local `supabase/.env.local` for:

```env
SUPABASE_SERVICE_ROLE_KEY=...
PAYHERE_MERCHANT_ID=...
PAYHERE_MERCHANT_SECRET=...
PAYHERE_SANDBOX=true
WEBXPAY_MERCHANT_ID=...
WEBXPAY_SECRET=...
WEBXPAY_SANDBOX=true
PUBLIC_SITE_URL=http://localhost:5173
PLATFORM_COMMISSION_PERCENT=10
ESCROW_HOLD_DAYS=2
```

## Phase 0 checklist

1. Clone and switch branch:

```powershell
Set-Location "D:\fath1"
git checkout production-hardening
```

1. Install frontend dependencies:

```powershell
Set-Location "D:\fath1\web"
npm install --legacy-peer-deps
```

1. Authenticate Supabase CLI if needed:

```powershell
Set-Location "D:\fath1"
npx supabase login
```

1. Link the remote project:

```powershell
Set-Location "D:\fath1"
npx supabase link --project-ref pxuydclxnnfgzpzccfoa
```

1. Start local Supabase services if Docker is available:

```powershell
Set-Location "D:\fath1"
npx supabase start
```

## Phase 1 database changes

The new migration pair introduces or hardens these tables:

- `bookings`
- `wallet_transactions`
- `payment_transactions`
- `notifications`
- `disputes`
- `kyc_documents`
- `payouts`
- `platform_config`
- `favorites`
- `messages`
- `availability_slots`

It also adds:

- `pgcrypto`, `postgis`, and `vector`
- escrow fields on bookings
- idempotency key support on payment transactions
- `public.is_admin()` helper
- strict RLS that blocks direct client writes to bookings, wallet transactions, payment transactions, payouts, and platform config
- verified review insert policy tied to completed bookings when `reviews` exists

Apply the migrations with:

```powershell
Set-Location "D:\fath1"
npx supabase db push
```

## Payment architecture now in place

### Checkout creation

Frontend calls `create-payhere-session`.

The function:

1. Verifies the authenticated user from the bearer token.
2. Creates a pending booking server-side.
3. Computes commission and escrow amounts server-side.
4. Creates an idempotent `payment_transactions` row.
5. Returns a signed PayHere form payload and checkout URL.

### Payment confirmation

PayHere posts back to `payment-webhook`.

The webhook:

1. Parses the form body.
2. Recomputes the official PayHere MD5 signature.
3. Rejects invalid signatures.
4. Enforces idempotency on `payment_ref`.
5. Updates `payment_transactions`.
6. Marks the booking as `paid` or `payment_failed`.

### MD5 verification pattern used

```text
merchant_id + order_id + payhere_amount + payhere_currency + status_code + upper(md5(merchant_secret))
```

The same helper module is used by both the session creator and webhook to reduce drift.

## Deploying the Edge Functions

Set secrets first:

```powershell
Set-Location "D:\fath1"
npx supabase secrets set SUPABASE_SERVICE_ROLE_KEY=... PAYHERE_MERCHANT_ID=... PAYHERE_MERCHANT_SECRET=... PAYHERE_SANDBOX=true PUBLIC_SITE_URL=https://pearlhubcode.vercel.app PLATFORM_COMMISSION_PERCENT=10
```

Deploy the functions:

```powershell
Set-Location "D:\fath1"
npx supabase functions deploy create-payhere-session
npx supabase functions deploy payment-webhook --no-verify-jwt
```

Configure PayHere notify URL:

```text
https://pxuydclxnnfgzpzccfoa.supabase.co/functions/v1/payment-webhook
```

## Frontend behavior after this change

`web/src/components/CheckoutModal.tsx` no longer inserts `bookings` or `wallet_transactions` directly from the browser.

Instead it:

1. Creates a secure session through Supabase Edge Functions.
2. Receives a signed PayHere payload.
3. Posts the user to PayHere using a hidden form.

Current state of gateways in the hardened branch:

- `PayHere`: fully wired end-to-end
- `LankaPay`: UI scaffold only
- `WebXPay`: UI scaffold only

## Vercel and CSP

Root `vercel.json` now explicitly allows:

- PayHere checkout endpoints
- WebXPay endpoints
- form submissions to those gateways

This avoids browser CSP breaks during redirect-based checkout.

## Validation performed

- Branch created: `production-hardening`
- Local env scaffolding created
- Migration files added
- Payment functions added
- CheckoutModal refactored to secure session flow

Web build should be validated with:

```powershell
Set-Location "D:\fath1\web"
npm run build
```

## Remaining recommended next steps

1. Add the real `SUPABASE_SERVICE_ROLE_KEY` to Supabase secrets.
2. Run `npx supabase db push` against the linked project.
3. Deploy `create-payhere-session` and `payment-webhook`.
4. Run one full sandbox payment success case and one failed payment case.
5. Add WebXPay and LankaPay session functions in the next payment phase.
6. Move into Phase 2 only after the PayHere webhook path is verified end-to-end.

## GitHub Actions secrets checklist

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`
- `NPM_TOKEN`
- `SUPABASE_SERVICE_ROLE_KEY`
- `PAYHERE_MERCHANT_ID`
- `PAYHERE_MERCHANT_SECRET`
- `WEBXPAY_MERCHANT_ID`
- `WEBXPAY_SECRET`

## Important note on credentials

The repository documentation intentionally uses placeholders for sensitive values.
Actual sandbox values should live only in ignored local env files or in Supabase and GitHub secrets.
