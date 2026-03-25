import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildPayHereSignature, formatPayHereAmount, getPayHereCheckoutUrl } from "../_shared/payhere.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type SessionRequest = {
  listingId: string;
  title: string;
  amount: number;
  currency?: string;
  type: "stay" | "vehicle" | "event" | "property";
  checkIn?: string;
  checkOut?: string;
  idempotencyKey?: string;
};

function badRequest(message: string, status = 400) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return badRequest("Method not allowed", 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return badRequest("Unauthorized", 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const merchantId = Deno.env.get("PAYHERE_MERCHANT_ID") ?? "";
    const merchantSecret = Deno.env.get("PAYHERE_MERCHANT_SECRET") ?? "";
    const isSandbox = (Deno.env.get("PAYHERE_SANDBOX") ?? "true") === "true";
    const publicSiteUrl = Deno.env.get("PUBLIC_SITE_URL") ?? "http://localhost:5173";
    const commissionPercent = Number(Deno.env.get("PLATFORM_COMMISSION_PERCENT") ?? "10");

    if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey || !merchantId || !merchantSecret) {
      return badRequest("Server payment secrets are not configured", 500);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const serviceClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) {
      return badRequest("Unauthorized", 401);
    }

    const payload = (await req.json()) as SessionRequest;
    if (!payload.listingId || !payload.title || !payload.type) {
      return badRequest("Missing listing details");
    }

    if (!Number.isFinite(payload.amount) || payload.amount <= 0) {
      return badRequest("Amount must be greater than zero");
    }

    const currency = payload.currency || "LKR";
    const amount = formatPayHereAmount(payload.amount);
    const idempotencyKey = payload.idempotencyKey || `${authData.user.id}:${payload.listingId}:${payload.type}`;

    const { data: existingTransaction } = await serviceClient
      .from("payment_transactions")
      .select("payment_ref, raw_response, status")
      .eq("idempotency_key", idempotencyKey)
      .eq("user_id", authData.user.id)
      .maybeSingle();

    if (existingTransaction?.raw_response) {
      return new Response(existingTransaction.raw_response, {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const totalAmount = Number(amount);
    const commissionAmount = Number((totalAmount * (commissionPercent / 100)).toFixed(2));
    const escrowAmount = Number((totalAmount - commissionAmount).toFixed(2));

    const { data: booking, error: bookingError } = await serviceClient
      .from("bookings")
      .insert({
        user_id: authData.user.id,
        listing_id: payload.listingId,
        listing_type: payload.type,
        booking_date: new Date().toISOString().slice(0, 10),
        check_in_date: payload.checkIn || null,
        check_out_date: payload.checkOut || null,
        total_amount: totalAmount,
        currency,
        status: "pending_payment",
        gateway: "payhere",
        escrow_amount: escrowAmount,
        platform_commission_amount: commissionAmount,
        escrow_released: false,
      })
      .select("id")
      .single();

    if (bookingError || !booking) {
      console.error("create-payhere-session booking insert failed", bookingError);
      return badRequest("Could not create booking", 500);
    }

    const paymentRef = booking.id;
    const signature = buildPayHereSignature({
      merchantId,
      orderId: paymentRef,
      amount,
      currency,
      merchantSecret,
    });

    const sessionResponse = {
      checkoutUrl: getPayHereCheckoutUrl(isSandbox),
      bookingId: booking.id,
      paymentRef,
      gateway: "payhere",
      payload: {
        merchant_id: merchantId,
        return_url: `${publicSiteUrl}/dashboard?payment=success&booking=${booking.id}`,
        cancel_url: `${publicSiteUrl}/dashboard?payment=cancelled&booking=${booking.id}`,
        notify_url: `${supabaseUrl}/functions/v1/payment-webhook`,
        order_id: paymentRef,
        items: payload.title,
        currency,
        amount,
        first_name: String(authData.user.user_metadata?.full_name || "PearlHub"),
        last_name: String(authData.user.user_metadata?.last_name || "Customer"),
        email: String(authData.user.email || "customer@pearlhub.lk"),
        phone: String(authData.user.user_metadata?.phone || "0770000000"),
        address: String(authData.user.user_metadata?.address || "Sri Lanka"),
        city: String(authData.user.user_metadata?.city || "Colombo"),
        country: "Sri Lanka",
        custom_1: authData.user.id,
        custom_2: booking.id,
        hash: signature,
      },
    };

    const { error: transactionError } = await serviceClient
      .from("payment_transactions")
      .insert({
        payment_ref: paymentRef,
        payhere_order_id: paymentRef,  // Store PayHere order ID for webhook verification
        idempotency_key: idempotencyKey,
        gateway: "payhere",
        amount: totalAmount,
        currency,
        status: "initiated",
        user_id: authData.user.id,
        booking_id: booking.id,
        raw_response: JSON.stringify(sessionResponse),
      });

    if (transactionError) {
      console.error("create-payhere-session transaction insert failed", transactionError);
      return badRequest("Could not create payment transaction", 500);
    }

    return new Response(JSON.stringify(sessionResponse), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("create-payhere-session error", error);
    return badRequest("Internal error", 500);
  }
});
