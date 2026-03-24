-- ============================================================
-- Pearl Hub Pro — Sprint 1 Migration
-- Missing Tables, Configs, Feature Flags, Security Improvements
-- Run: supabase db push (or apply via Supabase Dashboard)
-- ============================================================

-- ── 1. NOTIFICATIONS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  data        JSONB DEFAULT '{}',
  read        BOOLEAN DEFAULT false,
  channel     TEXT DEFAULT 'in_app' CHECK (channel IN ('in_app','push','email','sms','whatsapp')),
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own notifications"
  ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users mark own notifications read"
  ON notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Service can insert notifications"
  ON notifications FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, read, created_at DESC);

-- ── 2. FAVORITES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS favorites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES profiles(id) ON DELETE CASCADE,
  listing_id   UUID NOT NULL,
  listing_type TEXT NOT NULL CHECK (listing_type IN ('stay','vehicle','event','property','social','sme')),
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, listing_id, listing_type)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own favorites"
  ON favorites FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id, listing_type);

-- ── 3. DISPUTES ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS disputes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID REFERENCES bookings(id) ON DELETE SET NULL,
  raised_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reason        TEXT NOT NULL,
  evidence_urls TEXT[] DEFAULT '{}',
  status        TEXT DEFAULT 'open' CHECK (status IN ('open','investigating','resolved','dismissed')),
  resolution    TEXT,
  admin_id      UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  resolved_at   TIMESTAMPTZ
);

ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own disputes"     ON disputes FOR SELECT USING (auth.uid() = raised_by);
CREATE POLICY "Admins manage disputes"     ON disputes FOR ALL  USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status, created_at DESC);

-- ── 4. COUPONS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS coupons (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                 TEXT UNIQUE NOT NULL,
  description          TEXT,
  discount_type        TEXT NOT NULL CHECK (discount_type IN ('percentage','fixed')),
  discount_value       NUMERIC NOT NULL CHECK (discount_value > 0),
  min_order            NUMERIC DEFAULT 0,
  max_discount         NUMERIC,            -- cap for percentage type
  max_uses             INT DEFAULT 1,
  used_count           INT DEFAULT 0,
  valid_from           TIMESTAMPTZ DEFAULT now(),
  valid_until          TIMESTAMPTZ,
  applicable_verticals TEXT[] DEFAULT '{}', -- empty = all verticals
  applicable_user_ids  UUID[] DEFAULT '{}', -- empty = all users
  active               BOOLEAN DEFAULT true,
  created_by           UUID REFERENCES profiles(id),
  created_at           TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage coupons"    ON coupons FOR ALL   USING (is_admin(auth.uid()));
CREATE POLICY "Anyone can read active"   ON coupons FOR SELECT USING (active = true);

CREATE INDEX IF NOT EXISTS idx_coupons_code   ON coupons(code) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(active, valid_until);

-- ── 5. COUPON USAGES (prevents double-use) ────────────────────
CREATE TABLE IF NOT EXISTS coupon_usages (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id  UUID REFERENCES coupons(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  used_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (coupon_id, user_id)   -- one coupon per user per code
);

ALTER TABLE coupon_usages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own usages"   ON coupon_usages FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Service inserts usages" ON coupon_usages FOR INSERT WITH CHECK (true);

-- ── 6. REFERRALS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referrals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id     UUID REFERENCES profiles(id) ON DELETE CASCADE,
  referred_id     UUID REFERENCES profiles(id) ON DELETE CASCADE,
  referral_code   TEXT NOT NULL,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','completed','rewarded','expired')),
  referrer_reward NUMERIC DEFAULT 500,     -- Rs. 500 wallet credit
  referred_reward NUMERIC DEFAULT 300,     -- Rs. 300 for new user
  rewarded_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (referral_code)
);

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own referrals"  ON referrals FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);
CREATE POLICY "Admins manage referrals"  ON referrals FOR ALL  USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_referrals_code     ON referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id, status);

-- ── 7. PAYOUTS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payouts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount       NUMERIC NOT NULL CHECK (amount > 0),
  currency     TEXT DEFAULT 'LKR',
  method       TEXT CHECK (method IN ('bank_transfer','mobile_money','payhere','wallet')),
  bank_details JSONB DEFAULT '{}',    -- encrypted in prod
  status       TEXT DEFAULT 'pending' CHECK (status IN ('pending','processing','completed','failed','cancelled')),
  admin_notes  TEXT,
  processed_by UUID REFERENCES profiles(id),
  processed_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Providers see own payouts" ON payouts FOR SELECT USING (auth.uid() = provider_id);
