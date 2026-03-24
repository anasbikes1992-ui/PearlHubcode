-- Drop all policies that reference moderation_status
DROP POLICY IF EXISTS "Anyone can read approved active stays" ON public.stays_listings;
DROP POLICY IF EXISTS "Anyone can read approved active vehicles" ON public.vehicles_listings;
DROP POLICY IF EXISTS "Anyone can read approved active events" ON public.events_listings;
DROP POLICY IF EXISTS "Anyone can read approved active properties" ON public.properties_listings;
DROP POLICY IF EXISTS "Anyone can read approved active social listings" ON public.social_listings;
DROP POLICY IF EXISTS "Public read approved stays" ON public.stays_listings;
DROP POLICY IF EXISTS "Public read approved vehicles" ON public.vehicles_listings;
DROP POLICY IF EXISTS "Public read approved events" ON public.events_listings;
DROP POLICY IF EXISTS "Public read approved properties" ON public.properties_listings;
DROP POLICY IF EXISTS "Public read approved social" ON public.social_listings;