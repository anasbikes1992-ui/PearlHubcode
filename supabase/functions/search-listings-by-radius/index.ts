import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { corsHeaders } from "../_shared/cors.ts";

interface SearchRequest {
  latitude: number;
  longitude: number;
  radiusKm?: number;
  listingType?: string;
  limit?: number;
  offset?: number;
}

interface SearchResult {
  id: string;
  listing_id: string;
  listing_type: string;
  provider_id: string;
  title: string;
  description: string;
  location_name: string;
  latitude: number;
  longitude: number;
  distance_km: number;
  price_per_unit: number;
  currency: string;
  rating: number;
  review_count: number;
  is_featured: boolean;
  created_at: string;
  tags: string[];
  amenities: string[];
}

Deno.serve(async (req: Request) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Missing Supabase credentials");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Parse request body
    const body = (await req.json()) as SearchRequest;
    
    const { 
      latitude, 
      longitude, 
      radiusKm = 5, 
      listingType, 
      limit = 20, 
      offset = 0 
    } = body;

    // Validate required fields
    if (latitude === undefined || longitude === undefined) {
      return new Response(
        JSON.stringify({ 
          error: "latitude and longitude are required" 
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Call geospatial search function
    const { data, error } = await supabase.rpc(
      "search_listings_by_radius",
      {
        p_latitude: latitude,
        p_longitude: longitude,
        p_radius_km: radiusKm,
        p_listing_type: listingType,
        p_limit: limit,
        p_offset: offset,
      }
    ) as { data: SearchResult[] | null; error: any };

    if (error) {
      console.error("Search function error:", error);
      throw error;
    }

    // Return results
    return new Response(
      JSON.stringify({
        success: true,
        total: data?.length || 0,
        results: data || [],
        pagination: {
          limit,
          offset,
          hasNextPage: (data?.length || 0) >= limit,
        },
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
