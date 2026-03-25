-- Phase 6: Scaling, embeddings, event webhooks, payout queue

CREATE EXTENSION IF NOT EXISTS vector;

-- 1) Embeddings for semantic listing search
CREATE TABLE IF NOT EXISTS public.listing_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES public.listings_geospatial(id) ON DELETE CASCADE,
  embedding vector(1536) NOT NULL,
  model TEXT NOT NULL DEFAULT 'text-embedding-3-small',
  content_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(listing_id)
);

CREATE INDEX IF NOT EXISTS idx_listing_embeddings_ivfflat
  ON public.listing_embeddings
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- 2) Outbound webhook events (outbox pattern)
CREATE TABLE IF NOT EXISTS public.webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  destination_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'delivered', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0,
  next_retry_at TIMESTAMPTZ,
  last_error TEXT,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_status_retry
  ON public.webhook_events(status, next_retry_at, created_at);

-- 3) Payout queue for providers
CREATE TABLE IF NOT EXISTS public.payout_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  currency TEXT NOT NULL DEFAULT 'LKR',
  gross_amount NUMERIC(12,2) NOT NULL,
  platform_fee NUMERIC(12,2) NOT NULL DEFAULT 0,
  net_amount NUMERIC(12,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'paid', 'failed', 'reversed')),
  processor_ref TEXT,
  processor_message TEXT,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(booking_id)
);

CREATE INDEX IF NOT EXISTS idx_payout_queue_provider_status
  ON public.payout_queue(provider_id, status, created_at);

-- 4) Similarity search helper
CREATE OR REPLACE FUNCTION public.match_similar_listings(
  query_embedding vector(1536),
  match_count INT DEFAULT 10,
  min_similarity FLOAT DEFAULT 0.7
)
RETURNS TABLE (
  listing_id UUID,
  similarity FLOAT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    le.listing_id,
    1 - (le.embedding <=> query_embedding) AS similarity
  FROM public.listing_embeddings le
  WHERE 1 - (le.embedding <=> query_embedding) >= min_similarity
  ORDER BY le.embedding <=> query_embedding
  LIMIT match_count;
$$;

GRANT EXECUTE ON FUNCTION public.match_similar_listings(vector, INT, FLOAT) TO authenticated, anon;

-- 5) RLS
ALTER TABLE public.listing_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "listing_embeddings_read" ON public.listing_embeddings FOR SELECT USING (true);
CREATE POLICY IF NOT EXISTS "listing_embeddings_admin_write" ON public.listing_embeddings FOR ALL
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY IF NOT EXISTS "webhook_events_admin" ON public.webhook_events FOR ALL
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY IF NOT EXISTS "payout_queue_read_own_or_admin" ON public.payout_queue FOR SELECT
  USING (provider_id = auth.uid() OR public.is_admin(auth.uid()));

CREATE POLICY IF NOT EXISTS "payout_queue_admin_write" ON public.payout_queue FOR ALL
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));
