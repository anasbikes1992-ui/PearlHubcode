import { SupabaseClient } from '@supabase/supabase-js';
import { Vehicle, VehicleFilters } from '../types/index.js';

export class VehiclesModule {
  constructor(private readonly supabase: SupabaseClient) {}

  async list(filters: VehicleFilters = {}): Promise<Vehicle[]> {
    const { page = 1, pageSize = 20, location, vehicleType, withDriver, maxPricePerDay } = filters;
    const from = (page - 1) * pageSize;
    let query = this.supabase
      .from('vehicles')
      .select('*')
      .eq('status', 'active')
      .range(from, from + pageSize - 1);

    if (location) query = query.ilike('location', `%${location}%`);
    if (vehicleType) query = query.eq('vehicle_type', vehicleType);
    if (withDriver !== undefined) query = query.eq('with_driver', withDriver);
    if (maxPricePerDay !== undefined) query = query.lte('price_per_day', maxPricePerDay);

    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as Vehicle[];
  }

  async get(id: string): Promise<Vehicle> {
    const { data, error } = await this.supabase
      .from('vehicles')
      .select('*')
      .eq('id', id)
      .single();
    if (error) throw error;
    return data as Vehicle;
  }
}
