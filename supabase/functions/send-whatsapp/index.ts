import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

// Message payload types
interface TextPayload {
  type: "text";
  to: string;          // phone number with country code, e.g. "94771234567"
  message: string;
}

interface TemplatePayload {
  type: "template";
  to: string;
  templateName: string;
  language?: string;
  components?: unknown[];
}

interface OTPPayload {
  type: "otp";
  to: string;
  code: string;
  templateName?: string;
  language?: string;
}

type MessagePayload = TextPayload | TemplatePayload | OTPPayload;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Validate caller is authenticated
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // Verify the JWT belongs to a valid user
  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  // Parse request body
  let payload: MessagePayload;
  try {
    payload = await req.json() as MessagePayload;
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const waApiToken = Deno.env.get("WA_API_TOKEN");
  if (!waApiToken) {
    return jsonResponse({ error: "WhatsApp API not configured" }, 503);
  }

  const WA_API_BASE = "https://wa-api.me/api";

  let waRequest: Record<string, unknown>;
  let endpoint: string;

  if (payload.type === "otp") {
    endpoint = `${WA_API_BASE}/wa-accounts/messages/send-otp`;
    waRequest = {
      number: payload.to,
      code: payload.code,
      templateName: payload.templateName ?? "auth_otp",
      language: payload.language ?? "en",
    };
  } else if (payload.type === "template") {
    endpoint = `${WA_API_BASE}/wa-accounts/messages`;
    waRequest = {
      participants: [{ number: payload.to }],
      messageType: "template",
      template: {
        name: payload.templateName,
        language: { code: payload.language ?? "en" },
        components: payload.components ?? [],
      },
    };
  } else {
    // text
    endpoint = `${WA_API_BASE}/wa-accounts/messages`;
    waRequest = {
      participants: [{ number: payload.to }],
      messageType: "text",
      message: payload.message,
    };
  }

  try {
    const waResponse = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${waApiToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(waRequest),
    });

    const waData = await waResponse.json();

    if (!waResponse.ok) {
      console.error("wa-api.me error:", waData);
      return jsonResponse({ error: "WhatsApp delivery failed", detail: waData }, 502);
    }

    return jsonResponse({ success: true, result: waData });
  } catch (err) {
    console.error("send-whatsapp fetch error:", err);
    return jsonResponse({ error: "Network error reaching WhatsApp API" }, 502);
  }
});
