-- Phase 2: Geospatial Listings & Availability Management
-- Adds PostGIS support for location-based search and availability slot management

-- Enable PostGIS if not already enabled (redundant but safe)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- 1. GEOSPATIAL LISTINGS TABLE (for all listing types)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.listings_geospatial (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id TEXT NOT NULL UNIQUE,
  listing_type TEXT NOT NULL CHECK (listing_type IN ('stay', 'vehicle', 'event', 'property')),
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Location data
  title TEXT NOT NULL,
  description TEXT,
  location_name TEXT,
  latitude NUMERIC(11,8),
  longitude NUMERIC(11,8),
  geom GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
    CASE 
      WHEN latitude IS NOT NULL AND longitude IS NOT NULL 
      THEN ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
      ELSE NULL
    END
  ) STORED,
  
  -- Pricing
  price_per_unit NUMERIC(12,2),
  currency TEXT DEFAULT 'LKR',
  
  -- Availability window
  available_from DATE,
  available_until DATE,
  
  -- Search metadata
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  amenities TEXT[] DEFAULT ARRAY[]::TEXT[],
  rating NUMERIC(3,2) DEFAULT 0,
  review_count INTEGER DEFAULT 0,
  
  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for efficient querying
CREATE INDEX idx_listings_geospatial_geom ON public.listings_geospatial 
  USING GIST(geom);
CREATE INDEX idx_listings_geospatial_provider_id ON public.listings_geospatial(provider_id);
CREATE INDEX idx_listings_geospatial_listing_type ON public.listings_geospatial(listing_type);
CREATE INDEX idx_listings_geospatial_is_active ON public.listings_geospatial(is_active);
CREATE INDEX idx_listings_geospatial_created_at ON public.listings_geospatial(created_at DESC);
CREATE INDEX idx_listings_geospatial_tags ON public.listings_geospatial USING GIN(tags);

-- Trigger to update updated_at
CREATE TRIGGER update_listings_geospatial_updated_at
  BEFORE UPDATE ON public.listings_geospatial
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 2. AVAILABILITY SLOTS TABLE (for granular per-day availability)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.availability_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES public.listings_geospatial(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Date availability
  slot_date DATE NOT NULL,
  is_available BOOLEAN NOT NULL DEFAULT true,
  
  -- Time windows (for events/hourly rentals)
  time_start TIME,
  time_end TIME,
  
  -- Occupancy tracking
  total_slots INTEGER,
  booked_slots INTEGER DEFAULT 0,
  
  -- Pricing override (null = use default price)
  price_override NUMERIC(12,2),
  
  -- Status
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Enforce one slot per day per listing
  UNIQUE(listing_id, slot_date, time_start, time_end)
);

-- Indexes for efficient querying
CREATE INDEX idx_availability_slots_listing_id ON public.availability_slots(listing_id);
CREATE INDEX idx_availability_slots_provider_id ON public.availability_slots(provider_id);
CREATE INDEX idx_availability_slots_slot_date ON public.availability_slots(slot_date);
CREATE INDEX idx_availability_slots_is_available ON public.availability_slots(is_available);
CREATE INDEX idx_availability_slots_date_range ON public.availability_slots(slot_date) 
  WHERE is_available = true;

