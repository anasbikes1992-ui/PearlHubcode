# 🌐 Phase 4: Next.js 15 Migration & SEO - FULL IMPLEMENTATION

**Duration**: 5-7 days  
**Priority**: MEDIUM  
**Dependency**: ✅ Phase 1-3  
**Target**: Server-side rendering, dynamic metadata, SEO-optimized structure  

---

## 🎯 Phase 4 Executive Summary

Migrate to Next.js 15 for better SEO, performance, and developer experience:
- **App Router**: Server Components for better bundling
- **Dynamic Metadata**: Route-specific title, description, OG tags
- **Sitemap & Robots**: Dynamic XML generation
- **ISR**: Incremental Static Regeneration for listings
- **Migration**: Keep Vite as fallback, use both during transition

---

## 📊 Phase 4 Components

### 1. Next.js Project Structure

**File**: `d:\fath1\web-next\package.json`

```json
{
  "name": "pearlhub-web-next",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "@supabase/supabase-js": "^2.38.4",
    "@tanstack/react-query": "^5.0.0",
    "tailwindcss": "^3.3.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0",
    "@types/react": "^19.0.0"
  }
}
```

### 2. App Router Structure

**File**: `web-next/app/layout.tsx` (Root Layout)

```typescript
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PearlHub - Luxury Marketplace in Sri Lanka",
  description: "Book luxury stays, events, vehicles and services across Sri Lanka",
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"),
  openGraph: {
    type: "website",
    locale: "en_US",
    url: process.env.NEXT_PUBLIC_SITE_URL,
    title: "PearlHub - Luxury Marketplace",
    description: "Experience luxury in Sri Lanka",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

**File**: `web-next/app/(listings)/page.tsx` (Listings Page)

```typescript
import type { Metadata } from "next";
import ListingsGrid from "@/components/ListingsGrid";

export const metadata: Metadata = {
  title: "Browse Listings - PearlHub",
  description: "Discover amazing stays, events, and services across Sri Lanka",
};

export const revalidate = 3600; // ISR: Revalidate every hour

export default async function ListingsPage() {
  return (
    <div className="container py-8">
      <h1 className="text-4xl font-bold mb-8">Explore Listings</h1>
      <ListingsGrid />
    </div>
  );
}
```

**File**: `web-next/app/(listings)/[id]/page.tsx` (Dynamic Listing Detail)

```typescript
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { createServerComponentClient } from "@supabase/auth-helpers-nextjs";
import { cookies } from "next/headers";
import ListingDetail from "@/components/ListingDetail";

interface Props {
  params: { id: string };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const supabase = createServerComponentClient({ cookies });

  const { data: listing, error } = await supabase
    .from("listings")
    .select("id, title, description, image_url, price, rating")
    .eq("id", params.id)
    .single();

  if (error) {
    return { title: "Listing Not Found" };
  }

  return {
    title: `${listing.title} - PearlHub`,
    description: listing.description,
    openGraph: {
      title: listing.title,
      description: listing.description || "Luxury listing on PearlHub",
      images: [{ url: listing.image_url || "/og-default.jpg" }],
      type: "website",
    },
  };
}

export const revalidate = 600; // ISR: Revalidate every 10 minutes

export async function generateStaticParams() {
  const supabase = createServerComponentClient({ cookies });

  const { data: listings } = await supabase
    .from("listings")
    .select("id")
    .limit(100); // Generate top 100, on-demand for rest

  return (listings || []).map((listing) => ({
    id: listing.id,
  }));
}

export default async function ListingPage({ params }: Props) {
  const supabase = createServerComponentClient({ cookies });

  const { data: listing, error } = await supabase
    .from("listings")
    .select("*")
    .eq("id", params.id)
    .single();

  if (error || !listing) {
    notFound();
  }

  return <ListingDetail listing={listing} />;
}
```

### 3. Dynamic Sitemap & Robots

**File**: `web-next/app/sitemap.ts`

```typescript
import { MetadataRoute } from "next";
import { createServerComponentClient } from "@supabase/auth-helpers-nextjs";
import { cookies } from "next/headers";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const supabase = createServerComponentClient({ cookies });
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

  // Static routes
  const staticRoutes: MetadataRoute.Sitemap = [
    { url: baseUrl, lastModified: new Date(), changeFrequency: "daily", priority: 1 },
    { url: `${baseUrl}/listings`, lastModified: new Date(), changeFrequency: "hourly", priority: 0.9 },
    { url: `${baseUrl}/about`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.5 },
    { url: `${baseUrl}/contact`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.5 },
  ];

  // Dynamic listing routes
  const { data: listings } = await supabase
    .from("listings")
    .select("id, updated_at")
    .eq("status", "active");

  const listingRoutes: MetadataRoute.Sitemap =
    listings?.map((listing) => ({
      url: `${baseUrl}/listings/${listing.id}`,
      lastModified: new Date(listing.updated_at),
      changeFrequency: "weekly" as const,
      priority: 0.8,
    })) || [];

  return [...staticRoutes, ...listingRoutes];
}
```

**File**: `web-next/app/robots.ts`

```typescript
import { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/admin", "/auth", "/dashboard"],
      },
      {
        userAgent: "AdsBot-Google",
        crawlDelay: 1,
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
    host: baseUrl,
  };
}
```

---

## 📄 Phase 4 Configuration Files

**File**: `web-next/tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "preserve",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noEmit": true,
    "removeComments": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

**File**: `web-next/next.config.js`

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "pxuydclxnnfgzpzccfoa.supabase.co",
        pathname: "/storage/v1/object/**",
      },
    ],
  },
  env: {
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  },
};

module.exports = nextConfig;
```

---

## ✅ Phase 4 Completion Checklist

- [ ] Next.js 15 project scaffolded
- [ ] App Router implemented
- [ ] Dynamic metadata working for listings
- [ ] Sitemap generation working
- [ ] Robots.txt implemented
- [ ] ISR revalidation configured
- [ ] Server Components for performance
- [ ] Migration path from Vite clear
- [ ] Build passes with 0 errors
- [ ] Documentation complete
- [ ] Committed to GitHub

---

