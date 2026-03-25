-- Phase 3: Trust, Admin Controls, KYC, Disputes & Moderation
-- Comprehensive admin dashboard, KYC verification, dispute resolution

-- ============================================================================
-- 1. KYC VERIFICATION TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.kyc_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Document types: NATIONAL_ID, PASSPORT, DRIVERS_LICENSE
  document_type TEXT NOT NULL CHECK (document_type IN ('NATIONAL_ID', 'PASSPORT', 'DRIVERS_LICENSE')),
  document_number TEXT NOT NULL,
  
  -- Verification status: pending, approved, rejected, expired
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  
  -- Personal info (encrypted in production)
  full_name TEXT,
  date_of_birth DATE,
  nationality TEXT,
  
  -- Document images (S3 URLs)
  document_front_url TEXT,
  document_back_url TEXT,
  selfie_url TEXT,
  
  -- Verification metadata
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  rejection_reason TEXT,
  
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_kyc_verifications_user_id ON public.kyc_verifications(user_id);
CREATE INDEX idx_kyc_verifications_status ON public.kyc_verifications(status);
CREATE INDEX idx_kyc_verifications_created_at ON public.kyc_verifications(created_at DESC);

-- ============================================================================
-- 2. USER REPUTATION & TRUST SCORES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_reputation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Scores (0-100)
  trust_score NUMERIC(5,2) NOT NULL DEFAULT 0,
  response_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  cancellation_rate NUMERIC(5,2) NOT NULL DEFAULT 0,
  
  -- Counters
  total_bookings INTEGER NOT NULL DEFAULT 0,
  completed_bookings INTEGER NOT NULL DEFAULT 0,
  cancelled_bookings INTEGER NOT NULL DEFAULT 0,
  dispute_count INTEGER NOT NULL DEFAULT 0,
  
  -- Badges
  is_superhost BOOLEAN NOT NULL DEFAULT false,
  is_verified BOOLEAN NOT NULL DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_reputation_trust_score ON public.user_reputation(trust_score DESC);
CREATE INDEX idx_user_reputation_is_superhost ON public.user_reputation(is_superhost);

-- ============================================================================
-- 3. DISPUTES & RESOLUTION SYSTEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  initiated_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Dispute type: payment_issue, property_damage, cancellation, no_show, quality_issue, security, other
  dispute_type TEXT NOT NULL CHECK (dispute_type IN (
    'payment_issue', 'property_damage', 'cancellation', 'no_show', 
    'quality_issue', 'security', 'dispute', 'other'
  )),
  
  -- Status: open, investigating, resolved, appeal_pending, closed
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN (
    'open', 'investigating', 'resolved', 'appeal_pending', 'closed'
  )),
  
  -- Details
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  evidence_urls TEXT[] DEFAULT ARRAY[]::TEXT[],
  
  -- Resolution
  resolution_notes TEXT,
  resolution_type TEXT CHECK (resolution_type IN (
    'full_refund', 'partial_refund', 'no_action', 'mediation'
  )),
  resolved_amount NUMERIC(12,2),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_disputes_booking_id ON public.disputes(booking_id);
CREATE INDEX idx_disputes_initiated_by ON public.disputes(initiated_by);
CREATE INDEX idx_disputes_status ON public.disputes(status);
CREATE INDEX idx_disputes_created_at ON public.disputes(created_at DESC);

-- ============================================================================
-- 4. REVIEWS & RATINGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  
  -- Reviewer & reviewee
  reviewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Rating (1-5)
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  
  -- Detailed ratings (1-5 each)
  cleanliness_rating INTEGER CHECK (cleanliness_rating IS NULL OR (cleanliness_rating >= 1 AND cleanliness_rating <= 5)),
  accuracy_rating INTEGER CHECK (accuracy_rating IS NULL OR (accuracy_rating >= 1 AND accuracy_rating <= 5)),
  communication_rating INTEGER CHECK (communication_rating IS NULL OR (communication_rating >= 1 AND communication_rating <= 5)),
  value_rating INTEGER CHECK (value_rating IS NULL OR (value_rating >= 1 AND value_rating <= 5)),
  
  -- Review text
  title TEXT NOT NULL,
  comment TEXT,
  
  -- Additional data
  listing_id TEXT NOT NULL,
  listing_type TEXT NOT NULL,
  
  -- Moderation status: pending, approved, rejected, hidden
  moderation_status TEXT NOT NULL DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'hidden')),
  moderated_at TIMESTAMPTZ,
  moderated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Guest response
  host_response TEXT,
  host_response_at TIMESTAMPTZ,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_reviews_booking_id ON public.reviews(booking_id);
