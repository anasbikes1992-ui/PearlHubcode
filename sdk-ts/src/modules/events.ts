import { SupabaseClient } from '@supabase/supabase-js';
import { PearlEvent, EventFilters } from '../types/index.js';

export class EventsModule {
  constructor(private readonly supabase: SupabaseClient) {}

  async list(filters: EventFilters = {}): Promise<PearlEvent[]> {
    const { page = 1, pageSize = 20, location, category, fromDate } = filters;
    const from = (page - 1) * pageSize;
    let query = this.supabase
      .from('events')
      .select('*')
      .eq('status', 'active')
      .range(from, from + pageSize - 1);

    if (location) query = query.ilike('location', `%${location}%`);
    if (category) query = query.eq('category', category);
    if (fromDate) query = query.gte('start_date', fromDate);

    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as PearlEvent[];
  }

  async get(id: string): Promise<PearlEvent> {
    const { data, error } = await this.supabase
      .from('events')
      .select('*')
      .eq('id', id)
      .single();
    if (error) throw error;
    return data as PearlEvent;
  }
}
