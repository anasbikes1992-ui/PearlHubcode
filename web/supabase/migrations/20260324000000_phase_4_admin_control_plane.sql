-- ══════════════════════════════════════════════════════════════
-- PEARL HUB PRO — Phase 4 Admin Control Plane Migration
-- 2026-03-24
-- Unified backend controls for moderation, reports, metrics, and feature flags
-- ══════════════════════════════════════════════════════════════

-- ── 1. Core helper: admin authorization guard ─────────────────
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE ur.user_id = p_user_id
      AND ur.role = 'admin'
  );
$$;

-- ── 2. Unified admin action logger ─────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_log_action(
  p_action_type TEXT,
  p_target_type TEXT,
  p_target_id UUID,
  p_details JSONB DEFAULT '{}'::jsonb
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

  INSERT INTO public.admin_actions (admin_id, action_type, target_type, target_id, details)
  VALUES (auth.uid(), p_action_type, p_target_type, p_target_id, COALESCE(p_details, '{}'::jsonb));
END;
$$;

-- ── 3. Admin feature flags table (backend control switches) ───
CREATE TABLE IF NOT EXISTS public.admin_feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flag_key TEXT NOT NULL UNIQUE CHECK (char_length(flag_key) BETWEEN 2 AND 120),
  enabled BOOLEAN NOT NULL DEFAULT false,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  description TEXT DEFAULT '' CHECK (char_length(description) <= 1000),
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_feature_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can read feature flags" ON public.admin_feature_flags;
CREATE POLICY "Admins can read feature flags"
  ON public.admin_feature_flags FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage feature flags" ON public.admin_feature_flags;
CREATE POLICY "Admins can manage feature flags"
  ON public.admin_feature_flags FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Track updated_at
DROP TRIGGER IF EXISTS trg_admin_feature_flags_updated_at ON public.admin_feature_flags;
CREATE TRIGGER trg_admin_feature_flags_updated_at
  BEFORE UPDATE ON public.admin_feature_flags
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Seed critical toggles used by web + Flutter clients.
INSERT INTO public.admin_feature_flags (flag_key, enabled, payload, description)
VALUES
  ('feature.taxi.enabled', true, '{"rollout":100}'::jsonb, 'Master switch for Pearl Taxi flows'),
  ('feature.events.qr_scan.enabled', true, '{"offlineGraceMinutes":10}'::jsonb, 'Enable event QR validation flow'),
  ('feature.wallet.topup.enabled', true, '{}'::jsonb, 'Allow wallet top-ups and payment entries'),
  ('feature.ai.concierge.enabled', true, '{"provider":"anthropic"}'::jsonb, 'AI concierge access toggle'),
  ('feature.provider.dynamic_pricing.enabled', true, '{}'::jsonb, 'Enable provider pricing advisor')
ON CONFLICT (flag_key) DO NOTHING;

-- ── 4. Moderation indexes for admin queue performance ─────────
CREATE INDEX IF NOT EXISTS idx_user_reports_status_created_at
  ON public.user_reports (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_actions_created_at
  ON public.admin_actions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_properties_moderation_status
  ON public.properties_listings (moderation_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_social_moderation_status
  ON public.social_listings (moderation_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_sme_businesses_moderation_status
  ON public.sme_businesses (moderation_status, updated_at DESC);

-- Ensure moderation columns exist on legacy environments.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'stays_listings' AND column_name = 'moderation_status') THEN
    ALTER TABLE public.stays_listings ADD COLUMN moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'suspended'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'stays_listings' AND column_name = 'active') THEN
    ALTER TABLE public.stays_listings ADD COLUMN active BOOLEAN NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'stays_listings' AND column_name = 'admin_notes') THEN
    ALTER TABLE public.stays_listings ADD COLUMN admin_notes TEXT DEFAULT '';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles_listings' AND column_name = 'moderation_status') THEN
    ALTER TABLE public.vehicles_listings ADD COLUMN moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'suspended'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles_listings' AND column_name = 'active') THEN
    ALTER TABLE public.vehicles_listings ADD COLUMN active BOOLEAN NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles_listings' AND column_name = 'admin_notes') THEN
    ALTER TABLE public.vehicles_listings ADD COLUMN admin_notes TEXT DEFAULT '';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'events_listings' AND column_name = 'moderation_status') THEN
    ALTER TABLE public.events_listings ADD COLUMN moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'suspended'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'events_listings' AND column_name = 'active') THEN
    ALTER TABLE public.events_listings ADD COLUMN active BOOLEAN NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'events_listings' AND column_name = 'admin_notes') THEN
    ALTER TABLE public.events_listings ADD COLUMN admin_notes TEXT DEFAULT '';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'properties_listings' AND column_name = 'moderation_status') THEN
    ALTER TABLE public.properties_listings ADD COLUMN moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'suspended'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'properties_listings' AND column_name = 'active') THEN
    ALTER TABLE public.properties_listings ADD COLUMN active BOOLEAN NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'properties_listings' AND column_name = 'admin_notes') THEN
    ALTER TABLE public.properties_listings ADD COLUMN admin_notes TEXT DEFAULT '';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'social_listings' AND column_name = 'moderation_status') THEN
    ALTER TABLE public.social_listings ADD COLUMN moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'suspended'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'social_listings' AND column_name = 'active') THEN
    ALTER TABLE public.social_listings ADD COLUMN active BOOLEAN NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'social_listings' AND column_name = 'admin_notes') THEN
    ALTER TABLE public.social_listings ADD COLUMN admin_notes TEXT DEFAULT '';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'sme_businesses' AND column_name = 'moderation_status') THEN
    ALTER TABLE public.sme_businesses ADD COLUMN moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'suspended'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'sme_businesses' AND column_name = 'active') THEN
    ALTER TABLE public.sme_businesses ADD COLUMN active BOOLEAN NOT NULL DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'sme_businesses' AND column_name = 'admin_notes') THEN
    ALTER TABLE public.sme_businesses ADD COLUMN admin_notes TEXT DEFAULT '';
  END IF;
