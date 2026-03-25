// src/components/admin/ReviewModerationTab.tsx - Review moderation interface
import React from 'react';
import { usePendingReviews, useApproveReview, useRejectReview } from '@/hooks/useAdmin';
import { Star, ThumbsUp, ThumbsDown } from 'lucide-react';

const ReviewModerationTab: React.FC = () => {
  const { data: reviews, isLoading } = usePendingReviews();
  const approveReview = useApproveReview();
  const rejectReview = useRejectReview();

  if (isLoading) return <div>Loading reviews...</div>;
  if (!reviews || reviews.length === 0) {
    return <div className="text-center py-8 text-gray-600">No pending reviews</div>;
  }

  return (
    <div className="space-y-4">
      <div className="bg-blue-50 border border-blue-200 rounded p-4">
        <p className="text-sm text-blue-900">
          <strong>{reviews.length}</strong> reviews awaiting moderation
        </p>
      </div>

      <div className="space-y-3">
        {reviews.map((review) => (
          <div key={review.id} className="border rounded-lg p-4 hover:shadow-md transition">
            <div className="flex justify-between items-start mb-2">
              <div>
                <div className="flex items-center gap-2">
                  <h4 className="font-semibold">{review.title}</h4>
                  <div className="flex gap-0.5">
                    {[...Array(review.rating)].map((_, i) => (
                      <Star key={i} size={14} className="fill-yellow-400 text-yellow-400" />
                    ))}
                  </div>
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  Listing: {review.listing_type} • Created: {new Date(review.created_at).toLocaleDateString()}
                </p>
              </div>
              <span className="bg-orange-100 text-orange-700 text-xs px-2 py-1 rounded">
                {review.moderation_status}
              </span>
            </div>

            <p className="text-sm text-gray-700 mb-3 line-clamp-2">{review.comment}</p>

            {review.cleanliness_rating && (
              <div className="text-xs text-gray-600 mb-3 grid grid-cols-2 gap-2">
                {review.cleanliness_rating && (
                  <p>Cleanliness: {review.cleanliness_rating}/5</p>
                )}
                {review.communication_rating && (
                  <p>Communication: {review.communication_rating}/5</p>
                )}
                {review.accuracy_rating && (
                  <p>Accuracy: {review.accuracy_rating}/5</p>
                )}
                {review.value_rating && (
                  <p>Value: {review.value_rating}/5</p>
                )}
              </div>
            )}

            <div className="flex gap-2 mt-3">
              <button
                onClick={() => approveReview.mutate(review.id)}
                disabled={approveReview.isPending}
                className="flex-1 px-3 py-2 bg-green-500 text-white text-sm rounded hover:bg-green-600 disabled:opacity-50 flex items-center justify-center gap-1"
              >
                <ThumbsUp size={16} />
                Approve
              </button>
              <button
                onClick={() => rejectReview.mutate(review.id)}
                disabled={rejectReview.isPending}
                className="flex-1 px-3 py-2 bg-red-500 text-white text-sm rounded hover:bg-red-600 disabled:opacity-50 flex items-center justify-center gap-1"
              >
                <ThumbsDown size={16} />
                Reject
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ReviewModerationTab;
