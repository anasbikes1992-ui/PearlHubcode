-- Check which tables have moderation_status column
SELECT table_name, column_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND column_name = 'moderation_status'
AND table_name IN ('stays_listings', 'vehicles_listings', 'events_listings', 'properties_listings', 'social_listings', 'sme_businesses')
ORDER BY table_name;