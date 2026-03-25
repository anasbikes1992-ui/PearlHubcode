// SearchListingsMap.tsx - Leaflet map with listings and search functionality
import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { useListingsInfinite } from '@/hooks/useListingsInfinite';
import type { SearchListingsParams } from '@/types/marketplace';

interface SearchListingsMapProps {
  latitude: number;
  longitude: number;
  radiusKm?: number;
  listingType?: string;
  onListingSelect?: (listing: any) => void;
}

// Custom marker icon
const createMarkerIcon = (type: string) => {
  return L.icon({
    iconUrl: `https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-${
      type === 'stay' ? 'blue' :
      type === 'vehicle' ? 'green' :
      type === 'event' ? 'orange' : 'red'
    }.png`,
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
    shadowSize: [41, 41],
  });
};

export const SearchListingsMap: React.FC<SearchListingsMapProps> = ({
  latitude,
  longitude,
  radiusKm = 5,
  listingType,
  onListingSelect,
}) => {
  const [center, setCenter] = useState<[number, number]>([latitude, longitude]);
  const [zoom, setZoom] = useState(13);

  const searchParams: SearchListingsParams = {
    latitude,
    longitude,
    radiusKm,
    listingType,
    limit: 50, // Show up to 50 listings on map
  };

  const { data } = useListingsInfinite(searchParams);
  const listings = data?.pages.flatMap((page) => page.results) || [];

  // Update center when coordinates change
  useEffect(() => {
    setCenter([latitude, longitude]);
  }, [latitude, longitude]);

  return (
    <div className="relative w-full h-96 rounded-lg overflow-hidden shadow-lg">
      <MapContainer
        center={center}
        zoom={zoom}
        style={{ height: '100%', width: '100%' }}
        onzoomend={(e) => setZoom(e.target.getZoom())}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {/* User location marker */}
        <Marker
          position={center}
          icon={L.icon({
            iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-gold.png',
            shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
            iconSize: [25, 41],
            iconAnchor: [12, 41],
            popupAnchor: [1, -34],
            shadowSize: [41, 41],
          })}
        >
          <Popup>Your location</Popup>
        </Marker>

        {/* Listing markers */}
        {listings.map((listing) => (
          <Marker
            key={listing.id}
            position={[listing.latitude as number, listing.longitude as number]}
            icon={createMarkerIcon(listing.listing_type)}
            eventHandlers={{
              click: () => onListingSelect?.(listing),
            }}
          >
            <Popup maxWidth={250}>
              <div
                className="cursor-pointer"
                onClick={() => onListingSelect?.(listing)}
              >
                <h3 className="font-semibold text-sm line-clamp-2">
                  {listing.title}
                </h3>
                <p className="text-xs text-gray-600">{listing.location_name}</p>
                <p className="text-sm font-bold">
                  {listing.price_per_unit} {listing.currency}
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  📍 {listing.distance_km?.toFixed(1)} km away
                </p>
                {listing.rating > 0 && (
                  <p className="text-xs mt-1">
                    ⭐ {listing.rating.toFixed(1)} ({listing.review_count} reviews)
                  </p>
                )}
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>

      {/* Info overlay */}
      <div className="absolute top-3 left-3 bg-white px-3 py-2 rounded-lg shadow-md text-sm">
        <p className="font-semibold">{listings.length} listings</p>
        <p className="text-gray-600 text-xs">within {radiusKm} km</p>
      </div>
    </div>
  );
};
