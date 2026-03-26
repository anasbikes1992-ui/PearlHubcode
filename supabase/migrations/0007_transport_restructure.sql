-- ============================================================
-- 0007_transport_restructure.sql
-- Pearl Hub — Transport system overhaul
-- New tables: office transport, airport transfers, enhanced parcels
-- Restructures taxi categories by service_type
-- ============================================================

-- ── 1. Add service_type to taxi_vehicle_categories ──────────
ALTER TABLE public.taxi_vehicle_categories
  ADD COLUMN IF NOT EXISTS service_type TEXT DEFAULT 'taxi'
  CHECK (service_type IN ('taxi', 'vehicle_rental', 'office_transport'));

UPDATE public.taxi_vehicle_categories
  SET service_type = 'office_transport'
  WHERE name IN ('Rosa Bus A/c', 'Bus');

UPDATE public.taxi_vehicle_categories
  SET service_type = 'vehicle_rental'
  WHERE name IN ('Coach A/c', 'Luxury Coach');

-- ── 2. Add per_min_rate to taxi_vehicle_categories if missing ─
ALTER TABLE public.taxi_vehicle_categories
  ADD COLUMN IF NOT EXISTS per_min_rate NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS commission_pct NUMERIC DEFAULT 15;

-- ── 3. Add listing_subtype to vehicles_listings ──────────────
ALTER TABLE public.vehicles_listings
  ADD COLUMN IF NOT EXISTS listing_subtype TEXT DEFAULT 'rental'
  CHECK (listing_subtype IN ('rental', 'airport_transfer', 'coach'));

ALTER TABLE public.vehicles_listings
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS price_per_day NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vehicle_type TEXT DEFAULT 'car',
  ADD COLUMN IF NOT EXISTS with_driver BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS features TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS insurance_included BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_fleet BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 4.5,
  ADD COLUMN IF NOT EXISTS trips INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fuel TEXT DEFAULT 'Petrol',
  ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'LKR';

-- ── 4. Office Transport Plans ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.office_transport_plans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  duration    TEXT NOT NULL CHECK (duration IN ('weekly', 'monthly')),
  price       NUMERIC NOT NULL,
  ride_limit  INT,
  km_limit    NUMERIC,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

INSERT INTO public.office_transport_plans (name, duration, price, ride_limit) VALUES
  ('Weekly Basic',    'weekly',  1200, 20),
  ('Weekly Premium',  'weekly',  1800, NULL),
  ('Monthly Basic',   'monthly', 4500, 80),
  ('Monthly Premium', 'monthly', 6500, NULL)
ON CONFLICT DO NOTHING;

