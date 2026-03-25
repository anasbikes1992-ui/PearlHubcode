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
    const merchantId = Deno.env.get("PAYHERE_MERCHANT_ID") ?? "";

    if (!supabaseUrl || !serviceRoleKey || !merchantSecret || !merchantId) {
      return jsonResponse({ error: "Server payment secrets are not configured" }, 500);
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey);
    const rawBody = await req.text();
    const formData = new URLSearchParams(rawBody);

    const payloadMerchantId = formData.get("merchant_id") ?? "";
    const orderId = formData.get("order_id") ?? "";
    const amount = formatPayHereAmount(formData.get("payhere_amount") ?? "0");
    const currency = formData.get("payhere_currency") ?? "LKR";
    const statusCode = formData.get("status_code") ?? "";
    const receivedSignature = (formData.get("md5sig") ?? "").toUpperCase();

    if (!payloadMerchantId || !orderId || !statusCode || !receivedSignature) {
      return jsonResponse({ error: "Missing parameters" }, 400);
    }

    // ✅ CORRECTED: Verify merchant ID from env, not payload
    if (payloadMerchantId !== merchantId) {
      console.error("payment-webhook invalid merchant ID", { 
        received: payloadMerchantId, 
        expected: merchantId 
      });
      return jsonResponse({ error: "Invalid merchant" }, 403);
    }

    // ✅ CORRECTED: Build signature with correct MD5 pattern
    // Pattern: merchant_id + order_id + amount + currency + status_code + upper(md5(merchant_secret))
    const expectedSignature = buildPayHereSignature({
      merchantId: payloadMerchantId,
      orderId,
      amount,
      currency,
      merchantSecret,
      statusCode,
    });

    console.log("[WEBHOOK] Signature verification:", {
      orderId,
      received: receivedSignature,
      expected: expectedSignature,
      match: expectedSignature === receivedSignature,
    });

    if (expectedSignature !== receivedSignature) {
      console.error("payment-webhook invalid MD5 signature", { orderId, received: receivedSignature, expected: expectedSignature });
      return jsonResponse({ error: "Invalid signature" }, 401);
    }

    const mappedStatus = mapPayHereStatus(statusCode);

    // ✅ CORRECTED: Use payhere_order_id instead of payment_ref for lookups
    const { data: existingTransaction } = await serviceClient
      .from("payment_transactions")
      .select("id, status, webhook_received")
      .eq("payhere_order_id", orderId)
      .maybeSingle();

    // ✅ CORRECTED: Use idempotency check - webhook_received flag prevents double-processing
    if (existingTransaction?.webhook_received) {
      console.log("[IDEMPOTENT] Webhook already processed for order:", orderId);
      return new Response("OK", { status: 200, headers: corsHeaders });
    }

    // ✅ CORRECTED: Update existing transaction or insert new one
    if (existingTransaction?.id) {
      const { error: updateTransactionError } = await serviceClient
        .from("payment_transactions")
        .update({
          status: mappedStatus,
          webhook_received: true,
          webhook_received_at: new Date().toISOString(),
          webhook_signature_valid: true,
          md5_signature: receivedSignature,
          completed_at: mappedStatus === "success" ? new Date().toISOString() : null,
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
          payhere_order_id: orderId,
          gateway: "payhere",
          amount: Number(amount),
          currency,
          status: mappedStatus,
          user_id: formData.get("custom_1"),
          booking_id: formData.get("custom_2"),
          webhook_received: true,
          webhook_received_at: new Date().toISOString(),
          webhook_signature_valid: true,
          md5_signature: receivedSignature,
          completed_at: mappedStatus === "success" ? new Date().toISOString() : null,
        });

      if (insertTransactionError) {
        console.error("payment-webhook transaction insert failed", insertTransactionError);
        return jsonResponse({ error: "Could not persist transaction" }, 500);
      }
    }

    // ✅ CORRECTED: Update booking status if payment succeeds
    if (mappedStatus === "success") {
      const bookingId = formData.get("custom_2");
      if (bookingId) {
        const { error: bookingError } = await serviceClient
          .from("bookings")
          .update({
            status: "confirmed",
            updated_at: new Date().toISOString(),
          })
          .eq("id", bookingId);

        if (bookingError) {
          console.error("payment-webhook booking update failed", bookingError);
          // Don't fail the response - transaction was recorded
        }

        // Create notification for user
        const bookingUserId = formData.get("custom_1");
        if (bookingUserId) {
          await serviceClient
            .from("notifications")
            .insert({
              user_id: bookingUserId,
              type: "payment_success",
              title: "Payment Confirmed",
              message: "Your payment has been successfully processed",
              related_booking_id: bookingId,
            })
            .then(() => console.log("[NOTIFICATION] Payment success notification created"))
            .catch((err) => console.error("Failed to create notification:", err));
        }
      }
    }

    return new Response("OK", { status: 200, headers: corsHeaders });
  } catch (error) {
    console.error("payment-webhook error", error);
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
