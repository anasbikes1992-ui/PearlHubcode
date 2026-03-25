import { corsHeaders } from '../_shared/cors.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceKey) {
      throw new Error('Missing Supabase env vars');
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: events, error } = await supabase
      .from('webhook_events')
      .select('*')
      .in('status', ['pending', 'failed'])
      .or('next_retry_at.is.null,next_retry_at.lte.now()')
      .order('created_at', { ascending: true })
      .limit(20);

    if (error) throw error;

    let delivered = 0;
    let failed = 0;

    for (const event of events ?? []) {
      try {
        await supabase
          .from('webhook_events')
          .update({ status: 'processing', attempts: (event.attempts ?? 0) + 1 })
          .eq('id', event.id);

        const response = await fetch(event.destination_url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(event.payload),
        });

        if (!response.ok) {
          throw new Error(`Webhook failed with status ${response.status}`);
        }

        await supabase
          .from('webhook_events')
          .update({ status: 'delivered', delivered_at: new Date().toISOString(), last_error: null })
          .eq('id', event.id);

        delivered += 1;
      } catch (err) {
        const attempts = (event.attempts ?? 0) + 1;
        const retryMinutes = Math.min(60, Math.pow(2, Math.min(6, attempts)));
        const nextRetryAt = new Date(Date.now() + retryMinutes * 60_000).toISOString();

        await supabase
          .from('webhook_events')
          .update({
            status: attempts >= 10 ? 'failed' : 'pending',
            last_error: err instanceof Error ? err.message : 'Unknown dispatch error',
            next_retry_at: nextRetryAt,
          })
          .eq('id', event.id);

        failed += 1;
      }
    }

    return new Response(
      JSON.stringify({ success: true, processed: (events ?? []).length, delivered, failed }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
