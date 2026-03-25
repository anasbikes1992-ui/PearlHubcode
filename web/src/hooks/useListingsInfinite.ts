// useListingsInfinite.ts - Infinite scroll listings with React Query
import { useInfiniteQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import type { SearchListingsParams, SearchResponse } from '@/types/marketplace';

const LISTINGS_PAGE_SIZE = 20;

export const useListingsInfinite = (params: SearchListingsParams) => {
  return useInfiniteQuery({
    queryKey: [
      'listings',
      params.latitude,
      params.longitude,
      params.radiusKm,
      params.listingType,
    ],
    queryFn: async ({ pageParam = 0 }) => {
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/search-listings-by-radius`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${(await supabase.auth.getSession()).data.session?.access_token}`,
          },
          body: JSON.stringify({
            latitude: params.latitude,
            longitude: params.longitude,
            radiusKm: params.radiusKm || 5,
            listingType: params.listingType,
            limit: params.limit || LISTINGS_PAGE_SIZE,
            offset: pageParam,
          }),
        }
      );

      if (!response.ok) {
        throw new Error('Failed to search listings');
      }

      return (await response.json()) as SearchResponse;
    },
    getNextPageParam: (lastPage) => {
      if (!lastPage.pagination.hasNextPage) {
        return undefined;
      }
      return lastPage.pagination.offset + (lastPage.pagination.limit || LISTINGS_PAGE_SIZE);
    },
    initialPageParam: 0,
    enabled: params.latitude !== undefined && params.longitude !== undefined,
  });
};
