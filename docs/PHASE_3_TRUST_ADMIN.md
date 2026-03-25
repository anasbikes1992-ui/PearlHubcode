# 🛡️ Phase 3: Trust, Admin & Reviews - FULL IMPLEMENTATION

**Duration**: 3-4 days  
**Priority**: HIGH  
**Dependency**: ✅ Phase 1-2 (Database, payments, listings)  
**Target**: Complete trust infrastructure with KYC, disputes, moderation  

---

## 🎯 Phase 3 Executive Summary

Build trust & safety infrastructure:
- **KYC Verification**: Document upload, verification workflow
- **Disputes Management**: Complaint resolution system
- **Admin Dashboard**: React + Flutter admin interfaces
- **Review System**: Ratings, comments, verification
- **Moderation**: Flag inappropriate content, suspensions

---

## 📊 Phase 3 Components

### 1. KYC Verification Workflow

**Migration**: `0004_kyc_and_disputes.sql`

```sql
-- Enhanced KYC documents with verification metadata
ALTER TABLE public.kyc_documents
ADD COLUMN IF NOT EXISTS document_image_url TEXT,
ADD COLUMN IF NOT EXISTS verification_level VARCHAR(50) DEFAULT 'unverified',
ADD COLUMN IF NOT EXISTS expiry_date DATE,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- Create index for admin dashboard
CREATE INDEX IF NOT EXISTS idx_kyc_documents_verification_level
  ON public.kyc_documents(verification_level, created_at DESC);

-- Enhanced disputes with resolution tracking
ALTER TABLE public.disputes
ADD COLUMN IF NOT EXISTS resolution_amount NUMERIC(12,2),
ADD COLUMN IF NOT EXISTS resolution_type VARCHAR(50), -- refund, partial_refund, investigation_ongoing
ADD COLUMN IF NOT EXISTS evidence_urls TEXT[],
ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- Create index for upcoming resolution deadlines
CREATE INDEX IF NOT EXISTS idx_disputes_status_created
  ON public.disputes(status, created_at)
  WHERE status = 'open' OR status = 'under_review';

-- Create moderations table for content flags
CREATE TABLE IF NOT EXISTS public.moderations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  flagged_item_id UUID,
  flagged_item_type VARCHAR(50), -- listing, booking, review, user
  
  reason VARCHAR(255) NOT NULL,
  description TEXT,
  evidence_urls TEXT[],
  
  status VARCHAR(50) DEFAULT 'pending', -- pending, investigating, resolved, dismissed
  resolution TEXT,
  action_taken VARCHAR(50), -- warning, suspension, deletion, none
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_moderations_status
  ON public.moderations(status, created_at DESC);

-- Suspensions table
CREATE TABLE IF NOT EXISTS public.suspensions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  reason VARCHAR(255),
  suspension_level VARCHAR(50), -- warning, temporary, permanent
  expires_at TIMESTAMPTZ,
  
  moderation_id UUID REFERENCES public.moderations(id),
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_suspensions_user_expires
  ON public.suspensions(user_id, expires_at);

-- Reviews/Ratings table
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewed_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  verified_booking BOOLEAN DEFAULT true,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_user
  ON public.reviews(reviewed_user_id, created_at DESC);

-- RLS for reviews
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read reviews"
  ON public.reviews FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create reviews for bookings they were in"
  ON public.reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = reviewer_id AND
    EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = booking_id
        AND (user_id = auth.uid() OR provider_id = auth.uid())
    )
  );
```

### 2. Admin Panel Components

**File**: `web/src/components/AdminDashboard.tsx` (UPDATED)

```typescript
import { useState, useEffect } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "@/lib/supabase";
import KYCVerificationPanel from "./admin/KYCVerificationPanel";
import DisputesPanel from "./admin/DisputesPanel";
import ModerationsPanel from "./admin/ModerationsPanel";
import UsersPanel from "./admin/UsersPanel";

export default function AdminDashboard() {
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkAdmin = async () => {
      const { data: user } = await supabase.auth.getUser();
      if (!user) return;

      const { data, error } = await supabase.rpc("is_admin", { p_user_id: user.user.id });

      setIsAdmin(data === true);
      setLoading(false);
    };

    checkAdmin();
  }, []);

  if (loading) return <div>Loading...</div>;
  if (!isAdmin) return <div className="text-red-600">Access Denied</div>;

  return (
    <div className="space-y-4">
      <h1 className="text-3xl font-bold">Admin Dashboard</h1>

      <Tabs defaultValue="kyc">
        <TabsList>
          <TabsTrigger value="kyc">KYC Verification</TabsTrigger>
          <TabsTrigger value="disputes">Disputes</TabsTrigger>
          <TabsTrigger value="moderations">Moderations</TabsTrigger>
          <TabsTrigger value="users">Users</TabsTrigger>
        </TabsList>

        <TabsContent value="kyc">
          <KYCVerificationPanel />
        </TabsContent>

        <TabsContent value="disputes">
          <DisputesPanel />
        </TabsContent>

        <TabsContent value="moderations">
          <ModerationsPanel />
        </TabsContent>

        <TabsContent value="users">
          <UsersPanel />
        </TabsContent>
      </Tabs>
    </div>
  );
}
```

**File**: `web/src/components/admin/KYCVerificationPanel.tsx`

