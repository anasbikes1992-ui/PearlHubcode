import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";

interface SetAvailabilityRequest {
  listingId: string;
  startDate: string; // ISO date: 2024-03-01
  endDate: string; // ISO date: 2024-03-31
  isAvailable: boolean;
  totalSlots?: number;
}

Deno.serve(async (req: Request) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify authorization header
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    if (!token) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Missing Supabase credentials");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Verify token and get user
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Parse request body
    const body = (await req.json()) as SetAvailabilityRequest;
    
    const {
      listingId,
      startDate,
      endDate,
      isAvailable,
      totalSlots,
    } = body;

    // Validate required fields
    if (!listingId || !startDate || !endDate || isAvailable === undefined) {
      return new Response(
        JSON.stringify({
          error: "listingId, startDate, endDate, and isAvailable are required",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Validate dates
    const start = new Date(startDate);
    const end = new Date(endDate);
    if (start > end) {
      return new Response(
        JSON.stringify({
          error: "startDate must be before or equal to endDate",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Call set availability function
    const { data, error } = await supabase.rpc(
      "set_availability_range",
      {
        p_listing_id: listingId,
        p_start_date: startDate,
        p_end_date: endDate,
        p_is_available: isAvailable,
        p_total_slots: totalSlots,
      }
    ) as { 
      data: Array<{ slots_created: number; slots_modified: number }> | null; 
      error: any 
    };

    if (error) {
      console.error("Set availability error:", error);
      
      if (error.message?.includes("Unauthorized")) {
        return new Response(
          JSON.stringify({ error: "You can only modify your own listings" }),
          {
            status: 403,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      throw error;
    }

    const result = data?.[0] || { slots_created: 0, slots_modified: 0 };

    return new Response(
      JSON.stringify({
        success: true,
        message: `Updated availability: ${result.slots_created} created, ${result.slots_modified} modified`,
        data: result,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      }
    );
  } catch (error) {
    console.error("Error:", error);

    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "Internal server error",
        success: false,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      }
    );
  }
});
