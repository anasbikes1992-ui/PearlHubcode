# 🎯 Phase 2: Complete Marketplace Flows - FULL IMPLEMENTATION

**Duration**: 5-7 days  
**Priority**: HIGH  
**Dependency**: ✅ Phase 1 (Database & Payment functions)  
**Target**: Full marketplace with geosearch, pagination, availability, Flutter SDK, realtime  

---

## 🎯 Phase 2 Executive Summary

Transform PearlHub from a payment platform into a complete marketplace with:
- **Geospatial Search**: Find listings within X kilometers using PostGIS
- **Infinite Pagination**: TanStack Query infinite scroll (20 items/page)
- **Availability Management**: Provider calendars with block/unblock interface
- **Flutter Mobile SDK**: Publish to pub.dev with full marketplace access
- **Realtime Subscriptions**: Live booking/availability updates
- **Performance**: Sub-500ms search queries, 60 FPS scroll

---

## 📊 Phase 2 Components

### 1. Geospatial Search (PostGIS)

**Migration**: `0003_geospatial_listings.sql`

```sql
-- Add location columns to listings table
ALTER TABLE public.listings
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8),
ADD COLUMN IF NOT EXISTS location GEOMETRY(Point, 4326) GENERATED ALWAYS AS (
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
) STORED;

-- Create GiST index for fast spatial queries
CREATE INDEX IF NOT EXISTS idx_listings_location_gist
ON public.listings USING GIST(location);

-- Create function for radius search
CREATE OR REPLACE FUNCTION public.search_listings_by_radius(
  p_latitude DECIMAL,
  p_longitude DECIMAL,
  p_radius_km DECIMAL DEFAULT 50
)
RETURNS TABLE(
  id UUID,
  title TEXT,
  description TEXT,
  price NUMERIC,
  rating DECIMAL,
  review_count INT,
  image_url TEXT,
  listing_type TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  distance_km DECIMAL,
  provider_id UUID,
  provider_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.id,
    l.title,
    l.description,
    l.price,
    l.rating,
    l.review_count,
    l.image_url,
    l.listing_type,
    l.latitude,
    l.longitude,
    ROUND((ST_Distance(
      l.location,
      ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)
    ) / 1000)::NUMERIC, 2) as distance_km,
    l.provider_id,
    p.full_name
  FROM public.listings l
  JOIN public.profiles p ON l.provider_id = p.id
  WHERE ST_DWithin(
    l.location,
    ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326),
    p_radius_km * 1000
  )
  AND l.status = 'active'
  ORDER BY
    ST_Distance(l.location, ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)),
    l.rating DESC,
    l.review_count DESC
  LIMIT 100;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.search_listings_by_radius(DECIMAL, DECIMAL, DECIMAL) TO anon, authenticated;
```

### 2. Availability Slots Management

**Migration Addition**: Update `0003_geospatial_listings.sql` to include:

```sql
-- Create availability_slots table
CREATE TABLE IF NOT EXISTS public.availability_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id UUID NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  
  slot_date DATE NOT NULL,
  start_time TIME NOT NULL DEFAULT '00:00:00',
  end_time TIME NOT NULL DEFAULT '23:59:59',
  
  is_available BOOLEAN NOT NULL DEFAULT true,
  booked BOOLEAN NOT NULL DEFAULT false,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_availability_slots_provider_date
  ON public.availability_slots(provider_id, slot_date);

CREATE INDEX IF NOT EXISTS idx_availability_slots_listing_date
  ON public.availability_slots(listing_id, slot_date);

CREATE INDEX IF NOT EXISTS idx_availability_slots_available
  ON public.availability_slots(slot_date) WHERE is_available = true;

-- RLS Policies
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Providers can manage own slots" ON public.availability_slots;
CREATE POLICY "Providers can manage own slots"
  ON public.availability_slots
  FOR ALL
  TO authenticated
  USING (auth.uid() = provider_id)
  WITH CHECK (auth.uid() = provider_id);

DROP POLICY IF EXISTS "Users can read available slots" ON public.availability_slots;
CREATE POLICY "Users can read available slots"
  ON public.availability_slots FOR SELECT
  TO authenticated
  USING (is_available = true OR auth.uid() = provider_id);

-- Function to bulk create/update availability
CREATE OR REPLACE FUNCTION public.set_provider_availability(
  p_provider_id UUID,
  p_listing_id UUID,
  p_from_date DATE,
  p_to_date DATE,
  p_start_time TIME DEFAULT '00:00:00',
  p_end_time TIME DEFAULT '23:59:59',
  p_available BOOLEAN DEFAULT true
)
RETURNS INT AS $$
DECLARE
  v_current_date DATE;
  v_count INT := 0;
BEGIN
  -- Delete existing slots in date range
  DELETE FROM public.availability_slots
  WHERE provider_id = p_provider_id
    AND listing_id = p_listing_id
    AND slot_date >= p_from_date
    AND slot_date <= p_to_date;

  -- Insert new slots for each day in range
  v_current_date := p_from_date;
  WHILE v_current_date <= p_to_date LOOP
    INSERT INTO public.availability_slots (
      provider_id, listing_id, slot_date, start_time, end_time, is_available
    ) VALUES (
      p_provider_id, p_listing_id, v_current_date, p_start_time, p_end_time, p_available
    );
    v_count := v_count + 1;
    v_current_date := v_current_date + INTERVAL '1 day';
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.set_provider_availability(UUID, UUID, DATE, DATE, TIME, TIME, BOOLEAN)
  TO authenticated;
```

