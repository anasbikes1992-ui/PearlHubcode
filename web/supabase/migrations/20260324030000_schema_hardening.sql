-- ══════════════════════════════════════════════════════════════
-- PEARL HUB PRO — Schema Hardening (bookings + provider RPCs)
-- 2026-03-24
-- Adds payment_ref to bookings, provider_id denorm column,
-- and get_provider_bookings / get_provider_earnings RPCs.
-- ══════════════════════════════════════════════════════════════

-- ── 1. Add payment_ref to bookings ────────────────────────────
-- Required by payment-webhook Edge Function to record PayHere
-- transaction reference after successful payment confirmation.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'payment_ref'
  ) THEN
    ALTER TABLE public.bookings ADD COLUMN payment_ref TEXT NOT NULL DEFAULT '';
  END IF;
END $$;

-- ── 2. Add provider_id denorm column to bookings ──────────────
-- Set by the booking INSERT trigger below so providers can query
-- their own bookings without joining through listing tables.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'provider_id'
  ) THEN
    ALTER TABLE public.bookings ADD COLUMN provider_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bookings_provider_id
  ON public.bookings (provider_id, created_at DESC);

-- Back-fill provider_id for existing bookings via stays, then vehicles, then events
UPDATE public.bookings b
SET provider_id = s.user_id
FROM public.stays_listings s
WHERE b.listing_type = 'stay' AND b.listing_id = s.id AND b.provider_id IS NULL;

UPDATE public.bookings b
SET provider_id = v.user_id
FROM public.vehicles_listings v
WHERE b.listing_type = 'vehicle' AND b.listing_id = v.id AND b.provider_id IS NULL;

UPDATE public.bookings b
SET provider_id = e.user_id
FROM public.events_listings e
WHERE b.listing_type = 'event' AND b.listing_id = e.id AND b.provider_id IS NULL;

-- ── 3. Trigger: populate provider_id on booking INSERT ────────
CREATE OR REPLACE FUNCTION public.set_booking_provider_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.provider_id IS NULL THEN
    CASE NEW.listing_type
      WHEN 'stay' THEN
        SELECT user_id INTO NEW.provider_id FROM public.stays_listings WHERE id = NEW.listing_id;
      WHEN 'vehicle' THEN
        SELECT user_id INTO NEW.provider_id FROM public.vehicles_listings WHERE id = NEW.listing_id;
      WHEN 'event' THEN
        SELECT user_id INTO NEW.provider_id FROM public.events_listings WHERE id = NEW.listing_id;
      ELSE
        NULL;
    END CASE;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_booking_provider_id ON public.bookings;
CREATE TRIGGER trg_booking_provider_id
  BEFORE INSERT ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.set_booking_provider_id();

-- ── 4. RLS: providers can read own bookings ───────────────────
DROP POLICY IF EXISTS "Providers can read own bookings via provider_id" ON public.bookings;
CREATE POLICY "Providers can read own bookings via provider_id"
  ON public.bookings FOR SELECT TO authenticated
  USING (provider_id = auth.uid());

-- ── 5. RPC: get_provider_bookings ─────────────────────────────
-- Returns bookings for the calling provider, with listing title.
CREATE OR REPLACE FUNCTION public.get_provider_bookings(p_limit INT DEFAULT 50)
RETURNS TABLE (
  id             UUID,
  user_id        UUID,
  listing_id     UUID,
  listing_type   TEXT,
  booking_date   DATE,
  check_in_date  DATE,
  check_out_date DATE,
  total_amount   NUMERIC,
  currency       TEXT,
  status         TEXT,
  payment_ref    TEXT,
  created_at     TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    b.id, b.user_id, b.listing_id, b.listing_type,
    b.booking_date, b.check_in_date, b.check_out_date,
    b.total_amount, b.currency, b.status, b.payment_ref, b.created_at
  FROM public.bookings b
  WHERE b.provider_id = auth.uid()
  ORDER BY b.created_at DESC
  LIMIT p_limit;
$$;

-- ── 6. RPC: get_provider_earnings_summary ─────────────────────
CREATE OR REPLACE FUNCTION public.get_provider_earnings_summary()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'total_net',      COALESCE(SUM(net_amount), 0),
    'total_gross',    COALESCE(SUM(amount), 0),
    'total_commission', COALESCE(SUM(commission), 0),
    'count',          COUNT(*)
  )
  FROM public.earnings
  WHERE provider_id = auth.uid();
$$;

-- ── 7. Admin can see all bookings ──────────────────────────────
DROP POLICY IF EXISTS "Admins can read all bookings" ON public.bookings;
CREATE POLICY "Admins can read all bookings"
  ON public.bookings FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));
