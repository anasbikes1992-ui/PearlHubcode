# Pearl Hub — Development Plan V2
## Taxi Restructure · Vehicle Expansion · Admin Controls · Office Transport

> Generated: 2026-03-27 | Based on live site analysis at pearlhubcode.vercel.app

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current Issues Identified](#2-current-issues-identified)
3. [Architecture Changes](#3-architecture-changes)
4. [Phase A — Database Migrations](#phase-a--database-migrations-migration-0007)
5. [Phase B — Taxi Category Restructure](#phase-b--taxi-category-restructure)
6. [Phase C — Vehicle Page Expansion](#phase-c--vehicle-page-expansion--airport-transfers)
7. [Phase D — Parcel System (Uber-style)](#phase-d--parcel-system-uber-style-sendreceive)
8. [Phase E — Office Transport (Bus/Rosa)](#phase-e--office-transport-system-busrosa)
9. [Phase F — Admin Dashboard Rebuild](#phase-f--admin-dashboard-rebuild)
10. [Phase G — CMS Pages Fix](#phase-g--cms-pages-fix)
11. [File Change Map](#file-change-map)
12. [Execution Order](#execution-order)

---

## 1. Executive Summary

This plan restructures the taxi/vehicle/transport system into 4 distinct services with full admin CRUD, proper database persistence, and new business logic for office transportation and airport transfers.

**Key Changes:**
| Current State | Target State |
|---|---|
| 13 vehicle types all under Taxi | Taxi: 6 types · Vehicles: 4 types · Office Transport: 2 types |
| Admin taxi tab uses local-only state | All admin tabs persist to Supabase with full CRUD |
| No airport transfers | Dedicated airport pickup/drop tab under Vehicles |
| Parcel = basic mode toggle | Parcel = Uber-style send/receive with item types, insurance, tracking |
| Bus/Rosa = taxi rides | Office transport with subscriptions, QR, wallets |
| Vehicle admin page empty | Full fleet management with DB queries |
| CMS pages panel empty | CMS pages load from database with fallback |

---

## 2. Current Issues Identified

### 2.1 Taxi Page (TaxiPage.tsx — 327 lines)
| # | Issue | Severity |
|---|---|---|
| T1 | **Broken hero images** — Left column renders LeafletMap, but tiles from `basemaps.cartocdn.com` fail to load on some networks/browsers, showing broken `<img>` placeholder boxes | HIGH |
| T2 | **Distance hardcoded** — `km = 8` placeholder on line 64, no real distance calculation | HIGH |
| T3 | **Ride matching simulated** — 3-second timeout instead of real driver matching via Supabase Realtime | HIGH |
| T4 | **All 13 vehicle types shown** — includes Bus, Rosa Bus, Coach A/C, Luxury Coach which don't belong in ride-hailing | HIGH |
| T5 | **No driver GPS tracking** — Map shows fixed marker at Colombo coordinates | MEDIUM |
| T6 | **Parcel mode too basic** — Just recipient/phone/size, no item type, no tracking, no insurance | MEDIUM |

### 2.2 Vehicles Page (VehiclesPage.tsx — 519 lines)
| # | Issue | Severity |
|---|---|---|
| V1 | **No vehicles in database** — `useVehicles` queries `vehicles_listings` which is empty; page shows Zustand seed data only | HIGH |
| V2 | **No airport transfer option** — Missing service type entirely | HIGH |
| V3 | **Delete button incomplete** — Click handler has `/* delete logic */` comment, no implementation | MEDIUM |
| V4 | **No coach/luxury coach category** — Should be moved here from Taxi | MEDIUM |

### 2.3 Admin Dashboard — Vehicles Tab
| # | Issue | Severity |
|---|---|---|
| A1 | **AdminTable uses Zustand store** — Only shows 3 hardcoded seed vehicles, not DB data | CRITICAL |
| A2 | **No add vehicle for admin** — Can only change status, cannot create vehicles | HIGH |
| A3 | **No availability management** — No calendar/scheduling view | MEDIUM |

### 2.4 Admin Dashboard — Taxi Tab (AdvancedVehicleManager)
| # | Issue | Severity |
|---|---|---|
| A4 | **All state is local `useState`** — Category rates, vehicles, surge all reset on page reload | CRITICAL |
| A5 | **Vehicles hardcoded** — 3 static vehicles in component state, not from DB | CRITICAL |
| A6 | **Category rates hardcoded** — 6 categories with rates in component state, DB has 13 seeded categories | HIGH |
| A7 | **`Math.random()` for availability** — Line 1946: `available: vehicles.filter(v => v.status === 'active' && Math.random() > 0.3)` | HIGH |
| A8 | **No bus/rosa management** — These should move to a separate office transport section | MEDIUM |

### 2.5 Admin Dashboard — CMS Pages Tab
| # | Issue | Severity |
|---|---|---|
| P1 | **Pages list empty** — Migration 0006 creates `site_pages` table but may not have been applied to production Supabase | HIGH |
| P2 | **No delete page action** — Can create and edit but not remove pages | MEDIUM |
| P3 | **No markdown preview** — Content is plain textarea, no live preview | LOW |

---

## 3. Architecture Changes

### 3.1 Vehicle Category Redistribution

```
BEFORE (all under Taxi):                  AFTER (split across 3 services):
├─ Moto                                   TAXI (ride-hailing)
├─ TUK TUK                               ├─ Moto
├─ Car Economy                            ├─ TUK TUK
├─ Car Electric                           ├─ Car Economy
├─ Car Premium                            ├─ Car Electric
├─ Buddy Van                              ├─ Car Premium
├─ Van                                    └─ Buddy Van
├─ Premium Van
├─ SUV                                    VEHICLE RENTAL (daily/multi-day)
├─ Rosa Bus A/C                           ├─ [Existing: car, van, suv, bus]
├─ Bus                                    ├─ Coach A/C        ← moved from taxi
├─ Coach A/C                              ├─ Luxury Coach     ← moved from taxi
├─ Luxury Coach                           └─ Airport Transfer ← NEW
                                          
                                          OFFICE TRANSPORT (subscription)
                                          ├─ Rosa Bus A/C     ← moved from taxi
                                          └─ Bus              ← moved from taxi
```

### 3.2 New Database Tables Required

```
NEW TABLES:
├─ office_transport_routes         — Bus routes with stops, times
├─ office_transport_subscriptions  — User weekly/monthly subscription plans
├─ office_transport_wallets        — User wallet balance
├─ office_transport_wallet_txns    — Wallet top-up/debit history
├─ office_transport_trips          — Individual trip scan records
├─ office_transport_qr_codes       — QR code tokens for entry/exit
├─ airport_transfer_bookings       — Airport pickup/drop bookings
├─ parcel_deliveries               — Enhanced parcel tracking
├─ parcel_item_types               — Item categories (documents, food, etc.)

ALTERED TABLES:
├─ taxi_vehicle_categories         — Add `service_type` column (taxi/vehicle/office_transport)
├─ vehicles_listings               — Add `listing_subtype` column (rental/airport_transfer/coach)
```

---

## Phase A — Database Migration (migration 0007)

**File:** `supabase/migrations/0007_transport_restructure.sql`

### A.1 — Categorize Existing Taxi Vehicles

```sql
-- Add service_type to taxi_vehicle_categories
ALTER TABLE taxi_vehicle_categories 
  ADD COLUMN IF NOT EXISTS service_type TEXT DEFAULT 'taxi' 
  CHECK (service_type IN ('taxi', 'vehicle_rental', 'office_transport'));

-- Reclassify categories
UPDATE taxi_vehicle_categories SET service_type = 'office_transport' 
  WHERE name IN ('Rosa Bus A/c', 'Bus');
UPDATE taxi_vehicle_categories SET service_type = 'vehicle_rental' 
  WHERE name IN ('Coach A/c', 'Luxury Coach');
-- Remaining 9 stay as 'taxi'
```

### A.2 — Office Transport Tables

```sql
-- Subscription plans
CREATE TABLE IF NOT EXISTS public.office_transport_plans (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,                          -- e.g., "Weekly Basic", "Monthly Premium"
  duration     TEXT NOT NULL CHECK (duration IN ('weekly', 'monthly')),
  price        NUMERIC NOT NULL,                       -- LKR
  ride_limit   INT,                                    -- NULL = unlimited
  km_limit     NUMERIC,                                -- NULL = unlimited
  is_active    BOOLEAN DEFAULT true,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Routes
CREATE TABLE IF NOT EXISTS public.office_transport_routes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,                          -- e.g., "Colombo CBD Loop"
  vehicle_category_id UUID REFERENCES taxi_vehicle_categories(id),
  provider_id  UUID REFERENCES auth.users(id),         -- bus company/conductor
  stops        JSONB NOT NULL DEFAULT '[]',            -- [{name, lat, lng, order, arrival_time}]
  departure_time TIME NOT NULL,
  return_time  TIME,
  days_active  TEXT[] DEFAULT '{Mon,Tue,Wed,Thu,Fri}',
  fare_per_km  NUMERIC DEFAULT 15,
  flat_fare    NUMERIC,                                -- alternative to per-km
  status       TEXT DEFAULT 'active',
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- User subscriptions
CREATE TABLE IF NOT EXISTS public.office_transport_subscriptions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id      UUID NOT NULL REFERENCES office_transport_plans(id),
  route_id     UUID REFERENCES office_transport_routes(id),
  status       TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
  started_at   TIMESTAMPTZ DEFAULT now(),
  expires_at   TIMESTAMPTZ NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Wallets
CREATE TABLE IF NOT EXISTS public.office_transport_wallets (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance      NUMERIC NOT NULL DEFAULT 0 CHECK (balance >= 0),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

-- Wallet transactions
CREATE TABLE IF NOT EXISTS public.office_transport_wallet_txns (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type         TEXT NOT NULL CHECK (type IN ('topup', 'debit', 'refund', 'subscription')),
  amount       NUMERIC NOT NULL,
  balance_after NUMERIC NOT NULL,
  reference    TEXT,                                    -- payment ref or trip id
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- Trip records (QR scan based)
CREATE TABLE IF NOT EXISTS public.office_transport_trips (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  route_id     UUID NOT NULL REFERENCES office_transport_routes(id),
  subscription_id UUID REFERENCES office_transport_subscriptions(id),
  provider_id  UUID REFERENCES auth.users(id),         -- conductor account
  entry_stop   TEXT,
  exit_stop    TEXT,
  entry_time   TIMESTAMPTZ DEFAULT now(),
  exit_time    TIMESTAMPTZ,
  distance_km  NUMERIC,
  fare_charged NUMERIC DEFAULT 0,
  status       TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'cancelled')),
  qr_token     TEXT UNIQUE,                            -- scanned QR token
  created_at   TIMESTAMPTZ DEFAULT now()
);
```

### A.3 — Airport Transfers

```sql
-- Airport transfer bookings
CREATE TABLE IF NOT EXISTS public.airport_transfers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id     UUID REFERENCES auth.users(id),
  transfer_type   TEXT NOT NULL CHECK (transfer_type IN ('pickup', 'drop')),
  airport         TEXT NOT NULL DEFAULT 'BIA',          -- Bandaranaike International
  flight_number   TEXT,
  flight_time     TIMESTAMPTZ NOT NULL,
  pickup_address  TEXT NOT NULL,
  vehicle_type    TEXT NOT NULL,                        -- car, van, suv, luxury
  passengers      INT DEFAULT 1,
  luggage_count   INT DEFAULT 1,
  special_requests TEXT,
  fare            NUMERIC NOT NULL,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'driver_assigned', 'in_transit', 'completed', 'cancelled')),
  payment_status  TEXT DEFAULT 'pending',
  payment_method  TEXT DEFAULT 'cash',
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);
```

### A.4 — Enhanced Parcel System

```sql
-- Parcel item types
CREATE TABLE IF NOT EXISTS public.parcel_item_types (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE,                   -- Documents, Food, Electronics, etc.
  icon         TEXT DEFAULT '📦',
  max_weight_kg NUMERIC DEFAULT 30,
  base_fee     NUMERIC DEFAULT 100,
  is_active    BOOLEAN DEFAULT true
);

-- Insert default item types
INSERT INTO parcel_item_types (name, icon, max_weight_kg, base_fee) VALUES
  ('Documents', '📄', 2, 100),
  ('Food & Beverages', '🍱', 10, 150),
  ('Electronics', '💻', 15, 300),
  ('Clothing', '👕', 10, 120),
  ('Fragile Items', '⚠️', 20, 400),
  ('General Package', '📦', 30, 200)
ON CONFLICT (name) DO NOTHING;

-- Enhanced parcel deliveries
CREATE TABLE IF NOT EXISTS public.parcel_deliveries (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id          UUID REFERENCES taxi_rides(id),     -- links to taxi_rides for driver assignment
  sender_id        UUID NOT NULL REFERENCES auth.users(id),
  item_type_id     UUID REFERENCES parcel_item_types(id),
  recipient_name   TEXT NOT NULL,
  recipient_phone  TEXT NOT NULL,
  pickup_address   TEXT NOT NULL,
  pickup_lat       FLOAT8,
  pickup_lng       FLOAT8,
  dropoff_address  TEXT NOT NULL,
  dropoff_lat      FLOAT8,
  dropoff_lng      FLOAT8,
  weight_kg        NUMERIC,
  dimensions       TEXT,                               -- e.g., "30x20x15 cm"
  is_fragile       BOOLEAN DEFAULT false,
  insurance_opted  BOOLEAN DEFAULT false,
  insurance_amount NUMERIC DEFAULT 0,
  declared_value   NUMERIC DEFAULT 0,
  special_instructions TEXT,
  status           TEXT DEFAULT 'pending' CHECK (status IN (
    'pending', 'driver_assigned', 'picked_up', 'in_transit', 'delivered', 'returned', 'cancelled'
  )),
  otp_code         TEXT,                               -- delivery confirmation OTP
  delivered_at     TIMESTAMPTZ,
  fare             NUMERIC,
  created_at       TIMESTAMPTZ DEFAULT now()
);
```

### A.5 — Vehicles Listings Enhancement

```sql
-- Add subtype to vehicles_listings
ALTER TABLE vehicles_listings 
  ADD COLUMN IF NOT EXISTS listing_subtype TEXT DEFAULT 'rental' 
  CHECK (listing_subtype IN ('rental', 'airport_transfer', 'coach'));
```

### A.6 — RLS Policies

```sql
-- Office Transport RLS
ALTER TABLE office_transport_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads active plans" ON office_transport_plans FOR SELECT USING (is_active = true);
CREATE POLICY "Admins manage plans" ON office_transport_plans FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

ALTER TABLE office_transport_routes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads active routes" ON office_transport_routes FOR SELECT USING (status = 'active');
CREATE POLICY "Admins manage routes" ON office_transport_routes FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Providers manage own routes" ON office_transport_routes FOR ALL USING (provider_id = auth.uid());

ALTER TABLE office_transport_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own subs" ON office_transport_subscriptions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Admins manage subs" ON office_transport_subscriptions FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

ALTER TABLE office_transport_wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own wallet" ON office_transport_wallets FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "System manages wallets" ON office_transport_wallets FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

ALTER TABLE office_transport_wallet_txns ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own txns" ON office_transport_wallet_txns FOR SELECT USING (user_id = auth.uid());

ALTER TABLE office_transport_trips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own trips" ON office_transport_trips FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Providers view route trips" ON office_transport_trips FOR SELECT USING (provider_id = auth.uid());
CREATE POLICY "Admins view all trips" ON office_transport_trips FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

ALTER TABLE airport_transfers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own transfers" ON airport_transfers FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users create transfers" ON airport_transfers FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins manage transfers" ON airport_transfers FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

ALTER TABLE parcel_deliveries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own parcels" ON parcel_deliveries FOR SELECT USING (sender_id = auth.uid());
CREATE POLICY "Users create parcels" ON parcel_deliveries FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Admins manage parcels" ON parcel_deliveries FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

ALTER TABLE parcel_item_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone reads item types" ON parcel_item_types FOR SELECT USING (is_active = true);
CREATE POLICY "Admins manage item types" ON parcel_item_types FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
```

---

## Phase B — Taxi Category Restructure

### B.1 — Filter Taxi Categories (TaxiPage.tsx)

**Change:** Modify `useTaxiCategories` call to only show `service_type = 'taxi'` categories (Moto, TUK TUK, Car Economy, Car Electric, Car Premium, Buddy Van).

**File:** `web/src/hooks/useListings.ts`
```typescript
// BEFORE:
.eq("is_active", true)

// AFTER:
.eq("is_active", true)
.eq("service_type", "taxi")
```

This immediately removes Bus, Rosa Bus, Coach, Luxury Coach from the taxi booking page.

### B.2 — Fix Taxi Page Broken Images

**Root Cause:** The left column uses `<LeafletMap>` which loads tiles from CartoCDN. On some networks/CSP configurations, tiles fail to load showing broken placeholders.

**Fix:** Add a fallback tile provider + loading state with a gradient placeholder if tiles fail.

**File:** `web/src/components/LeafletMap.tsx`
- Add `onerror` handler on tileLayer to swap to OSM fallback
- Replace broken image areas with a styled gradient when map hasn't loaded
- Add error boundary for tile loading failures

### B.3 — Parcel Mode Enhancement

**File:** `web/src/pages/TaxiPage.tsx` — Parcel section rewrite

**New Parcel Flow (Uber Send-style):**
```
1. Select Item Type    → dropdown from parcel_item_types table
2. Enter Details       → weight, dimensions, fragile toggle, instructions
3. Pickup Address      → with map pin selection
4. Drop Address        → with map pin selection  
5. Insurance Option    → checkbox + declared value input
6. Delivery OTP        → auto-generated, recipient confirms via OTP
7. Live Tracking       → real-time on map via driver location
8. Proof of Delivery   → photo capture + OTP confirmation
```

**New state additions:**
```typescript
const [parcelItemTypes, setParcelItemTypes] = useState<ParcelItemType[]>([]);
const [selectedItemType, setSelectedItemType] = useState<string | null>(null);
const [weight, setWeight] = useState("");
const [dimensions, setDimensions] = useState("");
const [isFragile, setIsFragile] = useState(false);
const [wantInsurance, setWantInsurance] = useState(false);
const [declaredValue, setDeclaredValue] = useState("");
const [specialInstructions, setSpecialInstructions] = useState("");
const [dropoffAddress, setDropoffAddress] = useState("");
```

**New hook:** `useParcelItemTypes()` in `useListings.ts`

### B.4 — Fare Calculation Fix

Replace hardcoded `km = 8` with either:
- **Option A** (recommended): Let user input estimated distance via stop selection
- **Option B** (future): Integrate with OSRM or Google Directions API for real distance

**Immediate fix:** Use Haversine formula from pickup/dropoff coordinates as distance estimate.

```typescript
const haversineKm = (lat1: number, lon1: number, lat2: number, lon2: number) => {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180) * Math.cos(lat2*Math.PI/180) * Math.sin(dLon/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)) * 1.3; // 1.3x road factor
};
```

---

## Phase C — Vehicle Page Expansion + Airport Transfers

### C.1 — Connect Vehicles to Database

**Problem:** VehiclesPage filters via `useVehicles()` which queries `vehicles_listings` table. This table is either empty or has no `approved` entries. The Zustand store seed data (`INITIAL_VEHICLES`) is used for display but never written to DB.

**Fix options:**
1. **Seed `vehicles_listings`** with the 3 initial vehicles via migration
2. **Or** modify the admin "Add Vehicle" flow to insert into `vehicles_listings`
3. **And** the admin "Vehicles" tab should query `vehicles_listings` instead of Zustand

**Recommendation:** Do both. Seed data AND make admin CRUD use `vehicles_listings`.

**File:** Migration 0007 — Add seed vehicles:
```sql
INSERT INTO vehicles_listings (user_id, make, model, year, type, price, price_unit, seats, location, vehicle_type, moderation_status, active)
VALUES
  ('ADMIN_USER_ID', 'Toyota', 'Prius', 2022, 'car', 6500, 'day', 5, 'Colombo', 'car', 'approved', true),
  ('ADMIN_USER_ID', 'Toyota', 'Hiace', 2021, 'van', 12500, 'day', 12, 'Colombo', 'van', 'approved', true),
  ('ADMIN_USER_ID', 'Mitsubishi', 'Montero', 2019, 'suv', 25000, 'day', 7, 'Colombo', 'suv', 'approved', true);
```

### C.2 — Add Coach & Luxury Coach to Vehicles

**File:** `web/src/pages/VehiclesPage.tsx`

Add new filter categories:
```typescript
// BEFORE:
const vehicleTypes = ['All', 'Cars', 'Vans', 'SUVs', 'Buses', 'Luxury Coach'];

// AFTER:
const vehicleTypes = ['All', 'Cars', 'Vans', 'SUVs', 'Buses', 'Coaches', 'Luxury Coach', 'Airport'];
```

Map `Coaches` → `vehicle_type = 'coach'` and `Airport` → `listing_subtype = 'airport_transfer'`.

### C.3 — Airport Transfer Tab/Section

**New component:** `AirportTransferSection` within VehiclesPage (or separate page `AirportTransferPage.tsx`)

**UI Flow:**
```
┌──────────────────────────────────────────────┐
│  ✈️  AIRPORT TRANSFER BOOKING                │
├──────────────────────────────────────────────┤
│  Transfer Type:  [Pickup ▪] [Drop]           │
│  Airport:        [Bandaranaike (CMB) ▼]      │
│  Flight Number:  [UL 505          ]          │
│  Flight Time:    [2026-03-28 14:30 ]         │
│  Address:        [123 Galle Road, Col 3]     │
│  Vehicle:        [Sedan] [Van] [SUV] [Lux]   │
│  Passengers:     [2 ▼]   Luggage: [3 ▼]     │
│  Special Notes:  [_________________ ]         │
│                                              │
│  ┌─────────────────────────────────────────┐ │
│  │ FARE ESTIMATE                           │ │
│  │ Base fare:    Rs. 4,500                 │ │
│  │ Vehicle:      SUV (+Rs. 1,500)          │ │
│  │ Night surcharge: Rs. 0                  │ │
│  │ TOTAL:        Rs. 6,000                 │ │
│  └─────────────────────────────────────────┘ │
│  [Book Airport Transfer — Rs. 6,000]         │
└──────────────────────────────────────────────┘
```

**Fare logic:**
```typescript
const AIRPORT_RATES = {
  sedan:  { base: 3500, perKm: 45 },
  van:    { base: 5000, perKm: 55 },
  suv:    { base: 6000, perKm: 65 },
  luxury: { base: 8500, perKm: 85 },
};
const NIGHT_SURCHARGE = 500; // 22:00 - 05:00
const BIA_COORDS = { lat: 7.1801, lng: 79.8841 }; // Bandaranaike Airport
```

---

## Phase D — Parcel System (Uber-style Send/Receive)

### D.1 — Parcel Dashboard Restructure

**File:** `web/src/pages/TaxiPage.tsx` → Extract to `ParcelSection` component

**New Parcel UI (replaces current basic mode):**
```
┌──────────────────────────────────────────────┐
│  📦  SEND A PARCEL                           │
├──────────────────────────────────────────────┤
│  What are you sending?                       │
│  [📄 Docs] [🍱 Food] [💻 Elect] [📦 General]│
│                                              │
│  Pickup:   [📍 123 Galle Road         ]      │
│  Drop-off: [📍 45 Kandy Road          ]      │
│                                              │
│  Weight:   [___ kg]  Fragile: [✓]            │
│  Size:     [S] [M] [L] [XL]                  │
│                                              │
│  Recipient: [Name           ]                │
│  Phone:     [+94 77 xxx xxxx]                │
│  Notes:     [Handle with care...     ]       │
│                                              │
│  ┌─────────────────────────────┐             │
│  │ 🛡️ Insurance (Optional)     │             │
│  │ Declared value: Rs. [5000]  │             │
│  │ Insurance fee:  Rs. 250     │             │
│  │ [✓] Add insurance           │             │
│  └─────────────────────────────┘             │
│                                              │
│  DELIVERY FEE: Rs. 350                       │
│  [Send Parcel — Rs. 350]                     │
└──────────────────────────────────────────────┘
```

### D.2 — Parcel Tracking Page

**New file:** `web/src/pages/ParcelTrackingPage.tsx`

**States:** pending → driver_assigned → picked_up → in_transit → delivered

**Features:**
- Live map with driver location
- Timeline of status updates
- OTP confirmation on delivery
- Proof of delivery photo
- Receipt download

### D.3 — Admin Parcel Dashboard

Add to admin `taxi` or new `parcels` tab:
- Active deliveries list
- Delivery driver assignment
- Item type management (add/edit/remove)
- Insurance rate configuration
- Delivery fee calculator settings

---

## Phase E — Office Transport System (Bus/Rosa)

### E.1 — New Page: OfficeTransportPage.tsx

**Concept:** Pre-subscribed office commuters board Rosa Bus/Bus, scan QR on entry, scan on exit (or tap "End Trip" in app). Fare is deducted from wallet. Conductor (provider) gets notification.

**User Flow:**
```
1. Browse Routes      → See available bus routes with stops/times
2. Subscribe          → Choose weekly/monthly plan, pay to top up wallet
3. Board Bus          → Open app → "Start Trip" → shows QR code
4. Conductor Scans    → Conductor app scans QR → confirms entry
5. Ride               → Real-time route tracking on map
6. Exit               → Scan QR again OR tap "End Trip" in app
7. Fare Deducted      → Wallet balance decremented
8. Conductor Notified → Provider sees trip completed + passenger count
```

**UI Layout:**
```
┌──────────────────────────────────────────────────────┐
│  🚌 OFFICE TRANSPORT                                 │
│  Smart commute with Pearl Bus                        │
├──────────────────────────────────────────────────────┤
│                                                      │
│  MY SUBSCRIPTION: Monthly Premium — Rs. 4,500/mo     │
│  Wallet: Rs. 2,350  [Top Up]                         │
│  Rides this month: 42                                │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │ ACTIVE TRIP                      [End Trip]  │    │
│  │ Route: Colombo CBD Loop                      │    │
│  │ Entry: Fort Railway Station @ 08:15          │    │
│  │ Duration: 23 min                             │    │
│  │ [Show QR Code]                               │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  AVAILABLE ROUTES                                    │
│  ┌────────────────────┐ ┌────────────────────┐       │
│  │ 🚌 CBD Loop        │ │ 🚌 Airport Express │       │
│  │ Rosa Bus A/C       │ │ Bus               │        │
│  │ Mon-Fri 07:00-19:00│ │ Daily 05:00-23:00 │        │
│  │ 12 stops           │ │ 8 stops           │        │
│  │ Rs. 15/km          │ │ Rs. 12/km         │        │
│  │ [View Route]       │ │ [View Route]      │        │
│  └────────────────────┘ └────────────────────┘       │
│                                                      │
│  SUBSCRIPTION PLANS                                  │
│  [Weekly Basic Rs.1200] [Monthly Rs.4500] [Premium]  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### E.2 — QR Code System

**File:** `web/src/components/QRCodeScanner.tsx`

**Entry flow:**
```typescript
// User generates QR token
const startTrip = async (routeId: string) => {
  const qrToken = crypto.randomUUID();
  const { data: trip } = await db.from('office_transport_trips').insert({
    user_id: user.id,
    route_id: routeId,
    qr_token: qrToken,
    entry_time: new Date().toISOString(),
    status: 'in_progress'
  }).select().single();
  
  return { tripId: trip.id, qrToken }; // Display as QR code
};
```

**Exit flow (conductor scans or user ends trip):**
```typescript
const endTrip = async (tripId: string, exitStop?: string) => {
  // Calculate fare based on entry/exit stops
  const { data: trip } = await db.from('office_transport_trips')
    .select('*, route:office_transport_routes(*)')
    .eq('id', tripId).single();
  
  const distanceKm = calculateRouteDistance(trip.entry_stop, exitStop, trip.route.stops);
  const fare = trip.route.flat_fare || (distanceKm * trip.route.fare_per_km);
  
  // Debit wallet
  await db.rpc('debit_office_transport_wallet', {
    p_user_id: trip.user_id,
    p_amount: fare,
    p_reference: tripId
  });
  
  // Complete trip
  await db.from('office_transport_trips').update({
    exit_stop: exitStop,
    exit_time: new Date().toISOString(),
    distance_km: distanceKm,
    fare_charged: fare,
    status: 'completed'
  }).eq('id', tripId);
  
  // Notify conductor
  await db.from('notifications').insert({
    user_id: trip.provider_id,
    title: 'Passenger Exited',
    message: `Trip completed. Fare: Rs. ${fare}`
  });
};
```

### E.3 — Wallet System (Supabase RPC)

```sql
-- Atomic wallet debit function
CREATE OR REPLACE FUNCTION debit_office_transport_wallet(
  p_user_id UUID,
  p_amount NUMERIC,
  p_reference TEXT DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  -- Lock row for update
  SELECT balance INTO v_balance 
  FROM office_transport_wallets 
  WHERE user_id = p_user_id 
  FOR UPDATE;
  
  IF v_balance IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  
  IF v_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance. Current: %, Required: %', v_balance, p_amount;
  END IF;
  
  v_balance := v_balance - p_amount;
  
  UPDATE office_transport_wallets SET balance = v_balance, updated_at = now() WHERE user_id = p_user_id;
  
  INSERT INTO office_transport_wallet_txns (user_id, type, amount, balance_after, reference)
  VALUES (p_user_id, 'debit', p_amount, v_balance, p_reference);
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### E.4 — Conductor Dashboard

**Provider-side view** for bus conductors:
- Scan QR codes (camera access)
- See current passengers on route
- View trip history
- Manual entry/exit logging
- Revenue report

---

## Phase F — Admin Dashboard Rebuild

### F.1 — Vehicles Tab → Full DB CRUD

**File:** `web/src/pages/admin/AdminDashboard.tsx`

**Replace** current `<AdminTable>` with Zustand data → new `VehiclesAdminPanel` component:

```typescript
function VehiclesAdminPanel() {
  // Fetch from vehicles_listings table
  const [vehicles, setVehicles] = useState<VehicleListing[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingVehicle, setEditingVehicle] = useState<VehicleListing | null>(null);
  const [filterType, setFilterType] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [filterSubtype, setFilterSubtype] = useState('all'); // rental, airport_transfer, coach

  useEffect(() => {
    db.from('vehicles_listings').select('*').order('created_at', { ascending: false })
      .then(({ data }) => { setVehicles(data || []); setLoading(false); });
  }, []);

  // CRUD operations
  const addVehicle = async (vehicle) => { /* insert into vehicles_listings */ };
  const updateVehicle = async (id, updates) => { /* update vehicles_listings */ };
  const deleteVehicle = async (id) => { /* delete from vehicles_listings */ };
  const approveVehicle = async (id) => { /* set moderation_status = 'approved' */ };
  const suspendVehicle = async (id) => { /* set moderation_status = 'suspended' */ };
}
```

**UI sections:**
1. KPI cards (Total, Active, Pending Approval, Suspended)
2. Filter bar (type, status, subtype)
3. Vehicle table with full CRUD actions
4. Add/Edit vehicle modal with all fields
5. Moderation controls (approve/reject/suspend with reason)
6. Airport transfer settings section
7. Coach booking management section

### F.2 — Taxi Tab → DB-Persisted Controls

**Replace** current `AdvancedVehicleManager` local state with database-backed operations:

```typescript
function TaxiAdminPanel() {
  // Fetch categories from DB (only service_type = 'taxi')
  const [categories, setCategories] = useState<TaxiVehicleCategory[]>([]);
  
  useEffect(() => {
    db.from('taxi_vehicle_categories')
      .select('*')
      .eq('service_type', 'taxi')
      .order('base_fare')
      .then(({ data }) => setCategories(data || []));
  }, []);

  // Persist rate changes to DB
  const updateRate = async (id: string, updates: Partial<TaxiVehicleCategory>) => {
    await db.from('taxi_vehicle_categories').update(updates).eq('id', id);
    setCategories(prev => prev.map(c => c.id === id ? { ...c, ...updates } : c));
  };

  // Persist surge settings to app_settings table
  const updateSurge = async (multiplier: number, peak: boolean) => {
    await db.from('app_settings').upsert({
      key: 'taxi_surge', value: { multiplier, peak_mode: peak }
    });
  };
}
```

**Sections:**
1. Live taxi KPIs (active rides, online drivers, revenue today) — from `taxi_rides` + `taxi_provider_locations` tables
2. Category rates (CRUD from `taxi_vehicle_categories` WHERE `service_type = 'taxi'`)
3. Surge & peak controls (persisted to `app_settings`)
4. Fare simulator (using DB rates)
5. Active rides monitor (real-time from `taxi_rides`)
6. Driver management (from `taxi_provider_locations` + profiles)
7. Promo code management (from `taxi_promo_codes`)

### F.3 — New Admin Tab: Office Transport

**Add to AdminTab type:** `'office_transport'`

**Sections:**
1. Route management (CRUD for `office_transport_routes`)
2. Subscription plan management (CRUD for `office_transport_plans`)
3. Active trips monitor
4. Passenger stats (subscriptions, wallet balances)
5. Revenue/usage analytics
6. Conductor management

### F.4 — New Admin Tab: Airport Transfers

Could be a sub-section of Vehicles or its own tab.

**Sections:**
1. Active bookings list (today's pickups/drops)
2. Fare configuration by vehicle type
3. Driver assignment
4. Airport-specific settings (terminal preferences, meet & greet, etc.)

### F.5 — New Admin Tab: Parcels

**Sections:**
1. Active deliveries with status tracking
2. Item type management (CRUD for `parcel_item_types`)
3. Insurance rate configuration
4. Delivery fee calculator
5. Delivery driver management

---

## Phase G — CMS Pages Fix

### G.1 — Apply Migration

**Root Cause:** Migration `0006_site_pages_cms.sql` exists in the repo but hasn't been applied to production Supabase.

**Fix:** Run migration in Supabase Dashboard → SQL Editor:
```sql
-- Copy contents of supabase/migrations/0006_site_pages_cms.sql and execute
```

### G.2 — Add Error Handling & Loading State

**File:** `AdminDashboard.tsx` → `PagesPanel` component

```typescript
// Add error state
const [error, setError] = useState<string | null>(null);

// Better data fetching with error handling
useEffect(() => {
  db.from('site_pages').select('*').order('slug')
    .then(({ data, error }) => {
      if (error) {
        setError(`Failed to load pages: ${error.message}. Has migration 0006 been applied?`);
      } else {
        setPages(data as SitePage[]);
      }
      setLoading(false);
    });
}, []);
```

### G.3 — Add Delete Page Action

```typescript
const handleDelete = async (page: SitePage) => {
  if (!confirm(`Delete page "/${page.slug}"? This cannot be undone.`)) return;
  const { error } = await db.from('site_pages').delete().eq('id', page.id);
  if (!error) {
    setPages(prev => prev.filter(p => p.id !== page.id));
    if (selected?.id === page.id) setSelected(null);
  }
};
```

---

## File Change Map

| # | File | Action | Phase |
|---|---|---|---|
| 1 | `supabase/migrations/0007_transport_restructure.sql` | CREATE | A |
| 2 | `web/src/hooks/useListings.ts` | EDIT — add service_type filter, new hooks | B |
| 3 | `web/src/components/LeafletMap.tsx` | EDIT — tile fallback + error handling | B |
| 4 | `web/src/pages/TaxiPage.tsx` | MAJOR REWRITE — remove bus/coach, enhance parcel, fix fare calc | B, D |
| 5 | `web/src/pages/VehiclesPage.tsx` | EDIT — add coach/airport categories, DB vehicle connection | C |
| 6 | `web/src/pages/OfficeTransportPage.tsx` | CREATE — full new page | E |
| 7 | `web/src/pages/ParcelTrackingPage.tsx` | CREATE — parcel tracking | D |
| 8 | `web/src/components/QRCodeScanner.tsx` | CREATE — QR entry/exit | E |
| 9 | `web/src/components/AirportTransferBooking.tsx` | CREATE — airport booking form | C |
| 10 | `web/src/pages/admin/AdminDashboard.tsx` | MAJOR REWRITE — vehicles, taxi, office transport, parcels, airport tabs | F |
| 11 | `web/src/types/index.ts` | EDIT — add new types | All |
| 12 | `web/src/App.tsx` | EDIT — add new routes | E, D |
| 13 | `web/src/store/useStore.ts` | EDIT — remove hardcoded vehicles, add office transport state | C, E |
| 14 | `web/src/lib/fareCalculator.ts` | CREATE — shared fare logic for taxi, parcel, office transport | B, D, E |
| 15 | `web/src/components/WalletWidget.tsx` | CREATE — wallet balance/top-up UI | E |

---

## Execution Order

Execute phases in this order to minimize breakage and allow incremental testing:

```
WEEK 1: Foundation
─────────────────
  Step 1:  Phase G — Fix CMS (apply migration, add error handling)     [30 min]
  Step 2:  Phase A — Write and apply migration 0007                    [2-3 hrs]
  Step 3:  Phase B.1 — Filter taxi categories by service_type          [30 min]
  Step 4:  Phase B.2 — Fix LeafletMap broken images                    [1 hr]

WEEK 1: Taxi + Vehicles
───────────────────────
  Step 5:  Phase F.2 — Rebuild Taxi admin (DB-persisted)               [3-4 hrs]
  Step 6:  Phase F.1 — Rebuild Vehicles admin (DB CRUD)                [3-4 hrs]
  Step 7:  Phase C.1 — Connect vehicle page to DB                      [1-2 hrs]
  Step 8:  Phase C.2 — Add coach/luxury coach to vehicles              [1 hr]
  Step 9:  Phase B.4 — Fix fare calculation (Haversine)                [1 hr]
           → TEST & PUSH ← 

WEEK 2: New Features
────────────────────
  Step 10: Phase C.3 — Airport transfer booking UI + logic             [3-4 hrs]
  Step 11: Phase D.1 — Uber-style parcel send/receive                  [3-4 hrs]
  Step 12: Phase D.2 — Parcel tracking page                            [2-3 hrs]
  Step 13: Phase F.4 — Airport transfers admin                         [2 hrs]
  Step 14: Phase F.5 — Parcels admin panel                             [2 hrs]
           → TEST & PUSH ←

WEEK 2-3: Office Transport
──────────────────────────
  Step 15: Phase E.1 — Office transport page (routes, subscription)    [4-5 hrs]
  Step 16: Phase E.2 — QR code entry/exit system                       [3-4 hrs]
  Step 17: Phase E.3 — Wallet (top-up, debit, RPC functions)           [2-3 hrs]
  Step 18: Phase E.4 — Conductor dashboard                             [2-3 hrs]
  Step 19: Phase F.3 — Office transport admin panel                    [3-4 hrs]
           → TEST & PUSH ←

WEEK 3: Polish
──────────────
  Step 20: Phase D.3 — Parcel admin dashboard                          [2 hrs]
  Step 21: Update navigation (App.tsx routes, navbar links)            [1 hr]
  Step 22: Integration testing across all flows                        [2-3 hrs]
  Step 23: Build validation + push to production                       [1 hr]
```

### Pre-Execution Checklist

- [ ] Apply migration 0006 to production Supabase (CMS pages)
- [ ] Verify `taxi_vehicle_categories` table has all 13 categories seeded
- [ ] Confirm admin user UUID for vehicle seeding
- [ ] Test Supabase RLS policies work for new tables
- [ ] Ensure WhatsApp API token is set in Edge Function secrets

---

## Risk Assessment

| Risk | Impact | Mitigation |
|---|---|---|
| Migration 0007 conflicts with existing data | HIGH | Test on staging first, wrap in transaction |
| Breaking existing taxi bookings | HIGH | Filter change (B.1) is additive — old rides remain valid |
| Large AdminDashboard.tsx file (2800+ lines) | MEDIUM | Phase F restructures into smaller focused panels, consider code-splitting |
| QR code security (replay attacks) | HIGH | Tokens are UUID + one-time use, expire after trip completion |
| Wallet race conditions | HIGH | PostgreSQL `FOR UPDATE` lock in RPC function (E.3) |
| Offline bus conductor | MEDIUM | QR scan works offline, syncs when online |

---

*Plan authored by GitHub Copilot — Ready for execution on approval.*
