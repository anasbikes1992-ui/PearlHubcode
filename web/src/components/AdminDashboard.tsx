// src/components/AdminDashboard.tsx - Phase 3 Admin Dashboard
import React, { useState } from 'react';
import { useAdminStats } from '@/hooks/useAdmin';
import {
  BarChart3,
  Shield,
  FileText,
  AlertCircle,
  Flag,
  Users,
  TrendingDown,
  Clock,
  DollarSign,
} from 'lucide-react';
import KYCVerificationTab from './admin/KYCVerificationTab';
import DisputeResolutionTab from './admin/DisputeResolutionTab';
import ReviewModerationTab from './admin/ReviewModerationTab';
import ContentFlagTab from './admin/ContentFlagTab';
import AnalyticsTab from './admin/AnalyticsTab';

type AdminTab = 'overview' | 'kyc' | 'disputes' | 'reviews' | 'flags' | 'analytics';

interface AdminDashboardProps {
  isOpen?: boolean;
  onClose?: () => void;
}

export const AdminDashboard: React.FC<AdminDashboardProps> = ({
  isOpen = true,
  onClose,
}) => {
  const [activeTab, setActiveTab] = useState<AdminTab>('overview');
  const { data: stats, isLoading } = useAdminStats();

  if (!isOpen) return null;

  const StatCard = ({
    icon: Icon,
    label,
    value,
    onChange,
    color,
  }: {
    icon: React.ReactNode;
    label: string;
    value: number;
    onChange?: number;
    color: string;
  }) => (
    <div className="bg-white rounded-lg shadow p-4">
      <div className="flex justify-between items-start">
        <div>
          <p className="text-gray-600 text-sm">{label}</p>
          <p className="text-2xl font-bold mt-1">{value}</p>
          {onChange !== undefined && (
            <p
              className={`text-xs mt-1 ${
                onChange >= 0 ? 'text-green-600' : 'text-red-600'
              }`}
            >
              {onChange >= 0 ? '+' : ''}{onChange}% from yesterday
            </p>
          )}
        </div>
        <div className={`${color} p-3 rounded-lg text-white`}>{Icon}</div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold">Admin Dashboard</h1>
              <p className="text-gray-600 text-sm">Platform management & analytics</p>
            </div>
            {onClose && (
              <button
                onClick={onClose}
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 rounded-lg border"
              >
                Close
              </button>
            )}
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        {/* Quick Stats */}
        {activeTab === 'overview' && stats && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard
                icon={<Users size={20} />}
                label="Total Users"
                value={stats.total_users}
                color="bg-blue-500"
              />
              <StatCard
                icon={<BarChart3 size={20} />}
                label="Total Listings"
                value={stats.total_listings}
                color="bg-green-500"
              />
              <StatCard
                icon={<DollarSign size={20} />}
                label="Revenue Today"
                value={Math.floor(stats.revenue_today)}
                color="bg-purple-500"
              />
              <StatCard
                icon={<Clock size={20} />}
                label="Avg Response (min)"
                value={Math.floor(stats.avg_response_time)}
                color="bg-orange-500"
              />
            </div>

            {/* Priority Alerts */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <div className="flex items-center gap-2">
                  <AlertCircle className="text-red-600" size={20} />
                  <span className="font-semibold text-red-900">
                    {stats.pending_disputes} Open Disputes
                  </span>
                </div>
                <p className="text-sm text-red-700 mt-2">
                  Requires immediate attention
                </p>
              </div>

              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                <div className="flex items-center gap-2">
                  <Flag className="text-yellow-600" size={20} />
                  <span className="font-semibold text-yellow-900">
                    {stats.flagged_content} Flagged Content
                  </span>
                </div>
                <p className="text-sm text-yellow-700 mt-2">
                  Awaiting moderation review
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Tab Navigation */}
        <div className="mt-8 border-b border-gray-200">
          <div className="grid grid-cols-3 md:grid-cols-6 gap-2">
            {[
              { id: 'kyc', label: 'KYC', icon: Shield, count: stats?.pending_kyc },
              { id: 'disputes', label: 'Disputes', icon: AlertCircle, count: stats?.pending_disputes },
              { id: 'reviews', label: 'Reviews', icon: FileText, count: stats?.pending_reviews },
              { id: 'flags', label: 'Flags', icon: Flag, count: stats?.flagged_content },
              { id: 'analytics', label: 'Analytics', icon: BarChart3, count: undefined },
            ].map((tab) => {
              const TabIcon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as AdminTab)}
                  className={`px-4 py-3 border-b-2 font-medium flex items-center gap-2 transition-colors ${
                    activeTab === tab.id
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-600 hover:text-gray-900'
                  }`}
                >
                  <TabIcon size={18} />
                  <span className="hidden sm:inline">{tab.label}</span>
                  {tab.count !== undefined && tab.count > 0 && (
                    <span className="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">
                      {tab.count}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Tab Content */}
        <div className="mt-6 bg-white rounded-lg shadow p-6">
          {activeTab === 'kyc' && <KYCVerificationTab />}
          {activeTab === 'disputes' && <DisputeResolutionTab />}
          {activeTab === 'reviews' && <ReviewModerationTab />}
          {activeTab === 'flags' && <ContentFlagTab />}
          {activeTab === 'analytics' && <AnalyticsTab />}
        </div>
      </div>
    </div>
  );
};
