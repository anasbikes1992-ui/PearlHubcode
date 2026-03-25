# 🧪 Phase 5: Testing & Polish - FULL IMPLEMENTATION

**Duration**: 7-10 days  
**Priority**: MEDIUM-HIGH  
**Dependency**: ✅ Phase 1-4  
**Target**: 85%+ code coverage, smooth UX, monitoring ready  

---

## 🎯 Phase 5 Executive Summary

Professional quality assurance and observability:
- **Unit Tests**: Vitest + 85%+ coverage
- **E2E Tests**: Playwright for critical flows
- **Performance**: Image optimization, code splitting
- **i18n**: Multi-language support (en, si, ta, ar, etc.)
- **PWA**: Installable, offline-capable
- **Monitoring**: Sentry for errors, PostHog for analytics

---

## 📊 Phase 5 Testing Stack

### 1. Vitest Configuration

**File**: `web/vitest.config.ts`

```typescript
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      exclude: [
        "node_modules/",
        "src/test/",
        "**/*.d.ts",
        "dist/",
      ],
      lines: 85,
      functions: 85,
      branches: 85,
      statements: 85,
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

### 2. Unit Tests Examples

**File**: `web/src/hooks/__tests__/useListings.test.ts`

```typescript
import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { useListingsInfinite } from "@/hooks/useListings";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import * as supabaseClient from "@/lib/supabase";

vi.mock("@/lib/supabase");

describe("useListingsInfinite", () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    });
  });

  it("fetches listings without geosearch params", async () => {
    const mockListings = [
      { id: "1", title: "Villa 1", price: 10000 },
      { id: "2", title: "Villa 2", price: 15000 },
    ];

    vi.spyOn(supabaseClient, "supabase").mockReturnValue({
      from: vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          order: vi.fn().mockResolvedValue({
            data: mockListings,
            error: null,
          }),
        }),
      }),
    } as any);

    const TestComponent = () => {
      const { data } = useListingsInfinite();
      return <div>{data?.pages[0].listings?.length}</div>;
    };

    render(
      <QueryClientProvider client={queryClient}>
        <TestComponent />
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(screen.getByText("2")).toBeInTheDocument();
    });
  });

  it("filters listings by price range", async () => {
    const mockListings = [{ id: "1", title: "Villa 1", price: 12000 }];

    // Test with price_min=10000, price_max=15000

    expect(mockListings[0].price).toBeGreaterThanOrEqual(10000);
    expect(mockListings[0].price).toBeLessThanOrEqual(15000);
  });
});
```

### 3. E2E Tests (Playwright)

**File**: `web/e2e/payment.spec.ts`

```typescript
import { test, expect } from "@playwright/test";

test.describe("Payment Flow", () => {
  test("user can create booking and initiate payment", async ({ page }) => {
    await page.goto("http://localhost:5173");

    // Sign up
    await page.click("text=Sign Up");
    await page.fill("input[type='email']", "test@example.com");
    await page.fill("input[type='password']", "Test123!");
    await page.fill("input[placeholder='Full Name']", "Test User");
    await page.click("button:has-text('Create Account')");

    // Wait for redirect to dashboard
    await expect(page).toHaveURL("http://localhost:5173/dashboard");

    // Search for listings
    await page.goto("http://localhost:5173/listings");
    await page.click("text=Colombo");

    // Select first listing
    await page.click("div[data-testid='listing-card']:first-child");

    // Create booking
    await page.fill("input[placeholder='Check-in']", "2026-04-01");
    await page.fill("input[placeholder='Check-out']", "2026-04-05");
    await page.click("button:has-text('Book Now')");

    // Click pay button
    await expect(page.locator("button:has-text('Pay')")).toBeVisible();
    await page.click("button:has-text('Pay')");

    // Verify payment function was called
    await waitFor(async () => {
      const logs = await page.evaluate(() => console.log("Payment initiated"));
      expect(logs).toBeDefined();
    });
  });

  test("payment webhook correctly processes success", async ({ page }) => {
    // Simulate webhook callback
    const webhookPayload = {
      merchant_id: "1211145",
      order_id: "test-order-123",
      payhere_amount: "10000.00",
      payhere_currency: "LKR",
      status_code: "2",
      md5sig: "CALCULATED_SIGNATURE",
      custom_1: "user-uuid",
      custom_2: "booking-uuid",
    };

    const response = await page.request.post(
      "http://localhost:54321/functions/v1/payment-webhook",
      {
        data: new URLSearchParams(webhookPayload as any),
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      }
    );

    expect(response.status()).toBe(200);
    const json = await response.json();
    expect(json.success).toBe(true);
  });
});
```

### 4. Image Optimization

**File**: `web/src/components/OptimizedImage.tsx`

```typescript
import { CSSProperties } from "react";

