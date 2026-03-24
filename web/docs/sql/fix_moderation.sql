-- Drop policies that depend on moderation_status
DROP POLICY IF EXISTS "Anyone can read approved active stays" ON public.stays_listings;
DROP POLICY IF EXISTS "Anyone can read approved active vehicles" ON public.vehicles_listings;
DROP POLICY IF EXISTS "Anyone can read approved active events" ON public.events_listings;
DROP POLICY IF EXISTS "Anyone can read approved active properties" ON public.properties_listings;
DROP POLICY IF EXISTS "Anyone can read approved active social" ON public.social_listings;

-- Fix moderation_status columns to use TEXT instead of enum
ALTER TABLE public.stays_listings ALTER COLUMN moderation_status TYPE TEXT;
ALTER TABLE public.stays_listings ADD CONSTRAINT stays_moderation_check CHECK (moderation_status IN ('pending','approved','rejected','suspended'));

ALTER TABLE public.vehicles_listings ALTER COLUMN moderation_status TYPE TEXT;
ALTER TABLE public.vehicles_listings ADD CONSTRAINT vehicles_moderation_check CHECK (moderation_status IN ('pending','approved','rejected','suspended'));

ALTER TABLE public.events_listings ALTER COLUMN moderation_status TYPE TEXT;
ALTER TABLE public.events_listings ADD CONSTRAINT events_moderation_check CHECK (moderation_status IN ('pending','approved','rejected','suspended'));

ALTER TABLE public.properties_listings ALTER COLUMN moderation_status TYPE TEXT;
ALTER TABLE public.properties_listings ADD CONSTRAINT properties_moderation_check CHECK (moderation_status IN ('pending','approved','rejected','suspended'));

ALTER TABLE public.social_listings ALTER COLUMN moderation_status TYPE TEXT;
ALTER TABLE public.social_listings ADD CONSTRAINT social_moderation_check CHECK (moderation_status IN ('pending','approved','rejected','suspended'));

-- Update default values
ALTER TABLE public.stays_listings ALTER COLUMN moderation_status SET DEFAULT 'pending';
ALTER TABLE public.vehicles_listings ALTER COLUMN moderation_status SET DEFAULT 'pending';
ALTER TABLE public.events_listings ALTER COLUMN moderation_status SET DEFAULT 'pending';
ALTER TABLE public.properties_listings ALTER COLUMN moderation_status SET DEFAULT 'pending';
ALTER TABLE public.social_listings ALTER COLUMN moderation_status SET DEFAULT 'pending';

-- Recreate the policies
CREATE POLICY "Anyone can read approved active stays" ON public.stays_listings FOR SELECT TO anon, authenticated USING (moderation_status = 'approved' AND active = true);
CREATE POLICY "Anyone can read approved active vehicles" ON public.vehicles_listings FOR SELECT TO anon, authenticated USING (moderation_status = 'approved' AND active = true);
CREATE POLICY "Anyone can read approved active events" ON public.events_listings FOR SELECT TO anon, authenticated USING (moderation_status = 'approved' AND active = true);
CREATE POLICY "Anyone can read approved active properties" ON public.properties_listings FOR SELECT TO anon, authenticated USING (moderation_status = 'approved' AND active = true);
CREATE POLICY "Anyone can read approved active social" ON public.social_listings FOR SELECT TO anon, authenticated USING (moderation_status = 'approved' AND active = true);