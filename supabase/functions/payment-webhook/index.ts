import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildPayHereSignature, formatPayHereAmount } from "../_shared/payhere.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function mapPayHereStatus(statusCode: string): "success" | "pending" | "failed" | "cancelled" {
  if (statusCode === "2") return "success";
  if (statusCode === "0") return "pending";
  if (statusCode === "-1") return "cancelled";
  return "failed";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const merchantSecret = Deno.env.get("PAYHERE_MERCHANT_SECRET") ?? "";

    if (!supabaseUrl || !serviceRoleKey || !merchantSecret) {
      return jsonResponse({ error: "Server payment secrets are not configured" }, 500);
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey);
    const rawBody = await req.text();
    const formData = new URLSearchParams(rawBody);

    const merchantId = formData.get("merchant_id") ?? "";
    const orderId = formData.get("order_id") ?? "";
    const amount = formatPayHereAmount(formData.get("payhere_amount") ?? "0");
    const currency = formData.get("payhere_currency") ?? "LKR";
    const statusCode = formData.get("status_code") ?? "";
    const receivedSignature = (formData.get("md5sig") ?? "").toUpperCase();

    if (!merchantId || !orderId || !statusCode || !receivedSignature) {
      return jsonResponse({ error: "Missing parameters" }, 400);
    }

    const expectedSignature = buildPayHereSignature({
      merchantId,
      orderId,
      amount,
      currency,
      merchantSecret,
      statusCode,
    });

    if (expectedSignature !== receivedSignature) {
      console.error("payment-webhook invalid MD5 signature", { orderId });
      return jsonResponse({ error: "Invalid signature" }, 401);
    }

    const mappedStatus = mapPayHereStatus(statusCode);

    const { data: existingTransaction } = await serviceClient
      .from("payment_transactions")
      .select("id, status")
      .eq("payment_ref", orderId)
      .maybeSingle();

    if (existingTransaction?.status === "success") {
      return new Response("Already processed", { status: 200, headers: corsHeaders });
    }

    if (existingTransaction?.id) {
      const { error: updateTransactionError } = await serviceClient
        .from("payment_transactions")
        .update({
          status: mappedStatus,
          raw_response: rawBody,
          updated_at: new Date().toISOString(),
        })
        .eq("id", existingTransaction.id);

      if (updateTransactionError) {
        console.error("payment-webhook transaction update failed", updateTransactionError);
        return jsonResponse({ error: "Could not update transaction" }, 500);
      }
    } else {
      const { error: insertTransactionError } = await serviceClient
        .from("payment_transactions")
        .insert({
          payment_ref: orderId,
          gateway: "payhere",
          amount: Number(amount),
          currency,
          status: mappedStatus,
          user_id: formData.get("custom_1"),
          booking_id: formData.get("custom_2") || orderId,
          raw_response: rawBody,
        });

      if (insertTransactionError) {
        console.error("payment-webhook transaction insert failed", insertTransactionError);
        return jsonResponse({ error: "Could not persist transaction" }, 500);
      }
    }

    const bookingPatch = mappedStatus === "success"
      ? {
          status: "paid",
          payment_ref: orderId,
          gateway: "payhere",
          escrow_released: false,
          paid_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }
      : {
          status: mappedStatus === "pending" ? "pending_payment" : "payment_failed",
          payment_ref: orderId,
          gateway: "payhere",
          updated_at: new Date().toISOString(),
        };

    const { error: bookingError } = await serviceClient
      .from("bookings")
      .update(bookingPatch)
      .eq("id", orderId);

    if (bookingError) {
      console.error("payment-webhook booking update failed", bookingError);
      return jsonResponse({ error: "Could not update booking" }, 500);
    }

    return new Response("OK", { status: 200, headers: corsHeaders });
  } catch (error) {
    console.error("payment-webhook error", error);
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