END $$;

-- Ensure wallet currency exists for metrics aggregation.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'wallet_transactions'
      AND column_name = 'currency'
  ) THEN
    ALTER TABLE public.wallet_transactions
      ADD COLUMN currency TEXT NOT NULL DEFAULT 'LKR';
  END IF;
END $$;

-- ── 5. Unified moderation queue view ───────────────────────────
CREATE OR REPLACE VIEW public.admin_moderation_queue AS
SELECT
  'stay'::text AS listing_type,
  s.id,
  s.user_id,
  s.title AS display_name,
  s.location,
  s.moderation_status,
  s.active,
  s.admin_notes,
  s.updated_at,
  s.created_at
FROM public.stays_listings s
UNION ALL
SELECT
  'vehicle'::text AS listing_type,
  v.id,
  v.user_id,
  concat_ws(' ', v.make, v.model) AS display_name,
  v.location,
  v.moderation_status,
  v.active,
  v.admin_notes,
  v.updated_at,
  v.created_at
FROM public.vehicles_listings v
UNION ALL
SELECT
  'event'::text AS listing_type,
  e.id,
  e.user_id,
  e.title AS display_name,
  e.location,
  e.moderation_status,
  e.active,
  e.admin_notes,
  e.updated_at,
  e.created_at
FROM public.events_listings e
UNION ALL
SELECT
  'property'::text AS listing_type,
  p.id,
  p.user_id,
  p.title AS display_name,
  p.location,
  p.moderation_status,
  p.active,
  p.admin_notes,
  p.updated_at,
  p.created_at
FROM public.properties_listings p
UNION ALL
SELECT
  'social'::text AS listing_type,
  sl.id,
  sl.user_id,
  sl.name AS display_name,
  sl.location,
  sl.moderation_status,
  sl.active,
  sl.admin_notes,
  sl.updated_at,
  sl.created_at
FROM public.social_listings sl
UNION ALL
SELECT
  'sme'::text AS listing_type,
  sb.id,
  sb.user_id,
  sb.business_name AS display_name,
  sb.location,
  sb.moderation_status,
  sb.active,
  sb.admin_notes,
  sb.updated_at,
  sb.created_at
FROM public.sme_businesses sb;

GRANT SELECT ON public.admin_moderation_queue TO authenticated;

