# PEARL HUB PRO — Full Platform Audit, Analysis & Development Plan

> **Prepared**: 2026-03-24
> **Scope**: Web App (React) + Flutter Apps (Customer/Provider/Admin) + SDK + Admin God's View
> **Target Build Directory**: `D:\fath1`

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Platform Scorecard](#2-platform-scorecard)
3. [What's Good (Strengths)](#3-whats-good)
4. [What Needs Improvement](#4-what-needs-improvement)
5. [Critical Security Fixes](#5-critical-security-fixes)
6. [Frontend & UI Improvements](#6-frontend--ui-improvements)
7. [Backend & Database Improvements](#7-backend--database-improvements)
8. [Admin Dashboard — God's View Plan](#8-admin-dashboard--gods-view-plan)
9. [Flutter Apps — Completion Plan](#9-flutter-apps--completion-plan)
10. [SDK Development Plan](#10-sdk-development-plan)
11. [SEO & Marketing Strategy](#11-seo--marketing-strategy)
12. [Missing Features & Configs](#12-missing-features--configs)
13. [Growth & Business Development Ideas](#13-growth--business-development-ideas)
14. [Project Structure — D:\fath1](#14-project-structure)
15. [Phase-by-Phase Execution Roadmap](#15-execution-roadmap)
16. [File Inventory — What to Copy](#16-file-inventory)

---

## 1. EXECUTIVE SUMMARY

Pearl Hub Pro is an ambitious **7-vertical marketplace** for Sri Lanka covering Stays, Vehicles, Taxi, Events, Properties, Social, and SME businesses. The web app is ~80% functional with a strong foundation (React 19, Supabase, Zustand, Tailwind). The Flutter monorepo (3 apps + shared package) is ~60% complete with correct architecture (Riverpod + GoRouter) and real Supabase Realtime for taxi tracking.

**Overall Grade: B+** — Strong architecture, good type system, real payment integration (PayHere). Critical gaps: no tests, security vulnerabilities (payment replay, OTP abuse), no SDK, admin dashboard needs God's View with live maps, and ~40% of Flutter screens are stubs.

### Key Numbers
| Metric | Value |
|--------|-------|
| Web Routes | 21 |
| Components | 88 |
| DB Tables | 19 |
| RPC Functions | 11 |
| Edge Functions | 3 |
| Flutter Apps | 3 (customer, provider, admin) |
| Flutter Screens Complete | ~60% |
| Test Coverage | 0% |
| SDK Status | Not started |
| Languages Supported | 8 (en, si, ta, ar, de, fr, ja, zh, ru) |

---

## 2. PLATFORM SCORECARD

| Category | Current | Target | Gap |
|----------|---------|--------|-----|
| **Architecture** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | None |
| **Security** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Payment idempotency, OTP rate limit, CSP |
| **Frontend/UI** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Responsive, accessibility, skeleton loaders |
| **Backend/DB** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Pagination, rate limiting, caching |
| **Admin Control** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | God's View, user management, KYC |
| **Flutter Apps** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Complete stubs, offline mode |
| **SDK** | ⭐ | ⭐⭐⭐⭐⭐ | Not started |
| **Testing** | ⭐ | ⭐⭐⭐⭐ | Unit + integration + E2E |
| **SEO** | ⭐⭐ | ⭐⭐⭐⭐⭐ | SSR, structured data, dynamic sitemap |
| **Marketing** | ⭐⭐ | ⭐⭐⭐⭐⭐ | Analytics, conversion tracking, A/B |
| **DevOps/CI** | ⭐⭐ | ⭐⭐⭐⭐ | CI/CD, staging, monitoring |

---

## 3. WHAT'S GOOD

### Architecture & Tech Stack
- **React 19 + TypeScript + Vite 6** — Cutting-edge, fast HMR, SWC compilation
- **Supabase** — Perfect choice for Sri Lanka (free tier, real-time, auth, edge functions)
- **Zustand + React Query** — Lightweight, performant state management
- **Tailwind CSS** — Consistent design system with 40+ custom tokens
- **Radix UI** — Accessible primitives (50+ components)
- **Flutter Monorepo** — Shared package pattern (models, services) across 3 apps
- **Riverpod + GoRouter** — Industry-standard Flutter state + navigation

### Database Design
- **19 normalized tables** with proper indexing
- **Row-Level Security (RLS)** on all tables
- **Exclusion constraints** preventing double-bookings
- **Trigger-based automation** (auto-award Pearl Points on booking completion)
- **Audit logging** (admin_actions table)
- **Feature flags** (admin_feature_flags with payload support for A/B testing)

### Business Logic
- **7-vertical marketplace** — Comprehensive coverage for Sri Lanka tourism + local economy
- **Pearl Points loyalty** — Smart 1pt/Rs.100 with 0.80 LKR redemption (20% platform margin)
- **Provider tiers** — Gamification (Standard → Verified → Pro → Elite)
- **Commission model** — Clear 10% platform take
- **Multi-currency** — 7 currencies supported
- **8 languages** — Including Sinhala, Tamil (local), Arabic, Chinese, Russian (tourism)

### Security (What's Already Right)
- **Anthropic API key** — Stored as Supabase Edge Function secret, never in client
- **PayHere webhook** — MD5 signature verification (needs upgrade)
- **CSP headers** — Defined in vercel.json (needs tightening)
- **HSTS** — 2-year max-age with preload
- **RLS policies** — Enforced on all tables
- **Role-based auth** — Proper enum-based role system
- **Admin route** — Behind RequireAuth + admin role check

### Flutter Specifics
- **Real Supabase Realtime** for taxi tracking (fixes web app's mock data)
- **Edge Function integration** (AI concierge + payment webhook)
- **FCM dependencies** declared (notifications ready to wire)
- **QR code** generation + scanning libraries included

---

## 4. WHAT NEEDS IMPROVEMENT

### 4.1 Logic & Data Flow Issues

| Issue | Current State | Impact | Fix |
|-------|--------------|--------|-----|
| **Hardcoded sample data** | 3 stays, 3 vehicles, 2 events baked into Zustand store | Users see fake data, DB data ignored | Lazy-load from Supabase, remove hardcoded arrays |
| **Frozen exchange rates** | Set once at app init, never updated | Stale currency conversions | Fetch rates from API (exchangerate-api.com) every 6h |
| **No pagination** | All listings loaded at once | Crashes with 1000+ items | Cursor-based pagination (Supabase `.range()`) |
| **No search debounce** | Every keystroke fires a query | Supabase quota exhaustion | 300ms debounce with `useDeferredValue` |
| **Seat holds no cleanup** | TTL set but no cron/scheduled job | Orphaned seat holds fill table | Supabase pg_cron to delete expired holds |
| **Earnings in webhook** | Sync earnings insert in payment webhook | Slow webhook, potential timeout | Move to Supabase trigger or background job |
| **Session timeout client-only** | 30-min idle check in JS only | Can be bypassed | Server-side token refresh strategy |
| **Magic numbers** | Commission 0.10, timeout 30min, stale 5min | Hard to change, not centralized | Move to `platform_config` table |

### 4.2 Type Safety Issues

| Issue | Fix |
|-------|-----|
| `strictNullChecks: false` | Enable incrementally, fix null assertions |
| `noImplicitAny: false` | Enable, type all parameters |
| `@typescript-eslint/no-unused-vars: "off"` | Set to "warn" |
| Admin types use `any` | Replace with proper generics |
| Supabase generated types not used | Run `supabase gen types typescript` |

### 4.3 Performance Issues

| Issue | Fix | Expected Impact |
|-------|-----|-----------------|
| No lazy route loading | `React.lazy()` + `Suspense` for each page | -40% initial bundle |
| No image optimization | Use Supabase Storage + image transforms | -60% image payload |
| No skeleton loaders | Add Shimmer/skeleton for each listing card | Better perceived perf |
| Translation files loaded eagerly | i18next lazy backend for non-active languages | -200KB initial |
| AdminDashboard.tsx 1700+ lines | Split into sub-modules | Better code splitting |
| Service Worker not managed | Implement SW update prompt | Fresh cache on deploys |

---

## 5. CRITICAL SECURITY FIXES

### Priority 0 — Fix Before Launch

#### 5.1 Payment Webhook Idempotency
```
PROBLEM: Same PayHere webhook can fire multiple times for the same order.
         Each fires earnings + booking update → duplicate entries.

FIX: Add idempotency_key column to bookings table.
     In webhook: CHECK if payment_ref already exists → skip if so.
     Add UNIQUE constraint on (listing_id, payment_ref).
```

#### 5.2 OTP Rate Limiting
```
PROBLEM: otp-sender Edge Function has no rate limit.
         Attacker can request 10,000 OTPs/second → SMTP/WhatsApp bill explosion.

FIX: Add rate_limits table check in otp-sender.
     Max 3 OTPs per phone/email per 15 minutes.
     Max 10 OTPs per IP per hour.
     Return 429 Too Many Requests.
```

#### 5.3 CSP Hardening
```
PROBLEM: Content-Security-Policy allows 'unsafe-eval'.
         Enables XSS escalation.

FIX: Remove 'unsafe-eval' from CSP.
     Use nonce-based script loading for inline scripts.
     Tighten connect-src to exact Supabase project URL.
```

#### 5.4 Payment Signature Upgrade
```
PROBLEM: PayHere uses MD5 for webhook signature.
         MD5 is broken — collisions possible.

FIX: Upgrade to HMAC-SHA256 if PayHere supports it.
     If not, add secondary verification:
     - Call PayHere API to verify payment status server-side.
     - Compare amounts match.
```

#### 5.5 Admin 2FA
```
PROBLEM: Admin accounts have same auth as regular users.
         Single factor = single breach away from full platform access.

FIX: Require TOTP 2FA for all admin accounts.
     Use Supabase Auth MFA API (supabase.auth.mfa.enroll/verify).
     Block admin dashboard access until 2FA verified.
```

---

## 6. FRONTEND & UI IMPROVEMENTS

### 6.1 Web App Improvements

#### Responsive Design Gaps
- [ ] Test all pages at 320px, 375px, 768px, 1024px, 1440px
- [ ] Fix admin dashboard mobile layout (tabs → hamburger on mobile)
- [ ] Add `Suspense` boundaries per route
- [ ] Replace bare `useEffect` data fetches with React Query hooks

#### Accessibility (a11y)
- [ ] ARIA labels on all interactive elements
- [ ] Keyboard navigation for modals, dropdowns
- [ ] Focus trap in modals
- [ ] Color contrast audit (WCAG 2.1 AA)
- [ ] Screen reader testing (VoiceOver + NVDA)
- [ ] Skip-to-content link

#### UX Improvements
- [ ] Skeleton loaders for listing cards (Shimmer)
- [ ] Empty states for zero-result searches
- [ ] Error states with retry buttons
- [ ] Pull-to-refresh feel on mobile web
- [ ] Infinite scroll or "Load More" for listings
- [ ] Breadcrumbs for navigation depth
- [ ] Back-to-top button on long pages
- [ ] Photo gallery with pinch-zoom on mobile
- [ ] Dark mode toggle (already have obsidian theme — expose as toggle)

#### Component Optimization
- [ ] Split AdminDashboard.tsx (1700 lines) into:
  - `admin/tabs/StaysTab.tsx`
  - `admin/tabs/VehiclesTab.tsx`
  - `admin/tabs/TaxiTab.tsx`
  - `admin/tabs/EventsTab.tsx`
  - `admin/tabs/PropertiesTab.tsx`
  - `admin/tabs/SocialTab.tsx`
  - `admin/tabs/SmeTab.tsx`
  - `admin/tabs/UsersTab.tsx`
  - `admin/tabs/SettingsTab.tsx`
  - `admin/tabs/OpsTab.tsx`
  - `admin/components/AdminTable.tsx`
  - `admin/components/InsightCard.tsx`
- [ ] Memoize expensive renders with `React.memo` + `useMemo`
- [ ] Virtualize long lists with `@tanstack/react-virtual`

### 6.2 Design System Standardization
```
Current: 40+ custom Tailwind tokens, inconsistent spacing
Target: Design tokens file with:
  - 8px grid system
  - Typography scale (12/14/16/18/20/24/32/40/48)
  - Consistent border-radius (sm=4 md=8 lg=12 xl=16)
  - Shadow scale (sm/md/lg/xl)
  - Status color map (success=emerald, warning=amber, error=ruby, info=sapphire)
  - Animation duration scale (fast=150ms, normal=300ms, slow=500ms)
```

---

## 7. BACKEND & DATABASE IMPROVEMENTS

### 7.1 Missing Tables

```sql
-- 1. Notifications (push + in-app)
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  type TEXT NOT NULL, -- booking_confirmed, ride_accepted, review_received, etc.
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  read BOOLEAN DEFAULT false,
  channel TEXT DEFAULT 'in_app', -- in_app, push, email, sms
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Favorites/Wishlist
CREATE TABLE favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  listing_id UUID NOT NULL,
  listing_type TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, listing_id, listing_type)
);

-- 3. Disputes
CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES bookings(id),
  raised_by UUID REFERENCES profiles(id),
  reason TEXT NOT NULL,
  evidence_urls TEXT[],
  status TEXT DEFAULT 'open' CHECK (status IN ('open','investigating','resolved','dismissed')),
  resolution TEXT,
  admin_id UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

-- 4. Coupons / Promo Codes
CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  discount_type TEXT CHECK (discount_type IN ('percentage','fixed')),
  discount_value NUMERIC NOT NULL,
  min_order NUMERIC DEFAULT 0,
  max_uses INT DEFAULT 1,
  used_count INT DEFAULT 0,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  applicable_verticals TEXT[] DEFAULT '{}', -- empty = all
  active BOOLEAN DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Referral Program
CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID REFERENCES profiles(id),
  referred_id UUID REFERENCES profiles(id),
  referral_code TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','completed','rewarded')),
  reward_amount NUMERIC DEFAULT 500, -- Rs. 500
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Provider Payouts
CREATE TABLE payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID REFERENCES profiles(id),
  amount NUMERIC NOT NULL,
  currency TEXT DEFAULT 'LKR',
  method TEXT CHECK (method IN ('bank_transfer','mobile_money','payhere')),
  bank_details JSONB,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','processing','completed','failed')),
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. KYC Documents
CREATE TABLE kyc_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  doc_type TEXT CHECK (doc_type IN ('nic_front','nic_back','passport','driving_license','business_reg','bank_statement')),
  file_url TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  admin_notes TEXT,
  reviewed_by UUID,
  reviewed_at TIMESTAMPTZ,
  uploaded_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Analytics Events
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  event_type TEXT NOT NULL, -- page_view, listing_view, search, booking_start, etc.
  properties JSONB DEFAULT '{}',
  session_id TEXT,
  device_type TEXT,
  platform TEXT, -- web, ios, android
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### 7.2 Missing RPC Functions

```sql
-- 1. Dynamic search with pagination
CREATE OR REPLACE FUNCTION search_listings(
  p_query TEXT,
  p_vertical TEXT DEFAULT NULL,
  p_min_price NUMERIC DEFAULT NULL,
  p_max_price NUMERIC DEFAULT NULL,
  p_location TEXT DEFAULT NULL,
  p_lat DOUBLE PRECISION DEFAULT NULL,
  p_lng DOUBLE PRECISION DEFAULT NULL,
  p_radius_km NUMERIC DEFAULT 50,
  p_sort_by TEXT DEFAULT 'relevance',
  p_page INT DEFAULT 1,
  p_per_page INT DEFAULT 20
) RETURNS JSONB;

-- 2. Admin God's View — all active providers with locations
CREATE OR REPLACE FUNCTION admin_gods_view_providers()
RETURNS TABLE (
  provider_id UUID, full_name TEXT, role TEXT, lat DOUBLE PRECISION,
  lng DOUBLE PRECISION, active_listings INT, total_revenue NUMERIC,
  rating NUMERIC, online BOOLEAN, last_seen TIMESTAMPTZ
);

-- 3. Admin God's View — all active rides
CREATE OR REPLACE FUNCTION admin_gods_view_rides()
RETURNS TABLE (
  ride_id UUID, driver_name TEXT, customer_name TEXT,
  pickup_lat DOUBLE PRECISION, pickup_lng DOUBLE PRECISION,
  dropoff_lat DOUBLE PRECISION, dropoff_lng DOUBLE PRECISION,
  current_lat DOUBLE PRECISION, current_lng DOUBLE PRECISION,
  status TEXT, fare NUMERIC, started_at TIMESTAMPTZ
);

-- 4. Platform analytics aggregation
CREATE OR REPLACE FUNCTION admin_platform_analytics(p_period TEXT DEFAULT '30d')
RETURNS JSONB;

-- 5. Revenue breakdown by vertical
CREATE OR REPLACE FUNCTION admin_revenue_by_vertical(p_from TIMESTAMPTZ, p_to TIMESTAMPTZ)
RETURNS TABLE (vertical TEXT, bookings_count INT, gmv NUMERIC, commission NUMERIC);
```

### 7.3 Missing Edge Functions

```
1. notification-sender    — Push via FCM, email via SMTP, SMS via provider
2. exchange-rate-sync     — Fetch rates from ExchangeRate-API, cache in platform_config
3. analytics-ingest       — Batch insert analytics events (client → edge → table)
4. report-generator       — Generate CSV/PDF reports on demand
5. image-optimizer        — Resize + compress uploaded images to Supabase Storage
6. coupon-validator       — Validate + apply coupon codes during checkout
7. payout-processor       — Process provider payouts on schedule
8. kyc-ocr               — NIC/passport OCR for auto-extraction (optional, advanced)
```

### 7.4 Database Improvements

| Improvement | Details |
|-------------|---------|
| **Enable pg_cron** | Schedule: clean expired seat_holds every 5min, sync exchange rates every 6h |
| **Add full-text search** | `tsvector` index on title + description for all listings |
| **GIS extension** | `postgis` for radius-based location search |
| **Materialized views** | Pre-compute admin metrics daily (avoid slow RPC calls) |
| **Connection pooling** | Enable Supavisor for connection pooling |
| **Backup strategy** | Daily automated backups + point-in-time recovery |
| **Read replicas** | For analytics queries (when scale demands it) |

---

## 8. ADMIN DASHBOARD — GOD'S VIEW PLAN

### 8.1 God's View Map (Live)

The centerpiece of the admin upgrade — a **real-time map showing all platform activity**:

```
┌─────────────────────────────────────────────────────────┐
│  🗺  GOD'S VIEW — Pearl Hub Sri Lanka                    │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                                                     │ │
│  │          [LEAFLET MAP — FULL SRI LANKA]              │ │
│  │                                                     │ │
│  │  🟢 Active taxi rides (real-time GPS)                │ │
│  │  🔵 Online providers (by vertical)                   │ │
│  │  🟡 Pending bookings (clustered)                     │ │
│  │  🔴 SOS alerts (if taxi emergency)                   │ │
│  │  📍 Hot zones (high-demand areas)                    │ │
│  │                                                     │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                         │
│  [FILTERS]: Stays | Vehicles | Taxi | Events | All      │
│  [TIME]:    Live | Last 1h | Today | This Week          │
│                                                         │
│  ┌──────────┬──────────┬──────────┬──────────┐          │
│  │ Active   │ Online   │ Pending  │ Revenue  │          │
│  │ Rides: 47│ Provs:312│ Book: 89 │ Today:₨2M│          │
│  └──────────┴──────────┴──────────┴──────────┘          │
└─────────────────────────────────────────────────────────┘
```

**Implementation Plan**:
1. **Map Component**: Leaflet.js (already in project) + marker clustering
2. **Data Source**: Supabase Realtime subscriptions on:
   - `taxi_rides` WHERE status IN ('searching', 'accepted', 'arrived', 'in_transit')
   - `profiles` WHERE role IN (provider roles) AND last_seen > now() - interval '10min'
   - `bookings` WHERE status = 'pending'
3. **Markers**:
   - Color-coded by vertical (stays=blue, vehicles=green, taxi=yellow, events=purple)
   - Click → popup with entity details + quick actions
   - SOS marker = red pulsing with priority alert
4. **Heatmap Layer**: Toggle heatmap showing booking density (last 7 days)
5. **Geofencing**: Draw zones for surge pricing areas, restricted zones

### 8.2 Customer Management Panel

```
CUSTOMER 360° VIEW
├── Profile card (avatar, name, email, phone, NIC, verified ✓)
├── Account status (active/suspended/banned)
├── Booking history (all verticals, with status timeline)
├── Wallet balance + transaction history
├── Pearl Points balance + tier
├── Reviews written (sentiment score)
├── Reports filed + received
├── Communication log (messages, support tickets)
├── Active sessions (device, IP, last seen)
├── Referral tree (who they invited)
└── Actions: Suspend | Ban | Reset Password | Award Points | Send Notification
```

### 8.3 Provider Management Panel

```
PROVIDER 360° VIEW
├── Profile card + KYC status
├── Business details (NIC, business reg, bank details)
├── Active listings (by vertical, with moderation status)
├── Booking pipeline (pending → confirmed → completed)
├── Earnings summary (gross, commission, net, pending payout)
├── Payout history
├── Customer reviews + average rating
├── Response rate + response time
├── Compliance alerts (incomplete listings, expired docs)
├── Provider tier (Standard → Verified → Pro → Elite)
└── Actions: Verify | Upgrade Tier | Suspend | Request KYC | Adjust Commission
```

### 8.4 Full Admin Tab Enhancement Plan

| Tab | Current | Planned Additions |
|-----|---------|-------------------|
| **Overview** | Basic metrics | Revenue chart (7d/30d/90d), funnel (visits→bookings), vertical breakdown |
| **God's View** | NEW | Live map, provider/ride tracking, heatmaps, geofencing |
| **Stays** | Enhanced panel | Occupancy rate, seasonal pricing insights, competitor benchmarks |
| **Vehicles** | Fleet manager | Utilization rate, maintenance alerts, insurance expiry tracking |
| **Taxi** | Surge + fleet | Live dispatch queue, SOS response, driver scoring, route replay |
| **Events** | Enhanced panel | Seat map editor, QR ticket validation dashboard, attendance tracker |
| **Properties** | Enhanced panel | Market value estimator, inquiry funnel, agent performance |
| **Social** | Moderation | Content AI scoring, automated NSFW detection, trending topics |
| **SME** | Enhanced panel | SME performance dashboard, growth coaching tips, marketing ROI |
| **Users** | Basic table | Customer 360°, provider 360°, KYC workflow, bulk actions |
| **Finance** | NEW | Revenue by vertical, commission tracker, payout queue, refund management |
| **Coupons** | NEW | Create/manage promo codes, usage analytics, A/B test campaigns |
| **Referrals** | NEW | Referral tree visualization, reward distribution, fraud detection |
| **Settings** | Config center | Per-vertical SLA controls, feature flags, API key management |
| **Ops** | Basic alerts | SLA breach monitoring, incident tracker, status page management |
| **Reports** | NEW | Custom report builder, scheduled exports, PDF/CSV download |

---

## 9. FLUTTER APPS — COMPLETION PLAN

### 9.1 Current Status

| App | Screens Done | Screens Stub | Completion |
|-----|-------------|--------------|------------|
| **Customer** | 8 (auth, home, taxi×3, booking×2, splash) | 14 (all detail/list screens, profile, wallet, points, concierge, social, sme) | 36% |
| **Provider** | 3 (login, dashboard, earnings partial) | 8 (listings CRUD, booking queue, driver home, CRM) | 27% |
| **Admin** | 2 (login, overview) | 6 (moderation, users, KYC, taxi admin, transactions, settings) | 25% |
| **Shared** | 4 models, 3 services | Needs: notification, analytics, coupon, payout services | 60% |

### 9.2 Customer App — Screens to Build

```
PRIORITY 1 (Core Flow):
 1. StaysListScreen      — Grid/list toggle, filters (price, type, rating, date range)
 2. StayDetailScreen     — Photo gallery, availability calendar, book button, reviews
 3. VehiclesListScreen   — Grid, filters (type, price, driver?, insurance?)
 4. VehicleDetailScreen  — Specs, gallery, availability, book
 5. ProfileScreen        — Edit profile, NIC upload, change password, 2FA setup
 6. WalletScreen         — Balance, top-up (PayHere WebView), transaction history
 
PRIORITY 2 (Engagement):
 7. PropertiesListScreen — Grid, map view, filters (sale/rent, type, price, area)
 8. PropertyDetailScreen — Gallery, map, inquiry form, schedule visit
 9. EventsListScreen     — Cards, calendar view, category filter
10. EventDetailScreen    — Seat map (if enabled), ticket tiers, buy
11. PearlPointsScreen    — Balance, tier progress, redeem interface
12. SocialFeedScreen     — Feed, post creator, likes, comments

PRIORITY 3 (Discovery):
13. SmeListScreen        — Directory, category filter, map view
14. SearchResultsScreen  — Unified cross-vertical search results
15. ConciergeScreen      — Wire Edge Function, chat UI with history
16. NotificationsScreen  — In-app notification center
17. FavoritesScreen      — Saved listings by vertical
```

### 9.3 Provider App — Screens to Build

```
PRIORITY 1:
 1. ListingsScreen       — My listings by vertical, status badges, edit/delete
 2. CreateListingScreen  — Dynamic form by vertical type, image upload, validation
 3. BookingQueueScreen   — Incoming bookings, accept/decline, messaging
 4. DriverHomeScreen     — Go online/offline, incoming ride requests, navigation

PRIORITY 2:
 5. EarningsScreen       — Net earnings chart, payout request, history
 6. CrmScreen            — Customer list, message history, review responses
 7. AnalyticsScreen      — Views, bookings, conversion rate, revenue chart
 8. ProfileScreen        — Edit business info, KYC upload, bank details
```

### 9.4 Admin App — Screens to Build

```
PRIORITY 1:
 1. ListingsModerationScreen — Filter by vertical, approve/reject with notes
 2. UsersScreen              — Search, role filter, suspend/ban, KYC status
 3. KycReviewScreen          — Document viewer, approve/reject, NIC OCR
 4. GodsViewScreen           — Live map (flutter_map), provider/ride markers

PRIORITY 2:
 5. TaxiAdminScreen       — Categories, rates, surge control, driver queue
 6. TransactionsScreen     — Revenue ledger, commission breakdown, refunds
 7. PlatformSettingsScreen — Feature toggles, config editor, rate management
 8. CouponsScreen          — Create/manage promo codes
 9. ReportsScreen          — Download reports, schedule exports
```

### 9.5 Shared Package — Additional Services

```dart
// New services to add to shared/lib/services/

1. notification_service.dart
   - Register FCM token
   - Listen to in-app notifications stream
   - Mark as read/clear

2. analytics_service.dart
   - Track events (page_view, listing_view, search, etc.)
   - Batch send to Edge Function

3. coupon_service.dart
   - Validate coupon code
   - Apply discount to checkout

4. payout_service.dart
   - Request payout
   - Get payout history

5. favorites_service.dart
   - Add/remove favorite
   - Get favorites by vertical

6. kyc_service.dart
   - Upload KYC document
   - Check verification status

7. search_service.dart
   - Cross-vertical search
   - Location-based search with radius

// New models to add to shared/lib/models/

8. notification.dart
9. coupon.dart
10. dispute.dart
11. referral.dart
12. analytics_event.dart
13. kyc_document.dart
14. payout.dart
```

### 9.6 Flutter Build Configuration

```yaml
# Required for each app:

# Android
- android/app/build.gradle (minSdk: 21, targetSdk: 34)
- google-services.json (Firebase)
- AndroidManifest.xml permissions: INTERNET, ACCESS_FINE_LOCATION, CAMERA, READ_EXTERNAL_STORAGE

# iOS
- ios/Runner/Info.plist (location, camera, photo library descriptions)
- GoogleService-Info.plist (Firebase)
- Podfile (iOS 14.0 minimum)

# Environment
- --dart-define=SUPABASE_URL=https://xxx.supabase.co
- --dart-define=SUPABASE_ANON_KEY=xxx
- --dart-define=PAYHERE_MERCHANT_ID=xxx
- --dart-define=ENVIRONMENT=production|staging|development
```

---

## 10. SDK DEVELOPMENT PLAN

### 10.1 SDK-TypeScript (npm package: `@pearlhub/sdk`)

**Target Consumers**: Third-party developers, partners, booking widgets, property portals

```
@pearlhub/sdk/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts              — Main export barrel
│   ├── client.ts             — PearlHubClient class (auth, config)
│   ├── types/
│   │   ├── index.ts          — All type exports
│   │   ├── listings.ts       — Stay, Vehicle, Event, Property, Social, SME types
│   │   ├── bookings.ts       — Booking, Checkout types
│   │   ├── users.ts          — Profile, Role types
│   │   ├── taxi.ts           — Ride, Category, Driver types
│   │   └── common.ts         — Pagination, Filter, Sort types
│   ├── modules/
│   │   ├── auth.ts           — signUp, signIn, signOut, resetPassword, verifyOtp
│   │   ├── stays.ts          — list, get, search, create, update, delete
│   │   ├── vehicles.ts       — list, get, search, create, update, delete
│   │   ├── events.ts         — list, get, search, create, update, delete, holdSeat, releaseSeat
│   │   ├── properties.ts     — list, get, search, create, update, delete
│   │   ├── social.ts         — feed, post, like, comment, report
│   │   ├── sme.ts            — list, get, create, update, verify
│   │   ├── bookings.ts       — create, cancel, getHistory, getDetails
│   │   ├── taxi.ts           — requestRide, cancelRide, trackRide, rateRide
│   │   ├── wallet.ts         — getBalance, topUp, getHistory
│   │   ├── reviews.ts        — create, list, canReview
│   │   ├── favorites.ts      — add, remove, list
│   │   ├── notifications.ts  — list, markRead, registerDevice
│   │   └── admin.ts          — metrics, moderation, users, config, featureFlags
│   ├── realtime/
│   │   ├── index.ts          — RealtimeManager class
│   │   ├── taxi-tracker.ts   — Subscribe to ride updates
│   │   ├── booking-tracker.ts— Subscribe to booking status
│   │   └── chat.ts           — Subscribe to booking messages
│   └── utils/
│       ├── pagination.ts     — Cursor pagination helpers
│       ├── validation.ts     — Zod schemas (re-export from web app)
│       └── errors.ts         — PearlHubError class hierarchy
├── tests/
│   ├── auth.test.ts
│   ├── stays.test.ts
│   └── ...
└── README.md
```

**Usage Example**:
```typescript
import { PearlHubClient } from '@pearlhub/sdk'

const client = new PearlHubClient({
  url: 'https://xxx.supabase.co',
  anonKey: 'xxx',
})

// Auth
await client.auth.signIn({ email: 'user@example.com', password: 'xxx' })

// Search stays
const stays = await client.stays.search({
  location: 'Colombo',
  priceRange: { min: 5000, max: 20000 },
  checkIn: '2026-04-01',
  checkOut: '2026-04-03',
  page: 1,
  perPage: 20,
})

// Real-time taxi tracking
client.taxi.trackRide('ride-uuid', (update) => {
  console.log(update.driverLocation, update.eta, update.status)
})
```

### 10.2 SDK-Dart (pub.dev package: `pearlhub_sdk`)

**Target Consumers**: Flutter developers building custom apps on Pearl Hub platform

```
pearlhub_sdk/
├── pubspec.yaml
├── lib/
│   ├── pearlhub_sdk.dart     — Main library export
│   ├── src/
│   │   ├── client.dart       — PearlHubClient
│   │   ├── config.dart       — PearlHubConfig (url, key, options)
│   │   ├── models/           — Mirrors shared/lib/models/ from Flutter app
│   │   ├── modules/          — Same structure as TS SDK
│   │   ├── realtime/         — Supabase Realtime subscriptions
│   │   └── errors.dart       — Exception hierarchy
├── test/
│   ├── auth_test.dart
│   ├── stays_test.dart
│   └── ...
├── example/
│   └── example.dart
└── README.md
```

### 10.3 SDK Build & Publish Pipeline

```
1. Source from: D:\fath1\sdk-ts/ and D:\fath1\sdk-dart/
2. CI/CD:
   - GitHub Actions: lint → test → build → publish
   - TS SDK: npm publish --access public
   - Dart SDK: dart pub publish
3. Versioning: Semantic versioning (1.0.0)
4. Documentation: TypeDoc (TS) + dartdoc (Dart) → hosted on docs.pearlhub.lk
5. Changelog: Generated from conventional commits
```

---

## 11. SEO & MARKETING STRATEGY

### 11.1 SEO Critical Fixes

| Issue | Current | Fix | Impact |
|-------|---------|-----|--------|
| **No SSR** | Client-side only SPA | Pre-render key pages with `@preact/preset-vite` or migrate to Next.js for key landing pages | +300% organic traffic |
| **No meta tags** | Generic `<title>` | Dynamic meta per page with `react-helmet-async` | +40% click-through |
| **No JSON-LD** | Zero structured data | Add `LocalBusiness`, `LodgingBusiness`, `Event`, `RentalCar`, `Product` schemas | Rich search results |
| **Static sitemap** | 7 hardcoded URLs | Dynamic sitemap from DB (all approved listings) | 100x indexed pages |
| **No canonical URLs** | None | Add `<link rel="canonical">` per page | Prevent duplicate |
| **No Open Graph** | None | OG title, description, image per listing | Social sharing preview |
| **No hreflang** | 8 languages but no signals | `<link rel="alternate" hreflang="si">` etc. | Multi-language SEO |

### 11.2 Dynamic Sitemap Generation

```typescript
// Edge function: generate-sitemap
// Queries all approved listings → generates sitemap XML with:
// - /stays/[slug] for each stay
// - /vehicles/[slug] for each vehicle
// - /events/[slug] for each event
// - /properties/[slug] for each property
// - /sme/[slug] for each business
// - Priority: 0.8 for listings, 1.0 for homepage
// - lastmod: from updated_at
// Serve from /sitemap.xml with 1-hour cache
```

### 11.3 Marketing Features to Implement

| Feature | Description | Revenue Impact |
|---------|-------------|----------------|
| **Referral Program** | Share code → both get Rs. 500 credit | +25% user acquisition |
| **Promo Codes / Coupons** | First booking 10% off, seasonal promos | +15% conversion |
| **Email Marketing** | Welcome series, abandoned booking, review request | +20% retention |
| **Push Notifications** | Price drops, new listings in saved areas, booking reminders | +30% engagement |
| **Provider Verified Badge** | KYC-verified providers rank higher in search | Trust + conversion |
| **Featured Listings** | Providers pay to boost (promoted slots) | New revenue stream |
| **Affiliate Widget** | Embedding widget for travel blogs/sites (via SDK) | Channel expansion |
| **Google Ads Integration** | Conversion tracking, retargeting pixels | Paid acquisition |
| **Social Sharing** | Deep links → listing pages with OG previews | Organic virality |
| **Blog / Content** | Sri Lanka travel guides, "best stays" lists | SEO content |

### 11.4 Analytics Implementation

```
Tracking Layer:
1. Google Analytics 4 (GA4) — Page views, user demographics
2. Custom Analytics (analytics_events table) — Business KPIs
3. Hotjar / Microsoft Clarity — Heatmaps, session recordings (free tier)

Key Events to Track:
- page_view (all pages)
- search (query, filters, results count)
- listing_view (vertical, listing_id)
- booking_started (vertical, amount)
- booking_completed (vertical, amount, payment_method)
- booking_abandoned (step where dropped)
- review_submitted (rating, vertical)
- referral_shared (channel — link, whatsapp, email)
- taxi_requested, taxi_accepted, taxi_completed
- wallet_topup, points_redeemed

Dashboards:
- Conversion funnel: Visit → Search → View → Book → Complete
- Revenue by vertical (daily/weekly/monthly)
- Top providers by revenue
- Geographic demand heatmap
- User acquisition channels
```

---

## 12. MISSING FEATURES & CONFIGS

### 12.1 Missing Platform Configs (platform_config table)

```
CATEGORY: general
- platform_name = "Pearl Hub"
- support_email = "support@pearlhub.lk"
- support_phone = "+94..."
- maintenance_mode = false
- min_app_version_ios = "1.0.0"
- min_app_version_android = "1.0.0"
- force_update = false
- terms_version = "1.0"
- privacy_version = "1.0"

CATEGORY: fees
- provider_commission_rate = 0.10 (needs per-vertical override)
  - stays_commission_rate = 0.12
  - vehicles_commission_rate = 0.10
  - events_commission_rate = 0.08
  - properties_commission_rate = 0.05
  - taxi_commission_rate = 0.15
- wallet_topup_fee = 0.02
- withdrawal_fee = 50 (LKR)
- minimum_payout = 5000 (LKR)

CATEGORY: limits
- max_listings_per_provider = 50
- max_images_per_listing = 10
- max_bookings_per_user_per_day = 10
- max_failed_login_attempts = 5
- lockout_duration_minutes = 30
- max_review_length = 1000
- min_review_length = 10

CATEGORY: taxi
- max_surge_multiplier = 3.0
- min_fare = 300.0
- free_wait_minutes = 5
- per_minute_wait_charge = 15.0
- search_radius_km = 10.0
- max_scheduled_rides_ahead = 5
- driver_acceptance_timeout_seconds = 30
- sos_auto_alert = true

CATEGORY: notifications
- booking_confirm_template = "..."
- otp_email_from = "noreply@pearlhub.lk"
- max_notifications_per_day = 50
- push_enabled = true
- email_enabled = true
- sms_enabled = true
- whatsapp_enabled = true

CATEGORY: payments
- payhere_sandbox = false
- min_topup_amount = 100
- max_topup_amount = 500000
- auto_payout_threshold = 50000
- refund_window_hours = 48
- cancellation_fee_percentage = 0.05
```

### 12.2 Missing Feature Flags

```
feature.referral.enabled = true
feature.coupons.enabled = true
feature.push_notifications.enabled = true
feature.social_feed.enabled = true
feature.sme.directory.enabled = true
feature.provider.analytics.enabled = true
feature.customer.favorites.enabled = true
feature.admin.gods_view.enabled = true
feature.admin.kyc_review.enabled = true
feature.admin.finance_dashboard.enabled = true
feature.admin.bulk_operations.enabled = true
feature.listing.featured.enabled = true
feature.listing.boost.enabled = true
feature.payment.wallet.auto_topup = false
feature.taxi.scheduled_rides.enabled = true
feature.taxi.sos.enabled = true
feature.events.qr_checkin.enabled = true
feature.events.seat_selection.enabled = true
```

---

## 13. GROWTH & BUSINESS DEVELOPMENT IDEAS

### 13.1 Revenue Streams

| Stream | Current | Proposed |
|--------|---------|----------|
| **Booking Commission** | 10% flat | Per-vertical (5-15%) + volume discounts |
| **Featured Listings** | No | Pay-per-impression or monthly premium placement |
| **Subscription Plans** | No | Provider Pro ($49/mo): Lower commission, analytics, badges |
| **Advertising** | No | In-app banner ads for non-competing brands |
| **Data Insights** | No | Anonymized market reports for property developers / tourism boards |
| **White-label** | No | SDK + API for partners to build on platform |
| **Insurance Upsell** | No | Travel/vehicle insurance at checkout (affiliate) |
| **Airport Transfer** | No | Pre-booked taxi at flight arrival (premium pricing) |

### 13.2 Strategic Partnerships

```
1. Sri Lanka Tourism Board     — Official accommodation partner
2. Dialog / Mobitel / Airtel  — Mobile payment integration (carrier billing)
3. Hotels.com / Booking.com  — Channel manager (sync inventory)
4. Uber / PickMe             — Ride API fallback when Pearl Hub drivers not available
5. BOC / Commercial Bank     — Corporate credit card discounts
6. Sri Lankan Airlines       — Miles↔Pearl Points exchange
7. Google Maps               — Verified business listings
8. TripAdvisor               — Review syndication
```

### 13.3 Go-to-Market Phases

```
Phase 1 — Foundation (Month 1-2)
  Target: Colombo metro area only
  Focus: Stays + Taxi (highest frequency + revenue)
  Goal: 100 providers, 1000 users, 500 bookings
  Marketing: Google Ads (Sri Lanka tourism keywords), Facebook/Instagram

Phase 2 — Expansion (Month 3-4)
  Target: Galle, Kandy, Ella, Sigiriya, Trincomalee
  Focus: Add Events + Properties verticals
  Goal: 500 providers, 10,000 users, 5,000 bookings
  Marketing: Content marketing (travel blogs), influencer partnerships

Phase 3 — Full Platform (Month 5-6)
  Target: All Sri Lanka + diaspora (expat mode)
  Focus: Social feed, SME directory, referral program
  Goal: 2,000 providers, 50,000 users, 25,000 bookings
  Marketing: Referral program, PR, travel partnerships

Phase 4 — Scale (Month 7-12)
  Target: International tourists (8 languages live)
  Focus: SDK launch, white-label, analytics products
  Goal: 10,000 providers, 200,000 users, 100,000+ bookings
  Marketing: SEO content flywheel, B2B partnerships
```

### 13.4 Competitive Moat

```
1. HYPER-LOCAL FOCUS — No global platform understands Sri Lanka tuk-tuks, 
   cultural events, Ceylon tea estates, or Ella train rides.

2. 7 VERTICALS IN ONE — Airbnb does stays. Uber does rides. Eventbrite does events. 
   Pearl Hub does ALL with unified wallet + loyalty.

3. SINHALA + TAMIL FIRST — Native language support (not Google Translate) 
   for 22 million locals.

4. OFFLINE RESILIENCE — Sri Lanka has connectivity gaps. 
   Flutter apps with offline-first sync will win.

5. PEARL POINTS LOCK-IN — Cross-vertical loyalty creates switching costs.
   Book a stay → earn points → use for taxi → creates habit loops.

6. PROVIDER TIERS + KYC — Trust through verification (crucial in Sri Lanka 
   where scam listings exist on Facebook Marketplace).
```

---

## 14. PROJECT STRUCTURE — D:\fath1

```
D:\fath1/
├── PLAN.md                          ← This document
├── web/                             ← React web app (copy from PEARL-HUB-PRO-main)
│   ├── [all web app files]
│   └── src/
│       └── pages/admin/             ← Enhanced with God's View
│
├── flutter/                         ← Flutter monorepo (copy from pearlhub_flutter)
│   ├── shared/                      ← Shared Dart package
│   │   ├── lib/models/
│   │   ├── lib/services/
│   │   └── lib/utils/
│   ├── customer/                    ← Customer app
│   ├── provider/                    ← Provider app
│   └── admin/                       ← Admin app
│
├── sdk-ts/                          ← TypeScript SDK (NEW)
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   ├── index.ts
│   │   ├── client.ts
│   │   ├── types/
│   │   ├── modules/
│   │   ├── realtime/
│   │   └── utils/
│   └── tests/
│
├── sdk-dart/                        ← Dart SDK (NEW)
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── pearlhub_sdk.dart
│   │   └── src/
│   └── test/
│
├── supabase/                        ← Shared Supabase config + migrations
│   ├── config.toml
│   ├── migrations/
│   │   ├── [existing migrations]
│   │   ├── 20260325_add_missing_tables.sql
│   │   ├── 20260325_add_gods_view_rpc.sql
│   │   └── 20260325_add_feature_flags.sql
│   └── functions/
│       ├── ai-concierge/
│       ├── otp-sender/
│       ├── payment-webhook/
│       ├── notification-sender/     ← NEW
│       ├── exchange-rate-sync/      ← NEW
│       ├── analytics-ingest/        ← NEW
│       ├── generate-sitemap/        ← NEW
│       └── coupon-validator/        ← NEW
│
├── docs/                            ← Documentation
│   ├── api-reference.md
│   ├── sdk-quickstart.md
│   ├── deployment-guide.md
│   ├── security-audit.md
│   └── architecture.md
│
└── .github/                         ← CI/CD
    └── workflows/
        ├── web-deploy.yml           ← Vercel deploy on push
        ├── flutter-build.yml        ← Build APK + IPA
        ├── sdk-ts-publish.yml       ← npm publish
        └── sdk-dart-publish.yml     ← pub.dev publish
```

---

## 15. EXECUTION ROADMAP

### SPRINT 1 — Foundation & Security (Week 1-2)

```
□ Copy web app to D:\fath1\web\
□ Copy flutter apps to D:\fath1\flutter\
□ Create supabase migration: missing tables (notifications, favorites, disputes, coupons, referrals, payouts, kyc_documents, analytics_events)
□ Fix payment webhook idempotency
□ Add OTP rate limiting
□ Harden CSP (remove unsafe-eval)
□ Enable strictNullChecks (incremental)
□ Run Supabase gen types → update generated types
□ Add God's View RPC functions
□ Add revenue-by-vertical RPC
□ Create platform_config entries for all missing configs
□ Create feature flag entries for all missing flags
```

### SPRINT 2 — Admin God's View + Customer/Provider Management (Week 3-4)

```
□ Build God's View map component (Leaflet + Realtime)
  - Provider markers (color-coded by vertical)
  - Active taxi rides (GPS tracking)
  - Booking heatmap overlay
  - Click-to-details popups
  - SOS alert layer
□ Build Customer 360° panel
  - Profile, bookings, wallet, points, reviews, reports
  - Actions: suspend, ban, award points, notify
□ Build Provider 360° panel
  - Profile, KYC status, listings, earnings, reviews
  - Actions: verify, tier upgrade, suspend, adjust commission
□ Build Finance tab
  - Revenue by vertical chart
  - Commission tracker
  - Payout queue
  - Refund management
□ Build Coupons tab
  - Create/edit promo codes
  - Usage analytics
```

### SPRINT 3 — Flutter Completion (Week 5-7)

```
Customer App:
□ StaysListScreen + StayDetailScreen
□ VehiclesListScreen + VehicleDetailScreen
□ PropertiesListScreen + PropertyDetailScreen
□ EventsListScreen + EventDetailScreen
□ ProfileScreen (edit + KYC upload)
□ WalletScreen (balance + top-up)
□ PearlPointsScreen
□ SocialFeedScreen
□ SmeListScreen
□ NotificationsScreen
□ FavoritesScreen

Provider App:
□ ListingsScreen (CRUD)
□ CreateListingScreen (dynamic form)
□ BookingQueueScreen
□ DriverHomeScreen (online/offline + ride requests)
□ EarningsScreen + payout request
□ CrmScreen

Admin App:
□ GodsViewScreen (flutter_map + Realtime)
□ ListingsModerationScreen
□ UsersScreen + KycReviewScreen
□ TaxiAdminScreen
□ TransactionsScreen
□ PlatformSettingsScreen
□ CouponsScreen
```

### SPRINT 4 — SDK Development (Week 8-9)

```
TypeScript SDK:
□ Scaffold package structure
□ Implement PearlHubClient class
□ Implement all modules (auth, stays, vehicles, events, properties, social, sme, bookings, taxi, wallet, reviews, favorites, notifications, admin)
□ Add Realtime subscription manager
□ Add Zod validation re-exports
□ Write unit tests (>80% coverage)
□ Write README + API docs
□ Publish to npm

Dart SDK:
□ Scaffold package structure
□ Port TS SDK modules to Dart
□ Re-use shared/lib/models from Flutter app
□ Write unit tests
□ Write example app
□ Publish to pub.dev
```

### SPRINT 5 — SEO, Marketing & Polish (Week 10-11)

```
SEO:
□ Add react-helmet-async for dynamic meta tags
□ Add JSON-LD structured data (per listing type)
□ Build dynamic sitemap Edge Function
□ Add hreflang tags for 8 languages
□ Add canonical URLs
□ Add Open Graph + Twitter Card meta

Marketing:
□ Implement referral program (UI + backend)
□ Implement coupon system (UI + backend)
□ Set up GA4 tracking
□ Implement custom analytics events
□ Build email template system (welcome, booking confirm, review request)
□ Add push notification Edge Function + FCM integration

Polish:
□ Responsive audit (320-1440px)
□ Accessibility audit (WCAG 2.1 AA)
□ Performance audit (Lighthouse >90)
□ Skeleton loaders for all listing grids
□ Error boundaries per route
□ Empty states for zero results
```

### SPRINT 6 — Testing & Launch (Week 12)

```
Testing:
□ Web unit tests (Vitest, >70% coverage)
□ Web E2E tests (Playwright, critical flows)
□ Flutter unit tests (>70% coverage)
□ Flutter integration tests (key flows)
□ SDK unit tests (>80% coverage)
□ Security penetration test (basic)
□ Load test (k6 or Artillery, 1000 concurrent)

Launch Prep:
□ Vercel production deploy (web)
□ App Store submission (iOS)
□ Play Store submission (Android)
□ SDK npm + pub.dev publish
□ DNS + SSL for pearlhub.lk
□ Monitoring: Sentry (errors), Uptime Robot (availability)
□ Documentation: API reference, SDK quickstart, deployment guide
```

---

## 16. FILE INVENTORY — WHAT TO COPY

### From `D:\Pearl Hub Pro\PEARL-HUB-PRO-main` → `D:\fath1\web\`
```
Everything EXCEPT:
- node_modules/
- dist/
- .git/
- .env (recreate from template)
```

### From `D:\Pearl Hub Pro\pearlhub_flutter` → `D:\fath1\flutter\`
```
Everything EXCEPT:
- build/
- .dart_tool/
- .git/
- {shared (malformed folder — skip)
```

### From web Supabase → `D:\fath1\supabase\`
```
- supabase/config.toml
- supabase/migrations/ (all .sql files)
- supabase/functions/ (all edge functions)
- MERGE with flutter's supabase/functions/
```

### Create Fresh in `D:\fath1\`
```
- sdk-ts/ (new)
- sdk-dart/ (new)
- docs/ (new)
- .github/workflows/ (new)
- PLAN.md (this file)
```

---

## APPROVAL CHECKPOINT

**Before proceeding with development, confirm:**

1. **Copy Strategy**: Copy web app + flutter app + supabase to `D:\fath1` as described above?
2. **Priority Order**: Sprint 1 (security) → Sprint 2 (admin) → Sprint 3 (flutter) → Sprint 4 (SDK)?
3. **God's View**: Leaflet.js for web, flutter_map for mobile — both using Supabase Realtime?
4. **SDK**: TypeScript + Dart dual SDK? Or start with TS only?
5. **SEO**: Add react-helmet-async now, or defer SSR migration to Next.js?
6. **Flutter**: Complete all 3 apps, or prioritize Customer app first?

**Ready to proceed on your approval. Which sprint should we start with?**

---

> *"The best marketplace is one where both sides — customers and providers — feel they can't live without it."*
> — Pearl Hub Pro Development Thesis
