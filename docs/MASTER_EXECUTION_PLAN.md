# 🚀 PearlHub Production Hardening & Launch - Complete Master Plan

**Date**: March 25, 2026  
**Status**: IN EXECUTION  
**Repository**: https://github.com/anasbikes1992-ui/PearlHubcode  
**Branch**: `production-hardening`  
**Path**: D:\fath1  

---

## 📍 Current Credentials (Sandbox)

```env
# Supabase
SUPABASE_URL=https://pxuydclxnnfgzpzccfoa.supabase.co
SUPABASE_ANON_KEY=sb_publishable_XJZSHY9N6n1JVg9JvRd31Q_cJ5kjqBk
SUPABASE_PROJECT_ID=pxuydclxnnfgzpzccfoa
SUPABASE_SERVICE_ROLE_KEY=(Get from Settings → Database → Connection pooling)

# PayHere Configuration (SANDBOX)
PAYHERE_MERCHANT_ID=1211145
PAYHERE_MERCHANT_SECRET=demo_secret_key_123
PAYHERE_SANDBOX=true
PAYHERE_HASH_SECRET=(Get from PayHere merchant dashboard → API Settings)

# WebXPay / LankaPay Configuration (SANDBOX)
WEBXPAY_MERCHANT_ID=TESTMERCHANT
WEBXPAY_SECRET=webxpay_secret_456
WEBXPAY_SANDBOX=true

# Platform Config
PLATFORM_COMMISSION_PERCENT=10
ESCROW_HOLD_DAYS=2
PUBLIC_SITE_URL=http://localhost:5173 (development) | https://yourdomain.com (production)
```

**⚠️ IMPORTANT**: Replace sandbox values with LIVE credentials before public launch.

---

## 🎯 Executive Overview

**Goal**: Transform MVP into a secure, scalable Sri Lanka luxury marketplace with real payments, proper escrow, RLS, and SEO-ready structure.

**Timeline**: 6 Phases (8-12 weeks estimated)  
**Risk Level**: Low (security-first approach, all critical paths tested before user launch)  
**Team Size**: 2-3 developers recommended

**Success Metrics**:
- ✅ 0 payment-related security incidents
- ✅ > 99% payment success rate (sandbox)
- ✅ < 500ms average payment processing time
- ✅ All RLS policies audited & enforced
- ✅ 85%+ code test coverage
- ✅ Soft launch in Colombo with 100+ successful transactions

---

## 📋 Phase Overview

| Phase | Duration | Priority | Status | Owner |
| --- | --- | --- | --- | --- |
| **Phase 0** | 1 day | 🔴 CRITICAL | 🟢 IN EXECUTION | DevOps |
| **Phase 1** | 3-5 days | 🔴 CRITICAL | ⏳ PENDING | Backend |
| **Phase 2** | 5-7 days | 🔴 HIGH | ⏳ PENDING | Full-Stack |
| **Phase 3** | 3-4 days | 🟠 HIGH | ⏳ PENDING | Full-Stack |
| **Phase 4** | 5-7 days | 🟠 MEDIUM | ⏳ PENDING | Frontend |
| **Phase 5** | 7-10 days | 🟡 MEDIUM | ⏳ PENDING | QA/DevOps |
| **Phase 6** | 5-7 days | 🟢 LOW | ⏳ PENDING | Backend/DevOps |

---

## 🔒 Security Principles (NON-NEGOTIABLE)

```
1. SERVICE ROLE KEY ONLY IN EDGE FUNCTIONS
   - Never in frontend .env files
   - Never in client-side code
   - Only used inside Supabase functions

2. RLS ENFORCED ON EVERY TABLE
   - No table allows anonymous full read/write
   - Client can only read/write own data
   - Admins verified via JWT token

3. PAYMENTS ARE IDEMPOTENT
   - Same payment cannot be processed twice
   - Webhook can be called multiple times safely
   - Order IDs are globally unique

4. NO DIRECT CLIENT WRITES TO SENSITIVE TABLES
   - bookings, payment_transactions, wallet_transactions
   - All writes via Edge Functions only
   - Frontend calls functions via secure HTTP with bearer token

5. SECRETS NEVER COMMITTED
   - .env.local in .gitignore
   - Supabase secrets stored in project settings
   - GitHub Actions secrets for CI/CD

6. MD5 SIGNATURE VERIFIED ON EVERY WEBHOOK
   - Correct formula: merchant_id + order_id + amount + currency + status_code + upper(md5(merchant_secret))
   - Signature mismatch = reject immediately
   - Signature verified BEFORE any database changes
```

---

## ✅ Phase 0: Preparation & Setup (DAY 1)

### Objectives
- ✅ Clone and branch the repo
- ✅ Link Supabase CLI to remote project
- ✅ Create local env files (.env.local, .env.example)
- ✅ Add GitHub secrets for CI/CD
- ✅ Verify local Supabase running
- ✅ Document all setup steps

### Tasks

**Task 0.1: Clone & Branch**
```bash
cd ~
git clone https://github.com/anasbikes1992-ui/PearlHubcode.git
cd PearlHubcode
git checkout -b production-hardening
```

