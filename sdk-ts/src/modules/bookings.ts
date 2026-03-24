import { SupabaseClient } from '@supabase/supabase-js';
import { Booking, BookingStatus } from '../types/index.js';

export interface CreateBookingInput {
  listingType: Booking['listing_type'];
  listingId: string;
  providerId: string;
  startDate: string;
  endDate?: string;
  guests?: number;
  totalAmount: number;
  notes?: string;
}

export class BookingsModule {
  constructor(private readonly supabase: SupabaseClient) {}

  async create(input: CreateBookingInput): Promise<Booking> {
    const { data: { user } } = await this.supabase.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    const { data, error } = await this.supabase
      .from('bookings')
      .insert({
        listing_type: input.listingType,
        listing_id: input.listingId,
        provider_id: input.providerId,
        customer_id: user.id,
        start_date: input.startDate,
        end_date: input.endDate ?? null,
        guests: input.guests ?? null,
        total_amount: input.totalAmount,
        notes: input.notes ?? null,
        status: 'pending',
      })
      .select()
      .single();
    if (error) throw error;
    return data as Booking;
  }

  async listMine(status?: BookingStatus): Promise<Booking[]> {
    const { data: { user } } = await this.supabase.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    let query = this.supabase
      .from('bookings')
      .select('*')
      .eq('customer_id', user.id)
      .order('created_at', { ascending: false });

    if (status) query = query.eq('status', status);

    const { data, error } = await query;
    if (error) throw error;
    return (data ?? []) as Booking[];
  }

  async cancel(id: string): Promise<void> {
    const { error } = await this.supabase
      .from('bookings')
      .update({ status: 'cancelled' })
      .eq('id', id);
    if (error) throw error;
  }
}
