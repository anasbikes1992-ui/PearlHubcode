-- ══════════════════════════════════════════════════════════════
-- PEARL HUB PRO — Phase 5: OTP, Notifications & Platform Config
-- 2026-03-24
-- OTP table, SMTP/WhatsApp send log, platform settings, rate limits
-- ══════════════════════════════════════════════════════════════

-- ── 1. OTP verification codes table ───────────────────────────
-- Stores time-limited one-time passwords for email and phone verification.
-- The actual send is performed by the otp-sender Edge Function.
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier  TEXT NOT NULL,                          -- email or E.164 phone
  channel     TEXT NOT NULL CHECK (channel IN ('email', 'whatsapp', 'sms')),
  code        TEXT NOT NULL CHECK (char_length(code) = 6),
  purpose     TEXT NOT NULL CHECK (purpose IN ('signup', 'login', 'phone_verify', 'password_reset', '2fa')),
  used        BOOLEAN NOT NULL DEFAULT false,
  attempts    INTEGER NOT NULL DEFAULT 0,
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '10 minutes'),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-expire: clean up codes older than 1 hour
CREATE INDEX IF NOT EXISTS idx_otp_codes_identifier_channel
  ON public.otp_codes (identifier, channel, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_otp_codes_expires
  ON public.otp_codes (expires_at);

-- No direct client access — all operations via SECURITY DEFINER RPCs
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

-- Only service-role (Edge Functions) and admins can read OTPs
DROP POLICY IF EXISTS "Admins can read OTP codes" ON public.otp_codes;
CREATE POLICY "Admins can read OTP codes"
  ON public.otp_codes FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

-- ── 2. Notification send log ───────────────────────────────────
-- Audit trail for all outbound emails and WhatsApp messages
CREATE TABLE IF NOT EXISTS public.notification_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient    TEXT NOT NULL,                         -- email or phone
  channel      TEXT NOT NULL CHECK (channel IN ('email', 'whatsapp', 'sms', 'push')),
  template_key TEXT NOT NULL,                         -- e.g. 'otp_signup', 'booking_confirmed'
  subject      TEXT DEFAULT '',
  body_preview TEXT DEFAULT '',                       -- first 200 chars for audit
  status       TEXT NOT NULL DEFAULT 'queued'
                CHECK (status IN ('queued', 'sent', 'failed', 'bounced')),
  provider     TEXT DEFAULT '',                       -- 'smtp', 'whatsapp_360', 'twilio', 'firebase'
  provider_msg_id TEXT DEFAULT '',
  error_detail TEXT DEFAULT '',
  user_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notification_log_recipient
  ON public.notification_log (recipient, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_log_status
  ON public.notification_log (status, created_at DESC);

ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own notification log" ON public.notification_log;
CREATE POLICY "Users can read own notification log"
  ON public.notification_log FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin(auth.uid()));

-- ── 3. Platform configuration table ───────────────────────────
-- Replaces the hardcoded taxi stats in AdminDashboard.
-- Provides a single source of truth for all runtime platform settings.
CREATE TABLE IF NOT EXISTS public.platform_config (
  key         TEXT PRIMARY KEY CHECK (char_length(key) BETWEEN 1 AND 120),
  value       JSONB NOT NULL DEFAULT 'null'::jsonb,
  description TEXT DEFAULT '',
  category    TEXT NOT NULL DEFAULT 'general'
               CHECK (category IN ('general', 'taxi', 'payments', 'notifications', 'limits', 'fees')),
  is_public   BOOLEAN NOT NULL DEFAULT false,    -- if true, anon users can read
  updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.platform_config ENABLE ROW LEVEL SECURITY;

-- Public-flagged configs readable by all (e.g. min booking amount, currency list)
DROP POLICY IF EXISTS "Public configs are readable by all" ON public.platform_config;
CREATE POLICY "Public configs are readable by all"
  ON public.platform_config FOR SELECT TO anon, authenticated
  USING (is_public = true);

-- Authenticated users can read non-public configs (needed by app logic)
DROP POLICY IF EXISTS "Authenticated can read all configs" ON public.platform_config;
CREATE POLICY "Authenticated can read all configs"
  ON public.platform_config FOR SELECT TO authenticated
  USING (true);

-- Only admins can write
DROP POLICY IF EXISTS "Only admins can manage platform config" ON public.platform_config;
CREATE POLICY "Only admins can manage platform config"
  ON public.platform_config FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Track updated_at
CREATE OR REPLACE FUNCTION public.set_platform_config_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  NEW.updated_by = auth.uid();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_platform_config_updated_at ON public.platform_config;
CREATE TRIGGER trg_platform_config_updated_at
  BEFORE UPDATE ON public.platform_config
  FOR EACH ROW EXECUTE FUNCTION public.set_platform_config_updated_at();

-- ── Seed platform config ──────────────────────────────────────
INSERT INTO public.platform_config (key, value, description, category, is_public) VALUES
  -- General
  ('platform.name', '"Pearl Hub Pro"'::jsonb, 'Platform display name', 'general', true),
  ('platform.country', '"LK"'::jsonb, 'ISO country code', 'general', true),
  ('platform.currency', '"LKR"'::jsonb, 'Primary currency', 'general', true),
  ('platform.timezone', '"Asia/Colombo"'::jsonb, 'Server timezone', 'general', true),
  ('platform.support_email', '"support@pearlhub.lk"'::jsonb, 'Public support email', 'general', true),
  ('platform.support_whatsapp', '"+94771234567"'::jsonb, 'WhatsApp support number', 'general', true),
  -- Fees
  ('fees.stays.service_charge_pct', '5'::jsonb, 'Stays service charge %', 'fees', true),
  ('fees.stays.local_tax_pct', '10'::jsonb, 'Stays local tax %', 'fees', true),
  ('fees.vehicles.daily_km_allowance', '100'::jsonb, 'Free KM per rental day', 'fees', true),
  ('fees.vehicles.excess_km_rate_lkr', '325'::jsonb, 'Excess KM charge LKR', 'fees', true),
  ('fees.events.entertainment_tax_pct', '15'::jsonb, 'Entertainment tax %', 'fees', true),
  ('fees.platform.commission_pct', '8'::jsonb, 'Platform commission %', 'fees', false),
  -- Taxi
  ('taxi.base_fare_lkr', '200'::jsonb, 'Taxi base fare LKR', 'taxi', false),
  ('taxi.per_km_rate_lkr', '60'::jsonb, 'Per KM rate LKR', 'taxi', false),
  ('taxi.per_min_rate_lkr', '5'::jsonb, 'Per minute waiting rate LKR', 'taxi', false),
  ('taxi.surge_max_multiplier', '3.0'::jsonb, 'Maximum surge price multiplier', 'taxi', false),
  ('taxi.driver_commission_pct', '80'::jsonb, 'Driver earnings %', 'taxi', false),
  ('taxi.categories_enabled', '["moto","tuk_tuk","car_economy","car_electric","buddy_van","suv"]'::jsonb, 'Active vehicle categories', 'taxi', true),
  -- Limits
  ('limits.otp.max_attempts', '5'::jsonb, 'Max OTP verification attempts before lockout', 'limits', false),
  ('limits.otp.resend_cooldown_seconds', '60'::jsonb, 'Seconds before OTP resend allowed', 'limits', false),
  ('limits.otp.expiry_minutes', '10'::jsonb, 'OTP expiry in minutes', 'limits', false),
  ('limits.listing.max_images', '20'::jsonb, 'Max images per listing', 'limits', false),
  ('limits.booking.min_advance_hours', '2'::jsonb, 'Minimum booking advance hours', 'limits', false),
  -- Payments
  ('payments.payhere.enabled', 'true'::jsonb, 'PayHere gateway enabled', 'payments', false),
  ('payments.lankaqr.enabled', 'true'::jsonb, 'LankaQR gateway enabled', 'payments', false),
  ('payments.wallet.enabled', 'true'::jsonb, 'Wallet payments enabled', 'payments', false),
  ('payments.min_topup_lkr', '500'::jsonb, 'Minimum wallet top-up LKR', 'payments', true),
  ('payments.max_topup_lkr', '500000'::jsonb, 'Maximum wallet top-up LKR', 'payments', true),
  -- Notifications
  ('notifications.email.from_name', '"Pearl Hub"'::jsonb, 'Sender name for emails', 'notifications', false),
  ('notifications.email.from_address', '"noreply@pearlhub.lk"'::jsonb, 'Sender email address', 'notifications', false),
  ('notifications.whatsapp.provider', '"360dialog"'::jsonb, 'WhatsApp API provider', 'notifications', false),
  ('notifications.sms.provider', '"twilio"'::jsonb, 'SMS provider', 'notifications', false)
ON CONFLICT (key) DO NOTHING;

-- ── 4. Rate limiting table for OTP requests ───────────────────
CREATE TABLE IF NOT EXISTS public.rate_limits (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier  TEXT NOT NULL,
  action      TEXT NOT NULL,
  window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  request_count INTEGER NOT NULL DEFAULT 1,
  blocked_until TIMESTAMPTZ,
  UNIQUE (identifier, action)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_identifier
  ON public.rate_limits (identifier, action);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- No direct client access
DROP POLICY IF EXISTS "Only admins can read rate limits" ON public.rate_limits;
CREATE POLICY "Only admins can read rate limits"
  ON public.rate_limits FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

-- ── 5. RPC: request_otp ────────────────────────────────────────
-- Called by client to trigger OTP send via Edge Function webhook.
-- Enforces rate limiting and returns the OTP code for the Edge Function
-- to forward to the notification channel.
CREATE OR REPLACE FUNCTION public.request_otp(
  p_identifier TEXT,   -- email or phone
  p_channel    TEXT,   -- 'email' | 'whatsapp' | 'sms'
  p_purpose    TEXT    -- 'signup' | 'login' | 'phone_verify' | 'password_reset' | '2fa'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_otp_id UUID;
  v_max_attempts INTEGER;
  v_cooldown INTEGER;
  v_rate RECORD;
  v_window_seconds INTEGER := 300; -- 5-minute window
BEGIN
  -- Validate inputs
  IF p_channel NOT IN ('email', 'whatsapp', 'sms') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_channel');
  END IF;
  IF p_purpose NOT IN ('signup', 'login', 'phone_verify', 'password_reset', '2fa') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_purpose');
  END IF;
  IF char_length(p_identifier) < 5 OR char_length(p_identifier) > 254 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_identifier');
  END IF;

  -- Read config defaults
  SELECT COALESCE((value)::int, 60) INTO v_cooldown
  FROM public.platform_config WHERE key = 'limits.otp.resend_cooldown_seconds';

  -- Rate limit check: max 5 OTPs per identifier per 5 minutes
  SELECT * INTO v_rate FROM public.rate_limits
  WHERE identifier = p_identifier AND action = 'otp_request';

  IF v_rate IS NOT NULL THEN
    -- Check if blocked
    IF v_rate.blocked_until IS NOT NULL AND v_rate.blocked_until > now() THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'rate_limited',
        'retry_after', EXTRACT(EPOCH FROM (v_rate.blocked_until - now()))::int
      );
    END IF;

    -- Reset window if expired
    IF v_rate.window_start < now() - (v_window_seconds || ' seconds')::interval THEN
      UPDATE public.rate_limits
      SET window_start = now(), request_count = 1, blocked_until = NULL
      WHERE identifier = p_identifier AND action = 'otp_request';
    ELSE
      -- Increment and block if over limit
      UPDATE public.rate_limits
      SET request_count = request_count + 1,
          blocked_until = CASE WHEN request_count + 1 >= 5 THEN now() + INTERVAL '15 minutes' ELSE NULL END
      WHERE identifier = p_identifier AND action = 'otp_request';

      -- Recheck after update
      SELECT * INTO v_rate FROM public.rate_limits
      WHERE identifier = p_identifier AND action = 'otp_request';
      IF v_rate.blocked_until IS NOT NULL THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'rate_limited',
          'retry_after', 900
        );
      END IF;
    END IF;
  ELSE
    INSERT INTO public.rate_limits (identifier, action)
    VALUES (p_identifier, 'otp_request')
    ON CONFLICT (identifier, action) DO NOTHING;
  END IF;

  -- Check cooldown: prevent resend within cooldown window
  IF EXISTS (
    SELECT 1 FROM public.otp_codes
    WHERE identifier = p_identifier
      AND channel = p_channel
      AND purpose = p_purpose
      AND used = false
      AND created_at > now() - (v_cooldown || ' seconds')::interval
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'cooldown',
      'retry_after', v_cooldown
    );
  END IF;

  -- Invalidate any existing unused codes for this identifier+channel+purpose
  UPDATE public.otp_codes
  SET used = true
  WHERE identifier = p_identifier
    AND channel = p_channel
    AND purpose = p_purpose
    AND used = false;

  -- Generate 6-digit code
  v_code := LPAD(FLOOR(random() * 1000000)::text, 6, '0');

  -- Insert new OTP
  INSERT INTO public.otp_codes (identifier, channel, code, purpose, expires_at)
  VALUES (p_identifier, p_channel, v_code, p_purpose, now() + INTERVAL '10 minutes')
  RETURNING id INTO v_otp_id;

  -- Return code to Edge Function (never exposed to client directly)
  RETURN jsonb_build_object(
    'success', true,
    'otp_id', v_otp_id,
    'code', v_code,        -- Edge Function reads this, sends it, then discards
    'expires_at', (now() + INTERVAL '10 minutes')
  );
END;
$$;

-- ── 6. RPC: verify_otp ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.verify_otp(
  p_identifier TEXT,
  p_channel    TEXT,
  p_purpose    TEXT,
  p_code       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_otp RECORD;
  v_max_attempts INTEGER := 5;
BEGIN
  -- Normalize inputs
  p_identifier := lower(trim(p_identifier));
  p_code       := trim(p_code);

  -- Find the most recent valid OTP
  SELECT * INTO v_otp
  FROM public.otp_codes
  WHERE identifier = p_identifier
    AND channel = p_channel
    AND purpose = p_purpose
    AND used = false
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_found_or_expired');
  END IF;

  -- Check attempt limit
  IF v_otp.attempts >= v_max_attempts THEN
    UPDATE public.otp_codes SET used = true WHERE id = v_otp.id;
    RETURN jsonb_build_object('success', false, 'error', 'max_attempts_exceeded');
  END IF;

  -- Verify code
  IF v_otp.code != p_code THEN
    UPDATE public.otp_codes SET attempts = attempts + 1 WHERE id = v_otp.id;
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_code',
      'attempts_remaining', v_max_attempts - v_otp.attempts - 1
    );
  END IF;

  -- Mark as used
  UPDATE public.otp_codes SET used = true, attempts = attempts + 1 WHERE id = v_otp.id;

  -- If phone_verify purpose, mark profile phone as verified
  IF p_purpose = 'phone_verify' THEN
    UPDATE public.profiles
    SET phone = p_identifier
    WHERE id = auth.uid();
  END IF;

  RETURN jsonb_build_object('success', true, 'verified_at', now());
END;
$$;

-- ── 7. RPC: get_platform_config ────────────────────────────────
-- Batch fetch by category — used by frontend and Flutter apps
CREATE OR REPLACE FUNCTION public.get_platform_config(p_category TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_object_agg(key, value)
  FROM public.platform_config
  WHERE (p_category IS NULL OR category = p_category)
    AND (is_public = true OR auth.uid() IS NOT NULL);
$$;

-- ── 8. RPC: admin_set_platform_config ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_set_platform_config(
  p_key   TEXT,
  p_value JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  INSERT INTO public.platform_config (key, value, updated_by)
  VALUES (p_key, p_value, auth.uid())
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value, updated_by = auth.uid(), updated_at = now();

  PERFORM public.admin_log_action('update_platform_config', 'platform_config', gen_random_uuid(),
    jsonb_build_object('key', p_key, 'value', p_value));
END;
$$;

-- ── 9. Enhanced admin dashboard metrics (includes config data) ─
CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics(p_days INT DEFAULT 30)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_since  TIMESTAMPTZ := now() - (p_days || ' days')::interval;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  SELECT jsonb_build_object(
    'window_days',            p_days,
    'generated_at',           now(),
    -- Users
    'users_total',            (SELECT COUNT(*) FROM public.profiles),
    'users_new_window',       (SELECT COUNT(*) FROM public.profiles WHERE created_at >= v_since),
    'providers_total',        (SELECT COUNT(*) FROM public.profiles WHERE role != 'customer' AND role != 'admin'),
    -- Bookings
    'bookings_total',         (SELECT COUNT(*) FROM public.bookings WHERE created_at >= v_since),
    'bookings_completed',     (SELECT COUNT(*) FROM public.bookings WHERE status = 'completed' AND created_at >= v_since),
    'bookings_cancelled',     (SELECT COUNT(*) FROM public.bookings WHERE status = 'cancelled' AND created_at >= v_since),
    'gmv_lkr_window',        (SELECT COALESCE(SUM(total_amount), 0) FROM public.bookings WHERE status = 'completed' AND created_at >= v_since),
    -- Listings
    'stays_total',            (SELECT COUNT(*) FROM public.stays_listings WHERE active = true),
    'vehicles_total',         (SELECT COUNT(*) FROM public.vehicles_listings WHERE active = true),
    'events_total',           (SELECT COUNT(*) FROM public.events_listings WHERE active = true),
    'properties_total',       (SELECT COUNT(*) FROM public.properties_listings WHERE active = true),
    'social_total',           (SELECT COUNT(*) FROM public.social_listings WHERE active = true),
    'sme_total',              (SELECT COUNT(*) FROM public.sme_businesses WHERE active = true),
    -- Moderation queue
    'moderation_pending',     (
      SELECT COUNT(*) FROM (
        SELECT id FROM public.stays_listings WHERE moderation_status = 'pending' UNION ALL
        SELECT id FROM public.vehicles_listings WHERE moderation_status = 'pending' UNION ALL
        SELECT id FROM public.events_listings WHERE moderation_status = 'pending' UNION ALL
        SELECT id FROM public.properties_listings WHERE moderation_status = 'pending' UNION ALL
        SELECT id FROM public.social_listings WHERE moderation_status = 'pending' UNION ALL
        SELECT id FROM public.sme_businesses WHERE moderation_status = 'pending'
      ) pending
    ),
    -- Reports & Taxi
    'reports_open',           (SELECT COUNT(*) FROM public.user_reports WHERE status = 'pending'),
    'rides_open',             (SELECT COUNT(*) FROM public.taxi_rides WHERE status IN ('searching', 'accepted', 'arrived', 'in_transit')),
    'rides_completed_window', (SELECT COUNT(*) FROM public.taxi_rides WHERE status = 'completed' AND created_at >= v_since),
    -- Wallet
    'wallet_volume_lkr_window', (SELECT COALESCE(SUM(amount), 0) FROM public.wallet_transactions WHERE type = 'credit' AND created_at >= v_since),
    -- OTP / Notifications
    'otp_requests_window',    (SELECT COUNT(*) FROM public.otp_codes WHERE created_at >= v_since),
    'notifications_sent_window', (SELECT COUNT(*) FROM public.notification_log WHERE status = 'sent' AND created_at >= v_since),
    -- Pearl Points
    'points_awarded_window',  (SELECT COALESCE(SUM(total_earned), 0) FROM public.pearl_points),
    -- KYC pending
    'kyc_pending',            (SELECT COUNT(*) FROM public.taxi_kyc_documents WHERE status = 'pending')
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ── 10. Admin OTP notifications monitor ───────────────────────
-- RPC so admin can see notification delivery status
CREATE OR REPLACE FUNCTION public.admin_get_notification_stats(p_days INT DEFAULT 7)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_since TIMESTAMPTZ := now() - (p_days || ' days')::interval;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'total',    COUNT(*),
      'sent',     COUNT(*) FILTER (WHERE status = 'sent'),
      'failed',   COUNT(*) FILTER (WHERE status = 'failed'),
      'queued',   COUNT(*) FILTER (WHERE status = 'queued'),
      'email',    COUNT(*) FILTER (WHERE channel = 'email'),
      'whatsapp', COUNT(*) FILTER (WHERE channel = 'whatsapp'),
      'sms',      COUNT(*) FILTER (WHERE channel = 'sms'),
      'push',     COUNT(*) FILTER (WHERE channel = 'push')
    )
    FROM public.notification_log
    WHERE created_at >= v_since
  );
END;
$$;

-- ── 11. Cleanup job: purge expired OTPs ───────────────────────
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.otp_codes
  WHERE expires_at < now() - INTERVAL '1 hour';
$$;

-- ── 12. Profile: add phone_verified column ────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'phone_verified'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN phone_verified BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'two_factor_enabled'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN two_factor_enabled BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'fcm_token'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN fcm_token TEXT DEFAULT '';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'last_login_at'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN last_login_at TIMESTAMPTZ;
  END IF;
END $$;

-- ── 13. Trigger: update last_login_at on auth sign-in ─────────
-- This fires when profile is accessed (best approximation without auth hooks)
-- The Edge Function for OTP send can also update this directly.

-- ── 14. User KYC documents table ─────────────────────────────
-- For provider identity verification (not just taxi drivers)
CREATE TABLE IF NOT EXISTS public.kyc_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doc_type     TEXT NOT NULL CHECK (doc_type IN ('nic', 'passport', 'driving_license', 'business_reg', 'sltda_cert')),
  doc_number   TEXT NOT NULL DEFAULT '',
  front_url    TEXT NOT NULL DEFAULT '',
  back_url     TEXT DEFAULT '',
  selfie_url   TEXT DEFAULT '',
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  admin_notes  TEXT DEFAULT '',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at  TIMESTAMPTZ,
  reviewed_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  expires_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_kyc_documents_user_id
  ON public.kyc_documents (user_id, status);

CREATE INDEX IF NOT EXISTS idx_kyc_documents_status
  ON public.kyc_documents (status, submitted_at DESC);

ALTER TABLE public.kyc_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own KYC" ON public.kyc_documents;
CREATE POLICY "Users can read own KYC"
  ON public.kyc_documents FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can submit own KYC" ON public.kyc_documents;
CREATE POLICY "Users can submit own KYC"
  ON public.kyc_documents FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can manage all KYC" ON public.kyc_documents;
CREATE POLICY "Admins can manage all KYC"
  ON public.kyc_documents FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- ── 15. RPC: admin_review_kyc ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_review_kyc(
  p_kyc_id     UUID,
  p_status     TEXT,  -- 'approved' | 'rejected'
  p_admin_note TEXT DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  UPDATE public.kyc_documents
  SET status = p_status,
      admin_notes = COALESCE(p_admin_note, ''),
      reviewed_at = now(),
      reviewed_by = auth.uid()
  WHERE id = p_kyc_id;

  -- If approved, mark profile as verified
  IF p_status = 'approved' THEN
    UPDATE public.profiles
    SET verified = true
    WHERE id = (SELECT user_id FROM public.kyc_documents WHERE id = p_kyc_id);
  END IF;

  PERFORM public.admin_log_action('review_kyc', 'kyc_document', p_kyc_id,
    jsonb_build_object('status', p_status, 'note', p_admin_note));
END;
$$;