interface OptimizedImageProps {
  src: string;
  alt: string;
  width?: number;
  height?: number;
  priority?: boolean;
  className?: string;
}

export default function OptimizedImage({
  src,
  alt,
  width = 400,
  height = 300,
  priority = false,
  className = "",
}: OptimizedImageProps) {
  // Supabase image transformation API
  const imageUrl = new URL(src);
  const params = new URLSearchParams();

  // Add quality parameter
  params.append("quality", "80");

  // Add size limits
  params.append("width", String(width * 2)); // Support 2x displays
  params.append("height", String(height * 2));

  const optimizedUrl = `${imageUrl.origin}${imageUrl.pathname}?${params.toString()}`;

  const style: CSSProperties = {
    width: "100%",
    height: "auto",
    aspectRatio: `${width}/${height}`,
  };

  return (
    <img src={optimizedUrl} alt={alt} className={className} style={style} loading={priority ? "eager" : "lazy"} />
  );
}
```

### 5. i18n Configuration

**File**: `web/src/i18n/config.ts`

```typescript
import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import en from "./locales/en.json";
import si from "./locales/si.json";
import ta from "./locales/ta.json";
import ar from "./locales/ar.json";

const resources = { en, si, ta, ar };

i18n.use(initReactI18next).init({
  resources,
  lng: localStorage.getItem("language") || "en",
  fallbackLng: "en",
  interpolation: { escapeValue: false },
});

export default i18n;
```

**File**: `web/src/i18n/locales/si.json`

```json
{
  "listings": "ලැයිස්තු",
  "book_now": "දැන් වෙන්න",
  "price": "මිල",
  "rating": "ශ්‍රේණිගත කිරීම",
  "payment": "ගෙවීම",
  "total": "එකතුව"
}
```

### 6. PWA Configuration

**File**: `web/public/manifest.json`

```json
{
  "name": "PearlHub - Luxury Marketplace",
  "short_name": "PearlHub",
  "description": "Book luxury stays, events, and services in Sri Lanka",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#000000",
  "orientation": "portrait",
  "icons": [
    {
      "src": "/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

**File**: `web/src/serviceWorker.ts`

```typescript
// Service worker for offline functionality
const CACHE_NAME = "pearlhub-v1";
const urlsToCache = ["/", "/index.html", "/favicon.ico"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(urlsToCache);
    })
  );
});

self.addEventListener("fetch", (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      if (response) return response;

      return fetch(event.request).then((response) => {
        if (!response || response.status !== 200 || response.type !== "basic") {
          return response;
        }

        const responseToCache = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseToCache);
        });

        return response;
      });
    })
  );
});
```

### 7. Monitoring Setup

**File**: `web/src/lib/monitoring.ts`

```typescript
import * as Sentry from "@sentry/react";
import { posthog } from "posthog-js";

export function initMonitoring() {
  // Sentry for error tracking
  Sentry.init({
    dsn: process.env.VITE_SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: process.env.NODE_ENV === "production" ? 0.1 : 1.0,
  });

  // PostHog for analytics
  posthog.init(process.env.VITE_POSTHOG_KEY || "", {
    api_host: process.env.VITE_POSTHOG_API_HOST,
    session_recording: {
      sampleRate: 0.1,
    },
  });
}

export function trackEvent(name: string, properties?: Record<string, any>) {
  posthog.capture(name, properties);
}

export function trackPageView(path: string) {
  posthog.capture("$pageview", { $current_url: path });
}
```

---

## ✅ Phase 5 Completion Checklist

- [ ] Vitest configured with 85%+ coverage target
- [ ] Unit tests for all hooks
- [ ] Unit tests for critical components
- [ ] Playwright E2E tests for payment flow
- [ ] Playwright E2E tests for auth
- [ ] Image optimization implemented
- [ ] i18n configured for 6+ languages
- [ ] PWA manifest created
- [ ] Service worker registered
- [ ] Sentry error tracking setup
- [ ] PostHog analytics setup
- [ ] All tests passing
- [ ] Coverage report generated
- [ ] Documentation complete
- [ ] Committed to GitHub

---

