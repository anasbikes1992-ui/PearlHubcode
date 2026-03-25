// src/components/admin/AnalyticsTab.tsx - Analytics and reporting
import React from 'react';
import { TrendingUp, Users, DollarSign, Calendar } from 'lucide-react';

const AnalyticsTab: React.FC = () => {
  // Placeholder for analytics data
  const metrics = [
    { label: 'Daily Revenue', value: '$12,450', change: '+5%', icon: DollarSign },
    { label: 'New Users', value: '324', change: '+12%', icon: Users },
    { label: 'Bookings Today', value: '87', change: '+3%', icon: Calendar },
    { label: 'Avg Rating', value: '4.7/5', change: '+0.2', icon: TrendingUp },
  ];

  return (
    <div className="space-y-6">
      {/* Metrics Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {metrics.map((metric) => {
          const Icon = metric.icon;
          return (
            <div key={metric.label} className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-lg p-4 border border-blue-200">
              <div className="flex justify-between items-start mb-2">
                <span className="text-gray-600 text-sm font-medium">{metric.label}</span>
                <Icon size={18} className="text-blue-600" />
              </div>
              <p className="text-2xl font-bold text-gray-900 mb-1">{metric.value}</p>
              <p className="text-xs text-green-600 font-medium">{metric.change} from yesterday</p>
            </div>
          );
        })}
      </div>

      {/* Charts Placeholder */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="border rounded-lg p-4">
          <h3 className="font-semibold mb-4">Revenue Trend (7 days)</h3>
          <div className="h-48 bg-gray-50 rounded flex items-center justify-center text-gray-400">
            [Chart: Revenue over time]
          </div>
        </div>

        <div className="border rounded-lg p-4">
          <h3 className="font-semibold mb-4">Booking Status Distribution</h3>
          <div className="h-48 bg-gray-50 rounded flex items-center justify-center text-gray-400">
            [Chart: Pie chart - Completed/Pending/Cancelled]
          </div>
        </div>
      </div>

      {/* Top Listings */}
      <div className="border rounded-lg p-4">
        <h3 className="font-semibold mb-4">Top Performing Listings</h3>
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="flex justify-between items-center p-2 hover:bg-gray-50 rounded">
              <span className="text-sm">Listing {i + 1}</span>
              <span className="font-semibold">{Math.floor(Math.random() * 50) + 10} bookings</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default AnalyticsTab;
