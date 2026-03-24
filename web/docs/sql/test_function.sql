SELECT id::text, COALESCE(title,'') as title, 'stay' as listing_type, location, price_per_night, COALESCE(images[1],''), COALESCE(rating,0)
  FROM public.stays_listings WHERE moderation_status='approved' AND active=true
    AND (title ILIKE '%test%' OR location ILIKE '%test%') LIMIT 5;