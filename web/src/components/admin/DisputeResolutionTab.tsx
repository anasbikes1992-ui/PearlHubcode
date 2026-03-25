// src/components/admin/DisputeResolutionTab.tsx - Dispute resolution interface
import React, { useState } from 'react';
import { usePendingDisputes, useResolveDispute } from '@/hooks/useAdmin';
import { AlertCircle, DollarSign } from 'lucide-react';

const DisputeResolutionTab: React.FC = () => {
  const { data: disputes, isLoading } = usePendingDisputes();
  const resolveDispute = useResolveDispute();
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [resolutionData, setResolutionData] = useState<{
    [key: string]: {
      type: string;
      amount: number;
      notes: string;
    };
  }>({});

  if (isLoading) {
    return <div className="space-y-4">Loading disputes...</div>;
  }

  if (!disputes || disputes.length === 0) {
    return (
      <div className="text-center py-8 text-gray-600">
        No open disputes at this time
      </div>
    );
  }

  const handleResolve = (disputeId: string) => {
    const data = resolutionData[disputeId];
    if (!data) return;

    resolveDispute.mutate(
      {
        disputeId,
        resolutionType: data.type,
        resolvedAmount: data.amount,
        notes: data.notes,
      },
      {
        onSuccess: () => {
          setExpandedId(null);
          setResolutionData((prev) => {
            const copy = { ...prev };
            delete copy[disputeId];
            return copy;
          });
        },
      }
    );
  };

  return (
    <div className="space-y-4">
      <div className="bg-yellow-50 border border-yellow-200 rounded p-4">
        <p className="text-sm text-yellow-900">
          <strong>{disputes.length}</strong> disputes require resolution
        </p>
      </div>

      <div className="space-y-3">
        {disputes.map((dispute) => (
          <div
            key={dispute.id}
            className="border rounded-lg p-4 hover:shadow-md transition"
          >
            <div className="flex justify-between items-start mb-2">
              <div>
                <h4 className="font-semibold">{dispute.title}</h4>
                <p className="text-sm text-gray-600">
                  Type: {dispute.dispute_type}
                </p>
              </div>
              <span className="bg-yellow-100 text-yellow-700 text-xs px-2 py-1 rounded">
                {dispute.status}
              </span>
            </div>

            <p className="text-sm text-gray-700 mb-3">{dispute.description}</p>

            {expandedId === dispute.id ? (
              <div className="bg-gray-50 p-4 rounded mt-4 space-y-3">
                <div>
                  <label className="block text-sm font-medium mb-1">
                    Resolution Type
                  </label>
                  <select
                    value={resolutionData[dispute.id]?.type || 'no_action'}
                    onChange={(e) =>
                      setResolutionData((prev) => ({
                        ...prev,
                        [dispute.id]: {
                          ...prev[dispute.id],
                          type: e.target.value,
                        },
                      }))
                    }
                    className="w-full px-3 py-2 border rounded text-sm"
                  >
                    <option value="no_action">No Action</option>
                    <option value="full_refund">Full Refund</option>
                    <option value="partial_refund">Partial Refund</option>
                    <option value="mediation">Mediation</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium mb-1">
                    Amount
                  </label>
                  <input
                    type="number"
                    value={resolutionData[dispute.id]?.amount || 0}
                    onChange={(e) =>
                      setResolutionData((prev) => ({
                        ...prev,
                        [dispute.id]: {
                          ...prev[dispute.id],
                          amount: parseFloat(e.target.value),
                        },
                      }))
                    }
                    className="w-full px-3 py-2 border rounded text-sm"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-1">
                    Resolution Notes
                  </label>
                  <textarea
                    value={resolutionData[dispute.id]?.notes || ''}
                    onChange={(e) =>
                      setResolutionData((prev) => ({
                        ...prev,
                        [dispute.id]: {
                          ...prev[dispute.id],
                          notes: e.target.value,
                        },
                      }))
                    }
                    className="w-full px-3 py-2 border rounded text-sm"
                    rows={3}
                  />
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleResolve(dispute.id)}
                    disabled={resolveDispute.isPending}
                    className="flex-1 px-3 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50"
                  >
                    {resolveDispute.isPending ? 'Resolving...' : 'Resolve Dispute'}
                  </button>
                  <button
                    onClick={() => setExpandedId(null)}
                    className="px-3 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => setExpandedId(dispute.id)}
                className="text-blue-600 text-sm hover:underline"
              >
                Resolve →
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default DisputeResolutionTab;