-- ── 5. Office Transport Routes ───────────────────────────────
CREATE TABLE IF NOT EXISTS public.office_transport_routes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT NOT NULL,
  vehicle_category_id UUID REFERENCES public.taxi_vehicle_categories(id),
  provider_id         UUID REFERENCES auth.users(id),
  stops               JSONB NOT NULL DEFAULT '[]',
  departure_time      TIME NOT NULL,
  return_time         TIME,
  days_active         TEXT[] DEFAULT '{Mon,Tue,Wed,Thu,Fri}',
  fare_per_km         NUMERIC DEFAULT 15,
  flat_fare           NUMERIC,
  status              TEXT DEFAULT 'active',
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- ── 6. User Subscriptions ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.office_transport_subscriptions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id    UUID NOT NULL REFERENCES public.office_transport_plans(id),
  route_id   UUID REFERENCES public.office_transport_routes(id),
  status     TEXT DEFAULT 'active' CHECK (status IN ('active','expired','cancelled')),
  started_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  rides_used INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── 7. Wallets ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.office_transport_wallets (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance    NUMERIC NOT NULL DEFAULT 0 CHECK (balance >= 0),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── 8. Wallet Transactions ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.office_transport_wallet_txns (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type          TEXT NOT NULL CHECK (type IN ('topup','debit','refund','subscription')),
  amount        NUMERIC NOT NULL,
  balance_after NUMERIC NOT NULL,
  reference     TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- ── 9. Trip Records (QR scan based) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.office_transport_trips (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  route_id         UUID NOT NULL REFERENCES public.office_transport_routes(id),
  subscription_id  UUID REFERENCES public.office_transport_subscriptions(id),
  provider_id      UUID REFERENCES auth.users(id),
  entry_stop       TEXT,
  exit_stop        TEXT,
  entry_time       TIMESTAMPTZ DEFAULT now(),
  exit_time        TIMESTAMPTZ,
  distance_km      NUMERIC,
  fare_charged     NUMERIC DEFAULT 0,
  status           TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress','completed','cancelled')),
  qr_token         TEXT UNIQUE,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- ── 10. Airport Transfers ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.airport_transfers (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id      UUID REFERENCES auth.users(id),
  transfer_type    TEXT NOT NULL CHECK (transfer_type IN ('pickup','drop')),
  airport          TEXT NOT NULL DEFAULT 'BIA',
  flight_number    TEXT,
  flight_time      TIMESTAMPTZ NOT NULL,
  pickup_address   TEXT NOT NULL,
  vehicle_type     TEXT NOT NULL,
  passengers       INT DEFAULT 1,
  luggage_count    INT DEFAULT 1,
  special_requests TEXT,
  fare             NUMERIC NOT NULL,
  status           TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','driver_assigned','in_transit','completed','cancelled')),
  payment_status   TEXT DEFAULT 'pending',
  payment_method   TEXT DEFAULT 'cash',
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

-- ── 11. Parcel Item Types ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.parcel_item_types (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL UNIQUE,
  icon          TEXT DEFAULT '📦',
  max_weight_kg NUMERIC DEFAULT 30,
  base_fee      NUMERIC DEFAULT 100,
  is_active     BOOLEAN DEFAULT true
);

INSERT INTO public.parcel_item_types (name, icon, max_weight_kg, base_fee) VALUES
  ('Documents',       '📄', 2,  100),
  ('Food & Beverages','🍱', 10, 150),
  ('Electronics',     '💻', 15, 300),
  ('Clothing',        '👕', 10, 120),
  ('Fragile Items',   '⚠️', 20, 400),
  ('General Package', '📦', 30, 200),
  ('Medicine',        '💊', 5,  200),
  ('Flowers',         '💐', 5,  180)
ON CONFLICT (name) DO NOTHING;

-- ── 12. Enhanced Parcel Deliveries ──────────────────────────
CREATE TABLE IF NOT EXISTS public.parcel_deliveries (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id              UUID REFERENCES public.taxi_rides(id),
  sender_id            UUID NOT NULL REFERENCES auth.users(id),
  item_type_id         UUID REFERENCES public.parcel_item_types(id),
  recipient_name       TEXT NOT NULL,
  recipient_phone      TEXT NOT NULL,
  pickup_address       TEXT NOT NULL,
  pickup_lat           FLOAT8,
  pickup_lng           FLOAT8,
  dropoff_address      TEXT NOT NULL,
  dropoff_lat          FLOAT8,
  dropoff_lng          FLOAT8,
  weight_kg            NUMERIC,
  dimensions           TEXT,
  is_fragile           BOOLEAN DEFAULT false,
  insurance_opted      BOOLEAN DEFAULT false,
  insurance_amount     NUMERIC DEFAULT 0,
  declared_value       NUMERIC DEFAULT 0,
  special_instructions TEXT,
  status               TEXT DEFAULT 'pending' CHECK (status IN (
    'pending','driver_assigned','picked_up','in_transit','delivered','returned','cancelled'
  )),
  otp_code             TEXT,
  delivered_at         TIMESTAMPTZ,
  fare                 NUMERIC,
  created_at           TIMESTAMPTZ DEFAULT now()
);

-- ── 13. Row Level Security ───────────────────────────────────

-- Office Transport Plans
ALTER TABLE public.office_transport_plans ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_plans' AND policyname='plans_public_read') THEN
    CREATE POLICY plans_public_read ON public.office_transport_plans FOR SELECT USING (is_active = true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_plans' AND policyname='plans_admin_all') THEN
    CREATE POLICY plans_admin_all ON public.office_transport_plans FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Office Transport Routes
ALTER TABLE public.office_transport_routes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_routes' AND policyname='routes_public_read') THEN
    CREATE POLICY routes_public_read ON public.office_transport_routes FOR SELECT USING (status = 'active');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_routes' AND policyname='routes_admin_all') THEN
    CREATE POLICY routes_admin_all ON public.office_transport_routes FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Subscriptions
ALTER TABLE public.office_transport_subscriptions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_subscriptions' AND policyname='subs_own') THEN
    CREATE POLICY subs_own ON public.office_transport_subscriptions FOR SELECT USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_subscriptions' AND policyname='subs_admin') THEN
    CREATE POLICY subs_admin ON public.office_transport_subscriptions FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Wallets
ALTER TABLE public.office_transport_wallets ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_wallets' AND policyname='wallet_own') THEN
    CREATE POLICY wallet_own ON public.office_transport_wallets FOR SELECT USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_wallets' AND policyname='wallet_admin') THEN
    CREATE POLICY wallet_admin ON public.office_transport_wallets FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Wallet Txns
ALTER TABLE public.office_transport_wallet_txns ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_wallet_txns' AND policyname='txns_own') THEN
    CREATE POLICY txns_own ON public.office_transport_wallet_txns FOR SELECT USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_wallet_txns' AND policyname='txns_admin') THEN
    CREATE POLICY txns_admin ON public.office_transport_wallet_txns FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Office Transport Trips
ALTER TABLE public.office_transport_trips ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_trips' AND policyname='trips_own') THEN
    CREATE POLICY trips_own ON public.office_transport_trips FOR SELECT USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_trips' AND policyname='trips_provider') THEN
    CREATE POLICY trips_provider ON public.office_transport_trips FOR SELECT USING (provider_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_trips' AND policyname='trips_insert') THEN
    CREATE POLICY trips_insert ON public.office_transport_trips FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_trips' AND policyname='trips_update') THEN
    CREATE POLICY trips_update ON public.office_transport_trips FOR UPDATE USING (user_id = auth.uid() OR provider_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='office_transport_trips' AND policyname='trips_admin') THEN
    CREATE POLICY trips_admin ON public.office_transport_trips FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Airport Transfers
ALTER TABLE public.airport_transfers ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='airport_transfers' AND policyname='airport_own') THEN
    CREATE POLICY airport_own ON public.airport_transfers FOR SELECT USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='airport_transfers' AND policyname='airport_insert') THEN
    CREATE POLICY airport_insert ON public.airport_transfers FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='airport_transfers' AND policyname='airport_admin') THEN
    CREATE POLICY airport_admin ON public.airport_transfers FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Parcel Item Types
ALTER TABLE public.parcel_item_types ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='parcel_item_types' AND policyname='item_types_public') THEN
    CREATE POLICY item_types_public ON public.parcel_item_types FOR SELECT USING (is_active = true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='parcel_item_types' AND policyname='item_types_admin') THEN
    CREATE POLICY item_types_admin ON public.parcel_item_types FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- Parcel Deliveries
ALTER TABLE public.parcel_deliveries ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='parcel_deliveries' AND policyname='parcels_own') THEN
    CREATE POLICY parcels_own ON public.parcel_deliveries FOR SELECT USING (sender_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='parcel_deliveries' AND policyname='parcels_insert') THEN
    CREATE POLICY parcels_insert ON public.parcel_deliveries FOR INSERT WITH CHECK (auth.uid() = sender_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='parcel_deliveries' AND policyname='parcels_update') THEN
    CREATE POLICY parcels_update ON public.parcel_deliveries FOR UPDATE USING (sender_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='parcel_deliveries' AND policyname='parcels_admin') THEN
    CREATE POLICY parcels_admin ON public.parcel_deliveries FOR ALL USING (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
  END IF;
END $$;

-- ── 14. Wallet debit RPC (atomic) ──────────────────────────
CREATE OR REPLACE FUNCTION public.debit_office_transport_wallet(
  p_user_id  UUID,
  p_amount   NUMERIC,
  p_reference TEXT DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT balance INTO v_balance
    FROM public.office_transport_wallets
    WHERE user_id = p_user_id
    FOR UPDATE;

  IF v_balance IS NULL THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  IF v_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance. Current: %, Required: %', v_balance, p_amount;
  END IF;

  v_balance := v_balance - p_amount;

  UPDATE public.office_transport_wallets
    SET balance = v_balance, updated_at = now()
    WHERE user_id = p_user_id;

  INSERT INTO public.office_transport_wallet_txns
    (user_id, type, amount, balance_after, reference)
    VALUES (p_user_id, 'debit', p_amount, v_balance, p_reference);

  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 15. Wallet topup RPC ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.topup_office_transport_wallet(
  p_user_id  UUID,
  p_amount   NUMERIC,
  p_reference TEXT DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  INSERT INTO public.office_transport_wallets (user_id, balance)
    VALUES (p_user_id, p_amount)
    ON CONFLICT (user_id) DO UPDATE
      SET balance = public.office_transport_wallets.balance + p_amount,
          updated_at = now()
    RETURNING balance INTO v_balance;

  INSERT INTO public.office_transport_wallet_txns
    (user_id, type, amount, balance_after, reference)
    VALUES (p_user_id, 'topup', p_amount, v_balance, p_reference);

  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 16. Seed 3 sample vehicles so VehiclesPage is not empty ─
-- Note: requires a valid admin user_id — using a placeholder that admins should replace
-- Run this manually in Supabase SQL editor with your actual admin user_id if needed.
-- INSERT INTO public.vehicles_listings (user_id, make, model, year, type, price, price_unit, seats, ac, fuel, location, lat, lng, vehicle_type, moderation_status, active, title, price_per_day, with_driver, features, description, status, insurance_included, rating, trips, currency)
-- VALUES
--   ('YOUR-ADMIN-USER-ID', 'Toyota', 'Prius', 2022, 'car', 6500, 'day', 5, true, 'Hybrid', 'Colombo', 6.9147, 79.8527, 'car', 'approved', true, 'Eco-Friendly Toyota Prius', 6500, false, '{AC,Bluetooth,Hybrid}', 'Efficient hybrid car for city travel.', 'active', true, 4.7, 234, 'LKR'),
--   ('YOUR-ADMIN-USER-ID', 'Toyota', 'Hiace', 2021, 'van', 12500, 'day', 12, true, 'Diesel', 'Colombo', 6.9140, 79.8520, 'van', 'approved', true, 'Luxury Passenger Van', 12500, true, '{AC,Dual AC,DVD}', 'Spacious van for group travel.', 'active', true, 4.8, 156, 'LKR'),
--   ('YOUR-ADMIN-USER-ID', 'Mitsubishi', 'Montero', 2019, 'suv', 25000, 'day', 7, true, 'Diesel', 'Colombo', 6.9150, 79.8530, 'suv', 'approved', true, 'Premium Montero SUV', 25000, false, '{4WD,Sunroof,Leather}', 'Luxury 4x4 SUV for premium off-road comfort.', 'active', true, 4.9, 88, 'LKR');
