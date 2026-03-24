-- ══════════════════════════════════════════════════════════════
-- PEARL HUB PRO — Taxi System Migration
-- 2026-03-23
-- ══════════════════════════════════════════════════════════════

-- ── 1. Add NIC to profiles if missing ────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'nic_number') THEN
    ALTER TABLE public.profiles ADD COLUMN nic_number TEXT DEFAULT '';
  END IF;
END $$;

-- ── 2. Taxi Vehicle Categories ───────────────────────────────
CREATE TABLE IF NOT EXISTS public.taxi_vehicle_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL UNIQUE,
  is_active  BOOLEAN DEFAULT true,
  default_seats INT NOT NULL DEFAULT 4,
  base_fare  NUMERIC DEFAULT 0,
  per_km_rate NUMERIC DEFAULT 0,
  icon       TEXT DEFAULT '🚗',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.taxi_vehicle_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view taxi categories"
  ON public.taxi_vehicle_categories FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Admins manage taxi categories"
  ON public.taxi_vehicle_categories FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin')
  );

INSERT INTO public.taxi_vehicle_categories (name, default_seats, base_fare, per_km_rate, icon) VALUES
  ('Moto',          1,  100,  25, '🏍️'),
  ('TUK TUK',      3,  150,  35, '🛺'),
  ('Car Economy',   4,  300,  50, '🚗'),
  ('Car Electric',  4,  350,  55, '⚡'),
  ('Car Premium',   4,  450,  70, '🚙'),
  ('Buddy Van',     4,  400,  60, '🚐'),
  ('Van',           7,  600,  80, '🚐'),
  ('Premium Van',   7,  750,  95, '✨'),
  ('SUV',           6,  800,  90, '🚜'),
  ('Rosa Bus A/c', 29, 1500, 120, '🚌'),
  ('Bus',          40, 2000, 100, '🚌'),
  ('Coach A/c',    45, 3000, 150, '🚍'),
  ('Luxury Coach', 45, 5000, 200, '👑')
ON CONFLICT (name) DO NOTHING;

-- ── 3. Taxi Rides ────────────────────────────────────────────
CREATE TYPE taxi_ride_status AS ENUM ('searching','accepted','arrived','in_transit','completed','cancelled');

CREATE TABLE IF NOT EXISTS public.taxi_rides (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id         UUID REFERENCES auth.users(id),
  vehicle_category_id UUID REFERENCES public.taxi_vehicle_categories(id),
  pickup_lat          FLOAT8 NOT NULL,
  pickup_lng          FLOAT8 NOT NULL,
  pickup_address      TEXT,
  dropoff_lat         FLOAT8 NOT NULL,
  dropoff_lng         FLOAT8 NOT NULL,
  dropoff_address     TEXT,
  status              taxi_ride_status DEFAULT 'searching',
  fare                NUMERIC,
  distance_km         NUMERIC,
  ride_module         TEXT DEFAULT 'transport',
  parcel_details      JSONB,
  stops               JSONB,
  payment_method      TEXT DEFAULT 'cash',
  payment_status      TEXT DEFAULT 'pending',
  surge_multiplier    NUMERIC DEFAULT 1.0,
  scheduled_for       TIMESTAMPTZ,
  is_emergency_sos    BOOLEAN DEFAULT false,
  promo_id            UUID,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.taxi_rides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers view own taxi rides"
  ON public.taxi_rides FOR SELECT TO authenticated
  USING (auth.uid() = customer_id);
CREATE POLICY "Providers view assigned/searching taxi rides"
  ON public.taxi_rides FOR SELECT TO authenticated
  USING (auth.uid() = provider_id OR status = 'searching');
CREATE POLICY "Admins view all taxi rides"
  ON public.taxi_rides FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));
CREATE POLICY "Customers create taxi rides"
  ON public.taxi_rides FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Participants update taxi rides"
  ON public.taxi_rides FOR UPDATE TO authenticated
  USING (auth.uid() = customer_id OR auth.uid() = provider_id);
CREATE POLICY "Admins update any taxi ride"
  ON public.taxi_rides FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- ── 4. Provider Locations ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.taxi_provider_locations (
  provider_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  lat         FLOAT8 NOT NULL DEFAULT 0,
  lng         FLOAT8 NOT NULL DEFAULT 0,
  is_online   BOOLEAN DEFAULT false,
  updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.taxi_provider_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view online taxi locations"
  ON public.taxi_provider_locations FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Providers update own taxi location"
  ON public.taxi_provider_locations FOR ALL TO authenticated
  USING (auth.uid() = provider_id)
  WITH CHECK (auth.uid() = provider_id);

-- ── 5. Taxi Chat Messages ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.taxi_chat_messages (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id    UUID NOT NULL REFERENCES public.taxi_rides(id) ON DELETE CASCADE,
  sender_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content    TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.taxi_chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Ride participants view taxi chat"
  ON public.taxi_chat_messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.taxi_rides
      WHERE id = ride_id AND (customer_id = auth.uid() OR provider_id = auth.uid())
    )
  );
