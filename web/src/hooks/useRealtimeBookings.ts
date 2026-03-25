// useRealtimeBookings.ts - Real-time booking subscriptions
import { useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import type { RealtimeBooking } from '@/types/marketplace';

export const useRealtimeBookings = (providerId: string) => {
  const [bookings, setBookings] = useState<RealtimeBooking[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!providerId) return;

    // Fetch initial bookings
    const fetchInitialBookings = async () => {
      try {
        const { data, error: fetchError } = await supabase
          .from('bookings')
          .select('*')
          .eq('provider_id', providerId)
          .order('created_at', { ascending: false });

        if (fetchError) throw fetchError;
        setBookings((data as RealtimeBooking[]) || []);
      } catch (err) {
        setError(err instanceof Error ? err : new Error('Failed to fetch bookings'));
      } finally {
        setIsLoading(false);
      }
    };

    fetchInitialBookings();

    // Subscribe to real-time updates
    const channel = supabase
      .channel(`bookings:provider_${providerId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'bookings',
          filter: `provider_id=eq.${providerId}`,
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setBookings((prev) => [payload.new as RealtimeBooking, ...prev]);
          } else if (payload.eventType === 'UPDATE') {
            setBookings((prev) =>
              prev.map((booking) =>
                booking.id === payload.new.id
                  ? (payload.new as RealtimeBooking)
                  : booking
              )
            );
          } else if (payload.eventType === 'DELETE') {
            setBookings((prev) => prev.filter((booking) => booking.id !== payload.old.id));
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [providerId]);

  return { bookings, isLoading, error };
};

// Hook to watch a specific booking status
export const useBookingStatus = (bookingId: string) => {
  const [booking, setBooking] = useState<RealtimeBooking | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!bookingId) return;

    const fetchBooking = async () => {
      const { data, error } = await supabase
        .from('bookings')
        .select('*')
        .eq('id', bookingId)
        .single() as { data: RealtimeBooking | null; error: any };

      if (!error) {
        setBooking(data);
      }
      setIsLoading(false);
    };

    fetchBooking();

    // Subscribe to updates for this specific booking
    const channel = supabase
      .channel(`booking:${bookingId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'bookings',
          filter: `id=eq.${bookingId}`,
        },
        (payload) => {
          setBooking(payload.new as RealtimeBooking);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [bookingId]);

  return { booking, isLoading };
};

// Hook to subscribe to bookings by a specific user
export const useUserBookings = (userId: string) => {
  const [bookings, setBookings] = useState<RealtimeBooking[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!userId) return;

    const fetchBookings = async () => {
      const { data, error } = await supabase
        .from('bookings')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false }) as { 
          data: RealtimeBooking[] | null; 
          error: any 
        };

      if (!error) {
        setBookings(data || []);
      }
      setIsLoading(false);
    };

    fetchBookings();

    // Subscribe to real-time updates
    const channel = supabase
      .channel(`user_bookings:${userId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'bookings',
          filter: `user_id=eq.${userId}`,
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setBookings((prev) => [payload.new as RealtimeBooking, ...prev]);
          } else if (payload.eventType === 'UPDATE') {
            setBookings((prev) =>
              prev.map((booking) =>
                booking.id === payload.new.id
                  ? (payload.new as RealtimeBooking)
                  : booking
              )
            );
          } else if (payload.eventType === 'DELETE') {
            setBookings((prev) => prev.filter((booking) => booking.id !== payload.old.id));
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId]);

  return { bookings, isLoading };
};
