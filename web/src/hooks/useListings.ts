/**
 * Pearl Hub — React Query hooks for fetching listings from Supabase.
 *
 * Strategy: Supabase is the source of truth for all listing data.
 * The Zustand store is used only for UI state (favorites, compare, toasts).
 *
 * Usage:
 *   const { data: stays, isLoading } = useStays({ location: "Colombo" });
 *   const { data: vehicles }         = useVehicles();
 *   const { data: events }           = useEvents();
 *   const { data: properties }       = useProperties();
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

// ── Query key factory ─────────────────────────────────────
export const listingKeys = {
  all:        ["listings"]                       as const,
  stays:      (f?: StayFilters)  => ["stays",  f] as const,
  vehicles:   (f?: VehicleFilters) => ["vehicles", f] as const,
  events:     (f?: EventFilters) => ["events", f]  as const,
  properties: (f?: PropertyFilters) => ["properties", f] as const,
  providerStays:     (uid: string) => ["provider-stays",     uid] as const,
  providerVehicles:  (uid: string) => ["provider-vehicles",  uid] as const,
  providerEvents:    (uid: string) => ["provider-events",    uid] as const,
  providerProperties:(uid: string) => ["provider-properties", uid] as const,
  bookings:   (uid: string) => ["bookings", uid] as const,
};

// ── Filter types ──────────────────────────────────────────
export interface StayFilters {
  location?: string;
  stay_type?: string;
  maxPrice?: number;
  minRating?: number;
  amenity?: string;
}

export interface VehicleFilters {
  location?: string;
  vehicle_type?: string;
  maxPrice?: number;
  with_driver?: boolean;
}

export interface EventFilters {
  location?: string;
  category?: string;
}

export interface PropertyFilters {
  location?: string;
  type?: string;
  subtype?: string;
  maxPrice?: number;
}

// ── Stays ─────────────────────────────────────────────────
export function useStays(filters?: StayFilters) {
  return useQuery({
    queryKey: listingKeys.stays(filters),
    queryFn: async () => {
      let query = (supabase as any)
        .from("stays_listings")
        .select("*")
        .eq("moderation_status", "approved")
        .eq("active", true)
        .order("created_at", { ascending: false });

      if (filters?.location) query = query.ilike("location", `%${filters.location}%`);
      if (filters?.stay_type && filters.stay_type !== "all") query = query.eq("stay_type", filters.stay_type);
      if (filters?.maxPrice) query = query.lte("price_per_night", filters.maxPrice);

      const { data, error } = await query;
      if (error) throw error;
      return data ?? [];
    },
    staleTime: 3 * 60 * 1000, // 3 minutes
  });
}

// ── Vehicles ──────────────────────────────────────────────
export function useVehicles(filters?: VehicleFilters) {
  return useQuery({
    queryKey: listingKeys.vehicles(filters),
    queryFn: async () => {
      let query = (supabase as any)
        .from("vehicles_listings")
        .select("*")
        .eq("moderation_status", "approved")
        .eq("active", true)
        .order("created_at", { ascending: false });

      if (filters?.location)     query = query.ilike("location", `%${filters.location}%`);
      if (filters?.vehicle_type && filters.vehicle_type !== "all") query = query.eq("vehicle_type", filters.vehicle_type);
      if (filters?.maxPrice)     query = query.lte("price_per_day", filters.maxPrice);
      if (filters?.with_driver !== undefined) query = query.eq("with_driver", filters.with_driver);

      const { data, error } = await query;
      if (error) throw error;
      return data ?? [];
    },
    staleTime: 3 * 60 * 1000,
  });
}

// ── Events ────────────────────────────────────────────────
export function useEvents(filters?: EventFilters) {
  return useQuery({
    queryKey: listingKeys.events(filters),
    queryFn: async () => {
      let query = (supabase as any)
        .from("events_listings")
        .select("*")
        .eq("moderation_status", "approved")
        .eq("active", true)
        .gte("event_date", new Date().toISOString().split("T")[0]) // Future events only
        .order("event_date", { ascending: true });

      if (filters?.location) query = query.ilike("location", `%${filters.location}%`);
      if (filters?.category && filters.category !== "all") query = query.eq("category", filters.category);

      const { data, error } = await query;
      if (error) throw error;
      return data ?? [];
    },
    staleTime: 3 * 60 * 1000,
  });
}

// ── Properties ────────────────────────────────────────────
export function useProperties(filters?: PropertyFilters) {
  return useQuery({
    queryKey: listingKeys.properties(filters),
    queryFn: async () => {
      let query = (supabase as any)
        .from("properties_listings")
        .select("*")
        .eq("moderation_status", "approved")
        .eq("active", true)
        .order("created_at", { ascending: false });

      if (filters?.location) query = query.ilike("location", `%${filters.location}%`);
      if (filters?.type && filters.type !== "all") query = query.eq("type", filters.type);
      if (filters?.subtype) query = query.eq("subtype", filters.subtype);
      if (filters?.maxPrice) query = query.lte("price", filters.maxPrice);

      const { data, error } = await query;
      if (error) throw error;
      return data ?? [];
    },
    staleTime: 3 * 60 * 1000,
  });
}

// ── Provider: own listings ────────────────────────────────
export function useProviderStays(userId: string | undefined) {
  return useQuery({
    queryKey: listingKeys.providerStays(userId ?? ""),
    queryFn: async () => {
      if (!userId) return [];
      const { data, error } = await (supabase as any)
        .from("stays_listings")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!userId,
  });
}

export function useProviderVehicles(userId: string | undefined) {
  return useQuery({
    queryKey: listingKeys.providerVehicles(userId ?? ""),
    queryFn: async () => {
      if (!userId) return [];
      const { data, error } = await (supabase as any)
        .from("vehicles_listings")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!userId,
  });
}

export function useProviderEvents(userId: string | undefined) {
  return useQuery({
    queryKey: listingKeys.providerEvents(userId ?? ""),
    queryFn: async () => {
      if (!userId) return [];
      const { data, error } = await (supabase as any)
        .from("events_listings")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!userId,
  });
}

export function useProviderProperties(userId: string | undefined) {
  return useQuery({
    queryKey: listingKeys.providerProperties(userId ?? ""),
    queryFn: async () => {
      if (!userId) return [];
      const { data, error } = await (supabase as any)
        .from("properties_listings")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!userId,
  });
}

// ── User bookings ─────────────────────────────────────────
export function useUserBookings(userId: string | undefined) {
  return useQuery({
    queryKey: listingKeys.bookings(userId ?? ""),
    queryFn: async () => {
      if (!userId) return [];
      const { data, error } = await (supabase as any)
        .from("bookings")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!userId,
  });
}

// ── Mutation: invalidate provider listings after create/update/delete ─────
export function useInvalidateListings() {
  const qc = useQueryClient();
  return () => {
    qc.invalidateQueries({ queryKey: ["stays"] });
    qc.invalidateQueries({ queryKey: ["vehicles"] });
    qc.invalidateQueries({ queryKey: ["events"] });
    qc.invalidateQueries({ queryKey: ["properties"] });
    qc.invalidateQueries({ queryKey: ["provider-stays"] });
    qc.invalidateQueries({ queryKey: ["provider-vehicles"] });
    qc.invalidateQueries({ queryKey: ["provider-events"] });
    qc.invalidateQueries({ queryKey: ["provider-properties"] });
    qc.invalidateQueries({ queryKey: ["taxi-rides"] });
    qc.invalidateQueries({ queryKey: ["taxi-categories"] });
  };
}

// ── Taxi: Vehicle Categories ──────────────────────────────────
export function useTaxiCategories() {
  return useQuery({
    queryKey: ["taxi-categories"],
    queryFn: async () => {
      const { data, error } = await (supabase as any)
        .from("taxi_vehicle_categories")
        .select("*")
        .eq("is_active", true)
        .order("base_fare", { ascending: true });
      if (error) throw error;
      return data ?? [];
    },
    staleTime: 5 * 60 * 1000,
  });
}

// ── Taxi: Customer Rides ──────────────────────────────────────
export function useTaxiRides(userId: string | undefined) {
  return useQuery({
    queryKey: ["taxi-rides", userId],
    queryFn: async () => {
      if (!userId) return [];
      const { data, error } = await (supabase as any)
        .from("taxi_rides")
        .select("*")
        .eq("customer_id", userId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!userId,
  });
}

// ── Taxi: Provider Active Rides ───────────────────────────────
export function useTaxiProviderRides(providerId: string | undefined) {
  return useQuery({
    queryKey: ["taxi-provider-rides", providerId],
    queryFn: async () => {
      if (!providerId) return [];
      const { data, error } = await (supabase as any)
        .from("taxi_rides")
        .select("*")
        .eq("provider_id", providerId)
        .order("created_at", { ascending: false })
        .limit(20);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!providerId,
  });
}

// ── Taxi: Validate Promo Code ─────────────────────────────────
export async function validateTaxiPromo(code: string) {
  const { data, error } = await (supabase as any)
    .from("taxi_promo_codes")
    .select("*")
    .eq("code", code.trim().toUpperCase())
    .eq("is_active", true)
    .single();

  if (error || !data) return { valid: false, error: "Invalid promo code" };
  if (data.uses_count >= data.max_uses) return { valid: false, error: "Promo exhausted" };
  if (data.valid_until && new Date(data.valid_until) < new Date()) return { valid: false, error: "Promo expired" };
  return { valid: true, discount_type: data.discount_type, discount_amount: data.discount_amount, id: data.id };
}

// ── Taxi: Admin Stats ─────────────────────────────────────────
export function useTaxiAdminStats() {
  return useQuery({
    queryKey: ["taxi-admin-stats"],
    queryFn: async () => {
      const [ridesRes, driversRes, kycRes] = await Promise.all([
        (supabase as any).from("taxi_rides").select("fare, status", { count: "exact" }),
        (supabase as any).from("taxi_provider_locations").select("*", { count: "exact" }).eq("is_online", true),
        (supabase as any).from("taxi_kyc_documents").select("*", { count: "exact" }).eq("verification_status", "pending"),
      ]);
      const completed = ridesRes.data?.filter((r: any) => r.status === "completed") || [];
      const revenue = completed.reduce((sum: number, r: any) => sum + (r.fare || 0), 0);
      return {
        revenue, rides: completed.length,
        driversOnline: driversRes.count || 0,
        pendingKyc: kycRes.count || 0,
        totalRides: ridesRes.count || 0,
      };
    },
    staleTime: 30 * 1000,
  });
}