**Task 0.2: Install Dependencies**
```bash
# Install Supabase CLI
npm install -g supabase

# Install Node dependencies (web)
cd web
npm install --legacy-peer-deps
cd ..

# Verify Flutter (optional for this phase)
flutter --version
```

**Task 0.3: Create Environment Files**

Create `web/.env.local` (NEVER COMMIT):
```env
# Browser-safe values ONLY
VITE_SUPABASE_URL=https://pxuydclxnnfgzpzccfoa.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_XJZSHY9N6n1JVg9JvRd31Q_cJ5kjqBk
VITE_SUPABASE_PROJECT_ID=pxuydclxnnfgzpzccfoa
VITE_PUBLIC_SITE_URL=http://localhost:5173

# Platform Config
VITE_PLATFORM_COMMISSION_PERCENT=10

# Payment Gateway (sandbox - for reference in client)
VITE_PAYHERE_MERCHANT_ID=1211145
VITE_PAYHERE_SANDBOX=true
```

Create `supabase/.env.local` (NEVER COMMIT):
```env
# Server secrets ONLY (NOT in Vite env)
SUPABASE_SERVICE_ROLE_KEY=<Get from Supabase Settings → Database>
SUPABASE_URL=https://pxuydclxnnfgzpzccfoa.supabase.co

# PayHere (Sandbox)
PAYHERE_MERCHANT_ID=1211145
PAYHERE_MERCHANT_SECRET=demo_secret_key_123
PAYHERE_SANDBOX=true

# WebXPay / LankaPay (Sandbox)
WEBXPAY_MERCHANT_ID=TESTMERCHANT
WEBXPAY_SECRET=webxpay_secret_456
WEBXPAY_SANDBOX=true

# Platform Config
PUBLIC_SITE_URL=http://localhost:5173
PLATFORM_COMMISSION_PERCENT=10
ESCROW_HOLD_DAYS=2
```

**Task 0.4: Authenticate with Supabase**
```bash
supabase login
# Opens browser → Select organization → Authorize → Copy token back to terminal

supabase link --project-ref pxuydclxnnfgzpzccfoa
# Selects your remote project
```

**Task 0.5: Start Local Supabase**
```bash
# Start Docker (required for local Supabase)
docker desktop &

# Start Supabase local dev environment
supabase start
# Output: API URL, Anon Key, Service Role Key, etc.
```

**Task 0.6: Add GitHub Secrets**

Go to: https://github.com/anasbikes1992-ui/PearlHubcode → Settings → Secrets and variables → Actions

Add these secrets:
```
SUPABASE_SERVICE_ROLE_KEY=<value>
PAYHERE_MERCHANT_ID=1211145
PAYHERE_MERCHANT_SECRET=demo_secret_key_123
PAYHERE_SANDBOX=true
PAYHERE_HASH_SECRET=<from PayHere dashboard>
WEBXPAY_MERCHANT_ID=TESTMERCHANT
WEBXPAY_SECRET=webxpay_secret_456
WEBXPAY_SANDBOX=true
VERCEL_ORG_ID=<your Vercel org>
VERCEL_PROJECT_ID=<your Vercel project>
VERCEL_TOKEN=<your Vercel token>
NPM_TOKEN=<for SDK publishing>
```

**Task 0.7: Verify Setup**
```bash
# Test web app locally
cd web
npm run dev
# Opens http://localhost:5173

# In another terminal, verify Supabase
supabase status
# Should show: Docker running, services connected
```

**Deliverable for Phase 0**: 
- ✅ Repo cloned, branch created
- ✅ Local Supabase running
- ✅ Environment files created (.env.local files in .gitignore)
- ✅ GitHub secrets configured
- ✅ Web app & Supabase accessible

---

## 🔐 Phase 1: Security & Foundation Hardening (DAYS 2-6)

**DO'S**: Use service_role key ONLY inside Edge Functions. Enforce RLS on every table. Make all payments idempotent.  
**DON'Ts**: Never commit secrets. Never allow direct client-side writes to bookings, wallet, or payments tables.

### Objectives
- ✅ Create production schema (11 tables + extensions)
- ✅ Implement strict RLS policies
- ✅ Deploy secure payment functions
- ✅ Verify MD5 signature verification
- ✅ Setup idempotency pattern
- ✅ Update CheckoutModal for server-side payments

### Detailed Tasks (See next sections)

---

## Complete Master Documentation

See embedded guides:
- **PHASE_1_SCHEMA_AND_RLS.md** (detailed SQL)
- **PHASE_1_PAYMENT_FUNCTIONS.md** (edge function code)
- **PHASE_2_MARKETPLACE.md** (core flows)
- **PHASE_3_TRUST_AND_ADMIN.md** (moderation, disputes)
- **PHASE_4_SEO_AND_NEXTJS.md** (migration guide)
- **PHASE_5_TESTING.md** (QA & monitoring)
- **PHASE_6_SCALING.md** (performance & upgrades)

---

