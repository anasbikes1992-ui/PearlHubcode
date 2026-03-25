# PEARL HUB PRO

Sri Lanka's premier multi-vertical marketplace — properties, stays, vehicles, events, SME, and social.

**Stack:** React 19 · TypeScript · Vite · Supabase · Zustand · TanStack Query · Tailwind CSS · shadcn/ui

---

## Getting Started

### 1. Clone and install

```bash
git clone <YOUR_GIT_URL>
cd PEARL-HUB-PRO-main
npm install
```

### 2. Configure environment

Copy `.env.example` to `.env.local` and fill in only browser-safe values:

```bash
cp .env.example .env.local
```

| Variable | Where to find it |
| --- | --- |
| `VITE_SUPABASE_URL` | Supabase dashboard → Project Settings → API |
| `VITE_SUPABASE_ANON_KEY` | Supabase dashboard → Project Settings → API (anon key) |
| `VITE_SUPABASE_PROJECT_ID` | Supabase dashboard → Project Settings → General |

Server-only secrets such as `SUPABASE_SERVICE_ROLE_KEY`, `PAYHERE_MERCHANT_SECRET`, and `WEBXPAY_SECRET` must stay in Supabase Edge Function secrets or `supabase/.env.local` for local backend work.

**Optional — AI Concierge (local dev only):**

```env
# .env.local  (never commit this)
VITE_ANTHROPIC_API_KEY=sk-ant-...
```

> ⚠️ In production, the Anthropic API key must be in a **Supabase Edge Function**, not in a Vite env var. The browser bundle would expose it otherwise.

### 3. Run Supabase migrations

```bash
# Install Supabase CLI if needed
npm install -g supabase

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Push all migrations
supabase db push
```

### 4. Run locally

```bash
npm run dev
```

---

## Security Hardening Applied (Phase 1)

| Issue | Fix |
| --- | --- |
| `.env` with live secrets committed | Scrubbed; `.env` now in `.gitignore` |
| Mock `setTimeout` login | Real Supabase `signInWithPassword` / `signUp` via `AuthContext` |
| Client-side admin role check | `RequireAuth` verifies real Supabase session; RLS enforces server-side |
| No image validation | MIME type + extension + 5MB size guard in `ImageUpload` |
| Mock payment flows | `CheckoutModal` / `WalletModal` write to `bookings` / `wallet_transactions` tables |
| Reviews unverified | `ReviewSection` checks for completed booking via RLS policy + client check |
| No input validation | Zod schemas in `src/lib/validation.ts` used across forms |
| Admin self-promotion | `handle_new_user()` trigger blocks `admin` role on signup |

## Architecture

```
Supabase (PostgreSQL + Auth + Storage + RLS)
    ↕ React Query (cache + background refetch)
Zustand (UI state only: favorites, toasts, compare)
    ↕ React components
```

**Listing pages** (`StaysPage`, `VehiclesPage`, `EventsPage`, `PropertyPage`) now read from Supabase via React Query hooks in `src/hooks/useListings.ts`. The Zustand store is UI-state only.

## Payment Integration

The hardened checkout flow now creates a signed server-side PayHere session through `supabase/functions/create-payhere-session/` and confirms payment through `supabase/functions/payment-webhook/`.

The browser no longer writes `bookings` or `payment_transactions` directly.

## AI Concierge

The `AIConcierge` component calls the Anthropic API. In production:

1. Create `supabase/functions/ai-concierge/index.ts`
2. Move the API call there with `ANTHROPIC_API_KEY` as a Supabase secret
3. Uncomment the Edge Function call in `AIConcierge.tsx` and comment out the direct call

## Database Migrations

| Migration | Purpose |
| --- | --- |
| `phase_0_security_admin_foundations` | `user_reports`, `request_logs`, `admin_actions`, `bookings`, `earnings` |
| `create_properties_listings` | Properties table with RLS |
| `create_social_listings` | Social/community listings |
| `create_wallet_transactions` | Wallet transaction ledger |
| `phase_1_security_hardening` | Booking overlap constraint, reviews (verified only), seat holds, SME tables, input constraints, admin role promotion function |
| `phase_2_data_layer` | Performance indexes, vehicle/stay type columns, `handle_new_user` trigger with role from metadata, `can_review_listing` function |

## Available Scripts

```bash
npm run dev          # Start development server
npm run build        # Production build
npm run lint         # ESLint check
npm run test         # Vitest unit tests
```