---

## 🚀 Phase 2 Edge Functions

### Function 1: Search Listings by Radius

**File**: `supabase/functions/search-listings-by-radius/index.ts`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type SearchRequest = {
  latitude: number;
  longitude: number;
  radius_km?: number;
  listing_type?: string;
  price_min?: number;
  price_max?: number;
  min_rating?: number;
  limit?: number;
  offset?: number;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const client = createClient(supabaseUrl, supabaseAnonKey);

    const payload = (await req.json()) as SearchRequest;
    const { latitude, longitude, radius_km = 50, price_min, price_max, min_rating = 0, limit = 20, offset = 0 } =
      payload;

    if (!latitude || !longitude) {
      return jsonResponse({ error: "Latitude and longitude required" }, 400);
    }

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return jsonResponse({ error: "Invalid coordinates" }, 400);
    }

    // Call PostGIS search function
    let query = client.rpc("search_listings_by_radius", {
      p_latitude: latitude,
      p_longitude: longitude,
      p_radius_km: radius_km,
    });

    // Apply additional filters
    if (price_min !== undefined) {
      query = query.gte("price", price_min);
    }
    if (price_max !== undefined) {
      query = query.lte("price", price_max);
    }
    if (min_rating > 0) {
      query = query.gte("rating", min_rating);
    }
    if (payload.listing_type) {
      query = query.eq("listing_type", payload.listing_type);
    }

    const { data, error } = await query.range(offset, offset + limit - 1);

    if (error) {
      console.error("search-listings-by-radius error:", error);
      return jsonResponse({ error: "Search failed" }, 500);
    }

    return jsonResponse({
      listings: data || [],
      count: data?.length || 0,
      offset,
      limit,
    });
  } catch (error) {
    console.error("search-listings-by-radius exception:", error);
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
```

### Function 2: Set Availability

**File**: `supabase/functions/set-availability/index.ts`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type AvailabilityRequest = {
  listing_id: string;
  from_date: string; // YYYY-MM-DD
  to_date: string; // YYYY-MM-DD
  start_time?: string; // HH:MM:SS
  end_time?: string; // HH:MM:SS
  available: boolean;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: user, error: userError } = await userClient.auth.getUser();
    if (userError || !user?.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const payload = (await req.json()) as AvailabilityRequest;
    const { listing_id, from_date, to_date, start_time = "00:00:00", end_time = "23:59:59", available } = payload;

    if (!listing_id || !from_date || !to_date) {
      return jsonResponse({ error: "Missing required fields" }, 400);
    }

    // Verify user owns the listing
    const { data: listing, error: listingError } = await userClient
      .from("listings")
      .select("id, provider_id")
      .eq("id", listing_id)
      .single();

    if (listingError || !listing) {
      return jsonResponse({ error: "Listing not found" }, 404);
    }

    if (listing.provider_id !== user.user.id) {
      return jsonResponse({ error: "Unauthorized" }, 403);
    }

    // Call set_provider_availability function
    const { data: result, error: updateError } = await userClient.rpc("set_provider_availability", {
      p_provider_id: user.user.id,
      p_listing_id: listing_id,
      p_from_date: from_date,
      p_to_date: to_date,
      p_start_time: start_time,
      p_end_time: end_time,
      p_available: available,
    });

    if (updateError) {
      console.error("set-availability error:", updateError);
      return jsonResponse({ error: "Failed to update availability" }, 500);
    }

    return jsonResponse({
      success: true,
      slots_created: result,
      message: `Availability updated for ${result} day(s)`,
    });
  } catch (error) {
    console.error("set-availability exception:", error);
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
```

---

## 🎣 Frontend: Hooks & Components

### Hook 1: useListings - Infinite Pagination

**File**: `web/src/hooks/useListings.ts` (UPDATED)

```typescript
import { useInfiniteQuery, useQuery } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";

export interface Listing {
  id: string;
  title: string;
  description: string;
  price: number;
  rating: number;
  review_count: number;
  image_url: string;
  listing_type: string;
  latitude: number;
  longitude: number;
  distance_km?: number;
  provider_id: string;
  provider_name: string;
}

export interface SearchParams {
  latitude?: number;
  longitude?: number;
  radius_km?: number;
  listing_type?: string;
  price_min?: number;
  price_max?: number;
  min_rating?: number;
}

const LISTINGS_PER_PAGE = 20;

export function useListingsInfinite(searchParams?: SearchParams) {
  return useInfiniteQuery({
    queryKey: ["listings-infinite", searchParams],
    queryFn: async ({ pageParam = 0 }) => {
      const offset = pageParam * LISTINGS_PER_PAGE;

      if (searchParams?.latitude && searchParams?.longitude) {
        // Geosearch
        const response = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/search-listings-by-radius`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              ...searchParams,
              limit: LISTINGS_PER_PAGE,
              offset,
            }),
          }
        );

        if (!response.ok) throw new Error("Search failed");
        return await response.json();
      } else {
        // Regular pagination
        let query = supabase.from("listings").select("*").order("created_at", { ascending: false });

        if (searchParams?.listing_type) {
          query = query.eq("listing_type", searchParams.listing_type);
        }
        if (searchParams?.price_min) {
          query = query.gte("price", searchParams.price_min);
        }
        if (searchParams?.price_max) {
          query = query.lte("price", searchParams.price_max);
        }

        const { data, error, count } = await query.range(offset, offset + LISTINGS_PER_PAGE - 1);

        if (error) throw error;
        return { listings: data || [], count: count || 0 };
      }
    },
    getNextPageParam: (lastPage, allPages) => {
      const totalFetched = allPages.length * LISTINGS_PER_PAGE;
      return lastPage.listings.length === LISTINGS_PER_PAGE ? allPages.length : undefined;
    },
    initialPageParam: 0,
  });
}

