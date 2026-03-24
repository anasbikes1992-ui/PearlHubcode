import { SupabaseClient } from '@supabase/supabase-js';
import {
  Stay,
  StayFilters,
} from '../types/index.js';

export class StaysModule {
  constructor(private readonly supabase: SupabaseClient) {}

  async list(filters: StayFilters = {}): Promise<Stay[]> {
    const { page = 1, pageSize = 20, location, stayType, minPrice, maxPrice, guests } = filters;
    const from = (page - 1) * pageSize;
    let query = this.supabase
      .from('stays')
      .select('*')
      .eq('status', 'active')
      .range(from, from + pageSize - 1);

    if (location) query = query.ilike('location', `%${location}%`);
    if (stayType) query = query.eq('stay_type', stayType);
    if (minPrice !== undefined) query = query.gte('price_per_night', minPrice);
    if (maxPrice !== undefined) query = query.lte('price_per_night', maxPrice);
    if (guests) query = query.gte('max_guests', guests);

    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as Stay[];
  }

  async get(id: string): Promise<Stay> {
    const { data, error } = await this.supabase
      .from('stays')
      .select('*')
      .eq('id', id)
      .single();
    if (error) throw error;
    return data as Stay;
  }
}
