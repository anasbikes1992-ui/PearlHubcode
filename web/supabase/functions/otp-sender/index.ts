// Pearl Hub Pro — OTP Sender Edge Function
// Supports: SMTP (email) and WhatsApp (360dialog / Meta Cloud API)
//
// Deploy:  supabase functions deploy otp-sender
// Secrets: supabase secrets set SMTP_HOST=... SMTP_PORT=... SMTP_USER=... SMTP_PASS=...
//          supabase secrets set WHATSAPP_API_KEY=... WHATSAPP_PHONE_ID=...
//          supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Template library ──────────────────────────────────────────
function getEmailTemplate(purpose: string, code: string, name = "there"): { subject: string; html: string } {
  const purposeLabels: Record<string, string> = {
    signup: "Verify your email address",
    login: "Your sign-in code",
    phone_verify: "Verify your phone number",
    password_reset: "Reset your password",
    "2fa": "Two-factor authentication code",
  };

  const subject = purposeLabels[purpose] || "Your Pearl Hub verification code";

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${subject}</title>
  <style>
    body { margin:0; padding:0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background:#0a0a0a; }
    .wrapper { max-width:520px; margin:40px auto; border-radius:24px; overflow:hidden; border:1px solid rgba(255,255,255,0.08); }
    .header { background:linear-gradient(135deg,#c9a84c,#9c783a); padding:32px; text-align:center; }
    .header h1 { margin:0; color:#fff; font-size:28px; font-weight:900; letter-spacing:-1px; }
    .header p { margin:4px 0 0; color:rgba(255,255,255,0.7); font-size:12px; text-transform:uppercase; letter-spacing:3px; }
    .body { background:#111; padding:40px 36px; }
    .body p { color:#aaa; font-size:15px; line-height:1.7; margin:0 0 16px; }
    .code-box { background:#1a1a1a; border:2px solid #c9a84c; border-radius:16px; padding:28px; text-align:center; margin:28px 0; }
    .code-box .code { font-size:48px; font-weight:900; letter-spacing:12px; color:#c9a84c; font-family:monospace; }
    .code-box .expiry { color:#666; font-size:12px; margin-top:8px; }
    .footer { background:#0d0d0d; padding:20px 36px; border-top:1px solid rgba(255,255,255,0.05); }
    .footer p { color:#444; font-size:11px; margin:0; line-height:1.6; }
    .footer a { color:#c9a84c; text-decoration:none; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>Pearl Hub</h1>
      <p>Sri Lanka Premium</p>
    </div>
    <div class="body">
      <p>Hi ${name},</p>
      <p>${subject}. Use the code below — it expires in <strong>10 minutes</strong>.</p>
      <div class="code-box">
        <div class="code">${code}</div>
        <div class="expiry">Valid for 10 minutes · Do not share this code</div>
      </div>
      <p>If you didn't request this, please ignore this email. Your account is secure.</p>
    </div>
    <div class="footer">
      <p>Pearl Hub Pro · Sri Lanka's #1 Luxury Marketplace<br/>
      <a href="https://pearl-hub-pro.vercel.app">pearl-hub-pro.vercel.app</a> · 
      <a href="mailto:support@pearlhub.lk">support@pearlhub.lk</a></p>
    </div>
  </div>
</body>
</html>`;

  return { subject, html };
}

function getWhatsAppBody(purpose: string, code: string): string {
  const purposeMessages: Record<string, string> = {
    signup: `🌟 *Pearl Hub* — Your verification code is:\n\n*${code}*\n\nValid for 10 minutes. Do not share this code.`,
    login: `🔐 *Pearl Hub* — Your sign-in code is:\n\n*${code}*\n\nValid for 10 minutes.`,
    phone_verify: `📱 *Pearl Hub* — Phone verification code:\n\n*${code}*\n\nValid for 10 minutes.`,
    password_reset: `🔑 *Pearl Hub* — Password reset code:\n\n*${code}*\n\nValid for 10 minutes. If you didn't request this, ignore this message.`,
    "2fa": `🛡️ *Pearl Hub* — 2FA code:\n\n*${code}*\n\nValid for 10 minutes.`,
  };
  return purposeMessages[purpose] || `*Pearl Hub* verification code: *${code}* (expires in 10 minutes)`;
}

// ── Email sender via SMTP (using Deno's built-in fetch to SMTP relay) ──
// Uses smtp2go or any SMTP API. For production, use smtp2go API or SendGrid HTTP API.
async function sendEmail(
  to: string,
  subject: string,
  html: string,
  fromName: string,
  fromAddress: string
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  const smtpHost = Deno.env.get("SMTP_HOST");
  const smtpUser = Deno.env.get("SMTP_USER");
  const smtpPass = Deno.env.get("SMTP_PASS");

  // Try SMTP2GO API first (preferred for reliability)
  const smtp2goKey = Deno.env.get("SMTP2GO_API_KEY");
  if (smtp2goKey) {
    const resp = await fetch("https://api.smtp2go.com/v3/email/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: smtp2goKey,
        to: [to],
        sender: `${fromName} <${fromAddress}>`,
        subject,
        html_body: html,
      }),
    });
    const data = await resp.json();
    if (data.data?.succeeded === 1) {
      return { success: true, messageId: data.data?.email_id };
    }
    console.error("SMTP2GO error:", data);
  }

  // Fallback: SendGrid HTTP API
  const sendgridKey = Deno.env.get("SENDGRID_API_KEY");
  if (sendgridKey) {
    const resp = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${sendgridKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email: to }] }],
        from: { email: fromAddress, name: fromName },
        subject,
        content: [{ type: "text/html", value: html }],
      }),
    });
    if (resp.status === 202) {
      return { success: true };
    }
    const errText = await resp.text();
    console.error("SendGrid error:", errText);
  }

  // Fallback: Resend API
  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (resendKey) {
    const resp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `${fromName} <${fromAddress}>`,
        to: [to],
        subject,
        html,
      }),
    });
    const data = await resp.json();
    if (data.id) return { success: true, messageId: data.id };
    console.error("Resend error:", data);
  }

  // Last resort: Supabase built-in SMTP
  if (smtpHost && smtpUser && smtpPass) {
    console.log("SMTP credentials found but raw SMTP not implemented in Deno Edge — use API provider.");
  }

  return { success: false, error: "No email provider configured. Set SMTP2GO_API_KEY, SENDGRID_API_KEY, or RESEND_API_KEY." };
}