export function useListingDetail(listingId: string) {
  return useQuery({
    queryKey: ["listing", listingId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("listings")
        .select(
          `
          *,
          provider:profiles(id, full_name, avatar_url, rating),
          reviews(rating, comment, created_at)
        `
        )
        .eq("id", listingId)
        .single();

      if (error) throw error;
      return data;
    },
    enabled: !!listingId,
  });
}

export function useAvailability(listingId: string, fromDate: Date, toDate: Date) {
  return useQuery({
    queryKey: ["availability", listingId, fromDate, toDate],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("availability_slots")
        .select("*")
        .eq("listing_id", listingId)
        .gte("slot_date", fromDate.toISOString().split("T")[0])
        .lte("slot_date", toDate.toISOString().split("T")[0])
        .order("slot_date", { ascending: true });

      if (error) throw error;
      return data;
    },
    enabled: !!listingId,
  });
}
```

### Component 1: ListingGrid with Infinite Scroll

**File**: `web/src/components/ListingGrid.tsx` (NEW)

```typescript
import { useEffect, useRef, useCallback } from "react";
import { useListingsInfinite, Listing } from "@/hooks/useListings";
import { Skeleton } from "@/components/ui/skeleton";
import ListingCard from "./ListingCard";

interface ListingGridProps {
  latitude?: number;
  longitude?: number;
  radius_km?: number;
  listing_type?: string;
}

