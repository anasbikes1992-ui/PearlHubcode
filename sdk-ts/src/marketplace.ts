// src/marketplace.ts - Phase 2 Marketplace API
import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface ListingGeospatial {
  id: string;
  listing_id: string;
  listing_type: 'stay' | 'vehicle' | 'event' | 'property';
  provider_id: string;
  title: string;
  description: string | null;
  location_name: string | null;
  latitude: number;
  longitude: number;
  price_per_unit: number;
  currency: string;
  available_from: string | null;
  available_until: string | null;
  tags: string[];
  amenities: string[];
  rating: number;
  review_count: number;
  is_active: boolean;
  is_featured: boolean;
  created_at: string;
  updated_at: string;
}

export interface AvailabilitySlot {
  id: string;
  listing_id: string;
  provider_id: string;
  slot_date: string;
  is_available: boolean;
  time_start: string | null;
  time_end: string | null;
  total_slots: number | null;
  booked_slots: number;
  price_override: number | null;
  created_at: string;
  updated_at: string;
}

export interface SearchListingsParams {
  latitude: number;
  longitude: number;
  radiusKm?: number;
  listingType?: string;
  limit?: number;
  offset?: number;
}

export interface SearchResponse<T> {
  success: boolean;
  total: number;
  results: T[];
  pagination: {
    limit: number;
    offset: number;
    hasNextPage: boolean;
  };
}

export class MarketplaceClient {
  private supabase: SupabaseClient;

  constructor(supabaseClient: SupabaseClient) {
    this.supabase = supabaseClient;
  }

  /**
   * Search listings by geographic radius (PostGIS)
   * @param params Search parameters with location and radius
   * @returns List of listings within the specified radius
   */
  async searchListingsByRadius(
    params: SearchListingsParams
  ): Promise<SearchResponse<ListingGeospatial & { distance_km: number }>> {
    const {
      latitude,
      longitude,
      radiusKm = 5,
      listingType,
      limit = 20,
      offset = 0,
    } = params;

    try {
      const { data, error } = await this.supabase.functions.invoke(
        'search-listings-by-radius',
        {
          body: {
            latitude,
            longitude,
            radiusKm,
            listingType,
            limit,
            offset,
          },
        }
      );

      if (error) throw error;

      return data;
    } catch (error) {
      console.error('Error searching listings:', error);
      throw error;
    }
  }

  /**
   * Get availability for a specific date range
   * @param listingId UUID of the listing
   * @param startDate Start date (ISO format)
   * @param endDate End date (ISO format)
   * @returns Availability slots for the date range
   */
  async getAvailability(
    listingId: string,
    startDate: string,
    endDate: string
  ): Promise<AvailabilitySlot[]> {
    const { data, error } = await this.supabase
      .from('availability_slots')
      .select('*')
      .eq('listing_id', listingId)
      .gte('slot_date', startDate)
      .lte('slot_date', endDate);

    if (error) throw error;
    return data || [];
  }

  /**
   * Check if a date is available for a listing
   * @param listingId UUID of the listing
   * @param slotDate Date to check (ISO format)
   * @returns Availability information for the date
   */
  async checkAvailability(
    listingId: string,
    slotDate: string
  ): Promise<Array<{
    is_available: boolean;
    total_slots: number | null;
    booked_slots: number;
    available_slots: number;
    price_override: number | null;
  }>> {
    const { data, error } = await this.supabase.rpc('check_availability', {
      p_listing_id: listingId,
      p_slot_date: slotDate,
    });

    if (error) throw error;
    return data || [];
  }

  /**
   * Set availability for a date range (provider only)
   * @param listingId UUID of the listing
   * @param startDate Start date (ISO format)
   * @param endDate End date (ISO format)
   * @param isAvailable Whether dates are available
   * @param totalSlots Optional total slots for each date
   * @returns Result of the operation
   */
  async setAvailability(
    listingId: string,
    startDate: string,
    endDate: string,
    isAvailable: boolean,
    totalSlots?: number
  ): Promise<{ slots_created: number; slots_modified: number }> {
    try {
      const { data, error } = await this.supabase.functions.invoke(
        'set-availability',
        {
          body: {
            listingId,
            startDate,
            endDate,
            isAvailable,
            totalSlots,
          },
        }
      );

      if (error) throw error;

      return data?.data || { slots_created: 0, slots_modified: 0 };
    } catch (error) {
      console.error('Error setting availability:', error);
      throw error;
    }
  }

  /**
   * Subscribe to real-time listing updates
   * @param callback Function called when listings change
   */
  subscribeToListingUpdates(
    callback: (payload: { eventType: string; new?: ListingGeospatial; old?: ListingGeospatial }) => void
  ) {
    return this.supabase
      .channel('listings_changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'listings_geospatial' },
        (payload) => callback(payload)
      )
      .subscribe();
  }

  /**
   * Subscribe to availability changes for a listing
   * @param listingId UUID of the listing
   * @param callback Function called when availability changes
   */
  subscribeToAvailabilityUpdates(
    listingId: string,
    callback: (payload: { eventType: string; new?: AvailabilitySlot; old?: AvailabilitySlot }) => void
  ) {
    return this.supabase
      .channel(`availability_${listingId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'availability_slots',
          filter: `listing_id=eq.${listingId}`,
        },
        (payload) => callback(payload)
      )
      .subscribe();
  }

  /**
   * Search with infinite pagination utility
   * @param params Initial search parameters
   * @returns Object with search and loadMore functions
   */
  infiniteSearch(params: SearchListingsParams) {
    const pages: Array<SearchResponse<ListingGeospatial & { distance_km: number }>> = [];
    let currentOffset = 0;
    let hasMore = true;

    return {
      async search() {
        const result = await this.searchListingsByRadius({
          ...params,
          offset: 0,
          limit: params.limit || 20,
        });
        pages[0] = result;
        currentOffset = (params.limit || 20);
        hasMore = result.pagination.hasNextPage;
        return result.results;
      },

      async loadMore() {
        if (!hasMore) return [];

        const result = await this.searchListingsByRadius({
          ...params,
          offset: currentOffset,
          limit: params.limit || 20,
        });

        pages.push(result);
        currentOffset += (params.limit || 20);
        hasMore = result.pagination.hasNextPage;
        return result.results;
      },

      getAllResults() {
        return pages.flatMap((page) => page.results);
      },

      hasMoreResults() {
        return hasMore;
      },
    };
  }
}

export function createMarketplaceClient(supabaseClient: SupabaseClient) {
  return new MarketplaceClient(supabaseClient);
}
