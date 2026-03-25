// InfiniteListingGrid.tsx - Infinite scroll listing grid with skeleton loading
import React, { useCallback } from 'react';
import { useInView } from 'react-intersection-observer';
import { useListingsInfinite } from '@/hooks/useListingsInfinite';
import type { SearchListingsParams } from '@/types/marketplace';

interface InfiniteListingGridProps {
  searchParams: SearchListingsParams;
  renderListing?: (listing: any) => React.ReactNode;
}

export const InfiniteListingGrid: React.FC<InfiniteListingGridProps> = ({
  searchParams,
  renderListing,
}) => {
  const {
    data,
    error,
    fetchNextPage,
    hasNextPage,
    isFetching,
    isLoading,
  } = useListingsInfinite(searchParams);

  const { ref, inView } = useInView();

  // Load more when end of list comes into view
  React.useEffect(() => {
    if (inView && hasNextPage && !isFetching && !isLoading) {
      fetchNextPage();
    }
  }, [inView, hasNextPage, isFetching, isLoading, fetchNextPage]);

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {[...Array(6)].map((_, i) => (
          <div key={i} className="bg-gray-200 rounded-lg h-64 animate-pulse" />
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-red-600">Error loading listings</p>
        <p className="text-gray-600 text-sm">{error instanceof Error && error.message}</p>
      </div>
    );
  }

  const allListings = data?.pages.flatMap((page) => page.results) || [];

  if (allListings.length === 0) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600">No listings found in this area</p>
      </div>
    );
  }

  return (
    <div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {allListings.map((listing) => (
          <div key={listing.id}>
            {renderListing ? (
              renderListing(listing)
            ) : (
              <DefaultListingCard listing={listing} />
            )}
          </div>
        ))}
      </div>

      {/* Load more trigger */}
      {hasNextPage && (
        <div ref={ref} className="py-8 text-center">
          {isFetching && <p className="text-gray-600">Loading more...</p>}
        </div>
      )}

      {!hasNextPage && allListings.length > 0 && (
        <div className="text-center py-8">
          <p className="text-gray-500">No more listings</p>
        </div>
      )}
    </div>
  );
};

// Default card renderer
const DefaultListingCard: React.FC<{ listing: any }> = ({ listing }) => {
  return (
    <div className="bg-white rounded-lg shadow cursor-pointer hover:shadow-lg transition-shadow overflow-hidden h-full">
      <div className="bg-gray-200 h-40 flex items-center justify-center">
        <span className="text-gray-400 text-sm">{listing.listing_type}</span>
      </div>
      <div className="p-4">
        <h3 className="font-semibold text-lg truncate">{listing.title}</h3>
        <p className="text-sm text-gray-600 line-clamp-2">{listing.location_name}</p>
        
        <div className="mt-3 flex justify-between items-center">
          <span className="font-bold text-lg">
            {listing.price_per_unit} {listing.currency}
          </span>
          {listing.rating > 0 && (
            <span className="text-sm bg-yellow-100 px-2 py-1 rounded">
              ⭐ {listing.rating.toFixed(1)} ({listing.review_count})
            </span>
          )}
        </div>

        {listing.distance_km !== undefined && (
          <p className="text-xs text-gray-500 mt-2">
            📍 {listing.distance_km.toFixed(1)} km away
          </p>
        )}

        {listing.tags && listing.tags.length > 0 && (
          <div className="mt-3 flex flex-wrap gap-1">
            {listing.tags.slice(0, 3).map((tag: string, i: number) => (
              <span key={i} className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                {tag}
              </span>
            ))}
            {listing.tags.length > 3 && (
              <span className="text-xs text-gray-500">+{listing.tags.length - 3} more</span>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