CREATE POLICY "Providers request payouts" ON payouts FOR INSERT WITH CHECK (auth.uid() = provider_id);
CREATE POLICY "Admins manage payouts"     ON payouts FOR ALL   USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_payouts_provider ON payouts(provider_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payouts_status   ON payouts(status, created_at DESC);

-- ── 8. KYC DOCUMENTS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kyc_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES profiles(id) ON DELETE CASCADE,
  doc_type     TEXT NOT NULL CHECK (doc_type IN ('nic_front','nic_back','passport','driving_license','business_reg','bank_statement','selfie')),
  file_url     TEXT NOT NULL,
  status       TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  admin_notes  TEXT,
  reviewed_by  UUID REFERENCES profiles(id),
  reviewed_at  TIMESTAMPTZ,
  uploaded_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE kyc_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own KYC"        ON kyc_documents FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users upload KYC"         ON kyc_documents FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins review KYC"        ON kyc_documents FOR ALL   USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_kyc_user_status ON kyc_documents(user_id, status);
CREATE INDEX IF NOT EXISTS idx_kyc_pending     ON kyc_documents(status, uploaded_at DESC) WHERE status = 'pending';

-- ── 9. ANALYTICS EVENTS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS analytics_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID,       -- nullable for anonymous
  event_type  TEXT NOT NULL,
  properties  JSONB DEFAULT '{}',
  session_id  TEXT,
  device_type TEXT,       -- mobile, tablet, desktop
  platform    TEXT,       -- web, ios, android
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- No RLS — write-only from edge function, read by admin only
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins read analytics"    ON analytics_events FOR SELECT USING (is_admin(auth.uid()));
CREATE POLICY "Service inserts events"   ON analytics_events FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_analytics_type_time     ON analytics_events(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_user_time     ON analytics_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_session       ON analytics_events(session_id);

-- ── 10. ADD PAYMENT IDEMPOTENCY TO BOOKINGS ──────────────────
-- Prevent duplicate payment processing
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_idempotency_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_payment_idempotency
  ON bookings(payment_idempotency_key) WHERE payment_idempotency_key IS NOT NULL;

-- ── 11. PROVIDER REFERRAL CODES on PROFILES ──────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by_code TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS app_version TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS device_platform TEXT; -- web, ios, android

-- Generate referral codes for existing users
UPDATE profiles SET referral_code = UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8))
WHERE referral_code IS NULL;