-- Trigger to update updated_at
CREATE TRIGGER update_availability_slots_updated_at
  BEFORE UPDATE ON public.availability_slots
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 3. GEOSPATIAL SEARCH FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_listings_by_radius(
  p_latitude NUMERIC,
  p_longitude NUMERIC,
  p_radius_km NUMERIC DEFAULT 5,
  p_listing_type TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  listing_id TEXT,
  listing_type TEXT,
  provider_id UUID,
  title TEXT,
  description TEXT,
  location_name TEXT,
  latitude NUMERIC,
  longitude NUMERIC,
  distance_km NUMERIC,
  price_per_unit NUMERIC,
  currency TEXT,
  rating NUMERIC,
  review_count INTEGER,
  is_featured BOOLEAN,
  created_at TIMESTAMPTZ,
  tags TEXT[],
  amenities TEXT[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_search_point GEOMETRY;
BEGIN
  v_search_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
  
  RETURN QUERY
  SELECT 
    l.id,
    l.listing_id,
    l.listing_type,
    l.provider_id,
    l.title,
    l.description,
    l.location_name,
    l.latitude,
    l.longitude,
    ROUND(
      (ST_Distance(l.geom, v_search_point) * 111.32)::NUMERIC, 
      2
    ) AS distance_km,
    l.price_per_unit,
    l.currency,
    l.rating,
    l.review_count,
    l.is_featured,
    l.created_at,
    l.tags,
    l.amenities
  FROM public.listings_geospatial l
  WHERE 
    l.is_active = true
    AND l.geom IS NOT NULL
    AND ST_DWithin(l.geom, v_search_point, p_radius_km / 111.32)
    AND (p_listing_type IS NULL OR l.listing_type = p_listing_type)
  ORDER BY 
    l.is_featured DESC,
    ST_Distance(l.geom, v_search_point) ASC,
    l.rating DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_listings_by_radius(NUMERIC, NUMERIC, NUMERIC, TEXT, INTEGER, INTEGER) 
  TO anon, authenticated;

-- ============================================================================
-- 4. AVAILABILITY MANAGEMENT FUNCTIONS
-- ============================================================================

-- Function to set availability for a date range
CREATE OR REPLACE FUNCTION public.set_availability_range(
  p_listing_id UUID,
  p_start_date DATE,
  p_end_date DATE,
  p_is_available BOOLEAN,
  p_total_slots INTEGER DEFAULT NULL
)
RETURNS TABLE (
  slots_created INTEGER,
  slots_modified INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_date DATE;
  v_inserted_count INTEGER := 0;
  v_updated_count INTEGER := 0;
  v_provider_id UUID;
BEGIN
  -- Verify user owns the listing
  SELECT provider_id INTO v_provider_id
  FROM public.listings_geospatial
  WHERE id = p_listing_id;
  
  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Listing not found';
  END IF;
  
  IF v_provider_id != auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  
  -- Loop through date range and create/update slots
  v_current_date := p_start_date;
  WHILE v_current_date <= p_end_date LOOP
    INSERT INTO public.availability_slots (
      listing_id, provider_id, slot_date, is_available, total_slots
    )
    VALUES (
      p_listing_id, v_provider_id, v_current_date, p_is_available, p_total_slots
    )
    ON CONFLICT (listing_id, slot_date, time_start, time_end) 
    DO UPDATE SET
      is_available = EXCLUDED.is_available,
      total_slots = COALESCE(EXCLUDED.total_slots, public.availability_slots.total_slots),
      updated_at = now()
    WHERE public.availability_slots.time_start IS NULL;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
      v_inserted_count := v_inserted_count + 1;
    ELSE
      v_updated_count := v_updated_count + 1;
    END IF;
    
    v_current_date := v_current_date + INTERVAL '1 day';
  END LOOP;
  
  RETURN QUERY SELECT v_inserted_count, v_updated_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_availability_range(UUID, DATE, DATE, BOOLEAN, INTEGER) 
  TO authenticated;

-- Function to check availability for a listing on a date
CREATE OR REPLACE FUNCTION public.check_availability(
  p_listing_id UUID,
  p_slot_date DATE
)
RETURNS TABLE (
  is_available BOOLEAN,
  total_slots INTEGER,
  booked_slots INTEGER,
  available_slots INTEGER,
  price_override NUMERIC
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    COALESCE(s.is_available, true),
    s.total_slots,
    s.booked_slots,
    COALESCE(s.total_slots - s.booked_slots, 999),
    s.price_override
  FROM public.availability_slots s
  WHERE s.listing_id = p_listing_id
    AND s.slot_date = p_slot_date;
$$;

GRANT EXECUTE ON FUNCTION public.check_availability(UUID, DATE) 
  TO anon, authenticated;

-- ============================================================================
-- 5. ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE public.listings_geospatial ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

-- Listings: Read for everyone, write for provider/admin
CREATE POLICY "listings_geospatial_read"
  ON public.listings_geospatial FOR SELECT
  USING (is_active = true OR provider_id = auth.uid() OR public.is_admin(auth.uid()));

CREATE POLICY "listings_geospatial_write"
  ON public.listings_geospatial FOR INSERT
  WITH CHECK (provider_id = auth.uid());

CREATE POLICY "listings_geospatial_update"
  ON public.listings_geospatial FOR UPDATE
  USING (provider_id = auth.uid() OR public.is_admin(auth.uid()))
  WITH CHECK (provider_id = auth.uid() OR public.is_admin(auth.uid()));

CREATE POLICY "listings_geospatial_delete"
  ON public.listings_geospatial FOR DELETE
  USING (provider_id = auth.uid() OR public.is_admin(auth.uid()));

-- Availability: Read for everyone (live status), write for provider
CREATE POLICY "availability_slots_read"
  ON public.availability_slots FOR SELECT
  USING (true);

CREATE POLICY "availability_slots_write"
  ON public.availability_slots FOR INSERT
  WITH CHECK (provider_id = auth.uid());

CREATE POLICY "availability_slots_update"
  ON public.availability_slots FOR UPDATE
  USING (provider_id = auth.uid() OR public.is_admin(auth.uid()))
  WITH CHECK (provider_id = auth.uid() OR public.is_admin(auth.uid()));

CREATE POLICY "availability_slots_delete"
  ON public.availability_slots FOR DELETE
  USING (provider_id = auth.uid() OR public.is_admin(auth.uid()));

-- ============================================================================
-- 6. AUDIT LOGGING (track listing and availability changes)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  record_id UUID,
  action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_data JSONB,
  new_data JSONB,
  changed_by UUID REFERENCES auth.users(id),
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_table_record ON public.audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_changed_at ON public.audit_log(changed_at DESC);

-- Audit trigger for listings_geospatial
CREATE OR REPLACE FUNCTION public.audit_listings_geospatial()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.audit_log (table_name, record_id, action, old_data, new_data, changed_by)
  VALUES (
    'listings_geospatial',
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE NULL END,
    CASE WHEN TG_OP != 'DELETE' THEN row_to_json(NEW) ELSE NULL END,
    auth.uid()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER audit_listings_geospatial_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.listings_geospatial
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_listings_geospatial();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
