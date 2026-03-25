// Phase 2: Marketplace types for geospatial search and availability

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

export interface SearchResponse {
  success: boolean;
  total: number;
  results: (ListingGeospatial & { distance_km: number })[];
  pagination: {
    limit: number;
    offset: number;
    hasNextPage: boolean;
  };
}

export interface AvailabilityCheckResponse {
  is_available: boolean;
  total_slots: number | null;
  booked_slots: number;
  available_slots: number;
  price_override: number | null;
}

export interface SearchListingsParams {
  latitude: number;
  longitude: number;
  radiusKm?: number;
  listingType?: 'stay' | 'vehicle' | 'event' | 'property';
  limit?: number;
  offset?: number;
}

export interface SetAvailabilityParams {
  listingId: string;
  startDate: string;
  endDate: string;
  isAvailable: boolean;
  totalSlots?: number;
}

export interface BookmarkListingParams {
  listing_id: string;
  user_id: string;
}

export interface RealtimeBooking {
  id: string;
  listing_id: string;
  user_id: string;
  provider_id: string;
  status: 'pending_payment' | 'paid' | 'confirmed' | 'cancelled' | 'completed';
  check_in_date: string | null;
  check_out_date: string | null;
  total_amount: number;
  created_at: string;
}