CREATE INDEX idx_reviews_reviewer_id ON public.reviews(reviewer_id);
CREATE INDEX idx_reviews_reviewee_id ON public.reviews(reviewee_id);
CREATE INDEX idx_reviews_rating ON public.reviews(rating);
CREATE INDEX idx_reviews_moderation_status ON public.reviews(moderation_status);
CREATE INDEX idx_reviews_created_at ON public.reviews(created_at DESC);

-- ============================================================================
-- 5. CONTENT MODERATION & FLAG SYSTEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.content_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Content reference (polymorphic)
  content_type TEXT NOT NULL CHECK (content_type IN ('review', 'listing', 'profile', 'message', 'image')),
  content_id UUID NOT NULL,
  
  -- Flag reason: inappropriate, spam, fraud, abusive, explicit, fake, other
  flag_reason TEXT NOT NULL CHECK (flag_reason IN (
    'inappropriate', 'spam', 'fraud', 'abusive', 'explicit', 'fake', 'other'
  )),
  
  -- Flagged by user
  flagged_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  description TEXT,
  
  -- Moderation
  moderation_status TEXT NOT NULL DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'reviewing', 'approved', 'rejected', 'resolved')),
  moderated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  moderation_action TEXT,
  moderation_notes TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_content_flags_content_type_id ON public.content_flags(content_type, content_id);
CREATE INDEX idx_content_flags_moderation_status ON public.content_flags(moderation_status);
CREATE INDEX idx_content_flags_created_at ON public.content_flags(created_at DESC);

-- ============================================================================
-- 6. ADMIN ACTIONS & AUDIT LOG EXTENDED
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Action type: suspend_user, delete_listing, approve_review, ban_content, etc.
  action_type TEXT NOT NULL,
  
  -- Target
  target_type TEXT NOT NULL CHECK (target_type IN ('user', 'listing', 'review', 'booking', 'dispute')),
  target_id UUID NOT NULL,
  
  -- Details
  reason TEXT NOT NULL,
  details JSONB,
  
  -- Reversibility
  is_reversible BOOLEAN NOT NULL DEFAULT true,
  reversed_at TIMESTAMPTZ,
  reversed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_admin_actions_admin_id ON public.admin_actions(admin_id);
CREATE INDEX idx_admin_actions_target ON public.admin_actions(target_type, target_id);
CREATE INDEX idx_admin_actions_created_at ON public.admin_actions(created_at DESC);

-- ============================================================================
-- 7. USER SUSPENSIONS & BANS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_suspensions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Suspension type: temporary, permanent, appeal_pending
  suspension_type TEXT NOT NULL CHECK (suspension_type IN ('temporary', 'permanent', 'appeal_pending')),
  
  -- Duration (for temporary)
  suspended_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  suspended_until TIMESTAMPTZ,
  
  -- Reason
  reason TEXT NOT NULL,
  admin_notes TEXT,
  suspended_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Appeal
  appeal_submitted_at TIMESTAMPTZ,
  appeal_reason TEXT,
  appeal_decision TEXT,
  appeal_decided_at TIMESTAMPTZ,
  appeal_decided_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_suspensions_user_id ON public.user_suspensions(user_id);
CREATE INDEX idx_user_suspensions_suspended_until ON public.user_suspensions(suspended_until)
  WHERE suspension_type = 'temporary';

-- ============================================================================
-- 8. RLS POLICIES FOR PHASE 3
-- ============================================================================

-- Enable RLS
ALTER TABLE public.kyc_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_reputation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_suspensions ENABLE ROW LEVEL SECURITY;

