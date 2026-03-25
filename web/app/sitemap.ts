// app/sitemap.ts - Dynamic sitemap generation for Next.js 15
import { MetadataRoute } from 'next';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://pearlhub.lk';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // Static routes
  const staticRoutes = [
    { url: '', changeFrequency: 'daily', priority: 1 },
    { url: '/search', changeFrequency: 'daily', priority: 0.9 },
    { url: '/listings', changeFrequency: 'daily', priority: 0.8 },
    { url: '/about', changeFrequency: 'monthly', priority: 0.5 },
    { url: '/contact', changeFrequency: 'monthly', priority: 0.5 },
    { url: '/trust-safety', changeFrequency: 'monthly', priority: 0.6 },
  ].map((route) => ({
    url: `${baseUrl}${route.url}`,
    lastModified: new Date().toISOString(),
    changeFrequency: route.changeFrequency as any,
    priority: route.priority,
  }));

  // Dynamic listing routes
  const { data: listings, error } = await supabase
    .from('listings_geospatial')
    .select('id, updated_at')
    .eq('is_active', true)
    .limit(50000); // GSC limit

  if (error) {
    console.error('Error fetching listings for sitemap:', error);
    return staticRoutes;
  }

  const listingRoutes = (listings || []).map((listing) => ({
    url: `${baseUrl}/listing/${listing.id}`,
    lastModified: listing.updated_at,
    changeFrequency: 'weekly' as const,
    priority: 0.7,
  }));

  return [...staticRoutes, ...listingRoutes];
}
