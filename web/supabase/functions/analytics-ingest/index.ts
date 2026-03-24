import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface AnalyticsEvent {
  event_type: string;
  user_id?: string;
  session_id?: string;
  page?: string;
  listing_id?: string;
  listing_type?: string;
  properties?: Record<string, unknown>;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();

    // Accept either a single event or a batch array
    const events: AnalyticsEvent[] = Array.isArray(body) ? body : [body];

    if (events.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No events provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (events.length > 100) {
      return new Response(
        JSON.stringify({ error: 'Batch size must not exceed 100 events' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const rows = events.map((e) => ({
      event_type: e.event_type,
      user_id: e.user_id ?? null,
      session_id: e.session_id ?? null,
      page: e.page ?? null,
      listing_id: e.listing_id ?? null,
      listing_type: e.listing_type ?? null,
      properties: e.properties ?? {},
      created_at: new Date().toISOString(),
    }));

    const { error } = await supabase.from('analytics_events').insert(rows);
    if (error) throw error;

    return new Response(
      JSON.stringify({ success: true, ingested: rows.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
