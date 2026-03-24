// supabase/functions/ai-concierge/index.ts
// This fixes the critical security issue in the web app —
// ANTHROPIC_API_KEY is stored as a Supabase secret, never in client code.
//
// Deploy with:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy ai-concierge

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";

const SYSTEM_PROMPT = `You are Pearl, an expert AI travel concierge for Sri Lanka.
You help users discover and book:
- Stays: hotels, villas, guesthouses, boutique properties
- Vehicles: cars, vans, tuk-tuks, buses with or without drivers
- Events: cultural shows, music festivals, sports events, religious festivals
- Properties: real estate for sale or rent
- Taxi: ride-hailing across Sri Lanka
- SME businesses: local shops, restaurants, services

You have deep knowledge of Sri Lanka's regions:
- Western Province: Colombo, Negombo, Kalutara
- Central Province: Kandy, Nuwara Eliya, Ella
- Southern Province: Galle, Mirissa, Tangalle, Unawatuna  
- Northern Province: Jaffna, Trincomalee
- Eastern Province: Arugam Bay, Batticaloa

Always:
- Recommend specific PearlHub listings when relevant
- Mention prices in LKR (Sri Lankan Rupees)
- Be enthusiastic about Sri Lankan culture, food, and experiences
- Provide practical travel tips
- Be concise — responses under 250 words unless the user asks for detail

Current date context: respond as if it is 2026.`;

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    // Verify JWT — ensures only authenticated PearlHub users can call this
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { message, history = [] } = await req.json();

    if (!message || typeof message !== "string" || message.length > 2000) {
      return new Response(JSON.stringify({ error: "Invalid message" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Build messages array from history + new message
    const messages = [
      ...history.slice(-10).map((h: { role: string; content: string }) => ({
        role: h.role === "user" ? "user" : "assistant",
        content: String(h.content).slice(0, 1000),
      })),
      { role: "user", content: message },
    ];

    // Call Anthropic API — key never leaves the server
    const response = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": Deno.env.get("ANTHROPIC_API_KEY") ?? "",
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error("Anthropic error:", err);
      return new Response(JSON.stringify({ error: "AI service unavailable" }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    const data = await response.json();
    const reply = data.content?.[0]?.text ?? "I could not process that request.";

    return new Response(JSON.stringify({ response: reply }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    console.error("Concierge error:", error);
    return new Response(JSON.stringify({ error: "Internal error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
