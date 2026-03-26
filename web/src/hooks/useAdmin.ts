// src/hooks/useAdmin.ts - Admin dashboard hooks for Phase 3
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { db } from '@/integrations/supabase/client';
import type { 
  Dispute, 
  Review, 
  KYCVerification, 
  ContentFlag, 
  UserSuspension,
  AdminDashboardStats
} from '@/types/admin';

export const usePendingDisputes = () => {
  return useQuery({
    queryKey: ['admin', 'disputes', 'pending'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('disputes')
        .select('*')
        .eq('status', 'open')
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      return (data as Dispute[]) || [];
    },
  });
};

export const usePendingKYC = () => {
  return useQuery({
    queryKey: ['admin', 'kyc', 'pending'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('kyc_verifications')
        .select('*')
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      return (data as KYCVerification[]) || [];
    },
  });
};

export const usePendingReviews = () => {
  return useQuery({
    queryKey: ['admin', 'reviews', 'pending'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('reviews')
        .select('*')
        .eq('moderation_status', 'pending')
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      return (data as Review[]) || [];
    },
  });
};

export const useFlaggedContent = () => {
  return useQuery({
    queryKey: ['admin', 'flags', 'pending'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('content_flags')
        .select('*')
        .eq('moderation_status', 'pending')
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      return (data as ContentFlag[]) || [];
    },
  });
};

export const useApproveKYC = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (kycId: string) => {
      const { data, error } = await db.rpc('approve_kyc', {
        p_kyc_id: kycId,
      });

      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'kyc', 'pending'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
};

export const useRejectKYC = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: { kycId: string; reason: string }) => {
      const { error } = await supabase
        .from('kyc_verifications')
        .update({
          status: 'rejected',
          rejection_reason: params.reason,
          updated_at: new Date().toISOString(),
        })
        .eq('id', params.kycId);

      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'kyc', 'pending'] });
    },
  });
};

export const useResolveDispute = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: {
      disputeId: string;
      resolutionType: string;
      resolvedAmount: number;
      notes: string;
    }) => {
      const { error } = await supabase
        .from('disputes')
        .update({
          status: 'resolved',
          resolution_type: params.resolutionType,
          resolved_amount: params.resolvedAmount,
          resolution_notes: params.notes,
          resolved_at: new Date().toISOString(),
          resolved_by: (await db.auth.getUser()).data.user?.id,
        })
        .eq('id', params.disputeId);

      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'disputes', 'pending'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
};

export const useApproveReview = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (reviewId: string) => {
      const { error } = await supabase
        .from('reviews')
        .update({
          moderation_status: 'approved',
          moderated_at: new Date().toISOString(),
          moderated_by: (await db.auth.getUser()).data.user?.id,
        })
        .eq('id', reviewId);

      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'reviews', 'pending'] });
    },
  });
};

export const useRejectReview = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (reviewId: string) => {
      const { error } = await supabase
        .from('reviews')
        .update({
          moderation_status: 'rejected',
          moderated_at: new Date().toISOString(),
          moderated_by: (await db.auth.getUser()).data.user?.id,
        })
        .eq('id', reviewId);

      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'reviews', 'pending'] });
    },
  });
};

export const useSuspendUser = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (params: {
      userId: string;
      suspensionType: 'temporary' | 'permanent';
      reason: string;
      suspendedUntil?: string;
    }) => {
      const { error } = await supabase
        .from('user_suspensions')
        .insert({
          user_id: params.userId,
          suspension_type: params.suspensionType,
          reason: params.reason,
          suspended_until: params.suspendedUntil,
          suspended_by: (await db.auth.getUser()).data.user?.id,
        });

      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
};

export const useAdminStats = () => {
  return useQuery({
    queryKey: ['admin', 'stats'],
    queryFn: async () => {
      // Fetch all statistics in parallel
      const [
        usersRes,
        listingsRes,
        bookingsRes,
        disputesRes,
        kycRes,
        reviewsRes,
        flagsRes,
        suspensionsRes,
        revenueRes,
      ] = await Promise.all([
        db.from('profiles').select('count', { count: 'exact' }).gte('created_at', new Date(Date.now() - 86400000).toISOString()),
        db.from('listings_geospatial').select('count', { count: 'exact' }),
        db.from('bookings').select('count', { count: 'exact' }).gte('created_at', new Date(Date.now() - 86400000).toISOString()),
        db.from('disputes').select('count', { count: 'exact' }).eq('status', 'open'),
        db.from('kyc_verifications').select('count', { count: 'exact' }).eq('status', 'pending'),
        db.from('reviews').select('count', { count: 'exact' }).eq('moderation_status', 'pending'),
        db.from('content_flags').select('count', { count: 'exact' }).eq('moderation_status', 'pending'),
        db.from('user_suspensions').select('count', { count: 'exact' }).neq('suspended_until', null),
        db.from('bookings').select('total_amount').gte('created_at', new Date(Date.now() - 86400000).toISOString()).eq('status', 'completed'),
      ]);

      const revenue_today = (revenueRes.data || []).reduce(
        (sum: number, b: { total_amount: number }) => sum + (b.total_amount || 0), 0
      );

      return {
        total_users: usersRes.count || 0,
        total_listings: listingsRes.count || 0,
        total_bookings_today: bookingsRes.count || 0,
        pending_disputes: disputesRes.count || 0,
        pending_kyc: kycRes.count || 0,
        pending_reviews: reviewsRes.count || 0,
        flagged_content: flagsRes.count || 0,
        active_suspensions: suspensionsRes.count || 0,
        revenue_today,
        avg_response_time: 0, // Requires message timestamp analysis — deferred
      } as AdminDashboardStats;
    },
    refetchInterval: 60000, // Refetch every minute
  });
};