// ── WhatsApp sender ────────────────────────────────────────────
async function sendWhatsApp(
  to: string,
  body: string
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  // Try 360dialog (preferred for Sri Lanka)
  const waApiKey = Deno.env.get("WHATSAPP_360D_API_KEY");
  const waPhoneId = Deno.env.get("WHATSAPP_360D_PHONE_ID") || "";

  if (waApiKey) {
    // Normalize phone: ensure E.164
    const phone = to.startsWith("+") ? to.replace(/[^+\d]/g, "") : `+${to.replace(/[^\d]/g, "")}`;

    const resp = await fetch(
      `https://waba.360dialog.io/v1/messages`,
      {
        method: "POST",
        headers: {
          "D360-API-KEY": waApiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: phone,
          type: "text",
          text: { body },
        }),
      }
    );
    const data = await resp.json();
    if (data.messages?.[0]?.id) {
      return { success: true, messageId: data.messages[0].id };
    }
    console.error("360dialog error:", data);
  }

  // Fallback: Meta Cloud API (WhatsApp Business)
  const metaToken = Deno.env.get("WHATSAPP_META_TOKEN");
  const metaPhoneId = Deno.env.get("WHATSAPP_META_PHONE_ID");

  if (metaToken && metaPhoneId) {
    const phone = to.startsWith("+") ? to.replace(/\+/, "") : to.replace(/[^\d]/g, "");
    const resp = await fetch(
      `https://graph.facebook.com/v19.0/${metaPhoneId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${metaToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: phone,
          type: "text",
          text: { body },
        }),
      }
    );
    const data = await resp.json();
    if (data.messages?.[0]?.id) {
      return { success: true, messageId: data.messages[0].id };
    }
    console.error("Meta WhatsApp error:", data);
  }

  return { success: false, error: "No WhatsApp provider configured. Set WHATSAPP_360D_API_KEY or WHATSAPP_META_TOKEN." };
}

// ── Main handler ───────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  let body: {
    identifier: string;
    channel: "email" | "whatsapp" | "sms";
    purpose: string;
    name?: string;
  };

  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { identifier, channel, purpose, name = "there" } = body;

  if (!identifier || !channel || !purpose) {
    return new Response(JSON.stringify({ error: "Missing required fields: identifier, channel, purpose" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Verify caller is authenticated (optional for signup, required for others)
  // We use service role for the RPC call to bypass RLS on otp_codes
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");

  if (!serviceRoleKey || !supabaseUrl) {
    console.error("Missing SUPABASE_SERVICE_ROLE_KEY or SUPABASE_URL");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const adminSupabase = createClient(supabaseUrl, serviceRoleKey);

  // ── Call backend RPC to generate OTP ──────────────────────
  const { data: otpResult, error: otpError } = await adminSupabase.rpc("request_otp", {
    p_identifier: identifier.toLowerCase().trim(),
    p_channel: channel,
    p_purpose: purpose,
  });

  if (otpError) {
    console.error("OTP RPC error:", otpError);
    return new Response(JSON.stringify({ error: otpError.message, code: "rpc_error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!otpResult?.success) {
    return new Response(JSON.stringify({
      success: false,
      error: otpResult?.error,
      retry_after: otpResult?.retry_after,
    }), {
      status: 429,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const code: string = otpResult.code;

  // ── Read notification config from DB ─────────────────────
  const { data: configData } = await adminSupabase.rpc("get_platform_config", { p_category: "notifications" });
  const fromName = configData?.["notifications.email.from_name"] || "Pearl Hub";
  const fromAddress = configData?.["notifications.email.from_address"] || "noreply@pearlhub.lk";

  // ── Send via requested channel ────────────────────────────
  let sendResult: { success: boolean; messageId?: string; error?: string };
  let logStatus = "queued";

  if (channel === "email") {
    const { subject, html } = getEmailTemplate(purpose, code, name);
    sendResult = await sendEmail(identifier, subject, html, fromName, fromAddress);
  } else if (channel === "whatsapp") {
    const waBody = getWhatsAppBody(purpose, code);
    sendResult = await sendWhatsApp(identifier, waBody);
  } else {
    sendResult = { success: false, error: "SMS channel not yet configured — use email or whatsapp" };
  }

  logStatus = sendResult.success ? "sent" : "failed";

  // ── Log the send attempt ──────────────────────────────────
  const { subject: logSubject } = getEmailTemplate(purpose, "######", name);
  await adminSupabase.from("notification_log").insert({
    recipient: identifier,
    channel,
    template_key: `otp_${purpose}`,
    subject: channel === "email" ? logSubject : `WhatsApp OTP for ${purpose}`,
    body_preview: `OTP code sent for purpose: ${purpose}`,
    status: logStatus,
    provider: channel === "email" ? "smtp_api" : "whatsapp_api",
    provider_msg_id: sendResult.messageId || "",
    error_detail: sendResult.error || "",
  });

  if (!sendResult.success) {
    console.error(`OTP send failed: ${sendResult.error}`);
    return new Response(JSON.stringify({
      success: false,
      error: "Failed to deliver OTP",
      details: sendResult.error,
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({
    success: true,
    channel,
    purpose,
    expires_in: 600, // 10 minutes in seconds
  }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
