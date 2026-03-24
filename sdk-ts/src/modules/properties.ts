import { SupabaseClient } from '@supabase/supabase-js';
import { Property, PropertyFilters } from '../types/index.js';

export class PropertiesModule {
  constructor(private readonly supabase: SupabaseClient) {}

  async list(filters: PropertyFilters = {}): Promise<Property[]> {
    const { page = 1, pageSize = 20, location, listingType, minPrice, maxPrice } = filters;
    const from = (page - 1) * pageSize;
    let query = this.supabase
      .from('properties')
      .select('*')
      .eq('status', 'active')
      .range(from, from + pageSize - 1);

    if (location) query = query.ilike('location', `%${location}%`);
    if (listingType) query = query.eq('listing_type', listingType);
    if (minPrice !== undefined) query = query.gte('price', minPrice);
    if (maxPrice !== undefined) query = query.lte('price', maxPrice);

    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as Property[];
  }

  async get(id: string): Promise<Property> {
    const { data, error } = await this.supabase
      .from('properties')
      .select('*')
      .eq('id', id)
      .single();
    if (error) throw error;
    return data as Property;
  }
}
