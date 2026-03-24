import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface NotificationPayload {
  userId: string;
  type: 'booking_confirmed' | 'booking_cancelled' | 'booking_pending' | 'payment_received' | 'review_posted';
  title: string;
  body: string;
  data?: Record<string, string>;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const payload: NotificationPayload = await req.json();
    const { userId, type, title, body, data } = payload;

    if (!userId || !type || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'userId, type, title, and body are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Persist notification to DB
    const { error: dbError } = await supabase.from('notifications').insert({
      user_id: userId,
      type,
      title,
      body,
      data: data ?? {},
      is_read: false,
    });
    if (dbError) throw dbError;

    // Retrieve FCM token for user
    const { data: tokenRow } = await supabase
      .from('push_tokens')
      .select('token')
      .eq('user_id', userId)
      .single();

    if (tokenRow?.token) {
      const fcmKey = Deno.env.get('FCM_SERVER_KEY');
      if (fcmKey) {
        await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            Authorization: `key=${fcmKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            to: tokenRow.token,
            notification: { title, body },
            data: { type, ...(data ?? {}) },
          }),
        });
      }
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
