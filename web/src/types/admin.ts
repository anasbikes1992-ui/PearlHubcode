// src/types/admin.ts - Phase 3 Trust & Admin types

export interface KYCVerification {
  id: string;
  user_id: string;
  document_type: 'NATIONAL_ID' | 'PASSPORT' | 'DRIVERS_LICENSE';
  document_number: string;
  status: 'pending' | 'approved' | 'rejected' | 'expired';
  full_name: string | null;
  date_of_birth: string | null;
  nationality: string | null;
  document_front_url: string | null;
  document_back_url: string | null;
  selfie_url: string | null;
  verified_at: string | null;
  verified_by: string | null;
  rejection_reason: string | null;
  created_at: string;
  updated_at: string;
}

export interface UserReputation {
  id: string;
  user_id: string;
  trust_score: number;
  response_rate: number;
  cancellation_rate: number;
  total_bookings: number;
  completed_bookings: number;
  cancelled_bookings: number;
  dispute_count: number;
  is_superhost: boolean;
  is_verified: boolean;
  created_at: string;
  updated_at: string;
}

export interface Dispute {
  id: string;
  booking_id: string;
  initiated_by: string;
  dispute_type: 
    | 'payment_issue'
    | 'property_damage'
    | 'cancellation'
    | 'no_show'
    | 'quality_issue'
    | 'security'
    | 'dispute'
    | 'other';
  status: 'open' | 'investigating' | 'resolved' | 'appeal_pending' | 'closed';
  title: string;
  description: string;
  evidence_urls: string[];
  resolution_notes: string | null;
  resolution_type: 'full_refund' | 'partial_refund' | 'no_action' | 'mediation' | null;
  resolved_amount: number | null;
  resolved_at: string | null;
  resolved_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface Review {
  id: string;
  booking_id: string;
  reviewer_id: string;
  reviewee_id: string;
  rating: 1 | 2 | 3 | 4 | 5;
  cleanliness_rating: number | null;
  accuracy_rating: number | null;
  communication_rating: number | null;
  value_rating: number | null;
  title: string;
  comment: string | null;
  listing_id: string;
  listing_type: string;
  moderation_status: 'pending' | 'approved' | 'rejected' | 'hidden';
  moderated_at: string | null;
  moderated_by: string | null;
  host_response: string | null;
  host_response_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ContentFlag {
  id: string;
  content_type: 'review' | 'listing' | 'profile' | 'message' | 'image';
  content_id: string;
  flag_reason:
    | 'inappropriate'
    | 'spam'
    | 'fraud'
    | 'abusive'
    | 'explicit'
    | 'fake'
    | 'other';
  flagged_by: string;
  description: string | null;
  moderation_status: 'pending' | 'reviewing' | 'approved' | 'rejected' | 'resolved';
  moderated_by: string | null;
  moderation_action: string | null;
  moderation_notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface AdminAction {
  id: string;
  admin_id: string;
  action_type: string;
  target_type: 'user' | 'listing' | 'review' | 'booking' | 'dispute';
  target_id: string;
  reason: string;
  details: Record<string, any> | null;
  is_reversible: boolean;
  reversed_at: string | null;
  reversed_by: string | null;
  created_at: string;
}

export interface UserSuspension {
  id: string;
  user_id: string;
  suspension_type: 'temporary' | 'permanent' | 'appeal_pending';
  suspended_from: string;
  suspended_until: string | null;
  reason: string;
  admin_notes: string | null;
  suspended_by: string;
  appeal_submitted_at: string | null;
  appeal_reason: string | null;
  appeal_decision: string | null;
  appeal_decided_at: string | null;
  appeal_decided_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface AdminDashboardStats {
  total_users: number;
  total_listings: number;
  total_bookings_today: number;
  pending_disputes: number;
  pending_kyc: number;
  pending_reviews: number;
  flagged_content: number;
  active_suspensions: number;
  revenue_today: number;
  avg_response_time: number; // minutes
}
