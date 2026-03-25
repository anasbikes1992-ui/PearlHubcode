# 🚀 Phase 6: Bonus Upgrades & Scaling - FULL IMPLEMENTATION

**Duration**: 5-7 days  
**Priority**: LOW-MEDIUM  
**Dependency**: ✅ All Phases 1-5  
**Target**: Advanced features, performance optimization, enterprise readiness  

---

## 🎯 Phase 6 Executive Summary

Premium features and production-grade infrastructure:
- **AI Embeddings**: Recommendations via pgvector
- **Database Webhooks**: Real-time data sync
- **Automated Payouts**: Scheduled provider payouts
- **Advanced Monitoring**: Custom alerts, performance dashboards
- **Caching Strategy**: Redis for hot data
- **Load Testing**: k6 performance benchmarks

---

## 📊 Phase 6 Components

### 1. AI Recommendations with pgvector

**Migration**: `0005_ai_embeddings.sql`

```sql
-- Add vector column for embeddings
ALTER TABLE public.listings
ADD COLUMN IF NOT EXISTS embedding vector(1536);

-- Create index for similarity search
CREATE INDEX IF NOT EXISTS idx_listings_embedding_ivfflat
ON public.listings USING ivfflat (embedding)
WITH (lists = 100);

-- Function for similarity search
CREATE OR REPLACE FUNCTION public.search_similar_listings(
  p_listing_id UUID,
  p_limit INT DEFAULT 10
)
RETURNS TABLE(
  id UUID,
  title TEXT,
  description TEXT,
  similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.id,
    l.title,
    l.description,
    (l.embedding <-> (SELECT embedding FROM public.listings WHERE id = p_listing_id)) as similarity
  FROM public.listings l
  WHERE l.id != p_listing_id
  AND l.status = 'active'
  ORDER BY similarity ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.search_similar_listings(UUID, INT) TO authenticated;
```

**File**: `supabase/functions/generate-embeddings/index.ts`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";