-- ── 12. ADMIN GODS VIEW — PROVIDER LOCATIONS ──────────────────
-- Store last known location for providers (updated on app activity)
CREATE TABLE IF NOT EXISTS provider_locations (
  provider_id  UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  lat          DOUBLE PRECISION,
  lng          DOUBLE PRECISION,
  accuracy     NUMERIC,
  online       BOOLEAN DEFAULT false,
  last_updated TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE provider_locations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Providers update own location" ON provider_locations FOR ALL USING (auth.uid() = provider_id);
CREATE POLICY "Admins see all locations"      ON provider_locations FOR SELECT USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_provider_locations_online ON provider_locations(online, last_updated DESC);

-- ── 13. TAXI RIDES TABLE (if not exists from Flutter) ─────────
CREATE TABLE IF NOT EXISTS taxi_rides (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  driver_id       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  pickup_lat      DOUBLE PRECISION NOT NULL,
  pickup_lng      DOUBLE PRECISION NOT NULL,
  dropoff_lat     DOUBLE PRECISION,
  dropoff_lng     DOUBLE PRECISION,
  pickup_address  TEXT,
  dropoff_address TEXT,
  current_lat     DOUBLE PRECISION,
  current_lng     DOUBLE PRECISION,
  status          TEXT DEFAULT 'searching' CHECK (status IN ('searching','accepted','arrived','in_transit','completed','cancelled')),
  vehicle_category TEXT,
  fare            NUMERIC,
  surge_multiplier NUMERIC DEFAULT 1.0,
  distance_km     NUMERIC,
  payment_method  TEXT DEFAULT 'cash' CHECK (payment_method IN ('cash','wallet','card')),
  sos_active      BOOLEAN DEFAULT false,
  rating          NUMERIC CHECK (rating BETWEEN 1 AND 5),
  rating_feedback TEXT,
  scheduled_at    TIMESTAMPTZ,
  accepted_at     TIMESTAMPTZ,
  started_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE taxi_rides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Customers see own rides"    ON taxi_rides FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Drivers see assigned rides" ON taxi_rides FOR SELECT USING (auth.uid() = driver_id);
CREATE POLICY "Drivers update ride status" ON taxi_rides FOR UPDATE USING (auth.uid() = driver_id);
CREATE POLICY "Customers create rides"     ON taxi_rides FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Admins full access"         ON taxi_rides FOR ALL   USING (is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_taxi_rides_status     ON taxi_rides(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_taxi_rides_driver      ON taxi_rides(driver_id, status);
CREATE INDEX IF NOT EXISTS idx_taxi_rides_customer    ON taxi_rides(customer_id, created_at DESC);

-- Enable realtime on taxi_rides
ALTER PUBLICATION supabase_realtime ADD TABLE taxi_rides;
ALTER PUBLICATION supabase_realtime ADD TABLE provider_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ── 14. GODS VIEW RPC FUNCTIONS ───────────────────────────────

-- Live overview of online providers with location
CREATE OR REPLACE FUNCTION admin_gods_view_providers()
RETURNS TABLE (
  provider_id   UUID,
  full_name     TEXT,
  role          TEXT,
  lat           DOUBLE PRECISION,
  lng           DOUBLE PRECISION,
  online        BOOLEAN,
  last_seen     TIMESTAMPTZ,
  listing_count BIGINT,
  avg_rating    NUMERIC
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.role::TEXT,
    pl.lat,
    pl.lng,
    pl.online,
    pl.last_updated,
    COALESCE(lc.cnt, 0),
    COALESCE(rc.avg_r, 0)
  FROM profiles p
  LEFT JOIN provider_locations pl ON pl.provider_id = p.id
  LEFT JOIN LATERAL (
    SELECT COUNT(*) as cnt FROM (
      SELECT id FROM stays_listings WHERE user_id = p.id AND active = true
      UNION ALL
      SELECT id FROM vehicles_listings WHERE user_id = p.id AND active = true
      UNION ALL
      SELECT id FROM properties_listings WHERE user_id = p.id AND active = true
    ) x
  ) lc ON true
  LEFT JOIN LATERAL (
    SELECT AVG(r.rating) as avg_r FROM reviews r
    WHERE r.listing_id IN (
      SELECT id FROM stays_listings WHERE user_id = p.id
    )
  ) rc ON true
  WHERE p.role IN ('owner','broker','stay_provider','vehicle_provider','event_organizer','sme','admin')
  ORDER BY pl.online DESC NULLS LAST, pl.last_updated DESC;
END;
$$;

-- Live active taxi rides for God's View
CREATE OR REPLACE FUNCTION admin_gods_view_rides()
RETURNS TABLE (
  ride_id         UUID,
  driver_name     TEXT,
  customer_name   TEXT,
  pickup_lat      DOUBLE PRECISION,
  pickup_lng      DOUBLE PRECISION,
  dropoff_lat     DOUBLE PRECISION,
  dropoff_lng     DOUBLE PRECISION,
  current_lat     DOUBLE PRECISION,
  current_lng     DOUBLE PRECISION,
  status          TEXT,
  fare            NUMERIC,
  surge_multiplier NUMERIC,
  sos_active      BOOLEAN,
  started_at      TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    tr.id,
    d.full_name,
    c.full_name,
    tr.pickup_lat,
    tr.pickup_lng,
    tr.dropoff_lat,
    tr.dropoff_lng,
    tr.current_lat,
    tr.current_lng,
    tr.status,
    tr.fare,
    tr.surge_multiplier,
    tr.sos_active,
    tr.started_at
  FROM taxi_rides tr
  LEFT JOIN profiles d ON d.id = tr.driver_id
  LEFT JOIN profiles c ON c.id = tr.customer_id
  WHERE tr.status IN ('searching','accepted','arrived','in_transit')
  ORDER BY tr.sos_active DESC, tr.created_at DESC;
END;
$$;

-- Revenue breakdown by vertical
CREATE OR REPLACE FUNCTION admin_revenue_by_vertical(
  p_from TIMESTAMPTZ DEFAULT now() - INTERVAL '30 days',
  p_to   TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE (
  vertical       TEXT,
  bookings_count BIGINT,
  gmv            NUMERIC,
  commission     NUMERIC,
  net_to_providers NUMERIC
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    b.listing_type,
    COUNT(*)::BIGINT,
    COALESCE(SUM(b.total_amount), 0),
    COALESCE(SUM(e.amount * e.commission_rate), 0),
    COALESCE(SUM(e.amount), 0)
  FROM bookings b
  LEFT JOIN earnings e ON e.booking_id = b.id
  WHERE b.status = 'confirmed'
    AND b.created_at BETWEEN p_from AND p_to
  GROUP BY b.listing_type
  ORDER BY SUM(b.total_amount) DESC NULLS LAST;
END;
$$;

-- ── 15. MISSING PLATFORM CONFIGS ──────────────────────────────
INSERT INTO platform_config (key, value, description, category) VALUES
  -- General
  ('platform_name',             'Pearl Hub',             'Platform display name',                    'general'),
  ('support_email',             'support@pearlhub.lk',   'Customer support email',                   'general'),
  ('support_phone',             '+94112000000',          'Customer support phone',                   'general'),
  ('maintenance_mode',          'false',                 'If true, API returns 503 for non-admins',  'general'),
  ('min_app_version_ios',       '1.0.0',                 'Minimum iOS app version (force update)',   'general'),
  ('min_app_version_android',   '1.0.0',                 'Minimum Android app version',              'general'),
  ('terms_version',             '1.0',                   'Current T&C version shown to users',       'general'),
  ('privacy_version',           '1.0',                   'Current Privacy Policy version',           'general'),

  -- Fees (per-vertical commissions)
  ('stays_commission_rate',     '0.12',                  'Platform commission on stays bookings',    'fees'),
  ('vehicles_commission_rate',  '0.10',                  'Platform commission on vehicle rentals',   'fees'),
  ('events_commission_rate',    '0.08',                  'Platform commission on event tickets',     'fees'),
  ('properties_commission_rate','0.05',                  'Platform commission on property deals',    'fees'),
  ('taxi_commission_rate',      '0.15',                  'Platform commission on taxi rides',        'fees'),
  ('wallet_topup_fee',          '0.02',                  'Fee % charged on wallet top-ups',          'fees'),
  ('withdrawal_fee_fixed',      '50',                    'Fixed fee (LKR) per payout withdrawal',    'fees'),
  ('minimum_payout_amount',     '5000',                  'Min payout amount in LKR',                 'fees'),

  -- Limits
  ('max_listings_per_provider', '50',                    'Max active listings per provider account', 'limits'),
  ('max_images_per_listing',    '10',                    'Max images per listing upload',            'limits'),
  ('max_bookings_per_user_day', '10',                    'Max bookings a user can create per day',   'limits'),
  ('max_failed_login_attempts', '5',                     'Account lock after N failed logins',       'limits'),
  ('lockout_duration_minutes',  '30',                    'Account lockout duration in minutes',      'limits'),
  ('otp_max_per_15min',         '3',                     'Max OTPs per identifier per 15 minutes',   'limits'),
  ('otp_max_per_hour_ip',       '10',                    'Max OTPs per IP per hour',                 'limits'),

  -- Taxi
  ('taxi_max_surge_multiplier', '3.0',                   'Maximum surge multiplier allowed',         'taxi'),
  ('taxi_min_fare',             '300.0',                 'Minimum fare in LKR',                      'taxi'),
  ('taxi_free_wait_minutes',    '5',                     'Free waiting time before charges apply',   'taxi'),
  ('taxi_per_minute_wait_lkr',  '15.0',                  'Wait charge per minute (LKR)',             'taxi'),
  ('taxi_search_radius_km',     '10.0',                  'Search radius for available drivers (km)', 'taxi'),
  ('taxi_driver_timeout_sec',   '30',                    'Seconds before ride request expires',      'taxi'),
  ('taxi_sos_enabled',          'true',                  'Enable SOS emergency button in taxi',      'taxi'),

  -- Payments
  ('payhere_sandbox',           'true',                  'Run PayHere in sandbox mode',              'payments'),
  ('min_topup_amount',          '100',                   'Min wallet top-up amount (LKR)',            'payments'),
  ('max_topup_amount',          '500000',                'Max wallet top-up per transaction',        'payments'),
  ('refund_window_hours',       '48',                    'Cancellation refund window in hours',      'payments'),
  ('cancellation_fee_pct',      '0.05',                  'Late cancellation fee (5%)',               'payments'),

  -- Notifications
  ('push_notifications_enabled','true',                  'Enable Firebase push notifications',       'notifications'),
  ('email_notifications_enabled','true',                 'Enable email notifications',               'notifications'),
  ('sms_notifications_enabled', 'false',                 'Enable SMS notifications',                 'notifications'),
  ('whatsapp_notifications_enabled','true',              'Enable WhatsApp notifications',            'notifications'),
  ('email_from_name',           'Pearl Hub',             'From name in outgoing emails',             'notifications'),
  ('email_from_address',        'noreply@pearlhub.lk',  'From address in outgoing emails',          'notifications'),
  ('max_push_per_day',          '50',                    'Max push notifications per user per day',  'notifications')
ON CONFLICT (key) DO NOTHING;

-- ── 16. MISSING FEATURE FLAGS ─────────────────────────────────
INSERT INTO admin_feature_flags (flag_key, enabled, description) VALUES
  ('feature.referral.enabled',              true,  'Enable referral program'),
  ('feature.coupons.enabled',               true,  'Enable coupon/promo codes'),
  ('feature.push_notifications.enabled',    true,  'Enable push notification delivery'),
  ('feature.social_feed.enabled',           true,  'Enable social feed vertical'),
  ('feature.sme.directory.enabled',         true,  'Enable SME business directory'),
  ('feature.provider.analytics.enabled',    true,  'Enable provider analytics dashboard'),
  ('feature.customer.favorites.enabled',    true,  'Enable customer favorites/wishlist'),
  ('feature.admin.gods_view.enabled',       true,  'Enable admin God''s View map'),
  ('feature.admin.kyc_review.enabled',      true,  'Enable KYC document review workflow'),
  ('feature.admin.finance_dashboard.enabled',true, 'Enable admin finance dashboard'),
  ('feature.admin.bulk_operations.enabled', true,  'Enable bulk listing operations'),
  ('feature.listing.featured.enabled',      false, 'Enable featured/promoted listings'),
  ('feature.listing.boost.enabled',         false, 'Enable listing boost (paid)'),
  ('feature.taxi.scheduled_rides.enabled',  true,  'Enable scheduled taxi rides'),
  ('feature.taxi.sos.enabled',              true,  'Enable SOS emergency in taxi'),
  ('feature.events.qr_checkin.enabled',     true,  'Enable QR code check-in for events'),
  ('feature.events.seat_selection.enabled', true,  'Enable interactive seat selection'),
  ('feature.disputes.enabled',              true,  'Enable booking dispute system'),
  ('feature.payouts.enabled',               true,  'Enable provider payout requests'),
  ('feature.exchange_rates.auto_sync',      true,  'Auto-sync exchange rates every 6h')
ON CONFLICT (flag_key) DO NOTHING;

-- ── 17. SCHEDULED CLEANUP JOBS (pg_cron) ─────────────────────
-- Run: SELECT cron.schedule('cleanup-seat-holds', '*/5 * * * *', $$DELETE FROM seat_holds WHERE expires_at < now()$$);
-- Run: SELECT cron.schedule('cleanup-analytics', '0 2 * * 0', $$DELETE FROM analytics_events WHERE created_at < now() - INTERVAL '90 days'$$);
-- NOTE: pg_cron must be enabled in Supabase Dashboard → Database → Extensions

DO $$
BEGIN
  -- Only schedule if pg_cron extension exists
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'cleanup-expired-seat-holds',
      '*/5 * * * *',
      'DELETE FROM seat_holds WHERE expires_at < now()'
    );
    PERFORM cron.schedule(
      'cleanup-old-analytics',
      '0 2 * * 0',
      'DELETE FROM analytics_events WHERE created_at < now() - INTERVAL ''90 days'''
    );
    PERFORM cron.schedule(
      'update-provider-online-status',
      '*/2 * * * *',
      'UPDATE provider_locations SET online = false WHERE last_updated < now() - INTERVAL ''5 minutes'' AND online = true'
    );
  END IF;
END $$;
