import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Supported currency pairs against LKR
const BASE_CURRENCY = 'LKR';
const TARGET_CURRENCIES = ['USD', 'EUR', 'GBP', 'AUD', 'CAD', 'SGD', 'JPY', 'INR'];

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const apiKey = Deno.env.get('EXCHANGE_RATE_API_KEY');

    let rates: Record<string, number> = {};

    if (apiKey) {
      // Fetch from exchangerate-api.com
      const res = await fetch(
        `https://v6.exchangerate-api.com/v6/${apiKey}/latest/${BASE_CURRENCY}`
      );
      if (res.ok) {
        const json = await res.json();
        for (const currency of TARGET_CURRENCIES) {
          if (json.conversion_rates?.[currency]) {
            rates[currency] = json.conversion_rates[currency];
          }
        }
      }
    } else {
      // Fallback approximate rates (updated infrequently — cron keeps them fresh)
      rates = {
        USD: 0.00309,
        EUR: 0.00285,
        GBP: 0.00243,
        AUD: 0.00476,
        CAD: 0.00420,
        SGD: 0.00416,
        JPY: 0.472,
        INR: 0.258,
      };
    }

    // Upsert into exchange_rates table
    const rows = Object.entries(rates).map(([currency, rate]) => ({
      base: BASE_CURRENCY,
      target: currency,
      rate,
      fetched_at: new Date().toISOString(),
    }));

    const { error } = await supabase
      .from('exchange_rates')
      .upsert(rows, { onConflict: 'base,target' });
    if (error) throw error;

    return new Response(
      JSON.stringify({ success: true, updated: rows.length, rates }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
