// useAvailability.ts - Check and manage listing availability
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase, db } from '@/integrations/supabase/client';
import type { AvailabilityCheckResponse, SetAvailabilityParams } from '@/types/marketplace';

export const useAvailability = (listingId: string, slotDate: string) => {
  return useQuery({
    queryKey: ['availability', listingId, slotDate],
    queryFn: async () => {
      const { data, error } = await db.rpc('check_availability', {
        p_listing_id: listingId,
        p_slot_date: slotDate,
      }) as { data: AvailabilityCheckResponse[] | null; error: any };

      if (error) throw error;
      return data?.[0];
    },
    enabled: !!listingId && !!slotDate,
  });
};

export const useSetAvailability = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: SetAvailabilityParams) => {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData?.session?.access_token;

      if (!token) {
        throw new Error('Not authenticated');
      }

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/set-availability`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            listingId: params.listingId,
            startDate: params.startDate,
            endDate: params.endDate,
            isAvailable: params.isAvailable,
            totalSlots: params.totalSlots,
          }),
        }
      );

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to set availability');
      }

      return await response.json();
    },
    onSuccess: (data, variables) => {
      // Invalidate availability queries for this listing
      queryClient.invalidateQueries({
        queryKey: ['availability', variables.listingId],
      });
      // Invalidate listings query
      queryClient.invalidateQueries({
        queryKey: ['listings'],
      });
    },
  });
};

// Hook to check availability for multiple dates
export const useAvailabilityRange = (listingId: string, startDate: string, endDate: string) => {
  const dates = [];
  const current = new Date(startDate);
  const end = new Date(endDate);
  
  while (current <= end) {
    dates.push(current.toISOString().split('T')[0]);
    current.setDate(current.getDate() + 1);
  }

  return useQuery({
    queryKey: ['availabilityRange', listingId, startDate, endDate],
    queryFn: async () => {
      const { data, error } = await db
        .from('availability_slots')
        .select('*')
        .eq('listing_id', listingId)
        .gte('slot_date', startDate)
        .lte('slot_date', endDate);

      if (error) throw error;
      return data;
    },
    enabled: !!listingId && !!startDate && !!endDate,
  });
};
