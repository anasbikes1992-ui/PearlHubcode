// src/components/admin/KYCVerificationTab.tsx - KYC verification management
import React, { useState } from 'react';
import { usePendingKYC, useApproveKYC, useRejectKYC } from '@/hooks/useAdmin';
import { CheckCircle2, XCircle, AlertCircle, Eye } from 'lucide-react';

interface KYCTab {}

const KYCVerificationTab: React.FC<KYCTab> = () => {
  const { data: pendingKYC, isLoading } = usePendingKYC();
  const approveKYC = useApproveKYC();
  const rejectKYC = useRejectKYC();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [rejectingId, setRejectingId] = useState<string | null>(null);

  if (isLoading) {
    return (
      <div className="space-y-4">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="h-24 bg-gray-200 rounded animate-pulse" />
        ))}
      </div>
    );
  }

  if (!pendingKYC || pendingKYC.length === 0) {
    return (
      <div className="text-center py-8">
        <CheckCircle2 className="mx-auto text-green-600 mb-2" size={32} />
        <p className="text-gray-600">All KYC verifications are processed</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Summary */}
      <div className="bg-blue-50 border border-blue-200 rounded p-4">
        <p className="text-sm text-blue-900">
          <strong>{pendingKYC.length}</strong> pending KYC verifications waiting for review
        </p>
      </div>

      {/* KYC List */}
      <div className="space-y-3">
        {pendingKYC.map((kyc) => (
          <div
            key={kyc.id}
            className="border rounded-lg p-4 hover:shadow-md transition-shadow"
          >
            <div className="flex justify-between items-start">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-2">
                  <span className="font-semibold text-lg">{kyc.full_name}</span>
                  <span className="bg-blue-100 text-blue-700 text-xs px-2 py-1 rounded">
                    {kyc.document_type}
                  </span>
                </div>

                <p className="text-sm text-gray-600">
                  Document: {kyc.document_number}
                </p>
                <p className="text-sm text-gray-600">
                  Nationality: {kyc.nationality}
                </p>
                <p className="text-xs text-gray-500 mt-2">
                  Submitted: {new Date(kyc.created_at).toLocaleDateString()}
                </p>
              </div>

              <div className="flex gap-2">
                <button
                  onClick={() => setSelectedId(kyc.id)}
                  className="p-2 text-blue-600 hover:bg-blue-50 rounded transition"
                  title="View documents"
                >
                  <Eye size={18} />
                </button>
                <button
                  onClick={() => approveKYC.mutate(kyc.id)}
                  disabled={approveKYC.isPending}
                  className="px-3 py-2 bg-green-500 text-white text-sm rounded hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed transition"
                >
                  {approveKYC.isPending ? 'Approving...' : 'Approve'}
                </button>
                <button
                  onClick={() => setRejectingId(kyc.id)}
                  className="px-3 py-2 bg-red-500 text-white text-sm rounded hover:bg-red-600 transition"
                >
                  Reject
                </button>
              </div>
            </div>

            {/* Rejection form */}
            {rejectingId === kyc.id && (
              <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded">
                <textarea
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder="Reason for rejection..."
                  className="w-full px-3 py-2 border border-red-300 rounded text-sm mb-2"
                  rows={2}
                />
                <div className="flex gap-2">
                  <button
                    onClick={() => {
                      if (rejectReason.trim()) {
                        rejectKYC.mutate(
                          { kycId: kyc.id, reason: rejectReason },
                          {
                            onSuccess: () => {
                              setRejectingId(null);
                              setRejectReason('');
                            },
                          }
                        );
                      }
                    }}
                    disabled={rejectKYC.isPending || !rejectReason.trim()}
                    className="px-3 py-1 bg-red-500 text-white text-sm rounded hover:bg-red-600 disabled:opacity-50"
                  >
                    {rejectKYC.isPending ? 'Rejecting...' : 'Confirm Rejection'}
                  </button>
                  <button
                    onClick={() => {
                      setRejectingId(null);
                      setRejectReason('');
                    }}
                    className="px-3 py-1 bg-gray-300 text-gray-700 text-sm rounded hover:bg-gray-400"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Document viewer modal */}
      {selectedId && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg p-6 max-w-2xl w-full max-h-96 overflow-auto">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold">Document Preview</h3>
              <button
                onClick={() => setSelectedId(null)}
                className="text-gray-500 hover:text-gray-700"
              >
                ✕
              </button>
            </div>

            {/* Documents preview would go here */}
            <div className="space-y-4">
              <div className="border rounded p-4">
                <p className="text-sm text-gray-600 mb-2">Front Document</p>
                <p className="text-xs text-gray-500">
                  [Document image would render here - integration with S3]
                </p>
              </div>
              <div className="border rounded p-4">
                <p className="text-sm text-gray-600 mb-2">Back Document</p>
                <p className="text-xs text-gray-500">
                  [Document image would render here - integration with S3]
                </p>
              </div>
              <div className="border rounded p-4">
                <p className="text-sm text-gray-600 mb-2">Selfie</p>
                <p className="text-xs text-gray-500">
                  [Selfie image would render here - integration with S3]
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default KYCVerificationTab;