CREATE POLICY "Ride participants send taxi chat"
  ON public.taxi_chat_messages FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

-- ── 6. Taxi KYC Documents ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.taxi_kyc_documents (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  nic_number          TEXT,
  license_number      TEXT,
  nic_front_url       TEXT,
  nic_back_url        TEXT,
  license_front_url   TEXT,
  license_back_url    TEXT,
  verification_status TEXT DEFAULT 'pending'
    CHECK (verification_status IN ('pending','approved','rejected')),
  admin_notes         TEXT DEFAULT '',
  submitted_at        TIMESTAMPTZ DEFAULT now(),
  verified_at         TIMESTAMPTZ,
  CONSTRAINT taxi_nic_or_license CHECK (nic_number IS NOT NULL OR license_number IS NOT NULL)
);

ALTER TABLE public.taxi_kyc_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Providers view own taxi KYC"
  ON public.taxi_kyc_documents FOR SELECT TO authenticated
  USING (auth.uid() = provider_id);
CREATE POLICY "Providers submit taxi KYC"
  ON public.taxi_kyc_documents FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = provider_id);
CREATE POLICY "Admins manage taxi KYC"
  ON public.taxi_kyc_documents FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- ── 7. Taxi Promo Codes ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.taxi_promo_codes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT NOT NULL UNIQUE,
  discount_type   TEXT NOT NULL CHECK (discount_type IN ('percentage','flat')),
  discount_amount NUMERIC NOT NULL,
  max_uses        INT DEFAULT 100,
  uses_count      INT DEFAULT 0,
  valid_until     TIMESTAMPTZ,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.taxi_promo_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active taxi promos"
  ON public.taxi_promo_codes FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Admins manage taxi promos"
  ON public.taxi_promo_codes FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- ── 8. Taxi Provider Subscriptions ───────────────────────────
CREATE TABLE IF NOT EXISTS public.taxi_provider_subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_name       TEXT NOT NULL,
  commission_rate NUMERIC DEFAULT 15,
  status          TEXT DEFAULT 'active',
  valid_until     TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.taxi_provider_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Providers view own taxi subscription"
  ON public.taxi_provider_subscriptions FOR SELECT TO authenticated
  USING (auth.uid() = provider_id);
CREATE POLICY "Admins manage taxi subscriptions"
  ON public.taxi_provider_subscriptions FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

-- ── 9. Platform Settings (idempotent) ────────────────────────
CREATE TABLE IF NOT EXISTS public.platform_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'platform_settings' AND policyname = 'Anyone can read platform settings') THEN
    CREATE POLICY "Anyone can read platform settings"
      ON public.platform_settings FOR SELECT TO anon, authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'platform_settings' AND policyname = 'Admins manage platform settings') THEN
    CREATE POLICY "Admins manage platform settings"
      ON public.platform_settings FOR ALL TO authenticated
      USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));
  END IF;
END $$;

INSERT INTO public.platform_settings (key, value) VALUES
  ('taxi_google_maps', '{"enabled": false, "api_key": ""}'),
  ('taxi_payment_gateways', '{"payhere": {"enabled": false}, "webxpay": {"enabled": false}, "lankapay": {"enabled": false, "qr_mode": false}}')
ON CONFLICT (key) DO NOTHING;

-- ── 10. Taxi Ride Ratings ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.taxi_ratings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id     UUID NOT NULL REFERENCES public.taxi_rides(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating      INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  feedback    TEXT DEFAULT '',
  tip_amount  NUMERIC DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.taxi_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view own taxi ratings"
  ON public.taxi_ratings FOR SELECT TO authenticated
  USING (auth.uid() = reviewer_id OR auth.uid() = target_id);
CREATE POLICY "Users insert taxi ratings"
  ON public.taxi_ratings FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reviewer_id);

-- ── 11. Enable Realtime ──────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.taxi_rides;
ALTER PUBLICATION supabase_realtime ADD TABLE public.taxi_provider_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.taxi_chat_messages;

-- ── 12. Indexes ──────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_taxi_rides_customer   ON public.taxi_rides (customer_id);
CREATE INDEX IF NOT EXISTS idx_taxi_rides_provider   ON public.taxi_rides (provider_id);
CREATE INDEX IF NOT EXISTS idx_taxi_rides_status     ON public.taxi_rides (status);
CREATE INDEX IF NOT EXISTS idx_taxi_chat_ride        ON public.taxi_chat_messages (ride_id);
