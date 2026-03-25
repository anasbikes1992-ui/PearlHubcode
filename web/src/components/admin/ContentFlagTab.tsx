// src/components/admin/ContentFlagTab.tsx - Content flag moderation
import React from 'react';
import { useFlaggedContent } from '@/hooks/useAdmin';
import { Flag, AlertTriangle } from 'lucide-react';

const ContentFlagTab: React.FC = () => {
  const { data: flags, isLoading } = useFlaggedContent();

  if (isLoading) return <div>Loading flagged content...</div>;
  if (!flags || flags.length === 0) {
    return <div className="text-center py-8 text-gray-600">No flagged content</div>;
  }

  const reasonColors: Record<string, string> = {
    inappropriate: 'bg-red-100 text-red-700',
    spam: 'bg-orange-100 text-orange-700',
    fraud: 'bg-purple-100 text-purple-700',
    abusive: 'bg-red-100 text-red-700',
    explicit: 'bg-pink-100 text-pink-700',
    fake: 'bg-yellow-100 text-yellow-700',
    other: 'bg-gray-100 text-gray-700',
  };

  return (
    <div className="space-y-4">
      <div className="bg-red-50 border border-red-200 rounded p-4">
        <p className="text-sm text-red-900">
          <strong>{flags.length}</strong> content items flagged for review
        </p>
      </div>

      <div className="space-y-3">
        {flags.map((flag) => (
          <div key={flag.id} className="border rounded-lg p-4 hover:shadow-md transition">
            <div className="flex justify-between items-start">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-2">
                  <Flag size={16} className="text-red-600" />
                  <span className="font-semibold">
                    {flag.content_type.toUpperCase()}: {flag.content_id.substring(0, 8)}...
                  </span>
                  <span
                    className={`text-xs px-2 py-1 rounded font-medium ${
                      reasonColors[flag.flag_reason] || reasonColors.other
                    }`}
                  >
                    {flag.flag_reason}
                  </span>
                </div>

                {flag.description && (
                  <p className="text-sm text-gray-700 mb-2 bg-gray-50 p-2 rounded">
                    {flag.description}
                  </p>
                )}

                <p className="text-xs text-gray-500">
                  Flagged by user • {new Date(flag.created_at).toLocaleDateString()}
                </p>
              </div>
            </div>

            <div className="flex gap-2 mt-3">
              <button className="flex-1 px-3 py-2 bg-blue-500 text-white text-sm rounded hover:bg-blue-600">
                Approve
              </button>
              <button className="flex-1 px-3 py-2 bg-red-500 text-white text-sm rounded hover:bg-red-600">
                Remove
              </button>
              <button className="flex-1 px-3 py-2 bg-yellow-500 text-white text-sm rounded hover:bg-yellow-600">
                Keep
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ContentFlagTab;