export default function ListingGrid(props: ListingGridProps) {
  const { data, fetchNextPage, hasNextPage, isLoading, isError } = useListingsInfinite(props);

  const observerTarget = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasNextPage) {
          fetchNextPage();
        }
      },
      { threshold: 0.1 }
    );

    if (observerTarget.current) {
      observer.observe(observerTarget.current);
    }

    return () => observer.disconnect();
  }, [hasNextPage, fetchNextPage]);

  if (isError) {
    return <div className="text-center py-12 text-red-600">Error loading listings</div>;
  }

  const allListings: Listing[] = data?.pages.flatMap((page) => page.listings) || [];

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {allListings.map((listing) => (
          <ListingCard key={listing.id} listing={listing} />
        ))}
      </div>

      {/* Loading skeleton for next batch */}
      {isLoading && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {[...Array(6)].map((_, i) => (
            <Skeleton key={i} className="h-64 rounded-lg" />
          ))}
        </div>
      )}

      {/* Intersection observer target */}
      <div ref={observerTarget} className="h-10" />

      {!hasNextPage && allListings.length > 0 && (
        <div className="text-center py-8 text-gray-500">No more listings</div>
      )}
    </div>
  );
}
```

### Component 2: AvailabilityCalendar with Block/Unblock

**File**: `web/src/components/AvailabilityCalendarProvider.tsx` (NEW)

```typescript
import { useState, useCallback } from "react";
import { Calendar } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAvailability } from "@/hooks/useListings";
import { supabase } from "@/lib/supabase";
import BigCalendar from "react-big-calendar";
import "react-big-calendar/lib/css/react-big-calendar.css";

interface AvailabilityCalendarProps {
  listingId: string;
}

export default function AvailabilityCalendar({ listingId }: AvailabilityCalendarProps) {
  const [startDate, setStartDate] = useState(new Date());
  const [endDate, setEndDate] = useState(new Date(startDate.getTime() + 90 * 24 * 60 * 60 * 1000));
  const [isBlocking, setIsBlocking] = useState(false);

  const { data: slots, refetch } = useAvailability(listingId, startDate, endDate);

  const handleBlockDates = useCallback(async () => {
    if (!startDate || !endDate) return;

    setIsBlocking(true);
    try {
      const { data: session } = await supabase.auth.getSession();
      if (!session?.session) {
        alert("Please sign in to manage availability");
        return;
      }

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/set-availability`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session.session.access_token}`,
        },
        body: JSON.stringify({
          listing_id: listingId,
          from_date: startDate.toISOString().split("T")[0],
          to_date: endDate.toISOString().split("T")[0],
          available: false, // Block these dates
        }),
      });

      if (!response.ok) throw new Error("Failed to block dates");

      const result = await response.json();
      alert(`Blocked ${result.slots_created} days`);
      refetch();
    } catch (error) {
      console.error("Block dates error:", error);
      alert("Failed to block dates");
    } finally {
      setIsBlocking(false);
    }
  }, [listingId, startDate, endDate, refetch]);

  const handleUnblockDates = useCallback(async () => {
    if (!startDate || !endDate) return;

    setIsBlocking(true);
    try {
      const { data: session } = await supabase.auth.getSession();
      if (!session?.session) {
        alert("Please sign in to manage availability");
        return;
      }

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/set-availability`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session.session.access_token}`,
        },
        body: JSON.stringify({
          listing_id: listingId,
          from_date: startDate.toISOString().split("T")[0],
          to_date: endDate.toISOString().split("T")[0],
          available: true, // Unblock these dates
        }),
      });

      if (!response.ok) throw new Error("Failed to unblock dates");

      const result = await response.json();
      alert(`Unblocked ${result.slots_created} days`);
      refetch();
    } catch (error) {
      console.error("Unblock dates error:", error);
      alert("Failed to unblock dates");
    } finally {
      setIsBlocking(false);
    }
  }, [listingId, startDate, endDate, refetch]);

  const events = (slots || []).map((slot) => ({
    id: slot.id,
    title: slot.is_available ? "Available" : "Blocked",
    start: new Date(slot.slot_date),
    end: new Date(slot.slot_date),
    resource: slot,
  }));

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Calendar className="w-5 h-5" />
        <h3 className="font-semibold">Manage Availability</h3>
      </div>

      <BigCalendar events={events} defaultView="month" style={{ height: 500 }} />

      <div className="flex gap-2">
        <Button onClick={handleBlockDates} disabled={isBlocking} variant="destructive">
          Block Selected Dates
        </Button>
        <Button onClick={handleUnblockDates} disabled={isBlocking} variant="outline">
          Unblock Selected Dates
        </Button>
      </div>
    </div>
  );
}
```

---

## 📱 Phase 2: Flutter SDK Setup

**File**: `flutter_sdk/pubspec.yaml`

```yaml
name: pearlhub_sdk
description: PearlHub Marketplace SDK for Flutter applications
version: 1.0.0
homepage: https://github.com/anasbikes1992-ui/PearlHubcode

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  http: ^1.1.0
  uuid: ^4.0.0
  intl: ^0.19.0
  geolocator: ^10.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