-- KYC: Users see own, admins see all
CREATE POLICY "kyc_read_own" ON public.kyc_verifications FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin(auth.uid()));

CREATE POLICY "kyc_create_own" ON public.kyc_verifications FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "kyc_update_own" ON public.kyc_verifications FOR UPDATE
  USING (user_id = auth.uid() OR public.is_admin(auth.uid()))
  WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()));

-- Reputation: Public read, auth user see own details
CREATE POLICY "reputation_read" ON public.user_reputation FOR SELECT USING (true);

-- Disputes: Parties can see, admins can see all
CREATE POLICY "disputes_read" ON public.disputes FOR SELECT
  USING (
    initiated_by = auth.uid() OR
    (SELECT user_id FROM public.bookings WHERE id = booking_id LIMIT 1) = auth.uid() OR
    (SELECT provider_id FROM public.bookings WHERE id = booking_id LIMIT 1) = auth.uid() OR
    public.is_admin(auth.uid())
  );

CREATE POLICY "disputes_create" ON public.disputes FOR INSERT
  WITH CHECK (initiated_by = auth.uid());

CREATE POLICY "disputes_update_admin" ON public.disputes FOR UPDATE
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Reviews: Approved visible to public, own visible to reviewer, admins see all
CREATE POLICY "reviews_read" ON public.reviews FOR SELECT
  USING (
    moderation_status = 'approved' OR
    reviewer_id = auth.uid() OR
    reviewee_id = auth.uid() OR
    public.is_admin(auth.uid())
  );

CREATE POLICY "reviews_create" ON public.reviews FOR INSERT
  WITH CHECK (reviewer_id = auth.uid());

CREATE POLICY "reviews_update_own" ON public.reviews FOR UPDATE
  USING (reviewer_id = auth.uid() OR reviewee_id = auth.uid() OR public.is_admin(auth.uid()))
  WITH CHECK (reviewer_id = auth.uid() OR reviewee_id = auth.uid() OR public.is_admin(auth.uid()));

-- Content flags: Admin only
CREATE POLICY "content_flags_read_admin" ON public.content_flags FOR SELECT
  USING (public.is_admin(auth.uid()));

CREATE POLICY "content_flags_create" ON public.content_flags FOR INSERT
  WITH CHECK (flagged_by = auth.uid());

CREATE POLICY "content_flags_update_admin" ON public.content_flags FOR UPDATE
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Admin actions: Admin only
CREATE POLICY "admin_actions_read_admin" ON public.admin_actions FOR SELECT
  USING (public.is_admin(auth.uid()));

CREATE POLICY "admin_actions_create_admin" ON public.admin_actions FOR INSERT
  WITH CHECK (public.is_admin(auth.uid()) AND admin_id = auth.uid());

-- Suspensions: User see own, admin see all
CREATE POLICY "suspensions_read" ON public.user_suspensions FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin(auth.uid()));

CREATE POLICY "suspensions_create_admin" ON public.user_suspensions FOR INSERT
  WITH CHECK (public.is_admin(auth.uid()) AND suspended_by = auth.uid());

-- ============================================================================
-- 9. FUNCTIONS FOR KYC & MODERATION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_trust_score(p_user_id UUID)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT trust_score FROM public.user_reputation WHERE user_id = p_user_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_trust_score(UUID) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.approve_kyc(
  p_kyc_id UUID,
  p_admin_id UUID DEFAULT auth.uid()
)
RETURNS TABLE (
  kyc_id UUID,
  user_id UUID,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can approve KYC';
  END IF;

  UPDATE public.kyc_verifications
  SET status = 'approved', verified_at = now(), verified_by = p_admin_id
  WHERE id = p_kyc_id;

  UPDATE public.user_reputation
  SET is_verified = true, trust_score = trust_score + 20
  WHERE user_id = (SELECT user_id FROM public.kyc_verifications WHERE id = p_kyc_id);

  RETURN QUERY SELECT p_kyc_id, 
    (SELECT user_id FROM public.kyc_verifications WHERE id = p_kyc_id),
    'approved'::TEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_kyc(UUID, UUID) TO authenticated;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
