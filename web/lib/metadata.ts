// lib/metadata.ts - Dynamic metadata generation for listings
import { Metadata, ResolvingMetadata } from 'next';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://pearlhub.lk';

export async function generateListingMetadata(
  listingId: string,
  parent: ResolvingMetadata
): Promise<Metadata> {
  // Fetch listing data
  const { data: listing, error } = await supabase
    .from('listings_geospatial')
    .select('*')
    .eq('id', listingId)
    .single();

  if (error || !listing) {
    return {
      title: 'Listing | Pearl Hub',
      description: 'Discover amazing listings on Pearl Hub',
    };
  }

  const title = `${listing.title} | Pearl Hub`;
  const description = listing.description || `Discover ${listing.listing_type} on Pearl Hub`;
  const imageUrl = `${baseUrl}/og?id=${listingId}`;
  const url = `${baseUrl}/listing/${listingId}`;

  return {
    title,
    description,
    keywords: [listing.listing_type, listing.location_name, ...listing.tags].filter(Boolean),
    openGraph: {
      title,
      description,
      url,
      type: 'website',
      images: [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: title,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [imageUrl],
    },
    alternates: {
      canonical: url,
    },
    robots: {
      index: listing.is_active,
      follow: listing.is_active,
    },
  };
}

export async function generateSearchMetadata(params: {
  query?: string;
  type?: string;
  location?: string;
}): Promise<Metadata> {
  const searchTitle = params.query
    ? `Search: ${params.query} | Pearl Hub`
    : 'Search Listings | Pearl Hub';

  const searchDescription = params.query
    ? `Find ${params.query} on Pearl Hub in ${params.location || 'Sri Lanka'}`
    : 'Search and discover amazing listings on Pearl Hub';

  return {
    title: searchTitle,
    description: searchDescription,
    keywords: ['listings', 'search', params.query, params.type, params.location].filter(Boolean),
    openGraph: {
      title: searchTitle,
      description: searchDescription,
      url: `${baseUrl}/search${new URLSearchParams(params).toString()}`,
      type: 'website',
    },
  };
}

export function getRootMetadata(): Metadata {
  return {
    title: 'Pearl Hub | Trusted Marketplace for Sri Lanka',
    description:
      'Discover homestays, vehicles, events, and properties with verified owners. Trust & Safety guaranteed.',
    keywords: [
      'marketplace',
      'homestays',
      'vehicles',
      'events',
      'properties',
      'trusted',
      'sri lanka',
      'rental',
    ],
    openGraph: {
      title: 'Pearl Hub | Trusted Marketplace',
      description:
        'Discover amazing experiences with verified community members',
      url: baseUrl,
      type: 'website',
      locale: 'en_US',
      siteName: 'Pearl Hub',
      images: [
        {
          url: `${baseUrl}/og-image.jpg`,
          width: 1200,
          height: 630,
          alt: 'Pearl Hub',
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: 'Pearl Hub | Trusted Marketplace',
      description:
        'Discover amazing experiences with verified community members',
      images: [`${baseUrl}/og-image.jpg`],
    },
    robots: {
      index: true,
      follow: true,
      googleBot: {
        index: true,
        follow: true,
        'max-video-preview': -1,
        'max-image-preview': 'large',
        'max-snippet': -1,
      },
    },
  };
}
