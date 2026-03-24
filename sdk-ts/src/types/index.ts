export type ListingStatus = 'active' | 'inactive' | 'pending' | 'rejected';
export type BookingStatus = 'pending' | 'confirmed' | 'completed' | 'cancelled' | 'refunded';
export type VehicleType = 'car' | 'van' | 'bus' | 'tuk_tuk' | 'motorbike';
export type PropertyListingType = 'sale' | 'rent' | 'lease';
export type UserRole = 'customer' | 'provider' | 'admin';

// ---------- Core models ----------

export interface Profile {
  id: string;
  full_name: string | null;
  avatar_url: string | null;
  phone: string | null;
  role: UserRole;
  pearl_points: number;
  wallet_balance: number;
  is_verified: boolean;
  is_suspended: boolean;
  created_at: string;
}

export interface Stay {
  id: string;
  title: string;
  description: string | null;
  location: string;
  price_per_night: number;
  stay_type: string;
  amenities: string[];
  images: string[];
  max_guests: number;
  bedrooms: number | null;
  bathrooms: number | null;
  status: ListingStatus;
  provider_id: string;
  created_at: string;
}

export interface Vehicle {
  id: string;
  title: string;
  description: string | null;
  location: string | null;
  price_per_day: number;
  vehicle_type: VehicleType;
  with_driver: boolean;
  images: string[];
  make: string | null;
  model: string | null;
  year: number | null;
  seats: number | null;
  status: ListingStatus;
  provider_id: string;
  created_at: string;
}

export interface PearlEvent {
  id: string;
  title: string;
  description: string | null;
  location: string;
  start_date: string;
  end_date: string | null;
  ticket_price: number;
  capacity: number | null;
  category: string | null;
  images: string[];
  status: ListingStatus;
  provider_id: string;
  created_at: string;
}

export interface Property {
  id: string;
  title: string;
  description: string | null;
  location: string;
  price: number;
  listing_type: PropertyListingType;
  bedrooms: number | null;
  bathrooms: number | null;
  area_sqft: number | null;
  images: string[];
  status: ListingStatus;
  provider_id: string;
  created_at: string;
}

export interface SMEBusiness {
  id: string;
  business_name: string;
  description: string | null;
  category: string | null;
  location: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  website_url: string | null;
  images: string[];
  is_verified: boolean;
  owner_id: string;
  created_at: string;
}

export interface Booking {
  id: string;
  listing_type: 'stay' | 'vehicle' | 'event' | 'property';
  listing_id: string;
  customer_id: string;
  provider_id: string;
  start_date: string;
  end_date: string | null;
  guests: number | null;
  total_amount: number;
  status: BookingStatus;
  notes: string | null;
  created_at: string;
}

export interface Transaction {
  id: string;
  user_id: string;
  type: 'credit' | 'debit';
  amount: number;
  description: string | null;
  reference_id: string | null;
  created_at: string;
}

// ---------- Filter / pagination helpers ----------

export interface PaginationOptions {
  page?: number;
  pageSize?: number;
}

export interface StayFilters extends PaginationOptions {
  location?: string;
  stayType?: string;
  minPrice?: number;
  maxPrice?: number;
  guests?: number;
}

export interface VehicleFilters extends PaginationOptions {
  location?: string;
  vehicleType?: VehicleType;
  withDriver?: boolean;
  maxPricePerDay?: number;
}

export interface EventFilters extends PaginationOptions {
  location?: string;
  category?: string;
  fromDate?: string;
}

export interface PropertyFilters extends PaginationOptions {
  location?: string;
  listingType?: PropertyListingType;
  minPrice?: number;
  maxPrice?: number;
}
