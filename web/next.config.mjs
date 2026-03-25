// next.config.mjs - Phase 4 Next.js 15 Configuration
import { config } from 'dotenv';
config();

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Experimental features
  experimental: {
    // Enable App Router optimizations
    serverComponentsExternalPackages: ['@supabase/supabase-js'],
    instrumentationHook: true,
  },

  // Image optimization
  images: {
    domains: [
      'localhost',
      'supabase.co',
      's3.amazonaws.com',
      'cdn.example.com',
    ],
    sizes: [320, 640, 960, 1280, 1920],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    formats: ['image/avif', 'image/webp'],
    minimumCacheTTL: 31536000, // 1 year
  },

  // Static Export for Vercel
  output: 'standalone',

  // Rewrites & Redirects
  async rewrites() {
    return {
      beforeFiles: [
        // API routes
        {
          source: '/api/:path*',
          destination: '/api/:path*',
        },
      ],
    };
  },

  async redirects() {
    return [
      {
        source: '/listings/:id',
        destination: '/listing/:id',
        permanent: true,
      },
    ];
  },

  // Internationalization
  i18n: {
    locales: ['en', 'ar', 'fr', 'de', 'ja', 'ru', 'si', 'ta', 'zh'],
    defaultLocale: 'en',
    localeDetection: true,
  },

  // Environment variables
  env: {
    NEXT_PUBLIC_SUPABASE_URL: process.env.SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
    NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  },

  // Headers
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Cache-Control',
            value: 'public, max-age=60, s-maxage=120',
          },
        ],
      },
    ];
  },

  // Webpack
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.optimization.splitChunks.cacheGroups = {
        ...config.optimization.splitChunks.cacheGroups,
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          priority: 10,
        },
      };
    }
    return config;
  },

  // Compression
  compress: true,

  // Trailing slash
  trailingSlash: false,

  // React strict mode
  reactStrictMode: true,

  // SWC minification
  swcMinify: true,

  // PoweredBy header removal
  poweredByHeader: false,

  // Monitoring
  onDemandEntries: {
    maxInactiveAge: 60 * 1000,
    pagesBufferLength: 5,
  },
};

export default nextConfig;