```typescript
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function KYCVerificationPanel() {
  const [documents, setDocuments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchPendingDocuments = async () => {
      const { data, error } = await supabase
        .from("kyc_documents")
        .select("*, user:profiles(full_name, email)")
        .eq("verification_level", "unverified")
        .order("created_at", { ascending: true });

      if (!error) {
        setDocuments(data || []);
      }
      setLoading(false);
    };

    fetchPendingDocuments();
  }, []);

  const handleApprove = async (documentId: string) => {
    await supabase
      .from("kyc_documents")
      .update({ verification_level: "verified", verified_at: new Date().toISOString() })
      .eq("id", documentId);

    setDocuments(documents.filter((d) => d.id !== documentId));
  };

  const handleReject = async (documentId: string, reason: string) => {
    await supabase
      .from("kyc_documents")
      .update({
        verification_level: "rejected",
        rejection_reason: reason,
      })
      .eq("id", documentId);

    setDocuments(documents.filter((d) => d.id !== documentId));
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div className="space-y-4">
      <h2 className="font-semibold">Pending KYC Documents ({documents.length})</h2>

      <div className="grid gap-4">
        {documents.map((doc) => (
          <div key={doc.id} className="border rounded-lg p-4 space-y-2">
            <div className="flex justify-between items-start">
              <div>
                <p className="font-medium">{doc.user?.full_name}</p>
                <p className="text-sm text-gray-600">{doc.user?.email}</p>
                <Badge>{doc.document_type}</Badge>
              </div>
              <div className="space-x-2">
                <Button size="sm" onClick={() => handleApprove(doc.id)}>
                  Approve
                </Button>
                <Button size="sm" variant="destructive" onClick={() => handleReject(doc.id, "Invalid document")}>
                  Reject
                </Button>
              </div>
            </div>
            {doc.document_image_url && (
              <img src={doc.document_image_url} alt="KYC" className="max-h-48 rounded" />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 3. Review System

**File**: `web/src/components/ReviewSection.tsx` (UPDATED)

```typescript
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/lib/supabase";

export default function ReviewSection({ bookingId, reviewedUserId }: { bookingId: string; reviewedUserId: string }) {
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");
  const queryClient = useQueryClient();

  const { data: reviews } = useQuery({
    queryKey: ["reviews", reviewedUserId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("reviews")
        .select("*")
        .eq("reviewed_user_id", reviewedUserId)
        .order("created_at", { ascending: false });

      if (error) throw error;
      return data;
    },
  });

  const { mutate: submitReview, isPending } = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.from("reviews").insert({
        booking_id: bookingId,
        reviewed_user_id: reviewedUserId,
        rating,
        comment,
        verified_booking: true,
      });

      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["reviews", reviewedUserId] });
      setRating(0);
      setComment("");
    },
  });

  const avgRating = reviews ? reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length : 0;

  return (
    <div className="space-y-4">
      <div>
        <p className="text-sm text-gray-600">Average Rating</p>
        <div className="flex items-center gap-2">
          <div className="flex gap-1">
            {[...Array(5)].map((_, i) => (
              <Star
                key={i}
                className={`w-5 h-5 ${i < Math.round(avgRating) ? "text-yellow-400 fill-yellow-400" : "text-gray-300"}`}
              />
            ))}
          </div>
          <span className="font-semibold">{avgRating.toFixed(1)}</span>
          <span className="text-gray-600">({reviews?.length || 0} reviews)</span>
        </div>
      </div>

      <div className="space-y-2">
        <h3 className="font-semibold">Leave a Review</h3>
        <div className="flex gap-1">
          {[...Array(5)].map((_, i) => (
            <button key={i} onClick={() => setRating(i + 1)}>
              <Star
                className={`w-6 h-6 ${i < rating ? "text-yellow-400 fill-yellow-400" : "text-gray-300"}`}
              />
            </button>
          ))}
        </div>
        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          placeholder="Share your experience..."
          className="w-full p-2 border rounded"
        />
        <Button onClick={() => submitReview()} disabled={!rating || !comment || isPending}>
          Submit Review
        </Button>
      </div>

      <div className="space-y-2">
        <h3 className="font-semibold">Recent Reviews</h3>
        {reviews?.slice(0, 5).map((review) => (
          <div key={review.id} className="border rounded-lg p-3">
            <div className="flex items-center gap-2">
              <div className="flex gap-1">
                {[...Array(5)].map((_, i) => (
                  <Star
                    key={i}
                    className={`w-4 h-4 ${i < review.rating ? "text-yellow-400 fill-yellow-400" : "text-gray-300"}`}
                  />
                ))}
              </div>
              <span className="text-sm text-gray-600">{new Date(review.created_at).toLocaleDateString()}</span>
            </div>
            <p className="text-sm">{review.comment}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## ✅ Phase 3 Completion Checklist

- [ ] Database migration 0004 deployed
- [ ] KYC verification panel functional
- [ ] Disputes CRUD operations working
- [ ] Moderations panel created
- [ ] Review system with star ratings
- [ ] Admin dashboard accessible only to admins
- [ ] All RLS policies updated for new tables
- [ ] Tests passing (80%+ coverage)
- [ ] Documentation complete
- [ ] Committed to GitHub

---