-- ── 6. Admin RPC: update moderation status across verticals ───
CREATE OR REPLACE FUNCTION public.admin_update_listing_moderation(
  p_listing_type TEXT,
  p_listing_id UUID,
  p_moderation_status TEXT,
  p_admin_note TEXT DEFAULT '',
  p_active BOOLEAN DEFAULT true
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed_types CONSTANT TEXT[] := ARRAY['stay', 'vehicle', 'event', 'property', 'social', 'sme'];
  v_allowed_status CONSTANT TEXT[] := ARRAY['pending', 'approved', 'rejected', 'suspended'];
  v_updated_rows INTEGER := 0;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  IF NOT (p_listing_type = ANY (v_allowed_types)) THEN
    RAISE EXCEPTION 'Unsupported listing_type: %', p_listing_type;
  END IF;

  IF NOT (p_moderation_status = ANY (v_allowed_status)) THEN
    RAISE EXCEPTION 'Unsupported moderation_status: %', p_moderation_status;
  END IF;

  IF p_listing_type = 'stay' THEN
    UPDATE public.stays_listings
    SET moderation_status = p_moderation_status,
        active = p_active,
        admin_notes = COALESCE(p_admin_note, ''),
        updated_at = now()
    WHERE id = p_listing_id;
  ELSIF p_listing_type = 'vehicle' THEN
    UPDATE public.vehicles_listings
    SET moderation_status = p_moderation_status,
        active = p_active,
        admin_notes = COALESCE(p_admin_note, ''),
        updated_at = now()
    WHERE id = p_listing_id;
  ELSIF p_listing_type = 'event' THEN
    UPDATE public.events_listings
    SET moderation_status = p_moderation_status,
        active = p_active,
        admin_notes = COALESCE(p_admin_note, ''),
        updated_at = now()
    WHERE id = p_listing_id;
  ELSIF p_listing_type = 'property' THEN
    UPDATE public.properties_listings
    SET moderation_status = p_moderation_status,
        active = p_active,
        admin_notes = COALESCE(p_admin_note, ''),
        updated_at = now()
    WHERE id = p_listing_id;
  ELSIF p_listing_type = 'social' THEN
    UPDATE public.social_listings
    SET moderation_status = p_moderation_status,
        active = p_active,
        admin_notes = COALESCE(p_admin_note, ''),
        updated_at = now()
    WHERE id = p_listing_id;
  ELSE
    UPDATE public.sme_businesses
    SET moderation_status = p_moderation_status,
        active = p_active,
        admin_notes = COALESCE(p_admin_note, ''),
        updated_at = now()
    WHERE id = p_listing_id;
  END IF;

  GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

  IF v_updated_rows = 0 THEN
    RAISE EXCEPTION 'Listing not found for type % and id %', p_listing_type, p_listing_id;
  END IF;

  PERFORM public.admin_log_action(
    'moderation_update',
    'listing',
    p_listing_id,
    jsonb_build_object(
      'listing_type', p_listing_type,
      'moderation_status', p_moderation_status,
      'active', p_active,
      'admin_note', COALESCE(p_admin_note, '')
    )
  );
END;
$$;

-- ── 7. Admin RPC: resolve user reports ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_resolve_user_report(
  p_report_id UUID,
  p_status TEXT,
  p_admin_note TEXT DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed_status CONSTANT TEXT[] := ARRAY['pending', 'investigating', 'resolved', 'dismissed'];
  v_target_user UUID;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  IF NOT (p_status = ANY (v_allowed_status)) THEN
    RAISE EXCEPTION 'Unsupported report status: %', p_status;
  END IF;

  UPDATE public.user_reports
  SET status = p_status,
      admin_notes = COALESCE(p_admin_note, ''),
      updated_at = now()
  WHERE id = p_report_id
  RETURNING reported_user_id INTO v_target_user;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found: %', p_report_id;
  END IF;

  PERFORM public.admin_log_action(
    'report_resolution',
    'user_report',
    p_report_id,
    jsonb_build_object(
      'status', p_status,
      'reported_user_id', v_target_user,
      'admin_note', COALESCE(p_admin_note, '')
    )
  );
END;
$$;

-- ── 8. Admin RPC: dashboard metrics snapshot ──────────────────
CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics(
  p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_since TIMESTAMPTZ;
  v_result JSONB;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied: admin role required';
  END IF;

  IF p_days < 1 OR p_days > 365 THEN
    RAISE EXCEPTION 'p_days must be between 1 and 365';
  END IF;

  v_since := now() - make_interval(days => p_days);

  SELECT jsonb_build_object(
    'window_days', p_days,
    'generated_at', now(),
    'users_total', (SELECT COUNT(*) FROM public.profiles),
    'providers_total', (
      SELECT COUNT(*) FROM public.profiles
      WHERE role IN ('owner', 'broker', 'stay_provider', 'vehicle_provider', 'event_organizer', 'sme')
    ),
    'bookings_total', (
      SELECT COUNT(*) FROM public.bookings WHERE created_at >= v_since
    ),
    'bookings_completed', (
      SELECT COUNT(*) FROM public.bookings WHERE created_at >= v_since AND status = 'completed'
    ),
    'bookings_cancelled', (
      SELECT COUNT(*) FROM public.bookings WHERE created_at >= v_since AND status = 'cancelled'
    ),
    'gmv_lkr_window', (
      SELECT COALESCE(SUM(total_amount), 0)
      FROM public.bookings
      WHERE created_at >= v_since
        AND currency = 'LKR'
        AND status IN ('confirmed', 'completed')
    ),
    'reports_open', (
      SELECT COUNT(*) FROM public.user_reports WHERE status IN ('pending', 'investigating')
    ),
    'moderation_pending', (
      SELECT COUNT(*) FROM public.admin_moderation_queue WHERE moderation_status = 'pending'
    ),
    'rides_open', (
      SELECT COUNT(*) FROM public.taxi_rides
      WHERE status IN ('searching', 'accepted', 'arrived', 'in_transit')
    ),
    'wallet_volume_lkr_window', (
      SELECT COALESCE(SUM(ABS(amount)), 0)
      FROM public.wallet_transactions
      WHERE created_at >= v_since
        AND currency = 'LKR'
        AND status = 'completed'
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ── 9. Grants for authenticated clients calling RPCs ──────────
GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_log_action(TEXT, TEXT, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_listing_moderation(TEXT, UUID, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_user_report(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics(INTEGER) TO authenticated;
