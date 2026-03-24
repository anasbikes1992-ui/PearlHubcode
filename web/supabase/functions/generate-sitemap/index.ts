import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const BASE_URL = Deno.env.get('SITE_URL') ?? 'https://pearlhubpro.com';

serve(async (req: Request) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Static routes
    const staticRoutes = [
      { path: '/', priority: '1.0', changefreq: 'daily' },
      { path: '/stays', priority: '0.9', changefreq: 'hourly' },
      { path: '/vehicles', priority: '0.9', changefreq: 'hourly' },
      { path: '/events', priority: '0.9', changefreq: 'hourly' },
      { path: '/properties', priority: '0.9', changefreq: 'hourly' },
      { path: '/marketplace', priority: '0.8', changefreq: 'daily' },
      { path: '/taxi', priority: '0.8', changefreq: 'daily' },
      { path: '/social', priority: '0.7', changefreq: 'hourly' },
    ];

    const urlEntries: string[] = staticRoutes.map(({ path, priority, changefreq }) =>
      `  <url>
    <loc>${BASE_URL}${path}</loc>
    <changefreq>${changefreq}</changefreq>
    <priority>${priority}</priority>
  </url>`
    );

    // Dynamic listing pages
    const tables: Array<{ table: string; slug: string }> = [
      { table: 'stays', slug: 'stays' },
      { table: 'vehicles', slug: 'vehicles' },
      { table: 'events', slug: 'events' },
      { table: 'properties', slug: 'properties' },
    ];

    for (const { table, slug } of tables) {
      const { data } = await supabase
        .from(table)
        .select('id, updated_at')
        .eq('status', 'active')
        .limit(5000);

      for (const row of data ?? []) {
        urlEntries.push(
          `  <url>
    <loc>${BASE_URL}/${slug}/${row.id}</loc>
    <lastmod>${(row.updated_at ?? new Date().toISOString()).split('T')[0]}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.7</priority>
  </url>`
        );
      }
    }

    const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urlEntries.join('\n')}
</urlset>`;

    return new Response(sitemap, {
      headers: {
        'Content-Type': 'application/xml; charset=utf-8',
        'Cache-Control': 'public, max-age=3600',
      },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