**File**: `flutter_sdk/lib/pearlhub_sdk.dart`

```dart
export 'src/pearlhub_client.dart';
export 'src/services/listings_service.dart';
export 'src/services/bookings_service.dart';
export 'src/services/payments_service.dart';
export 'src/models/listing.dart';
export 'src/models/booking.dart';
export 'src/models/payment.dart';
```

**File**: `flutter_sdk/lib/src/pearlhub_client.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/listings_service.dart';
import 'services/bookings_service.dart';
import 'services/payments_service.dart';

class PearlHubClient {
  late final SupabaseClient _supabase;
  late final ListingsService listings;
  late final BookingsService bookings;
  late final PaymentsService payments;

  /// Initialize PearlHub SDK
  static Future<PearlHubClient> initialize({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );

    return PearlHubClient._(Supabase.instance.client);
  }

  PearlHubClient._(SupabaseClient supabase)
    : _supabase = supabase,
      listings = ListingsService(supabase),
      bookings = BookingsService(supabase),
      payments = PaymentsService(supabase);

  SupabaseClient get client => _supabase;

  /// Sign up with email
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'https://yourdomain.com/auth/callback',
      data: {'full_name': fullName},
    );
  }

  /// Sign in with email
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }
}
```

---

## 🔄 Realtime Subscriptions

**File**: `web/src/hooks/useRealtimeBookings.ts`

```typescript
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { RealtimeChannel } from "@supabase/supabase-js";

export interface BookingUpdate {
  id: string;
  status: string;
  updated_at: string;
}

export function useRealtimeBookings(userId: string) {
  const [isConnected, setIsConnected] = useState(false);
  const [channel, setChannel] = useState<RealtimeChannel | null>(null);

  useEffect(() => {
    if (!userId) return;

    const bookingsChannel = supabase
      .channel(`bookings:${userId}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "bookings",
          filter: `user_id=eq.${userId}`,
        },
        (payload) => {
          console.log("Booking update:", payload);
        }
      )
      .subscribe((status) => {
        setIsConnected(status === "SUBSCRIBED");
      });

    setChannel(bookingsChannel);

    return () => {
      supabase.removeChannel(bookingsChannel);
    };
  }, [userId]);

  const unsubscribe = () => {
    if (channel) {
      supabase.removeChannel(channel);
      setIsConnected(false);
    }
  };

  return { isConnected, unsubscribe };
}
```

---

## ✅ Phase 2 Completion Checklist

Before Phase 3:

- [ ] **Database**
  - [ ] 0003_geospatial_listings.sql deployed
  - [ ] PostGIS search function working
  - [ ] Availability slots table created
  - [ ] RLS policies on availability_slots

- [ ] **Edge Functions**
  - [ ] search-listings-by-radius deployed
  - [ ] set-availability deployed
  - [ ] Both functions authenticated + tested

- [ ] **Frontend**
  - [ ] useListingsInfinite hook working
  - [ ] ListingGrid component with infinite scroll
  - [ ] AvailabilityCalendar component
  - [ ] Realtime bookings subscription

- [ ] **Flutter SDK**
  - [ ] Scaffolded with basic services
  - [ ] Published to pub.dev
  - [ ] Example app included

- [ ] **Testing**
  - [ ] Geosearch: returns correct distance calculations
  - [ ] Pagination: loads 20 items per page, hasNextPage correct
  - [ ] Availability: block/unblock works, calendar updates
  - [ ] Realtime: live booking updates received

- [ ] **Documentation**
  - [ ] PHASE_2_MARKETPLACE.md complete
  - [ ] Code examples for all features
  - [ ] SDK documentation

- [ ] **Git**
  - [ ] All changes committed to production-hardening
  - [ ] Committed to GitHub

---

