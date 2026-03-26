/**
 * useWhatsApp – Client-side hook for wa-api.me WhatsApp integration.
 * All API calls are proxied through the `send-whatsapp` Supabase Edge Function
 * so the WA_API_TOKEN never reaches the browser.
 */
import { supabase } from "@/integrations/supabase/client";

type TextMessage = {
  type: "text";
  to: string;
  message: string;
};

type OTPMessage = {
  type: "otp";
  to: string;
  code: string;
  templateName?: string;
  language?: string;
};

type TemplateMessage = {
  type: "template";
  to: string;
  templateName: string;
  language?: string;
  components?: unknown[];
};

type WAMessage = TextMessage | OTPMessage | TemplateMessage;

async function sendWhatsApp(payload: WAMessage): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.functions.invoke("send-whatsapp", {
    body: payload,
  });

  if (error) {
    console.error("send-whatsapp edge fn error:", error);
    return { success: false, error: error.message };
  }

  return data as { success: boolean; error?: string };
}

/**
 * Send a booking confirmation WhatsApp message to a customer.
 * @param phone  Customer phone with country code (e.g. "94771234567")
 * @param details Booking details to include in the message
 */
export async function sendBookingConfirmation(
  phone: string,
  details: {
    customerName: string;
    listingTitle: string;
    bookingRef: string;
    checkIn?: string;
    checkOut?: string;
    totalAmount: number;
    currency?: string;
  }
): Promise<{ success: boolean; error?: string }> {
  const currency = details.currency ?? "LKR";
  const dateRange = details.checkIn && details.checkOut
    ? `${details.checkIn} → ${details.checkOut}`
    : "";

  const message =
    `🏝️ *Pearl Hub Booking Confirmed!*\n\n` +
    `Hello ${details.customerName},\n\n` +
    `Your booking has been confirmed.\n\n` +
    `📌 *${details.listingTitle}*\n` +
    (dateRange ? `📅 ${dateRange}\n` : "") +
    `💰 Total: ${currency} ${details.totalAmount.toLocaleString()}\n` +
    `🔖 Ref: #${details.bookingRef}\n\n` +
    `Thank you for choosing Pearl Hub! 🇱🇰\n` +
    `Need help? Reply to this message anytime.`;

  return sendWhatsApp({ type: "text", to: phone, message });
}

/**
 * Send an OTP verification code via WhatsApp.
 */
export async function sendWhatsAppOTP(
  phone: string,
  code: string
): Promise<{ success: boolean; error?: string }> {
  return sendWhatsApp({ type: "otp", to: phone, code });
}

/**
 * Notify a provider about a new booking.
 */
export async function notifyProviderNewBooking(
  providerPhone: string,
  details: {
    listingTitle: string;
    customerName: string;
    bookingRef: string;
    checkIn?: string;
    totalAmount: number;
  }
): Promise<{ success: boolean; error?: string }> {
  const message =
    `🔔 *New Booking on Pearl Hub!*\n\n` +
    `You have a new booking for *${details.listingTitle}*.\n\n` +
    `👤 Customer: ${details.customerName}\n` +
    (details.checkIn ? `📅 Check-in: ${details.checkIn}\n` : "") +
    `💰 Amount: LKR ${details.totalAmount.toLocaleString()}\n` +
    `🔖 Ref: #${details.bookingRef}\n\n` +
    `Login to your Pearl Hub dashboard to manage this booking.`;

  return sendWhatsApp({ type: "text", to: providerPhone, message });
}

/**
 * Send a payment receipt via WhatsApp.
 */
export async function sendPaymentReceipt(
  phone: string,
  details: {
    customerName: string;
    amount: number;
    currency: string;
    bookingRef: string;
    gatewayRef: string;
  }
): Promise<{ success: boolean; error?: string }> {
  const message =
    `✅ *Payment Received – Pearl Hub*\n\n` +
    `Hi ${details.customerName},\n\n` +
    `We've received your payment.\n\n` +
    `💳 Amount: ${details.currency} ${details.amount.toLocaleString()}\n` +
    `🔖 Booking: #${details.bookingRef}\n` +
    `🧾 Gateway Ref: ${details.gatewayRef}\n\n` +
    `Your receipt has also been emailed to you.\n` +
    `Questions? Reply to this chat. 🙏`;

  return sendWhatsApp({ type: "text", to: phone, message });
}

export { sendWhatsApp };