Deno.serve(async (req: Request) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get listings without embeddings
    const { data: listings } = await supabase
      .from("listings")
      .select("id, title, description")
      .is("embedding", null)
      .limit(10);

    if (!listings || listings.length === 0) {
      return new Response(JSON.stringify({ message: "No listings to process" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Generate embeddings via OpenAI
    for (const listing of listings) {
      const text = `${listing.title} ${listing.description}`;

      const embeddingResponse = await fetch("https://api.openai.com/v1/embeddings", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openaiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "text-embedding-3-small",
          input: text,
        }),
      });

      const embeddingData = await embeddingResponse.json();
      const embedding = embeddingData.data[0].embedding;

      // Store embedding
      await supabase
        .from("listings")
        .update({ embedding })
        .eq("id", listing.id);
    }

    return new Response(
      JSON.stringify({ processed: listings.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Embedding generation error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to generate embeddings" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

### 2. Database Webhooks

**File**: `supabase/migrations/0005_database_webhooks.sql`

```sql
-- Create hook for booking confirmations
CREATE OR REPLACE FUNCTION public.on_booking_confirmed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'confirmed' AND OLD.status != 'confirmed' THEN
    -- Send notification
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
      NEW.provider_id,
      'New Booking Confirmed',
      'You have a new confirmed booking',
      'booking'
    );

    -- Calculate provider payout
    INSERT INTO public.payouts (provider_id, amount, currency, status, period_start, period_end)
    SELECT
      NEW.provider_id,
      NEW.total_amount * ((100 - (SELECT commission_percent FROM public.platform_config LIMIT 1)) / 100),
      'LKR',
      'pending',
      NEW.booking_date,
      CURRENT_DATE
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trigger_booking_confirmed
AFTER UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.on_booking_confirmed();
```

### 3. Automated Payouts

**File**: `supabase/functions/process-payouts/index.ts`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface PayoutProvider {
  provider_id: string;
  payout_account: string;
  payment_bank: string;
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get pending payouts
    const { data: payouts } = await supabase
      .from("payouts")
      .select("*, provider:profiles(id, payout_account, payment_bank)")
      .eq("status", "pending")
      .order("created_at", { ascending: true });

    if (!payouts || payouts.length === 0) {
      return new Response(
        JSON.stringify({ message: "No payouts to process" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    for (const payout of payouts) {
      try {
        // Process via payment gateway (e.g., PayHere Payout API)
        const payoutResponse = await fetch("https://payhere.lk/api/v2/settlement/payouts", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${Deno.env.get("PAYHERE_API_KEY")}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            merchant_id: Deno.env.get("PAYHERE_MERCHANT_ID"),
            amount: payout.amount,
            currency: "LKR",
            account_id: payout.provider.payout_account,
            bank: payout.provider.payment_bank,
          }),
        });

        const result = await payoutResponse.json();

        // Update payout status
        if (result.success) {
          await supabase
            .from("payouts")
            .update({
              status: "processing",
              processed_at: new Date().toISOString(),
            })
            .eq("id", payout.id);

          // Notify provider
          await supabase.from("notifications").insert({
            user_id: payout.provider_id,
            title: "Payout Initiated",
            message: `Payout of LKR ${payout.amount} has been initiated to your bank account`,
            type: "payment",
          });
        }
      } catch (error) {
        console.error(`Payout processing error for ${payout.id}:`, error);

        // Update with error
        await supabase
          .from("payouts")
          .update({
            status: "failed",
          })
          .eq("id", payout.id);
      }
    }

    return new Response(
      JSON.stringify({ processed: payouts.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Payout processing error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to process payouts" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

### 4. Caching Strategy with Redis

**File**: `web/src/lib/cache.ts`

```typescript
import { redis } from "@/lib/redis";

interface CacheOptions {
  ttl?: number; // Time to live in seconds
  tags?: string[]; // For cache invalidation
}

export async function getCached<T>(
  key: string,
  fetcher: () => Promise<T>,
  options: CacheOptions = {}
): Promise<T> {
  const { ttl = 3600, tags = [] } = options;

  // Try to get from cache
  const cached = await redis.get(key);
  if (cached) {
    return JSON.parse(cached);
  }

  // Fetch and cache
  const data = await fetcher();
  await redis.set(key, JSON.stringify(data), { EX: ttl });

  // Store tags for invalidation
  for (const tag of tags) {
    await redis.sadd(`tag:${tag}`, key);
  }

  return data;
}

export async function invalidateTag(tag: string) {
  const keys = await redis.smembers(`tag:${tag}`);

  if (keys.length > 0) {
    await redis.del(...keys);
    await redis.del(`tag:${tag}`);
  }
}

export async function invalidateCache(key: string) {
  await redis.del(key);
}
```

**Usage Example**:

```typescript
// Cache listings for 1 hour, invalidate on "listings" tag change
const listings = await getCached(
  `listings:${latitude}:${longitude}`,
  () => searchListingsByRadius(latitude, longitude),
  { ttl: 3600, tags: ["listings"] }
);

// When creating a new listing, invalidate the tag
await invalidateTag("listings");
```

### 5. Performance Monitoring

**File**: `supabase/functions/performance-monitor/index.ts`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface PerformanceMetrics {
  endpoint: string;
  method: string;
  response_time_ms: number;
  status_code: number;
  timestamp: string;
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const metrics = (await req.json()) as PerformanceMetrics;

    // Store in analytics table
    await supabase.from("analytics_performance").insert({
      endpoint: metrics.endpoint,
      method: metrics.method,
      response_time_ms: metrics.response_time_ms,
      status_code: metrics.status_code,
      recorded_at: metrics.timestamp,
    });

    // Alert if response time > 1000ms
    if (metrics.response_time_ms > 1000) {
      console.warn(`Slow endpoint detected: ${metrics.endpoint} took ${metrics.response_time_ms}ms`);

      // Send alert to admin
      // await sendAlert(...);
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Performance monitoring error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to record metrics" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

### 6. Load Testing

**File**: `k6/load-test.js`

```javascript
import http from "k6/http";
import { check, group, sleep } from "k6";

export const options = {
  stages: [
    { duration: "2m", target: 50 }, // Ramp up
    { duration: "5m", target: 50 }, // Stay at 50 users
    { duration: "2m", target: 100 }, // Ramp up to 100
    { duration: "5m", target: 100 }, // Stay at 100
    { duration: "2m", target: 0 }, // Ramp down
  ],
  thresholds: {
    http_req_duration: ["p(95)<500", "p(99)<1000"],
    http_req_failed: ["rate<0.1"],
  },
};

export default function () {
  group("Search Listings", () => {
    const searchResponse = http.post(
      "http://localhost:54321/functions/v1/search-listings-by-radius",
      JSON.stringify({
        latitude: 6.9271,
        longitude: 80.7744,
        radius_km: 50,
      }),
      {
        headers: { "Content-Type": "application/json" },
      }
    );

    check(searchResponse, {
      "status is 200": (r) => r.status === 200,
      "response time < 500ms": (r) => r.timings.duration < 500,
      "listings returned": (r) => JSON.parse(r.body).listings.length > 0,
    });
  });

  sleep(1);
}
```

---

## ✅ Phase 6 Completion Checklist

- [ ] pgvector installed and configured
- [ ] Embedding generation function working
- [ ] AI recommendations component built
- [ ] Database webhooks triggering correctly
- [ ] Payout processing automated
- [ ] Payout notifications sent
- [ ] Redis cache layer implemented
- [ ] Caching strategy documented
- [ ] Performance metrics tracked
- [ ] k6 load tests passing
- [ ] Custom alerts configured
- [ ] Documentation complete
- [ ] All tests passing
- [ ] Committed to GitHub

---

## 🎉 POST-PHASE 6: LAUNCH READINESS

### Production Checklist

- [ ] **Security**
  - [ ] All secrets in Supabase vault
  - [ ] No hardcoded credentials
  - [ ] RLS policies reviewed by security team
  - [ ] Rate limiting enabled
  - [ ] CORS properly configured

- [ ] **Performance**
  - [ ] All pages < 3s load time
  - [ ] Images optimized
  - [ ] Code splitting configured
  - [ ] CDN enabled
  - [ ] Database queries optimized

- [ ] **Reliability**
  - [ ] 99.9% uptime target
  - [ ] Automated backups
  - [ ] Disaster recovery plan
  - [ ] Error monitoring active
  - [ ] Alerting configured

- [ ] **Compliance**
  - [ ] Terms of Service
  - [ ] Privacy Policy
  - [ ] GDPR compliance
  - [ ] Payment PCI compliance
  - [ ] Data retention policies

- [ ] **Operations**
  - [ ] Runbooks created
  - [ ] On-call schedule
  - [ ] Incident response plan
  - [ ] Escalation procedures
  - [ ] Training completed

---

## 🚀 Launch Timeline

| Phase | Duration | Status |
| --- | --- | --- |
| Phase 0 | 1 day | ✅ COMPLETE |
| Phase 1 | 3-5 days | ✅ COMPLETE |
| Phase 2 | 5-7 days | ⏳ IN PROGRESS |
| Phase 3 | 3-4 days | ⏳ PENDING |
| Phase 4 | 5-7 days | ⏳ PENDING |
| Phase 5 | 7-10 days | ⏳ PENDING |
| Phase 6 | 5-7 days | ⏳ PENDING |
| Launch Prep | 2-3 days | ⏳ PENDING |
| **Total** | **31-43 days** | **~6-9 weeks** |

**Estimated Launch**: Late Q2 2026 (45-50 days from start)

---

