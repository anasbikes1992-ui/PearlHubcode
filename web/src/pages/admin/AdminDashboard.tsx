import { useState, useEffect } from 'react';
import { useAuth } from '@/context/AuthContext';
import { supabase, db } from '@/integrations/supabase/client';
import { Navigate } from 'react-router-dom';
import { useStore } from '@/store/useStore';
import { fetchAdminMetrics, resolveUserReport, type AdminMetrics } from '@/lib/admin-control';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { formatPrice, timeAgo, obfuscateEmail } from '@/lib/utils';
import { ListingStatus, type Stay, type PearlEvent, type Property, type SocialPost, type SMEBusiness } from '@/types';
import { motion, AnimatePresence } from 'framer-motion';
import { ShieldCheck } from 'lucide-react';

type AdminTab = 'overview' | 'gods_view' | 'stays' | 'vehicles' | 'taxi' | 'events' | 'properties' | 'social' | 'sme' | 'users' | 'finance' | 'coupons' | 'alerts' | 'ops' | 'pages' | 'settings';

const StatusBadge = ({ status }: { status: ListingStatus }) => {
  const variants: Record<ListingStatus, string> = {
    active: 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20',
    paused: 'bg-amber-500/10 text-amber-500 border-amber-500/20',
    off: 'bg-ruby/10 text-ruby border-ruby/20',
    pending: 'bg-sapphire/10 text-sapphire border-sapphire/20',
    rejected: 'bg-mist/10 text-mist border-mist/20',
  };
  return <Badge variant="outline" className={`uppercase text-[10px] font-black tracking-widest ${variants[status]}`}>{status}</Badge>;
};

// ── Status control modal ──────────────────────
function StatusControlModal({
  open, onClose, itemName, currentStatus, onSave,
}: {
  open: boolean; onClose: () => void; itemName: string;
  currentStatus: ListingStatus; onSave: (status: ListingStatus, note: string) => void;
}) {
  const [status, setStatus] = useState<ListingStatus>(currentStatus);
  const [note, setNote] = useState('');

  const statusColors: Record<ListingStatus, string> = {
    active: 'border-emerald-500 bg-emerald-500/5',
    paused: 'border-amber-500 bg-amber-500/5',
    off: 'border-ruby bg-ruby/5', // using off as rejected/ruby
    pending: 'border-sapphire bg-sapphire/5',
    rejected: 'border-mist bg-mist/5',
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md bg-zinc-950 border-white/10 text-white rounded-[2.5rem] p-10">
        <DialogHeader>
          <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center text-primary mb-4 border border-primary/20 shadow-lg shadow-primary/10">
            <ShieldCheck size={24} />
          </div>
          <DialogTitle className="text-2xl font-black text-white tracking-tight">Security & Moderation Protocol</DialogTitle>
          <DialogDescription className="text-mist text-xs font-medium">Override architectural asset status for system integrity.</DialogDescription>
        </DialogHeader>
        <div className="space-y-6 py-4">
          <div className="p-6 bg-white/5 rounded-[2rem] border border-white/5 shadow-inner">
            <p className="text-sm font-black text-white tracking-tight truncate mb-1">{itemName}</p>
            <div className="flex items-center gap-2">
               <span className="text-[10px] text-mist/40 font-black uppercase tracking-widest italic">Current State:</span>
               <StatusBadge status={currentStatus} />
            </div>
          </div>

          <div className="grid grid-cols-1 gap-3">
            {(['active', 'paused', 'off'] as ListingStatus[]).map((s) => (
              <button
                key={s}
                onClick={() => setStatus(s)}
                className={`flex items-center justify-between p-5 rounded-2xl border-2 transition-all text-left group ${
                  status === s ? statusColors[s] : 'border-white/5 hover:border-white/10 bg-white/[0.02]'
                }`}
              >
                <div className="flex items-center gap-5">
                  <div className={`w-4 h-4 rounded-full border-4 border-zinc-950 ${
                    s === 'active' ? 'bg-emerald' : s === 'paused' ? 'bg-amber-500' : 'bg-ruby'
                  }`} />
                  <div>
                    <p className="font-black text-[11px] uppercase tracking-widest text-white group-hover:text-primary transition-colors">{s}</p>
                    <p className="text-[10px] text-mist/60 font-medium mt-0.5 max-w-[200px]">
                      {s === 'active' ? 'Publicly visible and indexed for discovery.' :
                        s === 'paused' ? 'Temporarily hidden from search and maps.' :
                        'Deactivated and locked from all transactions.'}
                    </p>
                  </div>
                </div>
              </button>
            ))}
          </div>

          <div className="space-y-2">
            <label className="text-[11px] font-black text-mist uppercase tracking-[0.2em] ml-2">Administrative Justification</label>
            <Textarea
              placeholder="Provide narrative for state transition..."
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="bg-white/5 border-white/10 focus:ring-primary/20 text-white min-h-[100px] rounded-2xl p-4 text-xs font-medium placeholder:text-mist/20"
            />
          </div>

          <div className="flex gap-4 pt-4">
            <Button variant="ghost" onClick={onClose} className="flex-1 rounded-2xl h-14 border border-white/5 text-mist/60 hover:text-white uppercase text-[10px] font-black tracking-widest">Abort</Button>
            <Button onClick={() => { onSave(status, note); onClose() }} className="flex-1 rounded-2xl h-14 bg-primary hover:bg-gold-light text-primary-foreground font-black uppercase text-[10px] tracking-widest shadow-xl shadow-primary/20">
              Apply Protocol
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

// ── Admin Table Row ───────────────────────────
function AdminTableRow({
  id, title, location, price, status, createdAt, providerLabel,
  onStatusChange, onDelete,
}: {
  id: string; title: string; location?: string; price?: string;
  status: ListingStatus; createdAt: string; providerLabel: string;
  onStatusChange: (id: string, status: ListingStatus, note: string) => void;
  onDelete: (id: string) => void;
}) {
  const [modal, setModal] = useState(false);

  return (
    <tr className="hover:bg-white/5 transition-colors border-b border-white/5 group">
      <td className="px-6 py-4">
        <p className="font-bold text-sm text-pearl max-w-[200px] truncate group-hover:text-primary transition-colors">{title}</p>
        {location && <p className="text-[11px] text-mist mt-0.5 font-medium">📍 {location}</p>}
      </td>
      <td className="px-6 py-4 text-[11px] text-mist font-bold uppercase tracking-tight">{providerLabel}</td>
      <td className="px-6 py-4">{price && <span className="text-sm font-black text-primary">{price}</span>}</td>
      <td className="px-6 py-4"><StatusBadge status={status} /></td>
      <td className="px-6 py-4 text-[11px] text-mist/60 font-medium">{timeAgo(createdAt)}</td>
      <td className="px-6 py-4">
        <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <Button
            size="sm"
            onClick={() => setModal(true)}
            className="h-8 px-4 rounded-lg bg-primary/10 text-primary hover:bg-primary text-[11px] font-black uppercase tracking-wider hover:text-white"
          >
            Manage
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={() => { if (confirm('Delete this listing?')) onDelete(id) }}
            className="h-8 rounded-lg text-ruby hover:bg-ruby/10 p-2"
          >
            🗑️
          </Button>
        </div>
        <StatusControlModal
          open={modal}
          onClose={() => setModal(false)}
          itemName={title}
          currentStatus={status}
          onSave={(s, n) => onStatusChange(id, s, n)}
        />
      </td>
    </tr>
  );
}




// ── Main Admin Dashboard ──────────────────────
export default function AdminDashboard() {
  const {
    currentUser, userRole,
    stays, vehicles, events, properties, socialPosts, smeBusinesses,
    updateStay, updateVehicle, updateEvent, updateProperty, updateSocialPost, updateSMEBusiness,
    deleteStay, deleteVehicle, deleteEvent, deleteProperty, deleteSocialPost,
    users, updateUserBadges,
    globalSettings, updateGlobalSettings
  } = useStore();

  const [reports, setReports] = useState<any[]>([]);
  const [metrics, setMetrics] = useState<AdminMetrics | null>(null);
  const [metricsLoading, setMetricsLoading] = useState(false);
  const [tab, setTab] = useState<AdminTab>('overview');

  useEffect(() => {
    if (userRole !== 'admin') return;

    setMetricsLoading(true);
    Promise.all([
      db.from('user_reports').select('*').in('status', ['pending', 'investigating']).order('created_at', { ascending: false }),
      fetchAdminMetrics(30),
    ])
      .then(([reportsRes, metricsRes]) => {
        setReports(reportsRes.data || []);
        setMetrics(metricsRes);
      })
      .catch((err) => {
        console.error('Admin dashboard load error:', err);
      })
      .finally(() => setMetricsLoading(false));
  }, [userRole]);

  const { profile } = useAuth();
  // Double-check: verify real Supabase profile role, not just Zustand state
  const isRealAdmin = profile?.role === 'admin';
  if (!isRealAdmin) return <Navigate to="/" replace />;

  const stats = {
    stays: stays.length,
    vehicles: vehicles.length,
    events: events.length,
    properties: properties.length,
    social: socialPosts.length,
    sme: smeBusinesses.length,
    pending: [
      ...stays, ...vehicles, ...events,
      ...properties, ...smeBusinesses,
    ].filter((x: any) => x.status === 'pending').length,
  };

  const TABS: { id: AdminTab; label: string; icon: string; count?: number }[] = [
    { id: 'overview', label: 'Overview', icon: '📊' },
    { id: 'gods_view', label: "God's View", icon: '🗺️' },
    { id: 'stays', label: 'Stays', icon: '🏨', count: stats.stays },
    { id: 'vehicles', label: 'Vehicles', icon: '🚗', count: stats.vehicles },
    { id: 'taxi', label: 'Taxi', icon: '🚕' },
    { id: 'events', label: 'Events', icon: '🎭', count: stats.events },
    { id: 'properties', label: 'Props', icon: '🏡', count: stats.properties },
    { id: 'social', label: 'Social', icon: '🌏', count: stats.social },
    { id: 'sme', label: 'SMEs', icon: '🛍️', count: stats.sme },
    { id: 'users', label: 'Users', icon: '👥' },
    { id: 'finance', label: 'Finance', icon: '💰' },
    { id: 'coupons', label: 'Coupons', icon: '🏷️' },
    { id: 'alerts', label: 'Alerts', icon: '🚩', count: reports.length },
    { id: 'ops', label: 'Ops Audit', icon: '📋' },
    { id: 'pages', label: 'Pages / CMS', icon: '📝' },
    { id: 'settings', label: 'Settings', icon: '⚙️' },
  ];

  return (
    <div className="min-h-screen bg-obsidian">
      {/* Header */}
      <div className="bg-primary/10 border-b border-primary/20 backdrop-blur-md sticky top-16 z-40">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-primary/20 flex items-center justify-center text-3xl shadow-lg border border-primary/20">🛡️</div>
            <div>
              <h1 className="text-2xl font-black text-pearl tracking-tight">Admin Control Panel</h1>
              <p className="text-mist text-xs font-bold uppercase tracking-[0.2em] mt-1">Total System Management · Sri Lanka</p>
            </div>
            {stats.pending > 0 && (
              <div className="ml-auto bg-ruby text-white text-[10px] font-black px-4 py-2 rounded-full shadow-lg shadow-ruby/20 flex items-center gap-2 animate-pulse uppercase tracking-wider">
                <span className="w-1.5 h-1.5 rounded-full bg-white" /> {stats.pending} Needs Review
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 py-10">
        {/* Tabs */}
        <div className="flex gap-2 bg-white/5 rounded-2xl p-1.5 border border-white/10 shadow-inner mb-10 overflow-x-auto no-scrollbar">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={`flex-shrink-0 flex items-center gap-2 px-6 py-2.5 rounded-xl text-xs font-black transition-all uppercase tracking-widest ${
                tab === t.id ? 'bg-primary text-white shadow-lg shadow-primary/20' : 'text-mist hover:text-pearl hover:bg-white/5'
              }`}
            >
              {t.icon} {t.label}
              {t.count !== undefined && (
                <span className={`ml-1 text-[10px] px-2 py-0.5 rounded-full ${
                  tab === t.id ? 'bg-white/20' : 'bg-white/5 text-mist/60'
                }`}>{t.count}</span>
              )}
            </button>
          ))}
        </div>

        {tab === 'gods_view' && (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
            <GodsViewPanel />
          </motion.div>
        )}

        {/* Overview */}
        {tab === 'overview' && (
          <div className="space-y-10">
            {metrics && (
              <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
                {[
                  { label: 'Users', value: metrics.users_total, icon: '👥', color: 'text-sapphire bg-sapphire/10' },
                  { label: 'Providers', value: metrics.providers_total, icon: '🧭', color: 'text-indigo-500 bg-indigo-500/10' },
                  { label: 'Bookings 30d', value: metrics.bookings_total, icon: '🧾', color: 'text-emerald-500 bg-emerald-500/10' },
                  { label: 'GMV LKR 30d', value: formatPrice(metrics.gmv_lkr_window, 'LKR'), icon: '💰', color: 'text-amber-500 bg-amber-500/10' },
                  { label: 'Open Reports', value: metrics.reports_open, icon: '🚩', color: 'text-ruby bg-ruby/10' },
                  { label: 'Open Rides', value: metrics.rides_open, icon: '🚕', color: 'text-teal-500 bg-teal-500/10' },
                ].map((stat) => (
                  <div key={stat.label} className={`rounded-2xl p-5 border border-white/10 group hover:border-white/20 transition-all ${stat.color}`}>
                    <div className="text-2xl mb-3 group-hover:scale-110 transition-transform">{stat.icon}</div>
                    <div className="text-lg font-black text-pearl truncate">{stat.value}</div>
                    <div className="text-[10px] font-black uppercase tracking-widest text-mist mt-1">{stat.label}</div>
                  </div>
                ))}
              </div>
            )}

            {!metrics && metricsLoading && (
              <div className="rounded-2xl border border-white/10 bg-white/5 px-6 py-4 text-xs font-black uppercase tracking-widest text-mist">
                Loading live admin metrics...
              </div>
            )}

            <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
              {[
                { label: 'Stays', value: stats.stays, icon: '🏨', color: 'text-emerald-500 bg-emerald-500/10' },
                { label: 'Vehicles', value: stats.vehicles, icon: '🚗', color: 'text-sapphire bg-sapphire/10' },
                { label: 'Events', value: stats.events, icon: '🎭', color: 'text-indigo-500 bg-indigo-500/10' },
                { label: 'Props', value: stats.properties, icon: '🏡', color: 'text-amber-500 bg-amber-500/10' },
                { label: 'Posts', value: stats.social, icon: '🌏', color: 'text-teal-500 bg-teal-500/10' },
                { label: 'SMEs', value: stats.sme, icon: '🛍️', color: 'text-orange-500 bg-orange-500/10' },
                { label: 'Pending', value: stats.pending, icon: '⏳', color: 'text-ruby bg-ruby/10' },
              ].map((stat) => (
                <div key={stat.label} className={`rounded-2xl p-5 border border-white/10 group hover:border-white/20 transition-all ${stat.color}`}>
                  <div className="text-3xl mb-3 group-hover:scale-110 transition-transform">{stat.icon}</div>
                  <div className="text-2xl font-black text-pearl">{stat.value}</div>
                  <div className="text-[10px] font-black uppercase tracking-widest text-mist mt-1">{stat.label}</div>
                </div>
              ))}
            </div>

            <div className="bg-white/5 rounded-3xl border border-white/10 p-8">
              <h2 className="font-black text-pearl text-lg mb-6 uppercase tracking-widest flex items-center gap-3">
                <span className="w-1.5 h-6 bg-primary rounded-full" /> Quick Actions
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {[
                  { label: 'Review Stays', icon: '🏨', action: () => setTab('stays') },
                  { label: 'Manage Fleet', icon: '🚗', action: () => setTab('vehicles') },
                  { label: 'Taxi Config', icon: '🚕', action: () => setTab('taxi') },
                  { label: 'Audit Events', icon: '🎭', action: () => setTab('events') },
                  { label: 'Property List', icon: '🏡', action: () => setTab('properties') },
                  { label: 'Social Mods', icon: '🌏', action: () => setTab('social') },
                  { label: 'SME Registry', icon: '🛍️', action: () => setTab('sme') },
                ].map((action) => (
                  <button
                    key={action.label}
                    onClick={action.action}
                    className="flex items-center gap-4 p-5 rounded-2xl bg-white/5 border border-white/10 hover:border-primary/50 hover:bg-primary/5 transition-all text-left"
                  >
                    <span className="text-2xl">{action.icon}</span>
                    <span className="text-xs font-black uppercase tracking-widest text-pearl">{action.label}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Stays Enhanced */}
        {tab === 'stays' && (
          <StaysEnhancedPanel
            stays={stays}
            onStatusChange={(id, status, note) => updateStay(id, { status, admin_note: note })}
            onDelete={deleteStay}
          />
        )}

        {/* Taxi Config Tab - Advanced Vehicle Management */}
        {tab === 'taxi' && (
          <AdvancedVehicleManager />
        )}

        {/* Events Enhanced */}
        {tab === 'events' && (
          <EventsEnhancedPanel
            events={events}
            onStatusChange={(id, status, note) => updateEvent(id, { status, admin_note: note })}
            onDelete={deleteEvent}
          />
        )}

        {/* Properties Enhanced */}
        {tab === 'properties' && (
          <PropertiesEnhancedPanel
            properties={properties}
            onStatusChange={(id, status, note) => updateProperty(id, { status, admin_note: note })}
            onDelete={deleteProperty}
          />
        )}

        {/* Social Enhanced */}
        {tab === 'social' && (
          <SocialEnhancedPanel
            posts={socialPosts}
            onStatusChange={(id, status) => updateSocialPost(id, { status })}
            onDelete={deleteSocialPost}
          />
        )}

        {/* SME Enhanced */}
        {tab === 'sme' && (
          <SmeEnhancedPanel
            businesses={smeBusinesses}
            onStatusChange={(id, status, note) => updateSMEBusiness(id, { status, admin_note: note })}
            onDelete={() => {}}
          />
        )}

        {/* Users — Customer & Provider 360° */}
        {tab === 'users' && (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
            <UsersPanel360 />
          </motion.div>
        )}

        {/* Alerts Table (formerly Reports) */}
        {tab === 'alerts' && (
          <div className="bg-white/5 rounded-[2.5rem] border border-white/10 p-10">
            <h3 className="text-xl font-black text-white mb-8 tracking-tight uppercase tracking-widest">Active System Reports</h3>
            <div className="space-y-4">
              {reports.map((r) => (
                <div key={r.id} className="p-6 bg-white/[0.02] border border-white/5 rounded-3xl flex justify-between items-center group hover:bg-white/5 transition-all">
                  <div>
                    <div className="flex items-center gap-3 mb-1">
                      <span className="text-[10px] font-black uppercase tracking-widest text-ruby bg-ruby/10 px-2 py-0.5 rounded-full">{r.type}</span>
                      <span className="text-xs font-bold text-white italic">ID: {r.listing_id}</span>
                    </div>
                    <p className="text-sm text-mist/80 font-medium">{r.reason || r.description}</p>
                    <p className="text-[10px] text-mist/40 mt-1 font-black uppercase tracking-widest italic">{timeAgo(r.created_at)}</p>
                  </div>
                  <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Button
                      size="sm"
                      variant="ghost"
                      className="rounded-xl text-emerald hover:bg-emerald/10 uppercase text-[9px] font-black tracking-widest group-hover:text-white"
                      onClick={async () => {
                        try {
                          await resolveUserReport({ reportId: r.id, status: 'resolved', adminNote: 'Resolved from Admin Dashboard' });
                          setReports((prev) => prev.filter((item) => item.id !== r.id));
                        } catch (err) {
                          console.error('Failed to resolve report:', err);
                        }
                      }}
                    >
                      Resolve
                    </Button>
                    <Button size="sm" variant="ghost" className="rounded-xl text-ruby hover:bg-ruby/10 uppercase text-[9px] font-black tracking-widest group-hover:text-white">Block Asset</Button>
                  </div>
                </div>
              ))}
              {reports.length === 0 && <div className="text-center py-20 text-mist/20 font-black uppercase tracking-[0.3em]">No security alerts</div>}
            </div>
          </div>
        )}

        {tab === 'ops' && (
          <motion.div initial={{ opacity: 0, scale: 0.98 }} animate={{ opacity: 1, scale: 1 }}>
             <OpsDashboard />
          </motion.div>
        )}

        {tab === 'finance' && (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
            <FinancePanel />
          </motion.div>
        )}

        {tab === 'coupons' && (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
            <CouponsPanel />
          </motion.div>
        )}

        {tab === 'pages' && (
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
            <PagesPanel />
          </motion.div>
        )}

        {tab === 'settings' && (
          <motion.div
            key="settings"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            transition={{ duration: 0.3 }}
          >
            <SupabaseSettingsPanel />
          </motion.div>
        )}
      </div>
    </div>
  );
}

// ── Generic Admin Table ───────────────────────
function AdminTable({ title, rows, onStatusChange, onDelete }: {
  title: string
  rows: {
    id: string; title: string; location?: string; price?: string;
    status: ListingStatus; createdAt: string; providerLabel: string;
  }[]
  onStatusChange: (id: string, status: ListingStatus, note: string) => void
  onDelete: (id: string) => void
}) {
  const [filter, setFilter] = useState<ListingStatus | ''>('');
  const filtered = filter ? rows.filter((r) => r.status === filter) : rows;

  return (
    <div className="bg-white/5 rounded-3xl border border-white/10 shadow-xl overflow-hidden">
      <div className="flex items-center justify-between px-8 py-6 border-b border-white/5 bg-white/[0.02]">
        <h2 className="font-black text-pearl text-base uppercase tracking-widest">{title}</h2>
        <div className="flex gap-4">
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value as ListingStatus | '')}
            className="bg-obsidian border border-white/10 text-mist text-[11px] font-black uppercase tracking-wider px-4 py-2 rounded-xl outline-none focus:border-primary/50"
          >
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="pending">Pending</option>
            <option value="paused">Paused</option>
            <option value="off">Off</option>
          </select>
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-left">
          <thead>
            <tr className="bg-white/[0.01] border-b border-white/5">
              <th className="px-8 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Listing Details</th>
              <th className="px-8 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Type</th>
              <th className="px-8 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Price</th>
              <th className="px-8 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Status</th>
              <th className="px-8 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Listed</th>
              <th className="px-8 py-4 text-[10px] font-black text-mist uppercase tracking-widest text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {filtered.length === 0 ? (
              <tr><td colSpan={6} className="px-8 py-20 text-center text-mist text-xs italic">No listings match the current filters</td></tr>
            ) : filtered.map((row) => (
              <AdminTableRow
                key={row.id}
                {...row}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function InsightCard({ label, value, icon }: { label: string; value: string | number; icon: string }) {
  return (
    <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
      <div className="text-2xl">{icon}</div>
      <div className="mt-2 text-xl font-black text-pearl">{value}</div>
      <div className="text-[10px] font-black uppercase tracking-widest text-mist mt-1">{label}</div>
    </div>
  );
}

function RecoStrip({ title, items }: { title: string; items: string[] }) {
  return (
    <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
      <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">{title}</h3>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-2">
        {items.map((item) => (
          <div key={item} className="text-[11px] text-mist bg-white/[0.03] rounded-xl px-3 py-2 border border-white/5">{item}</div>
        ))}
      </div>
    </div>
  );
}

function StaysEnhancedPanel({
  stays,
  onStatusChange,
  onDelete,
}: {
  stays: Stay[];
  onStatusChange: (id: string, status: ListingStatus, note: string) => void;
  onDelete: (id: string) => void;
}) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | ListingStatus>('all');
  const [priceFilter, setPriceFilter] = useState<'all' | 'budget' | 'mid' | 'luxury'>('all');

  const getViews = (stay: Stay) => {
    const raw = (stay as unknown as Record<string, unknown>).views;
    if (typeof raw === 'number') return raw;
    return (stay.review_count || 0) * 120 + Math.round((stay.rating || 0) * 75);
  };

  const withViews = stays.map((s) => ({ stay: s, views: getViews(s) }));
  const topPerformers = withViews.slice().sort((a, b) => b.views - a.views).slice(0, 3);

  const filteredStays = stays.filter((s) => {
    const bySearch = search.trim().length === 0
      || s.name.toLowerCase().includes(search.toLowerCase())
      || s.location.toLowerCase().includes(search.toLowerCase());
    const byStatus = statusFilter === 'all' || s.status === statusFilter;
    const byPrice =
      priceFilter === 'all'
      || (priceFilter === 'budget' && s.price_per_night < 5000)
      || (priceFilter === 'mid' && s.price_per_night >= 5000 && s.price_per_night < 15000)
      || (priceFilter === 'luxury' && s.price_per_night >= 15000);
    return bySearch && byStatus && byPrice;
  });

  const avgNight = Math.round(stays.reduce((sum, s) => sum + (s.price_per_night || 0), 0) / Math.max(stays.length, 1));
  const topRated = stays.slice().sort((a, b) => (b.rating || 0) - (a.rating || 0))[0];
  const activeCount = stays.filter((s) => s.status === 'active').length;
  const pendingCount = stays.filter((s) => s.status === 'pending').length;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <InsightCard label="Total Stays" value={stays.length} icon="🏨" />
        <InsightCard label="Active" value={activeCount} icon="✅" />
        <InsightCard label="Pending" value={pendingCount} icon="⏳" />
        <InsightCard label="Avg Nightly" value={`Rs. ${avgNight.toLocaleString()}`} icon="💰" />
        <InsightCard label="Top Rating" value={topRated ? topRated.rating.toFixed(1) : '0.0'} icon="⭐" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {topPerformers.map(({ stay, views }, index) => (
          <div key={stay.id} className="bg-white/5 rounded-2xl border border-white/10 p-5 hover:border-primary/50 transition-all">
            <div className="flex items-start justify-between">
              <div>
                <div className="text-[10px] font-black uppercase tracking-widest text-primary">Top Performer #{index + 1}</div>
                <div className="text-sm font-black text-pearl mt-1">{stay.name}</div>
                <div className="text-[11px] text-mist mt-1">📍 {stay.location}</div>
              </div>
              <Badge className="bg-sapphire/15 text-sapphire border border-sapphire/20">{views.toLocaleString()} views</Badge>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search stays by title or location"
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl placeholder:text-mist/50"
        />
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'all' | ListingStatus)}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Statuses</option>
          <option value="active">Active</option>
          <option value="pending">Pending</option>
          <option value="paused">Paused</option>
          <option value="off">Off</option>
          <option value="rejected">Rejected</option>
        </select>
        <select
          value={priceFilter}
          onChange={(e) => setPriceFilter(e.target.value as 'all' | 'budget' | 'mid' | 'luxury')}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Price Ranges</option>
          <option value="budget">Budget (&lt; 5,000)</option>
          <option value="mid">Mid (5,000 - 14,999)</option>
          <option value="luxury">Luxury (15,000+)</option>
        </select>
      </div>

      <RecoStrip
        title="Recommendations"
        items={[
          'Photo quality: enforce at least 8 high-res images for trust uplift',
          'Price optimization: apply weekend and seasonal price bands',
          'Review focus: auto-prioritize low-rated stays for admin quality checks',
        ]}
      />
      <AdminTable
        title="Hospitality Management"
        rows={filteredStays.map((s) => ({
          id: s.id,
          title: s.name,
          location: s.location,
          price: formatPrice(s.price_per_night, s.currency) + '/nt',
          status: s.status,
          createdAt: s.created_at,
          providerLabel: `${s.stars || 0}★ · ${s.max_guests || 0} guests · ${getViews(s).toLocaleString()} views`,
        }))}
        onStatusChange={onStatusChange}
        onDelete={onDelete}
      />
    </div>
  );
}

function EventsEnhancedPanel({
  events,
  onStatusChange,
  onDelete,
}: {
  events: PearlEvent[];
  onStatusChange: (id: string, status: ListingStatus, note: string) => void;
  onDelete: (id: string) => void;
}) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | ListingStatus>('all');
  const [categoryFilter, setCategoryFilter] = useState<'all' | PearlEvent['category']>('all');

  const now = new Date();
  const sortedUpcoming = events
    .filter((e) => new Date(e.date) >= now)
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  const topEvents = events
    .slice()
    .sort((a, b) => (b.tickets_sold || 0) - (a.tickets_sold || 0))
    .slice(0, 4);
  const maxSold = Math.max(1, ...events.map((e) => e.tickets_sold || 0));

  const sold = events.reduce((sum, e) => sum + (e.tickets_sold || 0), 0);
  const revenue = events.reduce((sum, e) => {
    const base = (Object.values(e.prices)[0] as number) || 0;
    return sum + base * (e.tickets_sold || 0);
  }, 0);
  const avgAttendance = Math.round(sold / Math.max(events.length, 1));
  const categories = Array.from(new Set(events.map((e) => e.category)));

  const filteredEvents = events.filter((e) => {
    const bySearch = search.trim().length === 0
      || e.title.toLowerCase().includes(search.toLowerCase())
      || e.venue.toLowerCase().includes(search.toLowerCase());
    const byStatus = statusFilter === 'all' || e.status === statusFilter;
    const byCategory = categoryFilter === 'all' || e.category === categoryFilter;
    return bySearch && byStatus && byCategory;
  });

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <InsightCard label="Total Events" value={events.length} icon="🎭" />
        <InsightCard label="Upcoming" value={sortedUpcoming.length} icon="📅" />
        <InsightCard label="Revenue" value={`Rs. ${revenue.toLocaleString()}`} icon="💰" />
        <InsightCard label="Avg Attendance" value={avgAttendance} icon="👥" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-4">Upcoming Events</h3>
          <div className="space-y-2">
            {sortedUpcoming.slice(0, 5).map((e) => (
              <div key={e.id} className="rounded-xl border border-white/5 bg-white/[0.02] p-3 flex items-center justify-between">
                <div>
                  <div className="text-sm font-black text-pearl">{e.title}</div>
                  <div className="text-[11px] text-mist">{new Date(e.date).toLocaleDateString()} · {e.venue}</div>
                </div>
                <Badge className="bg-emerald-500/15 text-emerald-500 border border-emerald-500/20">{e.tickets_sold || 0} sold</Badge>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-4">Top Events (Ticket Sales)</h3>
          <div className="space-y-3">
            {topEvents.map((e, idx) => {
              const pct = Math.round(((e.tickets_sold || 0) / maxSold) * 100);
              return (
                <div key={e.id}>
                  <div className="flex items-center justify-between text-[11px] mb-1">
                    <span className="text-pearl font-black">#{idx + 1} {e.title}</span>
                    <span className="text-mist">{e.tickets_sold || 0} tickets</span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-white/10 overflow-hidden">
                    <div className="h-2 bg-primary rounded-full" style={{ width: `${pct}%` }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search events by title or venue"
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl placeholder:text-mist/50"
        />
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'all' | ListingStatus)}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Statuses</option>
          <option value="active">Active</option>
          <option value="pending">Pending</option>
          <option value="paused">Paused</option>
          <option value="off">Off</option>
          <option value="rejected">Rejected</option>
        </select>
        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value as 'all' | PearlEvent['category'])}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Categories</option>
          {categories.map((cat) => (
            <option key={cat} value={cat}>{cat}</option>
          ))}
        </select>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filteredEvents.slice(0, 6).map((e) => {
          const basePrice = (Object.values(e.prices)[0] as number) || 0;
          const estRevenue = basePrice * (e.tickets_sold || 0);
          return (
            <div key={e.id} className="rounded-2xl bg-white/5 border border-white/10 p-4 hover:border-primary/40 transition-all">
              <div className="text-sm font-black text-pearl">{e.title}</div>
              <div className="text-[11px] text-mist mt-1">{new Date(e.date).toLocaleDateString()} · {e.venue}</div>
              <div className="mt-3 grid grid-cols-3 gap-2 text-[10px]">
                <div className="bg-white/[0.03] rounded-lg p-2 border border-white/5"><div className="text-mist">Tickets</div><div className="text-pearl font-black">{e.tickets_sold || 0}</div></div>
                <div className="bg-white/[0.03] rounded-lg p-2 border border-white/5"><div className="text-mist">Price</div><div className="text-pearl font-black">{formatPrice(basePrice, 'LKR')}</div></div>
                <div className="bg-white/[0.03] rounded-lg p-2 border border-white/5"><div className="text-mist">Revenue</div><div className="text-pearl font-black">Rs. {estRevenue.toLocaleString()}</div></div>
              </div>
            </div>
          );
        })}
      </div>

      <RecoStrip
        title="Recommendations"
        items={[
          'Ticket pricing: adjust per tier based on seat-fill velocity',
          'Venue management: enforce capacity and safety checkpoints',
          'Capacity planning: recommend extra slots for high-demand categories',
        ]}
      />
      <AdminTable
        title="Entertainment & Events"
        rows={filteredEvents.map((e) => ({
          id: e.id,
          title: e.title,
          location: e.venue,
          price: formatPrice((Object.values(e.prices)[0] as number) || 0, 'LKR'),
          status: e.status,
          createdAt: e.created_at,
          providerLabel: `${e.category} · sold ${e.tickets_sold || 0}`,
        }))}
        onStatusChange={onStatusChange}
        onDelete={onDelete}
      />
    </div>
  );
}

function PropertiesEnhancedPanel({
  properties,
  onStatusChange,
  onDelete,
}: {
  properties: Property[];
  onStatusChange: (id: string, status: ListingStatus, note: string) => void;
  onDelete: (id: string) => void;
}) {
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState<'all' | 'sale' | 'rent'>('all');
  const [sortBy, setSortBy] = useState<'newest' | 'high' | 'low'>('newest');

  const getInquiries = (p: Property) => {
    const raw = (p as unknown as Record<string, unknown>).inquiries;
    if (typeof raw === 'number') return raw;
    return Math.round((p.views || 0) * 0.22);
  };

  const mostInquired = properties.slice().sort((a, b) => getInquiries(b) - getInquiries(a)).slice(0, 3);
  const recentlyAdded = properties.slice().sort((a, b) => new Date(b.listed).getTime() - new Date(a.listed).getTime()).slice(0, 3);

  const filteredProperties = properties
    .filter((p) => {
      const bySearch = search.trim().length === 0
        || p.title.toLowerCase().includes(search.toLowerCase())
        || p.location.toLowerCase().includes(search.toLowerCase());
      const byType = typeFilter === 'all' || p.listing_type === typeFilter;
      return bySearch && byType;
    })
    .sort((a, b) => {
      if (sortBy === 'high') return b.price - a.price;
      if (sortBy === 'low') return a.price - b.price;
      return new Date(b.listed).getTime() - new Date(a.listed).getTime();
    });

  const avgPrice = Math.round(properties.reduce((sum, p) => sum + (p.price || 0), 0) / Math.max(properties.length, 1));
  const forSale = properties.filter((p) => p.listing_type === 'sale').length;
  const forRent = properties.filter((p) => p.listing_type === 'rent').length;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <InsightCard label="Total Properties" value={properties.length} icon="🏡" />
        <InsightCard label="Sale" value={forSale} icon="🏷️" />
        <InsightCard label="Rent" value={forRent} icon="🔑" />
        <InsightCard label="Avg Value" value={`Rs. ${avgPrice.toLocaleString()}`} icon="📈" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Most Inquired</h3>
          <div className="space-y-2">
            {mostInquired.map((p, idx) => (
              <div key={p.id} className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2 flex items-center justify-between">
                <div>
                  <div className="text-sm font-black text-pearl">#{idx + 1} {p.title}</div>
                  <div className="text-[11px] text-mist">{p.location}</div>
                </div>
                <Badge className="bg-amber-500/15 text-amber-500 border border-amber-500/20">{getInquiries(p)} inquiries</Badge>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Recently Added</h3>
          <div className="space-y-2">
            {recentlyAdded.map((p) => (
              <div key={p.id} className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2 flex items-center justify-between">
                <div>
                  <div className="text-sm font-black text-pearl">{p.title}</div>
                  <div className="text-[11px] text-mist">Listed {timeAgo(p.listed)}</div>
                </div>
                <span className="text-[11px] font-black text-primary">{formatPrice(p.price, p.currency)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search properties by title or location"
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl placeholder:text-mist/50"
        />
        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value as 'all' | 'sale' | 'rent')}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Types</option>
          <option value="sale">Sale</option>
          <option value="rent">Rent</option>
        </select>
        <select
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value as 'newest' | 'high' | 'low')}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="newest">Sort: Newest</option>
          <option value="high">Sort: High Price</option>
          <option value="low">Sort: Low Price</option>
        </select>
      </div>

      <RecoStrip
        title="Recommendations"
        items={[
          'Market positioning: compare pricing by neighborhood and type',
          'Photo galleries: enforce full-room and exterior image sets',
          'Price adjustments: highlight stale listings for strategic re-pricing',
        ]}
      />
      <AdminTable
        title="Real Estate Inventory"
        rows={filteredProperties.map((p) => ({
          id: p.id,
          title: p.title,
          location: p.location,
          price: formatPrice(p.price, p.currency),
          status: p.status,
          createdAt: p.listed,
          providerLabel: `${p.listing_type.toUpperCase()} · ${p.property_type}`,
        }))}
        onStatusChange={onStatusChange}
        onDelete={onDelete}
      />
    </div>
  );
}

function SocialEnhancedPanel({
  posts,
  onStatusChange,
  onDelete,
}: {
  posts: SocialPost[];
  onStatusChange: (id: string, status: ListingStatus, note: string) => void;
  onDelete: (id: string) => void;
}) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | ListingStatus>('all');
  const [reportedOnly, setReportedOnly] = useState(false);

  const getReports = (p: SocialPost) => {
    const raw = (p as unknown as Record<string, unknown>).reports;
    if (typeof raw === 'number') return raw;
    return p.status === 'rejected' || p.status === 'off' ? 1 : 0;
  };

  const trending = posts
    .slice()
    .sort((a, b) => ((b.likes || 0) + (b.comments_count || 0)) - ((a.likes || 0) + (a.comments_count || 0)))
    .slice(0, 5);

  const moderationQueue = posts
    .filter((p) => getReports(p) > 0)
    .sort((a, b) => getReports(b) - getReports(a))
    .slice(0, 5);

  const filteredPosts = posts.filter((p) => {
    const bySearch = search.trim().length === 0
      || p.content.toLowerCase().includes(search.toLowerCase())
      || (p.location || '').toLowerCase().includes(search.toLowerCase());
    const byStatus = statusFilter === 'all' || p.status === statusFilter;
    const byReports = !reportedOnly || getReports(p) > 0;
    return bySearch && byStatus && byReports;
  });

  const likes = posts.reduce((sum, p) => sum + (p.likes || 0), 0);
  const comments = posts.reduce((sum, p) => sum + (p.comments_count || 0), 0);
  const flagged = posts.filter((p) => getReports(p) > 0).length;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <InsightCard label="Total Posts" value={posts.length} icon="🌏" />
        <InsightCard label="Total Likes" value={likes} icon="❤️" />
        <InsightCard label="Comments" value={comments} icon="💬" />
        <InsightCard label="Flagged" value={flagged} icon="🚩" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Trending Posts</h3>
          <div className="space-y-2">
            {trending.map((p, idx) => (
              <div key={p.id} className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2">
                <div className="text-sm font-black text-pearl">#{idx + 1} {p.content.slice(0, 48)}...</div>
                <div className="text-[11px] text-mist mt-1">❤️ {p.likes || 0} · 💬 {p.comments_count || 0}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Moderation Queue</h3>
          <div className="space-y-2">
            {moderationQueue.length === 0 && (
              <div className="text-[11px] text-mist">No flagged posts right now.</div>
            )}
            {moderationQueue.map((p) => (
              <div key={p.id} className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2">
                <div className="text-sm font-black text-pearl">{p.content.slice(0, 52)}...</div>
                <div className="flex items-center justify-between mt-2">
                  <span className="text-[11px] text-ruby font-black">{getReports(p)} report(s)</span>
                  <div className="flex gap-2">
                    <button
                      onClick={() => onStatusChange(p.id, 'active', 'Approved by admin moderation queue')}
                      className="px-2 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider bg-emerald-500/15 text-emerald-500 border border-emerald-500/20"
                    >
                      Approve
                    </button>
                    <button
                      onClick={() => onStatusChange(p.id, 'off', 'Removed by admin moderation queue')}
                      className="px-2 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider bg-ruby/15 text-ruby border border-ruby/20"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search posts by content or location"
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl placeholder:text-mist/50"
        />
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'all' | ListingStatus)}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Statuses</option>
          <option value="active">Active</option>
          <option value="pending">Pending</option>
          <option value="paused">Paused</option>
          <option value="off">Off</option>
          <option value="rejected">Rejected</option>
        </select>
        <button
          onClick={() => setReportedOnly((v) => !v)}
          className={`h-10 rounded-xl border text-xs font-black uppercase tracking-widest transition-all ${
            reportedOnly
              ? 'bg-ruby/15 text-ruby border-ruby/30'
              : 'bg-obsidian text-mist border-white/10'
          }`}
        >
          {reportedOnly ? 'Reported Only: ON' : 'Reported Only: OFF'}
        </button>
      </div>

      <RecoStrip
        title="Recommendations"
        items={[
          'Content moderation: prioritize high-reach flagged posts first',
          'Community engagement: surface healthy high-interaction posts',
          'Spam detection: auto-score repeated low-value posting patterns',
        ]}
      />
      <AdminTable
        title="Community Moderation"
        rows={filteredPosts.map((p) => ({
          id: p.id,
          title: p.content.slice(0, 60) + '...',
          location: p.location || 'Unknown',
          status: p.status,
          createdAt: p.created_at,
          providerLabel: `likes ${p.likes || 0} · comments ${p.comments_count || 0}`,
        }))}
        onStatusChange={onStatusChange}
        onDelete={onDelete}
      />
    </div>
  );
}

function SmeEnhancedPanel({
  businesses,
  onStatusChange,
  onDelete,
}: {
  businesses: SMEBusiness[];
  onStatusChange: (id: string, status: ListingStatus, note: string) => void;
  onDelete: (id: string) => void;
}) {
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState<'all' | ListingStatus>('all');

  const estimateMonthlyRevenue = (b: SMEBusiness) => {
    const raw = (b as unknown as Record<string, unknown>).monthly_revenue;
    if (typeof raw === 'number') return raw;
    const products = Array.isArray(b.products) ? b.products : [];
    return products.reduce((sum, p) => sum + (p.price || 0) * Math.max(1, Math.floor((p.quantity_available || 0) * 0.2)), 0);
  };

  const topPerformers = businesses
    .slice()
    .sort((a, b) => estimateMonthlyRevenue(b) - estimateMonthlyRevenue(a))
    .slice(0, 3);

  const categoriesList = Array.from(new Set(businesses.map((b) => b.category))).sort();
  const filteredBusinesses = businesses.filter((b) => {
    const bySearch = search.trim().length === 0
      || b.business_name.toLowerCase().includes(search.toLowerCase())
      || b.location.toLowerCase().includes(search.toLowerCase());
    const byCategory = categoryFilter === 'all' || b.category === categoryFilter;
    const byStatus = statusFilter === 'all' || b.status === statusFilter;
    return bySearch && byCategory && byStatus;
  });

  const verified = businesses.filter((b) => b.verified).length;
  const active = businesses.filter((b) => b.status === 'active').length;
  const categories = new Set(businesses.map((b) => b.category)).size;
  const pending = businesses.filter((b) => b.status === 'pending').length;
  const monthlyRevenueTotal = businesses.reduce((sum, b) => sum + estimateMonthlyRevenue(b), 0);

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <InsightCard label="Total SMEs" value={businesses.length} icon="🛍️" />
        <InsightCard label="Active" value={active} icon="📦" />
        <InsightCard label="Pending" value={pending} icon="⏳" />
        <InsightCard label="Monthly Revenue" value={`Rs. ${monthlyRevenueTotal.toLocaleString()}`} icon="💵" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Top Performers</h3>
          <div className="space-y-2">
            {topPerformers.map((b, idx) => (
              <div key={b.id} className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2 flex items-center justify-between">
                <div>
                  <div className="text-sm font-black text-pearl">#{idx + 1} {b.business_name}</div>
                  <div className="text-[11px] text-mist">{b.category} · {b.location}</div>
                </div>
                <Badge className="bg-emerald-500/15 text-emerald-500 border border-emerald-500/20">Rs. {estimateMonthlyRevenue(b).toLocaleString()}/mo</Badge>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white/5 rounded-2xl border border-white/10 p-5">
          <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Growth Recommendations</h3>
          <div className="space-y-2 text-[11px] text-mist">
            <div className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2">Digital presence: improve profile completeness and image quality</div>
            <div className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2">Training programs: onboarding for pricing, packaging and customer response</div>
            <div className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2">Analytics dashboard: monitor conversion, repeat buyers, product velocity</div>
            <div className="rounded-xl bg-white/[0.03] border border-white/5 px-3 py-2">B2B networking: create bundles with stays, events and local logistics</div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search businesses by name or location"
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl placeholder:text-mist/50"
        />
        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Categories</option>
          {categoriesList.map((cat) => (
            <option key={cat} value={cat}>{cat}</option>
          ))}
        </select>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'all' | ListingStatus)}
          className="h-10 rounded-xl bg-obsidian border border-white/10 px-3 text-sm text-pearl"
        >
          <option value="all">All Statuses</option>
          <option value="active">Active</option>
          <option value="pending">Pending</option>
          <option value="paused">Paused</option>
          <option value="off">Off</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filteredBusinesses.slice(0, 9).map((b) => (
          <div key={b.id} className="rounded-2xl bg-white/5 border border-white/10 p-4 hover:border-primary/40 transition-all">
            <div className="flex items-center justify-between">
              <div className="text-sm font-black text-pearl">{b.business_name}</div>
              <StatusBadge status={b.status} />
            </div>
            <div className="text-[11px] text-mist mt-1">{b.category} · {b.location}</div>
            <div className="mt-3 text-[11px] text-mist">Revenue: <span className="text-pearl font-black">Rs. {estimateMonthlyRevenue(b).toLocaleString()}/mo</span></div>
            <div className="text-[11px] text-mist">Verified: <span className="text-pearl font-black">{b.verified ? 'Yes' : 'No'}</span></div>
          </div>
        ))}
      </div>

      <RecoStrip
        title="Recommendations"
        items={[
          'Digital presence improvements for discoverability',
          'Structured training programs for SME conversion uplift',
          'B2B networking to increase order consistency and scale',
        ]}
      />
      <AdminTable
        title="Local Business Registry"
        rows={filteredBusinesses.map((b) => ({
          id: b.id,
          title: b.business_name,
          location: b.location,
          status: b.status,
          createdAt: b.created_at,
          providerLabel: `${b.category} · ${b.verified ? 'verified' : 'unverified'} · Rs. ${estimateMonthlyRevenue(b).toLocaleString()}/mo`,
        }))}
        onStatusChange={onStatusChange}
        onDelete={onDelete}
      />
    </div>
  );
}

// ── Ops Dashboard ──────────────────────────────
function OpsDashboard() {
  return (
    <div className="space-y-8">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        {[
          { label: 'Total Revenue', value: 'Rs. 450K', icon: '💰' },
          { label: 'Total Rides', value: '1,240', icon: '🚕' },
          { label: 'Drivers Online', value: '85', icon: '🟢' },
          { label: 'Pending KYC', value: '12', icon: '📄' },
        ].map((stat) => (
          <div key={stat.label} className="bg-white/5 rounded-2xl border border-white/10 p-6 flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center text-2xl">{stat.icon}</div>
            <div>
              <div className="text-xl font-black text-pearl">{stat.value}</div>
              <div className="text-[10px] uppercase font-black tracking-widest text-mist">{stat.label}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Supabase Settings Panel ────────────────────
type PlatformCfg = {
  key: string;
  value: unknown;
  category: string;
  description: string;
  is_public: boolean;
};

type ConfigTemplate = {
  key: string;
  category: 'general' | 'taxi' | 'payments' | 'notifications' | 'limits' | 'fees';
  description: string;
  defaultValue: unknown;
  isPublic: boolean;
  min?: number;
  max?: number;
};

const CONFIG_BASELINE: ConfigTemplate[] = [
  { key: 'platform.name', category: 'general', description: 'Platform display name', defaultValue: 'Pearl Hub Pro', isPublic: true },
  { key: 'platform.country', category: 'general', description: 'ISO country code', defaultValue: 'LK', isPublic: true },
  { key: 'platform.currency', category: 'general', description: 'Primary currency', defaultValue: 'LKR', isPublic: true },
  { key: 'platform.timezone', category: 'general', description: 'Server timezone', defaultValue: 'Asia/Colombo', isPublic: true },
  { key: 'platform.support_email', category: 'general', description: 'Public support email', defaultValue: 'support@pearlhub.lk', isPublic: true },
  { key: 'platform.support_whatsapp', category: 'general', description: 'Support WhatsApp number', defaultValue: '+94771234567', isPublic: true },

  { key: 'fees.stays.service_charge_pct', category: 'fees', description: 'Stays service charge %', defaultValue: 5, isPublic: true, min: 0, max: 25 },
  { key: 'fees.stays.local_tax_pct', category: 'fees', description: 'Local tax %', defaultValue: 10, isPublic: true, min: 0, max: 30 },
  { key: 'fees.vehicles.daily_km_allowance', category: 'fees', description: 'Free KM/day', defaultValue: 100, isPublic: true, min: 20, max: 300 },
  { key: 'fees.vehicles.excess_km_rate_lkr', category: 'fees', description: 'Excess KM fee', defaultValue: 325, isPublic: true, min: 50, max: 1000 },
  { key: 'fees.events.entertainment_tax_pct', category: 'fees', description: 'Entertainment tax %', defaultValue: 15, isPublic: true, min: 0, max: 35 },
  { key: 'fees.platform.commission_pct', category: 'fees', description: 'Platform commission %', defaultValue: 8, isPublic: false, min: 1, max: 30 },

  { key: 'taxi.base_fare_lkr', category: 'taxi', description: 'Taxi base fare', defaultValue: 200, isPublic: false, min: 50, max: 2000 },
  { key: 'taxi.per_km_rate_lkr', category: 'taxi', description: 'Per KM rate', defaultValue: 60, isPublic: false, min: 10, max: 500 },
  { key: 'taxi.per_min_rate_lkr', category: 'taxi', description: 'Per minute wait rate', defaultValue: 5, isPublic: false, min: 1, max: 100 },
  { key: 'taxi.surge_max_multiplier', category: 'taxi', description: 'Maximum surge multiplier', defaultValue: 3.0, isPublic: false, min: 1, max: 5 },
  { key: 'taxi.driver_commission_pct', category: 'taxi', description: 'Driver earnings %', defaultValue: 80, isPublic: false, min: 50, max: 95 },
  { key: 'taxi.categories_enabled', category: 'taxi', description: 'Enabled taxi categories', defaultValue: ['moto','tuk_tuk','car_economy','car_electric','buddy_van','suv'], isPublic: true },

  { key: 'limits.otp.max_attempts', category: 'limits', description: 'OTP max attempts', defaultValue: 5, isPublic: false, min: 3, max: 10 },
  { key: 'limits.otp.resend_cooldown_seconds', category: 'limits', description: 'OTP resend cooldown', defaultValue: 60, isPublic: false, min: 15, max: 300 },
  { key: 'limits.otp.expiry_minutes', category: 'limits', description: 'OTP expiry minutes', defaultValue: 10, isPublic: false, min: 3, max: 30 },
  { key: 'limits.listing.max_images', category: 'limits', description: 'Max listing images', defaultValue: 20, isPublic: false, min: 5, max: 60 },
  { key: 'limits.booking.min_advance_hours', category: 'limits', description: 'Booking min advance', defaultValue: 2, isPublic: false, min: 0, max: 72 },

  { key: 'payments.payhere.enabled', category: 'payments', description: 'Enable PayHere', defaultValue: true, isPublic: false },
  { key: 'payments.lankaqr.enabled', category: 'payments', description: 'Enable LankaQR', defaultValue: true, isPublic: false },
  { key: 'payments.wallet.enabled', category: 'payments', description: 'Enable wallet', defaultValue: true, isPublic: false },
  { key: 'payments.min_topup_lkr', category: 'payments', description: 'Minimum top-up', defaultValue: 500, isPublic: true, min: 100, max: 50000 },
  { key: 'payments.max_topup_lkr', category: 'payments', description: 'Maximum top-up', defaultValue: 500000, isPublic: true, min: 5000, max: 5000000 },

  { key: 'notifications.email.from_name', category: 'notifications', description: 'Sender name', defaultValue: 'Pearl Hub', isPublic: false },
  { key: 'notifications.email.from_address', category: 'notifications', description: 'Sender email', defaultValue: 'noreply@pearlhub.lk', isPublic: false },
  { key: 'notifications.whatsapp.provider', category: 'notifications', description: 'WhatsApp provider', defaultValue: '360dialog', isPublic: false },
  { key: 'notifications.sms.provider', category: 'notifications', description: 'SMS provider', defaultValue: 'twilio', isPublic: false },
];

const RECOMMENDED_NEXT_CONFIGS: ConfigTemplate[] = [
  { key: 'taxi.peak_mode_enabled', category: 'taxi', description: 'Enable peak-hour pricing mode', defaultValue: false, isPublic: false },
  { key: 'taxi.surge_default_multiplier', category: 'taxi', description: 'Default surge multiplier in peak mode', defaultValue: 1.2, isPublic: false, min: 1, max: 3 },
  { key: 'growth.referral.enabled', category: 'general', description: 'Enable referral growth channel', defaultValue: true, isPublic: false },
  { key: 'growth.coupon.enabled', category: 'general', description: 'Enable campaign coupons', defaultValue: true, isPublic: false },
  { key: 'growth.dynamic_pricing.enabled', category: 'general', description: 'Enable dynamic pricing assistant', defaultValue: false, isPublic: false },
  { key: 'limits.moderation.sla_hours', category: 'limits', description: 'Moderation SLA target hours', defaultValue: 12, isPublic: false, min: 1, max: 72 },
  { key: 'notifications.push.enabled', category: 'notifications', description: 'Enable push notifications', defaultValue: false, isPublic: false },
];

function SupabaseSettingsPanel() {
  const [configs, setConfigs] = useState<PlatformCfg[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [editValue, setEditValue] = useState<string>('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchConfigs();
  }, []);

  const fetchConfigs = async () => {
    try {
      setLoading(true);
      const { data, error } = await (supabase as unknown as { from: (table: string) => any })
        .from('platform_config')
        .select('key, value, category, description, is_public')
        .order('category')
        .order('key');

      if (error) throw error;
      setConfigs((data || []) as PlatformCfg[]);
    } catch (err) {
      console.error('Failed to fetch configs:', err);
    } finally {
      setLoading(false);
    }
  };

  const saveConfig = async (key: string, newValue: string) => {
    try {
      setSaving(true);
      let jsonValue: unknown;
      try {
        jsonValue = JSON.parse(newValue);
      } catch {
        jsonValue = newValue;
      }

      const { error } = await (supabase as unknown as { rpc: (name: string, args: Record<string, unknown>) => Promise<{ error: unknown }> }).rpc('admin_set_platform_config', {
        p_key: key,
        p_value: jsonValue,
      });

      if (error) throw error;
      setEditingKey(null);
      await fetchConfigs();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown save error';
      console.error('Failed to save config:', err);
      alert('Failed to save: ' + message);
    } finally {
      setSaving(false);
    }
  };

  const upsertTemplates = async (templates: ConfigTemplate[]) => {
    if (templates.length === 0) return;
    try {
      setSaving(true);
      const rows = templates.map((t) => ({
        key: t.key,
        value: t.defaultValue,
        category: t.category,
        description: t.description,
        is_public: t.isPublic,
      }));

      const { error } = await (supabase as unknown as { from: (table: string) => any })
        .from('platform_config')
        .upsert(rows, { onConflict: 'key' });

      if (error) throw error;
      await fetchConfigs();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown upsert error';
      alert('Failed to apply templates: ' + message);
    } finally {
      setSaving(false);
    }
  };

  const cfgMap = new Map(configs.map((c) => [c.key, c]));
  const baselineMissing = CONFIG_BASELINE.filter((c) => !cfgMap.has(c.key));
  const nextMissing = RECOMMENDED_NEXT_CONFIGS.filter((c) => !cfgMap.has(c.key));

  const riskyConfigs = CONFIG_BASELINE.filter((c) => {
    if (c.min === undefined && c.max === undefined) return false;
    const row = cfgMap.get(c.key);
    if (!row) return false;
    const raw = row.value;
    const n = typeof raw === 'number' ? raw : typeof raw === 'string' ? Number(raw) : NaN;
    if (Number.isNaN(n)) return false;
    return (c.min !== undefined && n < c.min) || (c.max !== undefined && n > c.max);
  });

  const boolValue = (key: string, fallback = false) => {
    const raw = cfgMap.get(key)?.value;
    if (typeof raw === 'boolean') return raw;
    if (typeof raw === 'string') return raw.toLowerCase() === 'true';
    return fallback;
  };

  const autoFixGuardrails = async () => {
    const updates = riskyConfigs.map((c) => {
      const row = cfgMap.get(c.key);
      const current = row?.value;
      const n = typeof current === 'number' ? current : typeof current === 'string' ? Number(current) : Number(c.defaultValue);
      let next = n;
      if (c.min !== undefined) next = Math.max(next, c.min);
      if (c.max !== undefined) next = Math.min(next, c.max);
      return { key: c.key, value: next };
    });

    if (updates.length === 0) return;

    try {
      setSaving(true);
      for (const u of updates) {
        const { error } = await (supabase as unknown as { rpc: (name: string, args: Record<string, unknown>) => Promise<{ error: unknown }> }).rpc('admin_set_platform_config', {
          p_key: u.key,
          p_value: u.value,
        });
        if (error) throw error;
      }
      await fetchConfigs();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown guardrail error';
      alert('Failed to fix guardrails: ' + message);
    } finally {
      setSaving(false);
    }
  };

  const grouped = configs.reduce((acc, cfg) => {
    const cat = cfg.category || 'general';
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(cfg);
    return acc;
  }, {} as Record<string, PlatformCfg[]>);

  const coveragePct = Math.round(((CONFIG_BASELINE.length - baselineMissing.length) / CONFIG_BASELINE.length) * 100);

  return (
    <div className="space-y-8">
      <div className="bg-white/5 rounded-[2.5rem] border border-white/10 p-10">
        <h2 className="text-2xl font-black text-white mb-8 tracking-widest uppercase flex items-center gap-3">
          <span className="w-1.5 h-6 bg-primary rounded-full" /> Platform Configuration
        </h2>

        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
          <InsightCard label="Baseline Coverage" value={`${coveragePct}%`} icon="📊" />
          <InsightCard label="Missing Baseline" value={baselineMissing.length} icon="🧩" />
          <InsightCard label="Guardrail Alerts" value={riskyConfigs.length} icon="⚠️" />
          <InsightCard label="Recommended Missing" value={nextMissing.length} icon="🚀" />
          <InsightCard label="Total Configs" value={configs.length} icon="⚙️" />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-8">
          <div className="bg-zinc-900 border border-white/5 rounded-2xl p-5">
            <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Missing Baseline Configs</h3>
            {baselineMissing.length === 0 ? (
              <div className="text-[11px] text-emerald-500 font-bold">All baseline configs are present.</div>
            ) : (
              <div className="space-y-2">
                {baselineMissing.slice(0, 8).map((m) => (
                  <div key={m.key} className="text-[11px] text-mist">• {m.key}</div>
                ))}
              </div>
            )}
            <button
              onClick={() => upsertTemplates(baselineMissing)}
              disabled={saving || baselineMissing.length === 0}
              className="mt-4 w-full rounded-xl px-3 py-2 text-[10px] font-black uppercase tracking-widest bg-primary/20 text-primary border border-primary/30 disabled:opacity-40"
            >
              Create Missing Baseline Defaults
            </button>
          </div>

          <div className="bg-zinc-900 border border-white/5 rounded-2xl p-5">
            <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Next Recommended Configs</h3>
            {nextMissing.length === 0 ? (
              <div className="text-[11px] text-emerald-500 font-bold">All recommended growth/service configs are present.</div>
            ) : (
              <div className="space-y-2">
                {nextMissing.map((m) => (
                  <div key={m.key} className="text-[11px] text-mist">• {m.key}</div>
                ))}
              </div>
            )}
            <button
              onClick={() => upsertTemplates(nextMissing)}
              disabled={saving || nextMissing.length === 0}
              className="mt-4 w-full rounded-xl px-3 py-2 text-[10px] font-black uppercase tracking-widest bg-emerald-500/20 text-emerald-500 border border-emerald-500/30 disabled:opacity-40"
            >
              Apply Recommended Service/Growth Configs
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-8">
          <div className="bg-zinc-900 border border-white/5 rounded-2xl p-5">
            <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Service Controls</h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {[
                { key: 'payments.payhere.enabled', label: 'PayHere' },
                { key: 'payments.lankaqr.enabled', label: 'LankaQR' },
                { key: 'payments.wallet.enabled', label: 'Wallet' },
                { key: 'growth.referral.enabled', label: 'Referrals' },
                { key: 'growth.coupon.enabled', label: 'Coupons' },
                { key: 'notifications.push.enabled', label: 'Push' },
              ].map((x) => {
                const enabled = boolValue(x.key, false);
                return (
                  <button
                    key={x.key}
                    onClick={() => saveConfig(x.key, JSON.stringify(!enabled))}
                    className={`rounded-xl px-3 py-2 text-[10px] font-black uppercase tracking-widest border ${enabled ? 'bg-emerald-500/15 text-emerald-500 border-emerald-500/30' : 'bg-white/5 text-mist border-white/10'}`}
                  >
                    {x.label}: {enabled ? 'ON' : 'OFF'}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="bg-zinc-900 border border-white/5 rounded-2xl p-5">
            <h3 className="text-xs font-black uppercase tracking-widest text-primary mb-3">Guardrail Alerts</h3>
            {riskyConfigs.length === 0 ? (
              <div className="text-[11px] text-emerald-500 font-bold">No risky values detected.</div>
            ) : (
              <div className="space-y-2">
                {riskyConfigs.map((r) => (
                  <div key={r.key} className="text-[11px] text-amber-500">• {r.key} is outside expected range</div>
                ))}
              </div>
            )}
            <button
              onClick={autoFixGuardrails}
              disabled={saving || riskyConfigs.length === 0}
              className="mt-4 w-full rounded-xl px-3 py-2 text-[10px] font-black uppercase tracking-widest bg-amber-500/20 text-amber-500 border border-amber-500/30 disabled:opacity-40"
            >
              Auto-Fix Guardrails
            </button>
          </div>
        </div>

        {loading ? (
          <div className="text-center py-20 text-mist font-black uppercase tracking-widest">Loading settings...</div>
        ) : (
          <div className="space-y-8">
            {Object.entries(grouped).map(([category, items]) => (
              <div key={category} className="space-y-4">
                <h3 className="text-xs font-black uppercase tracking-widest text-primary/80 px-4">{category}</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  {items.map((cfg) => (
                    <div key={cfg.key} className="bg-zinc-900 border border-white/5 rounded-2xl p-5 hover:border-white/10 transition-all group">
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex-1 min-w-0">
                          <div className="text-xs font-black text-white truncate">{cfg.key}</div>
                          {cfg.description && <div className="text-[10px] text-mist/60 mt-1 line-clamp-2">{cfg.description}</div>}
                        </div>
                        {cfg.is_public && <span className="text-[10px] text-emerald-500 font-black">PUBLIC</span>}
                      </div>

                      {editingKey === cfg.key ? (
                        <div className="mt-3 space-y-2">
                          <input
                            type="text"
                            value={editValue}
                            onChange={(e) => setEditValue(e.target.value)}
                            className="w-full bg-zinc-950 border border-white/10 rounded-lg px-3 py-2 text-xs text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                            autoFocus
                          />
                          <div className="flex gap-2">
                            <button
                              onClick={() => saveConfig(cfg.key, editValue)}
                              disabled={saving}
                              className="flex-1 bg-emerald-500/20 text-emerald-500 rounded-lg px-3 py-1 text-[10px] font-black uppercase hover:bg-emerald-500/30 disabled:opacity-50"
                            >
                              {saving ? 'Saving...' : 'Save'}
                            </button>
                            <button
                              onClick={() => setEditingKey(null)}
                              className="flex-1 bg-white/5 text-mist rounded-lg px-3 py-1 text-[10px] font-black uppercase hover:bg-white/10"
                            >
                              Cancel
                            </button>
                          </div>
                        </div>
                      ) : (
                        <div
                          onClick={() => {
                            setEditingKey(cfg.key);
                            setEditValue(JSON.stringify(cfg.value));
                          }}
                          className="mt-3 p-2 bg-white/5 rounded-lg text-xs text-mist/80 cursor-pointer hover:bg-white/10 transition-all font-mono break-all group-hover:text-white"
                        >
                          {JSON.stringify(cfg.value)}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-12 p-6 bg-primary/10 border border-primary/20 rounded-3xl flex items-center gap-4">
          <div className="w-10 h-10 rounded-full bg-primary/20 flex items-center justify-center text-xl border border-primary/20 animate-pulse">⚡</div>
          <p className="text-xs text-mist font-bold uppercase tracking-widest">Changes are applied immediately across the platform.</p>
        </div>

        {/* WhatsApp Integration Section */}
        <WhatsAppSettingsSection />
      </div>
    </div>
  );
}

// ── Advanced Vehicle Manager Component ─────────────────────
type FleetVehicle = {
  id: number;
  title: string;
  category: string;
  capacity: number;
  pricePerDay: number;
  description: string;
  features: string[];
  status: 'active' | 'maintenance' | 'inactive';
};

type CategoryRate = {
  category: string;
  baseFare: number;
  perKm: number;
  perMin: number;
  commission: number;
};

function AdvancedVehicleManager() {
  const [vehicles, setVehicles] = useState<FleetVehicle[]>([
    { id: 1, title: 'Eco-Friendly Toyota Prius', category: 'Car Economy', capacity: 4, pricePerDay: 2500, description: 'Fuel-efficient sedan', features: ['AC', 'ABS', 'Power steering'], status: 'active' },
    { id: 2, title: 'Luxury Passenger Van', category: 'Buddy Van', capacity: 8, pricePerDay: 12500, description: 'Fleet vehicle', features: ['AC', 'WiFi', 'USB ports'], status: 'active' },
    { id: 3, title: 'Premium Montero SUV', category: 'SUV', capacity: 7, pricePerDay: 25000, description: 'Premium SUV', features: ['Panoramic roof', 'Leather seats', 'Navigation'], status: 'active' },
  ]);

  const [categoryRates, setCategoryRates] = useState<CategoryRate[]>([
    { category: 'Moto', baseFare: 50, perKm: 8, perMin: 1, commission: 10 },
    { category: 'TUK TUK', baseFare: 100, perKm: 12, perMin: 1.5, commission: 12 },
    { category: 'Car Economy', baseFare: 150, perKm: 20, perMin: 2, commission: 15 },
    { category: 'Car Electric', baseFare: 180, perKm: 22, perMin: 2.5, commission: 15 },
    { category: 'Buddy Van', baseFare: 250, perKm: 25, perMin: 3, commission: 18 },
    { category: 'SUV', baseFare: 300, perKm: 35, perMin: 4, commission: 20 },
  ]);

  const [editingModal, setEditingModal] = useState(false);
  const [editingVehicle, setEditingVehicle] = useState<FleetVehicle | null>(null);
  const [editingRate, setEditingRate] = useState<CategoryRate | null>(null);
  const [filterStatus, setFilterStatus] = useState('all');
  const [filterCategory, setFilterCategory] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [ratesModal, setRatesModal] = useState(false);
  const [bulkEditMode, setBulkEditMode] = useState(false);
  const [surgeMultiplier, setSurgeMultiplier] = useState(1.2);
  const [peakMode, setPeakMode] = useState(false);
  const [simCategory, setSimCategory] = useState('Car Economy');
  const [simKm, setSimKm] = useState(8);
  const [simMin, setSimMin] = useState(12);

  const filteredVehicles = vehicles.filter(v => {
    const matchStatus = filterStatus === 'all' || v.status === filterStatus;
    const matchCategory = filterCategory === 'all' || v.category === filterCategory;
    const matchSearch = searchTerm === '' || v.title.toLowerCase().includes(searchTerm.toLowerCase());
    return matchStatus && matchCategory && matchSearch;
  });

  const handleSaveVehicle = (vehicle: FleetVehicle | null) => {
    if (!vehicle) return;
    if (editingVehicle?.id) {
      setVehicles(vehicles.map(v => v.id === vehicle.id ? vehicle : v));
    } else {
      setVehicles([...vehicles, { ...vehicle, id: Date.now() }]);
    }
    setEditingModal(false);
    setEditingVehicle(null);
  };

  const handleDeleteVehicle = (id: number) => {
    if (confirm('Delete this vehicle?')) {
      setVehicles(vehicles.filter(v => v.id !== id));
    }
  };

  const handleSaveRate = () => {
    if (editingRate) {
      setCategoryRates(categoryRates.map(r => r.category === editingRate.category ? editingRate : r));
      setEditingRate(null);
    }
  };

  const handleBulkApply = (multiplier: number) => {
    setCategoryRates(categoryRates.map(r => ({
      ...r,
      baseFare: Math.round(r.baseFare * multiplier),
      perKm: Math.round(r.perKm * multiplier * 100) / 100,
      perMin: Math.round(r.perMin * multiplier * 100) / 100,
    })));
    setBulkEditMode(false);
  };

  const stats = {
    total: vehicles.length,
    active: vehicles.filter(v => v.status === 'active').length,
    available: vehicles.filter(v => v.status === 'active' && Math.random() > 0.3).length,
    maintenance: vehicles.filter(v => v.status === 'maintenance').length,
  };

  const rateForSim = categoryRates.find((r) => r.category === simCategory) || categoryRates[0];
  const activeMultiplier = peakMode ? surgeMultiplier : 1;
  const farePreview = Math.round((rateForSim.baseFare + (rateForSim.perKm * simKm) + (rateForSim.perMin * simMin)) * activeMultiplier);

  return (
    <div className="space-y-8">
      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        {[
          { label: 'Total Vehicles', value: stats.total, icon: '🚕', color: 'text-sapphire-500 bg-sapphire-500/10' },
          { label: 'Active Fleet', value: stats.active, icon: '✅', color: 'text-emerald-500 bg-emerald-500/10' },
          { label: 'Available Now', value: stats.available, icon: '🟢', color: 'text-lime-500 bg-lime-500/10' },
          { label: 'In Maintenance', value: stats.maintenance, icon: '🔧', color: 'text-amber-500 bg-amber-500/10' },
        ].map((stat) => (
          <div key={stat.label} className={`rounded-2xl p-6 border border-white/10 group hover:border-white/20 transition-all ${stat.color}`}>
            <div className="text-3xl mb-2">{stat.icon}</div>
            <div className="text-2xl font-black text-pearl">{stat.value}</div>
            <div className="text-[10px] uppercase font-black tracking-widest text-mist mt-1">{stat.label}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white/5 rounded-2xl border border-white/10 p-6">
          <h3 className="text-sm font-black uppercase tracking-widest text-pearl mb-4">Taxi Dynamic Controls</h3>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black uppercase tracking-wider text-mist">Peak Mode</span>
              <Switch checked={peakMode} onCheckedChange={setPeakMode} className="data-[state=checked]:bg-emerald-500" />
            </div>
            <div>
              <div className="flex items-center justify-between text-xs mb-2">
                <span className="font-black uppercase tracking-wider text-mist">Surge Multiplier</span>
                <span className="font-black text-primary">x{surgeMultiplier.toFixed(2)}</span>
              </div>
              <input
                type="range"
                min={1}
                max={2.5}
                step={0.05}
                value={surgeMultiplier}
                onChange={(e) => setSurgeMultiplier(Number(e.target.value))}
                className="w-full"
              />
            </div>
            <div className="flex flex-wrap gap-2">
              {[1, 1.15, 1.3, 1.5, 2].map((m) => (
                <button
                  key={m}
                  onClick={() => setSurgeMultiplier(m)}
                  className="px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-wider bg-white/5 border border-white/10 text-mist hover:bg-primary/20 hover:text-white"
                >
                  x{m.toFixed(2)}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="bg-white/5 rounded-2xl border border-white/10 p-6">
          <h3 className="text-sm font-black uppercase tracking-widest text-pearl mb-4">Fare Simulator</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
            <select value={simCategory} onChange={(e) => setSimCategory(e.target.value)} className="bg-zinc-900 border border-white/10 rounded-xl px-3 py-2 text-xs text-white">
              {categoryRates.map((r) => <option key={r.category} value={r.category}>{r.category}</option>)}
            </select>
            <input type="number" min={1} value={simKm} onChange={(e) => setSimKm(Number(e.target.value || 0))} className="bg-zinc-900 border border-white/10 rounded-xl px-3 py-2 text-xs text-white" placeholder="KM" />
            <input type="number" min={0} value={simMin} onChange={(e) => setSimMin(Number(e.target.value || 0))} className="bg-zinc-900 border border-white/10 rounded-xl px-3 py-2 text-xs text-white" placeholder="Minutes" />
          </div>
          <div className="rounded-xl bg-primary/10 border border-primary/20 p-4">
            <div className="text-[10px] font-black uppercase tracking-widest text-mist">Estimated Fare</div>
            <div className="text-2xl font-black text-primary mt-1">Rs. {farePreview.toLocaleString()}</div>
            <div className="text-[10px] text-mist mt-1">Formula: (base + km + min) x surge</div>
          </div>
        </div>
      </div>

      {/* Vehicle Management */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-8">
        <div className="flex items-center justify-between mb-8">
          <h2 className="text-2xl font-black text-white uppercase tracking-widest flex items-center gap-3">
            <span className="w-2 h-6 bg-primary rounded-full"></span> Fleet Inventory
          </h2>
          <Button
            onClick={() => {
              setEditingVehicle(null);
              setEditingModal(true);
            }}
            className="bg-primary hover:bg-gold-light text-white font-black h-10 px-6 rounded-xl flex items-center gap-2"
          >
            ➕ Add Vehicle
          </Button>
        </div>

        {/* Filters */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <input
            type="text"
            placeholder="🔍 Search vehicles..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-mist/40 focus:ring-1 focus:ring-primary/40 focus:outline-none"
          />
          <select
            value={filterCategory}
            onChange={(e) => setFilterCategory(e.target.value)}
            className="bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
          >
            <option value="all">All Categories</option>
            {Array.from(new Set(vehicles.map(v => v.category))).map(cat => (
              <option key={cat} value={cat}>{cat}</option>
            ))}
          </select>
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
          >
            <option value="all">All Status</option>
            <option value="active">Active</option>
            <option value="maintenance">Maintenance</option>
            <option value="inactive">Inactive</option>
          </select>
        </div>

        {/* Vehicle Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-white/5">
                <th className="px-6 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Vehicle</th>
                <th className="px-6 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Category</th>
                <th className="px-6 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Capacity</th>
                <th className="px-6 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Daily Rate</th>
                <th className="px-6 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Features</th>
                <th className="px-6 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Status</th>
                <th className="px-6 py-4 text-[10px] font-black text-mist uppercase tracking-widest">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {filteredVehicles.map((vehicle) => (
                <tr key={vehicle.id} className="hover:bg-white/5 transition-colors group">
                  <td className="px-6 py-4">
                    <div className="font-bold text-pearl group-hover:text-primary transition-colors">{vehicle.title}</div>
                    <div className="text-[10px] text-mist mt-1">{vehicle.description}</div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-xs font-black text-primary bg-primary/10 px-3 py-1 rounded-lg">{vehicle.category}</span>
                  </td>
                  <td className="px-6 py-4 text-sm font-bold text-amber-500">{vehicle.capacity} seats</td>
                  <td className="px-6 py-4">
                    <div className="font-black text-pearl">Rs. {vehicle.pricePerDay.toLocaleString()}</div>
                    <div className="text-[10px] text-mist">/day</div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex flex-wrap gap-1">
                      {vehicle.features.slice(0, 2).map((f: string) => (
                        <span key={f} className="text-[9px] bg-white/10 text-mist px-2 py-1 rounded-full">{f}</span>
                      ))}
                      {vehicle.features.length > 2 && (
                        <span className="text-[9px] bg-white/10 text-mist px-2 py-1 rounded-full">+{vehicle.features.length - 2}</span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className={`px-3 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider ${
                      vehicle.status === 'active' ? 'bg-emerald-500/20 text-emerald-500' :
                      vehicle.status === 'maintenance' ? 'bg-amber-500/20 text-amber-500' :
                      'bg-mist/10 text-mist'
                    }`}>
                      {vehicle.status}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        onClick={() => {
                          setEditingVehicle(vehicle);
                          setEditingModal(true);
                        }}
                        className="px-3 py-1 bg-primary/10 text-primary rounded-lg text-[10px] font-black hover:bg-primary hover:text-white transition-all"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDeleteVehicle(vehicle.id)}
                        className="px-3 py-1 bg-ruby/10 text-ruby rounded-lg text-[10px] font-black hover:bg-ruby hover:text-white transition-all"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Category Rates Management */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-8">
        <div className="flex items-center justify-between mb-8">
          <h2 className="text-2xl font-black text-white uppercase tracking-widest flex items-center gap-3">
            <span className="w-2 h-6 bg-amber-500 rounded-full"></span> Category Rates & Pricing
          </h2>
          <div className="flex gap-2">
            <Button
              onClick={() => setBulkEditMode(!bulkEditMode)}
              className={`font-black h-10 px-6 rounded-xl transition-all ${
                bulkEditMode ? 'bg-amber-500 text-white' : 'bg-white/10 text-mist hover:bg-white/20'
              }`}
            >
              {bulkEditMode ? '✓ Bulk Edit' : '⚙️ Bulk Update'}
            </Button>
            <Button
              onClick={() => {
                setEditingRate(null);
                setRatesModal(true);
              }}
              className="bg-primary hover:bg-gold-light text-white font-black h-10 px-6 rounded-xl"
            >
              ➕ New Rate
            </Button>
          </div>
        </div>

        {bulkEditMode && (
          <div className="mb-6 p-6 bg-amber-500/10 border border-amber-500/20 rounded-2xl">
            <p className="text-sm font-bold text-amber-500 mb-4">Apply percentage multiplier to all rates:</p>
            <div className="flex flex-wrap gap-2">
              {[0.8, 0.9, 1.0, 1.1, 1.2, 1.5].map((mult) => (
                <button
                  key={mult}
                  onClick={() => handleBulkApply(mult)}
                  className={`px-4 py-2 rounded-lg font-black text-sm transition-all ${
                    mult === 1.0 ? 'bg-amber-500 text-white' : 'bg-white/10 text-mist hover:bg-white/20'
                  }`}
                >
                  {mult === 1.0 ? 'Reset' : `${((mult - 1) * 100 > 0 ? '+' : '')}${Math.round((mult - 1) * 100)}%`}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Rates Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {categoryRates.map((rate) => (
            <div key={rate.category} className="bg-zinc-900 border border-white/5 rounded-2xl p-6 hover:border-white/20 transition-all group cursor-pointer">
              <div className="flex items-start justify-between mb-4">
                <div>
                  <h3 className="font-black text-pearl text-lg">{rate.category}</h3>
                  <p className="text-[10px] text-mist mt-1 font-bold">Category rates & commission</p>
                </div>
                <span className="px-3 py-1 bg-primary/20 text-primary rounded-lg text-[10px] font-black">{rate.commission}% COM</span>
              </div>

              <div className="space-y-2 mb-4">
                <div className="flex justify-between">
                  <span className="text-mist text-sm font-bold">Base Fare:</span>
                  <span className="font-black text-pearl">Rs. {rate.baseFare}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-mist text-sm font-bold">Per km:</span>
                  <span className="font-black text-pearl">Rs. {rate.perKm}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-mist text-sm font-bold">Per minute:</span>
                  <span className="font-black text-pearl">Rs. {rate.perMin}</span>
                </div>
              </div>

              <button
                onClick={() => {
                  setEditingRate(rate);
                  setRatesModal(true);
                }}
                className="w-full p-2 bg-primary/10 text-primary rounded-lg text-[10px] font-black uppercase hover:bg-primary hover:text-white transition-all"
              >
                Edit Rates
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Vehicle Edit Modal */}
      <Dialog open={editingModal} onOpenChange={setEditingModal}>
        <DialogContent className="sm:max-w-2xl bg-zinc-950 border-white/10 text-white rounded-[2.5rem] p-8">
          <DialogHeader>
            <DialogTitle className="text-2xl font-black uppercase tracking-widest">{editingVehicle ? 'Edit Vehicle' : 'Add New Vehicle'}</DialogTitle>
          </DialogHeader>

          <div className="space-y-5">
            <div>
              <label className="text-[10px] font-black text-mist uppercase tracking-widest">Vehicle Title *</label>
              <input
                type="text"
                defaultValue={editingVehicle?.title || ''}
                onChange={(e) => setEditingVehicle({...editingVehicle, title: e.target.value})}
                className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                placeholder="e.g., Eco-Friendly Toyota Prius"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-[10px] font-black text-mist uppercase tracking-widest">Category *</label>
                <select
                  value={editingVehicle?.category || ''}
                  onChange={(e) => setEditingVehicle({...editingVehicle, category: e.target.value})}
                  className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                >
                  <option>Select category...</option>
                  {Array.from(new Set(categoryRates.map(r => r.category))).map(cat => (
                    <option key={cat} value={cat}>{cat}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-[10px] font-black text-mist uppercase tracking-widest">Capacity (seats) *</label>
                <input
                  type="number"
                  defaultValue={editingVehicle?.capacity || ''}
                  onChange={(e) => setEditingVehicle({...editingVehicle, capacity: parseInt(e.target.value)})}
                  className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="text-[10px] font-black text-mist uppercase tracking-widest">Description</label>
              <textarea
                defaultValue={editingVehicle?.description || ''}
                onChange={(e) => setEditingVehicle({...editingVehicle, description: e.target.value})}
                className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white text-sm focus:ring-1 focus:ring-primary/40 focus:outline-none h-20 resize-none"
                placeholder="Vehicle description..."
              />
            </div>

            <div>
              <label className="text-[10px] font-black text-mist uppercase tracking-widest">Daily Rate (LKR) *</label>
              <input
                type="number"
                defaultValue={editingVehicle?.pricePerDay || ''}
                onChange={(e) => setEditingVehicle({...editingVehicle, pricePerDay: parseInt(e.target.value)})}
                className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
              />
            </div>

            <div>
              <label className="text-[10px] font-black text-mist uppercase tracking-widest">Features (comma separated)</label>
              <input
                type="text"
                defaultValue={editingVehicle?.features?.join(', ') || ''}
                onChange={(e) => setEditingVehicle({...editingVehicle, features: e.target.value.split(',').map(f => f.trim())})}
                className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                placeholder="e.g., AC, ABS, Power steering"
              />
            </div>

            <div>
              <label className="text-[10px] font-black text-mist uppercase tracking-widest">Status</label>
              <select
                value={editingVehicle?.status || 'active'}
                onChange={(e) => setEditingVehicle({ ...editingVehicle, status: e.target.value as FleetVehicle['status'] })}
                className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
              >
                <option value="active">Active</option>
                <option value="maintenance">Maintenance</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>

            <div className="flex gap-4 pt-4">
              <Button onClick={() => setEditingModal(false)} variant="outline" className="flex-1">Cancel</Button>
              <Button
                onClick={() => handleSaveVehicle(editingVehicle)}
                className="flex-1 bg-primary hover:bg-gold-light text-white font-black"
              >
                Save Vehicle
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Rates Edit Modal */}
      <Dialog open={ratesModal} onOpenChange={setRatesModal}>
        <DialogContent className="sm:max-w-xl bg-zinc-950 border-white/10 text-white rounded-[2.5rem] p-8">
          <DialogHeader>
            <DialogTitle className="text-2xl font-black uppercase tracking-widest">{editingRate ? `Edit ${editingRate.category} Rates` : 'Add New Rate'}</DialogTitle>
          </DialogHeader>

          {editingRate && (
            <div className="space-y-5">
              <div>
                <label className="text-[10px] font-black text-mist uppercase tracking-widest">Category</label>
                <div className="mt-2 p-4 bg-zinc-900 rounded-xl font-black text-pearl text-lg">{editingRate.category}</div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-[10px] font-black text-mist uppercase tracking-widest">Base Fare (LKR)</label>
                  <input
                    type="number"
                    value={editingRate.baseFare}
                    onChange={(e) => setEditingRate({...editingRate, baseFare: parseFloat(e.target.value)})}
                    className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-black text-mist uppercase tracking-widest">Per KM (LKR)</label>
                  <input
                    type="number"
                    step="0.5"
                    value={editingRate.perKm}
                    onChange={(e) => setEditingRate({...editingRate, perKm: parseFloat(e.target.value)})}
                    className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-[10px] font-black text-mist uppercase tracking-widest">Per Minute (LKR)</label>
                  <input
                    type="number"
                    step="0.5"
                    value={editingRate.perMin}
                    onChange={(e) => setEditingRate({...editingRate, perMin: parseFloat(e.target.value)})}
                    className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-black text-mist uppercase tracking-widest">Commission (%)</label>
                  <input
                    type="number"
                    step="0.5"
                    value={editingRate.commission}
                    onChange={(e) => setEditingRate({...editingRate, commission: parseFloat(e.target.value)})}
                    className="w-full mt-2 bg-zinc-900 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-1 focus:ring-primary/40 focus:outline-none"
                  />
                </div>
              </div>

              <div className="bg-primary/10 border border-primary/20 rounded-2xl p-4">
                <p className="text-xs font-black text-primary uppercase tracking-widest">Estimated Fare Example:</p>
                <p className="text-2xl font-black text-pearl mt-2">Rs. {Math.round(editingRate.baseFare + (10 * editingRate.perKm) + (15 * editingRate.perMin))}</p>
                <p className="text-[10px] text-mist mt-1">For 10km ride, 15 min wait</p>
              </div>

              <div className="flex gap-4 pt-4">
                <Button onClick={() => setRatesModal(false)} variant="outline" className="flex-1">Cancel</Button>
                <Button
                  onClick={handleSaveRate}
                  className="flex-1 bg-primary hover:bg-gold-light text-white font-black"
                >
                  Save Rates
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GOD'S VIEW PANEL — Live provider & ride tracker
// ─────────────────────────────────────────────────────────────────────────────
function GodsViewPanel() {
  const [providers, setProviders] = useState<any[]>([]);
  const [rides, setRides] = useState<any[]>([]);
  const [filter, setFilter] = useState<'all' | 'stays' | 'vehicles' | 'taxi' | 'events'>('all');
  const [stats, setStats] = useState({ activeRides: 0, onlineProviders: 0, pendingBookings: 0, todayRevenue: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const [provRes, rideRes, bkRes, revRes] = await Promise.all([
        db.rpc('admin_gods_view_providers'),
        db.rpc('admin_gods_view_rides'),
        db.from('bookings').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
        db.from('bookings').select('total_price').gte('created_at', new Date().toISOString().slice(0, 10)),
      ]);
      setProviders((provRes.data as any[]) || []);
      setRides((rideRes.data as any[]) || []);
      const todayRev = ((revRes.data as any[]) || []).reduce((s: number, b: any) => s + (b.total_price || 0), 0);
      setStats({
        activeRides: (rideRes.data as any[] || []).filter((r: any) => r.status === 'in_progress').length,
        onlineProviders: (provRes.data as any[] || []).length,
        pendingBookings: bkRes.count || 0,
        todayRevenue: todayRev,
      });
      setLoading(false);
    };
    load();

    // Realtime subscriptions
    const provCh = supabase.channel('gods-view-providers')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'provider_locations' }, () => load())
      .subscribe();
    const rideCh = supabase.channel('gods-view-rides')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'taxi_rides' }, () => load())
      .subscribe();
    return () => { supabase.removeChannel(provCh); supabase.removeChannel(rideCh); };
  }, []);

  const filtered = providers.filter(p => filter === 'all' || p.vertical === filter);
  const verticalColor: Record<string, string> = {
    stays: 'bg-sapphire', vehicles: 'bg-emerald-500', taxi: 'bg-amber-500',
    events: 'bg-primary', properties: 'bg-purple-500', sme: 'bg-cyan-500',
  };

  return (
    <div className="space-y-6">
      {/* KPI Strip */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Active Rides', value: stats.activeRides, icon: '🚖', color: 'text-amber-400' },
          { label: 'Online Providers', value: stats.onlineProviders, icon: '🟢', color: 'text-emerald-400' },
          { label: 'Pending Bookings', value: stats.pendingBookings, icon: '⏳', color: 'text-primary' },
          { label: "Today's Revenue", value: `LKR ${stats.todayRevenue.toLocaleString()}`, icon: '💰', color: 'text-gold' },
        ].map(k => (
          <div key={k.label} className="bg-white/5 rounded-2xl border border-white/10 p-5">
            <p className="text-2xl mb-1">{k.icon}</p>
            <p className={`text-2xl font-black ${k.color}`}>{k.value}</p>
            <p className="text-mist text-[10px] font-bold uppercase tracking-widest">{k.label}</p>
          </div>
        ))}
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-2 flex-wrap">
        {(['all', 'stays', 'vehicles', 'taxi', 'events'] as const).map(f => (
          <button key={f} onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
              filter === f ? 'bg-primary text-white shadow-lg shadow-primary/25' : 'bg-white/5 text-mist hover:bg-white/10'
            }`}>{f}</button>
        ))}
      </div>

      {/* Map Container — styled provider dots on Sri Lanka grid */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-6 overflow-hidden">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-black text-white uppercase tracking-widest">Live Provider Map — Sri Lanka</h3>
          <span className="flex items-center gap-1.5 text-emerald-400 text-xs font-bold">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" /> LIVE
          </span>
        </div>

        {loading ? (
          <div className="h-80 flex items-center justify-center">
            <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <div className="relative bg-zinc-900/60 rounded-2xl border border-white/5 overflow-hidden" style={{ height: '400px' }}>
            {/* Sri Lanka outline hint */}
            <div className="absolute inset-0 flex items-center justify-center opacity-5">
              <svg viewBox="0 0 100 150" className="h-full text-white fill-current">
                <ellipse cx="50" cy="75" rx="28" ry="55" />
              </svg>
            </div>
            {/* Province labels */}
            <div className="absolute top-4 left-4 text-[8px] text-mist/30 font-bold">N • Jaffna</div>
            <div className="absolute bottom-4 right-4 text-[8px] text-mist/30 font-bold">S • Galle</div>
            <div className="absolute top-1/2 left-6 text-[8px] text-mist/30 font-bold">W • Colombo</div>
            <div className="absolute top-1/2 right-6 text-[8px] text-mist/30 font-bold">E • Batticaloa</div>
            <div className="absolute top-1/3 left-1/2 text-[8px] text-mist/30 font-bold -translate-x-1/2">Kandy</div>

            {/* Provider dots */}
            {filtered.map((p: any, i: number) => {
              const lat = p.last_lat ?? (6.9 + Math.random() * 2.5);
              const lng = p.last_lng ?? (80.1 + Math.random() * 1.8);
              const x = ((lng - 79.5) / 2.5) * 100;
              const y = (1 - (lat - 5.9) / 3.4) * 100;
              const color = verticalColor[p.vertical] || 'bg-white';
              return (
                <div key={p.id || i} title={`${p.name} — ${p.vertical}`}
                  className={`absolute w-3 h-3 rounded-full ${color} border-2 border-zinc-950 shadow-lg cursor-pointer hover:scale-150 transition-transform z-10`}
                  style={{ left: `${Math.min(95, Math.max(5, x))}%`, top: `${Math.min(95, Math.max(5, y))}%` }}
                />
              );
            })}

            {/* Taxi rides */}
            {rides.filter(r => r.status === 'in_progress').map((r: any, i: number) => {
              const x = 30 + (i % 5) * 12;
              const y = 40 + Math.floor(i / 5) * 12;
              return (
                <div key={r.id || i} title={`Ride #${r.id}`}
                  className="absolute w-4 h-4 rounded-full bg-amber-500 border-2 border-zinc-950 shadow-lg shadow-amber-500/50 animate-ping z-20"
                  style={{ left: `${x}%`, top: `${y}%` }}
                />
              );
            })}
          </div>
        )}

        {/* Legend */}
        <div className="flex flex-wrap gap-3 mt-4">
          {Object.entries(verticalColor).map(([v, c]) => (
            <span key={v} className="flex items-center gap-1.5 text-xs text-mist font-bold capitalize">
              <span className={`w-2.5 h-2.5 rounded-full ${c}`} />{v}
            </span>
          ))}
          <span className="flex items-center gap-1.5 text-xs text-amber-400 font-bold">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-ping" /> Active Ride
          </span>
        </div>
      </div>

      {/* Provider List */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
        <h3 className="text-sm font-black text-white uppercase tracking-widest mb-4">Online Providers ({filtered.length})</h3>
        {filtered.length === 0 ? (
          <p className="text-mist text-sm text-center py-8 opacity-50">No online providers right now</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-mist/50 text-[10px] uppercase tracking-widest font-black border-b border-white/5">
                  <th className="text-left pb-3">Provider</th>
                  <th className="text-left pb-3">Vertical</th>
                  <th className="text-left pb-3">Location</th>
                  <th className="text-right pb-3">Last Seen</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {filtered.slice(0, 50).map((p: any, i: number) => (
                  <tr key={p.id || i} className="hover:bg-white/3 transition-all">
                    <td className="py-3 font-bold text-white">{p.name || p.full_name || 'Provider'}</td>
                    <td className="py-3">
                      <span className={`px-2 py-0.5 rounded-lg text-[9px] font-black uppercase ${verticalColor[p.vertical] || 'bg-white/10'} text-white`}>
                        {p.vertical || '—'}
                      </span>
                    </td>
                    <td className="py-3 text-mist">{p.city || `${(p.last_lat || '?')} / ${(p.last_lng || '?')}`}</td>
                    <td className="py-3 text-right text-mist">{p.last_seen ? new Date(p.last_seen).toLocaleTimeString() : '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE PANEL — Revenue, Payouts, Top Earners
// ─────────────────────────────────────────────────────────────────────────────
function FinancePanel() {
  const [period, setPeriod] = useState<'7d' | '30d' | '90d'>('30d');
  const [revenueByVertical, setRevenueByVertical] = useState<any[]>([]);
  const [payouts, setPayouts] = useState<any[]>([]);
  const [topEarners, setTopEarners] = useState<any[]>([]);
  const [totals, setTotals] = useState({ gross: 0, commission: 0, net: 0, pending: 0 });
  const [loading, setLoading] = useState(true);
  const [processingId, setProcessingId] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
      const since = new Date(Date.now() - days * 86400000).toISOString();

      const [revRes, payRes, earnerRes] = await Promise.all([
        db.rpc('admin_revenue_by_vertical', { since_date: since }),
        db.from('payouts').select('*, profiles(full_name, avatar_url)').order('created_at', { ascending: false }).limit(30),
        db.from('bookings').select('provider_id, total_price, profiles!provider_id(full_name)')
          .gte('created_at', since).eq('status', 'confirmed'),
      ]);

      const rv = (revRes.data as any[]) || [];
      const py = (payRes.data as any[]) || [];
      setRevenueByVertical(rv);
      setPayouts(py);

      // Aggregate top earners
      const earnerMap: Record<string, { name: string; gross: number }> = {};
      ((earnerRes.data as any[]) || []).forEach((b: any) => {
        const id = b.provider_id;
        if (!earnerMap[id]) earnerMap[id] = { name: (b.profiles as any)?.full_name || 'Provider', gross: 0 };
        earnerMap[id].gross += b.total_price || 0;
      });
      setTopEarners(Object.entries(earnerMap).sort((a, b) => b[1].gross - a[1].gross).slice(0, 10).map(([id, v]) => ({ id, ...v })));

      const gross = rv.reduce((s: number, r: any) => s + (r.gross || 0), 0);
      const commission = rv.reduce((s: number, r: any) => s + (r.commission || 0), 0);
      const pendingPayout = py.filter((p: any) => p.status === 'pending').reduce((s: number, p: any) => s + (p.amount || 0), 0);
      setTotals({ gross, commission, net: gross - commission, pending: pendingPayout });
      setLoading(false);
    };
    load();
  }, [period]);

  const processPayout = async (payoutId: string) => {
    setProcessingId(payoutId);
    await db.from('payouts').update({ status: 'processing', processed_at: new Date().toISOString() }).eq('id', payoutId);
    setPayouts(p => p.map((x: any) => x.id === payoutId ? { ...x, status: 'processing' } : x));
    setProcessingId(null);
  };

  const maxBar = Math.max(...revenueByVertical.map(r => r.gross || 0), 1);

  return (
    <div className="space-y-6">
      {/* Period selector + Totals */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex gap-2">
          {(['7d', '30d', '90d'] as const).map(p => (
            <button key={p} onClick={() => setPeriod(p)}
              className={`px-5 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
                period === p ? 'bg-primary text-white shadow-lg shadow-primary/25' : 'bg-white/5 text-mist hover:bg-white/10'
              }`}>{p}</button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Gross Revenue', value: totals.gross, color: 'text-gold' },
          { label: 'Commission', value: totals.commission, color: 'text-primary' },
          { label: 'Net to Providers', value: totals.net, color: 'text-emerald-400' },
          { label: 'Pending Payouts', value: totals.pending, color: 'text-amber-400' },
        ].map(k => (
          <div key={k.label} className="bg-white/5 rounded-2xl border border-white/10 p-5">
            <p className={`text-xl font-black ${k.color}`}>LKR {k.value.toLocaleString()}</p>
            <p className="text-mist text-[10px] font-bold uppercase tracking-widest mt-1">{k.label}</p>
          </div>
        ))}
      </div>

      {/* Revenue by Vertical Bar Chart */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
        <h3 className="text-sm font-black text-white uppercase tracking-widest mb-6">Revenue by Vertical</h3>
        {loading ? (
          <div className="h-40 flex items-center justify-center">
            <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : revenueByVertical.length === 0 ? (
          <p className="text-mist text-sm text-center py-8 opacity-50">No revenue data for this period</p>
        ) : (
          <div className="space-y-3">
            {revenueByVertical.map((r: any) => (
              <div key={r.vertical} className="flex items-center gap-4">
                <span className="text-xs font-black text-mist uppercase tracking-widest w-20 capitalize shrink-0">{r.vertical}</span>
                <div className="flex-1 bg-white/5 rounded-full h-3 overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }} animate={{ width: `${((r.gross || 0) / maxBar) * 100}%` }}
                    transition={{ duration: 0.8, ease: 'easeOut' }}
                    className="h-full bg-gradient-to-r from-primary to-gold rounded-full"
                  />
                </div>
                <span className="text-xs font-black text-gold w-28 text-right shrink-0">
                  LKR {(r.gross || 0).toLocaleString()}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Top Earners */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
        <h3 className="text-sm font-black text-white uppercase tracking-widest mb-4">Top Earning Providers</h3>
        <div className="space-y-2">
          {topEarners.length === 0 ? (
            <p className="text-mist text-sm text-center py-4 opacity-50">No data</p>
          ) : topEarners.map((e, i) => (
            <div key={e.id} className="flex items-center gap-4 p-3 rounded-xl bg-white/3 hover:bg-white/5 transition-all">
              <span className="text-lg font-black text-mist/40 w-6">{i + 1}</span>
              <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center text-primary font-black text-sm">
                {e.name[0]}
              </div>
              <span className="flex-1 text-sm font-bold text-white">{e.name}</span>
              <span className="text-sm font-black text-gold">LKR {e.gross.toLocaleString()}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Payout Queue */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
        <h3 className="text-sm font-black text-white uppercase tracking-widest mb-4">Payout Queue</h3>
        {payouts.length === 0 ? (
          <p className="text-mist text-sm text-center py-4 opacity-50">No pending payouts</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-mist/50 text-[10px] uppercase tracking-widest font-black border-b border-white/5">
                  <th className="text-left pb-3">Provider</th>
                  <th className="text-left pb-3">Amount</th>
                  <th className="text-left pb-3">Method</th>
                  <th className="text-left pb-3">Status</th>
                  <th className="text-right pb-3">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {payouts.map((py: any) => (
                  <tr key={py.id} className="hover:bg-white/3 transition-all">
                    <td className="py-3 font-bold text-white">{(py.profiles as any)?.full_name || '—'}</td>
                    <td className="py-3 text-gold font-black">LKR {(py.amount || 0).toLocaleString()}</td>
                    <td className="py-3 text-mist uppercase">{py.method || 'bank'}</td>
                    <td className="py-3">
                      <span className={`px-2 py-0.5 rounded-lg text-[9px] font-black uppercase ${
                        py.status === 'paid' ? 'bg-emerald-500/20 text-emerald-400' :
                        py.status === 'processing' ? 'bg-amber-500/20 text-amber-400' :
                        'bg-white/10 text-mist'
                      }`}>{py.status}</span>
                    </td>
                    <td className="py-3 text-right">
                      {py.status === 'pending' && (
                        <button
                          onClick={() => processPayout(py.id)}
                          disabled={processingId === py.id}
                          className="px-3 py-1.5 rounded-lg bg-primary/20 text-primary text-[10px] font-black uppercase tracking-widest hover:bg-primary/30 transition-all disabled:opacity-50"
                        >
                          {processingId === py.id ? '...' : 'Process'}
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COUPONS PANEL — Promo code management
// ─────────────────────────────────────────────────────────────────────────────
function CouponsPanel() {
  const [coupons, setCoupons] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    code: '', discount_type: 'percentage', discount_value: '', min_order_value: '',
    max_uses: '', valid_from: '', valid_until: '', applicable_verticals: [] as string[],
    description: '',
  });

  useEffect(() => { loadCoupons(); }, []);

  const loadCoupons = async () => {
    setLoading(true);
    const { data } = await db.from('coupons').select('*, coupon_usages(count)').order('created_at', { ascending: false });
    setCoupons((data as any[]) || []);
    setLoading(false);
  };

  const toggleCoupon = async (id: string, isActive: boolean) => {
    await db.from('coupons').update({ is_active: !isActive }).eq('id', id);
    setCoupons(cs => cs.map((c: any) => c.id === id ? { ...c, is_active: !isActive } : c));
  };

  const createCoupon = async () => {
    if (!form.code || !form.discount_value) return;
    setSaving(true);
    const { error } = await db.from('coupons').insert({
      code: form.code.toUpperCase(),
      discount_type: form.discount_type,
      discount_value: parseFloat(form.discount_value),
      min_order_value: form.min_order_value ? parseFloat(form.min_order_value) : null,
      max_uses: form.max_uses ? parseInt(form.max_uses) : null,
      valid_from: form.valid_from || null,
      valid_until: form.valid_until || null,
      applicable_verticals: form.applicable_verticals.length > 0 ? form.applicable_verticals : null,
      description: form.description || null,
      is_active: true,
    });
    setSaving(false);
    if (!error) {
      setShowForm(false);
      setForm({ code: '', discount_type: 'percentage', discount_value: '', min_order_value: '', max_uses: '', valid_from: '', valid_until: '', applicable_verticals: [], description: '' });
      loadCoupons();
    }
  };

  const verticals = ['stays', 'vehicles', 'taxi', 'events', 'properties', 'sme'];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-black text-white uppercase tracking-widest">Coupon & Promo Codes</h3>
        <button onClick={() => setShowForm(v => !v)}
          className="px-5 py-2.5 rounded-xl bg-primary text-white text-xs font-black uppercase tracking-widest shadow-lg shadow-primary/25 hover:bg-primary/90 transition-all">
          {showForm ? '✕ Cancel' : '+ New Coupon'}
        </button>
      </div>

      {/* Create Form */}
      <AnimatePresence>
        {showForm && (
          <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} exit={{ opacity: 0, height: 0 }}
            className="overflow-hidden">
            <div className="bg-white/5 rounded-3xl border border-white/10 p-6 space-y-4">
              <h4 className="text-sm font-black text-white uppercase tracking-widest">Create New Coupon</h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {[
                  { label: 'Coupon Code *', key: 'code', type: 'text', placeholder: 'PEARL20' },
                  { label: 'Discount Value *', key: 'discount_value', type: 'number', placeholder: '20' },
                  { label: 'Min Order (LKR)', key: 'min_order_value', type: 'number', placeholder: '5000' },
                  { label: 'Max Uses', key: 'max_uses', type: 'number', placeholder: '100' },
                  { label: 'Valid From', key: 'valid_from', type: 'datetime-local', placeholder: '' },
                  { label: 'Valid Until', key: 'valid_until', type: 'datetime-local', placeholder: '' },
                ].map(f => (
                  <div key={f.key}>
                    <label className="text-[10px] text-mist font-black uppercase tracking-widest mb-1.5 block">{f.label}</label>
                    <input type={f.type} placeholder={f.placeholder}
                      value={(form as any)[f.key]}
                      onChange={e => setForm(prev => ({ ...prev, [f.key]: e.target.value }))}
                      className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-primary/50 transition-all"
                    />
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="text-[10px] text-mist font-black uppercase tracking-widest mb-1.5 block">Discount Type</label>
                  <select value={form.discount_type} onChange={e => setForm(p => ({ ...p, discount_type: e.target.value }))}
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-primary/50">
                    <option value="percentage">Percentage (%)</option>
                    <option value="fixed">Fixed Amount (LKR)</option>
                    <option value="free_delivery">Free Delivery</option>
                  </select>
                </div>
                <div>
                  <label className="text-[10px] text-mist font-black uppercase tracking-widest mb-1.5 block">Description</label>
                  <input type="text" placeholder="Optional internal note"
                    value={form.description}
                    onChange={e => setForm(p => ({ ...p, description: e.target.value }))}
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-primary/50"
                  />
                </div>
              </div>

              {/* Vertical toggles */}
              <div>
                <label className="text-[10px] text-mist font-black uppercase tracking-widest mb-2 block">Apply To Verticals (empty = all)</label>
                <div className="flex flex-wrap gap-2">
                  {verticals.map(v => (
                    <button key={v} type="button"
                      onClick={() => setForm(p => ({
                        ...p,
                        applicable_verticals: p.applicable_verticals.includes(v)
                          ? p.applicable_verticals.filter(x => x !== v)
                          : [...p.applicable_verticals, v],
                      }))}
                      className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all ${
                        form.applicable_verticals.includes(v) ? 'bg-primary text-white' : 'bg-white/5 text-mist hover:bg-white/10'
                      }`}>{v}</button>
                  ))}
                </div>
              </div>

              <button onClick={createCoupon} disabled={saving || !form.code || !form.discount_value}
                className="px-8 py-3 rounded-xl bg-primary text-white text-sm font-black uppercase tracking-widest shadow-lg shadow-primary/25 hover:bg-primary/90 transition-all disabled:opacity-50">
                {saving ? 'Creating...' : 'Create Coupon'}
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Coupons Table */}
      <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : coupons.length === 0 ? (
          <p className="text-mist text-sm text-center py-12 opacity-50">No coupons created yet</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-mist/50 text-[10px] uppercase tracking-widest font-black border-b border-white/5">
                  <th className="text-left pb-3">Code</th>
                  <th className="text-left pb-3">Discount</th>
                  <th className="text-left pb-3">Usage</th>
                  <th className="text-left pb-3">Expiry</th>
                  <th className="text-left pb-3">Verticals</th>
                  <th className="text-right pb-3">Active</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {coupons.map((c: any) => {
                  const uses = c.coupon_usages?.[0]?.count || 0;
                  const maxUses = c.max_uses;
                  const pct = maxUses ? Math.min(100, (uses / maxUses) * 100) : null;
                  return (
                    <tr key={c.id} className="hover:bg-white/3 transition-all">
                      <td className="py-3">
                        <span className="font-black text-white text-sm tracking-wider">{c.code}</span>
                        {c.description && <p className="text-mist text-[10px] mt-0.5">{c.description}</p>}
                      </td>
                      <td className="py-3 text-gold font-black">
                        {c.discount_type === 'percentage' ? `${c.discount_value}%` :
                         c.discount_type === 'fixed' ? `LKR ${c.discount_value}` : 'Free Delivery'}
                      </td>
                      <td className="py-3">
                        <div className="flex items-center gap-2">
                          <span className="text-mist">{uses}{maxUses ? `/${maxUses}` : ''}</span>
                          {pct !== null && (
                            <div className="w-16 bg-white/10 rounded-full h-1.5">
                              <div className="h-full bg-primary rounded-full" style={{ width: `${pct}%` }} />
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="py-3 text-mist">
                        {c.valid_until ? new Date(c.valid_until).toLocaleDateString() : '∞'}
                      </td>
                      <td className="py-3">
                        {c.applicable_verticals?.length > 0 ? (
                          <div className="flex flex-wrap gap-1">
                            {c.applicable_verticals.map((v: string) => (
                              <span key={v} className="px-1.5 py-0.5 rounded bg-white/10 text-mist text-[9px] font-bold capitalize">{v}</span>
                            ))}
                          </div>
                        ) : <span className="text-mist/40">All</span>}
                      </td>
                      <td className="py-3 text-right">
                        <button onClick={() => toggleCoupon(c.id, c.is_active)}
                          className={`relative w-10 h-5 rounded-full transition-all ${c.is_active ? 'bg-primary' : 'bg-white/10'}`}>
                          <span className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-all ${c.is_active ? 'left-5.5' : 'left-0.5'}`} />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// USERS PANEL 360° — Customer & Provider deep-dive
// ─────────────────────────────────────────────────────────────────────────────
function UsersPanel360() {
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState<'all' | 'customer' | 'provider' | 'admin'>('all');
  const [users360, setUsers360] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<any | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detail, setDetail] = useState<any | null>(null);
  const [actionLoading, setActionLoading] = useState('');

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      let q = supabase.from('profiles').select('id, full_name, email, role, avatar_url, created_at, is_suspended, kyc_status, referral_code, pearl_points_balance, wallet_balance').order('created_at', { ascending: false }).limit(100);
      if (roleFilter !== 'all') q = q.eq('role', roleFilter);
      if (search) q = q.ilike('full_name', `%${search}%`);
      const { data } = await q;
      setUsers360((data as any[]) || []);
      setLoading(false);
    };
    load();
  }, [search, roleFilter]);

  const openDetail = async (user: any) => {
    setSelected(user);
    setDetailLoading(true);
    const [bkRes, txRes, listRes] = await Promise.all([
      db.from('bookings').select('id, vertical, status, total_price, created_at').or(`customer_id.eq.${user.id},provider_id.eq.${user.id}`).order('created_at', { ascending: false }).limit(20),
      db.from('wallet_transactions').select('id, type, amount, description, created_at').eq('user_id', user.id).order('created_at', { ascending: false }).limit(20),
      db.from('listings').select('id, title, vertical, status').eq('provider_id', user.id).limit(10),
    ]);
    setDetail({
      bookings: (bkRes.data as any[]) || [],
      transactions: (txRes.data as any[]) || [],
      listings: (listRes.data as any[]) || [],
    });
    setDetailLoading(false);
  };

  const doAction = async (action: string, userId: string) => {
    setActionLoading(action);
    if (action === 'suspend') {
      await supabase.from('profiles').update({ is_suspended: !selected?.is_suspended }).eq('id', userId);
      setSelected((u: any) => u ? { ...u, is_suspended: !u.is_suspended } : u);
    } else if (action === 'verify') {
      await supabase.from('profiles').update({ kyc_status: 'verified' }).eq('id', userId);
      setSelected((u: any) => u ? { ...u, kyc_status: 'verified' } : u);
    } else if (action === 'notify') {
      await db.from('notifications').insert({ user_id: userId, type: 'admin', title: 'Message from Admin', body: 'You have a message from the Pearl Hub team.', read: false });
    }
    setActionLoading('');
  };

  return (
    <div className="flex gap-6 h-[calc(100vh-250px)] min-h-[600px]">
      {/* User List */}
      <div className="w-80 shrink-0 flex flex-col gap-4">
        <input type="text" placeholder="Search users…" value={search}
          onChange={e => setSearch(e.target.value)}
          className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-primary/50"
        />
        <div className="flex gap-1.5 flex-wrap">
          {(['all', 'customer', 'provider', 'admin'] as const).map(r => (
            <button key={r} onClick={() => setRoleFilter(r)}
              className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all ${
                roleFilter === r ? 'bg-primary text-white' : 'bg-white/5 text-mist hover:bg-white/10'
              }`}>{r}</button>
          ))}
        </div>
        <div className="flex-1 overflow-y-auto space-y-2 pr-1">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
            </div>
          ) : users360.map((u: any) => (
            <button key={u.id} onClick={() => openDetail(u)}
              className={`w-full text-left p-4 rounded-2xl border transition-all ${
                selected?.id === u.id ? 'border-primary/50 bg-primary/10' : 'border-white/5 bg-white/3 hover:bg-white/5'
              }`}>
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-primary/20 flex items-center justify-center text-primary font-black text-sm shrink-0">
                  {(u.full_name || u.email || '?')[0].toUpperCase()}
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-black text-white truncate">{u.full_name || 'No name'}</p>
                  <p className="text-[10px] text-mist truncate">{u.email}</p>
                  <div className="flex items-center gap-1.5 mt-0.5">
                    <span className={`px-1.5 py-0.5 rounded text-[8px] font-black uppercase ${
                      u.role === 'admin' ? 'bg-primary/20 text-primary' :
                      u.role === 'provider' ? 'bg-emerald-500/20 text-emerald-400' :
                      'bg-sapphire/20 text-sapphire'
                    }`}>{u.role}</span>
                    {u.is_suspended && <span className="px-1.5 py-0.5 rounded text-[8px] font-black uppercase bg-ruby/20 text-ruby">Suspended</span>}
                    {u.kyc_status === 'verified' && <span className="text-emerald-400 text-[10px]">✓</span>}
                  </div>
                </div>
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Detail Panel */}
      <div className="flex-1 overflow-y-auto">
        {!selected ? (
          <div className="h-full flex items-center justify-center">
            <p className="text-mist/40 text-sm font-bold">Select a user to view 360° profile</p>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Profile Card */}
            <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
              <div className="flex items-start justify-between gap-4 flex-wrap">
                <div className="flex items-center gap-4">
                  <div className="w-16 h-16 rounded-2xl bg-primary/20 flex items-center justify-center text-primary font-black text-2xl">
                    {(selected.full_name || '?')[0].toUpperCase()}
                  </div>
                  <div>
                    <h3 className="text-xl font-black text-white">{selected.full_name || 'No name'}</h3>
                    <p className="text-mist text-sm">{selected.email}</p>
                    <div className="flex items-center gap-2 mt-1 flex-wrap">
                      <span className={`px-2 py-0.5 rounded-lg text-[10px] font-black uppercase ${
                        selected.role === 'admin' ? 'bg-primary/20 text-primary' :
                        selected.role === 'provider' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-sapphire/20 text-sapphire'
                      }`}>{selected.role}</span>
                      <span className={`px-2 py-0.5 rounded-lg text-[10px] font-black uppercase ${
                        selected.kyc_status === 'verified' ? 'bg-emerald-500/20 text-emerald-400' :
                        selected.kyc_status === 'pending' ? 'bg-amber-500/20 text-amber-400' : 'bg-white/10 text-mist'
                      }`}>KYC: {selected.kyc_status || 'none'}</span>
                      {selected.is_suspended && <span className="px-2 py-0.5 rounded-lg text-[10px] font-black uppercase bg-ruby/20 text-ruby">Suspended</span>}
                    </div>
                  </div>
                </div>
                {/* Quick Stats */}
                <div className="flex gap-3 flex-wrap">
                  <div className="text-center px-4 py-2 rounded-xl bg-white/5">
                    <p className="text-lg font-black text-gold">{(selected.wallet_balance || 0).toLocaleString()}</p>
                    <p className="text-[10px] text-mist font-bold uppercase">Wallet (LKR)</p>
                  </div>
                  <div className="text-center px-4 py-2 rounded-xl bg-white/5">
                    <p className="text-lg font-black text-primary">{selected.pearl_points_balance || 0}</p>
                    <p className="text-[10px] text-mist font-bold uppercase">Pearl Points</p>
                  </div>
                  <div className="text-center px-4 py-2 rounded-xl bg-white/5">
                    <p className="text-lg font-black text-mist">{selected.referral_code || '—'}</p>
                    <p className="text-[10px] text-mist font-bold uppercase">Referral Code</p>
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex flex-wrap gap-2 mt-5 pt-5 border-t border-white/5">
                <button onClick={() => doAction('suspend', selected.id)} disabled={!!actionLoading}
                  className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
                    selected.is_suspended ? 'bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30' : 'bg-ruby/20 text-ruby hover:bg-ruby/30'
                  } disabled:opacity-50`}>
                  {actionLoading === 'suspend' ? '...' : selected.is_suspended ? 'Un-Suspend' : 'Suspend'}
                </button>
                {selected.kyc_status !== 'verified' && (
                  <button onClick={() => doAction('verify', selected.id)} disabled={!!actionLoading}
                    className="px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30 transition-all disabled:opacity-50">
                    {actionLoading === 'verify' ? '...' : 'Verify KYC'}
                  </button>
                )}
                <button onClick={() => doAction('notify', selected.id)} disabled={!!actionLoading}
                  className="px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest bg-sapphire/20 text-sapphire hover:bg-sapphire/30 transition-all disabled:opacity-50">
                  {actionLoading === 'notify' ? '...' : 'Send Notification'}
                </button>
              </div>
            </div>

            {detailLoading ? (
              <div className="flex items-center justify-center py-12">
                <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
              </div>
            ) : detail && (
              <>
                {/* Listings (Providers) */}
                {detail.listings.length > 0 && (
                  <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
                    <h4 className="text-sm font-black text-white uppercase tracking-widest mb-4">Active Listings ({detail.listings.length})</h4>
                    <div className="space-y-2">
                      {detail.listings.map((l: any) => (
                        <div key={l.id} className="flex items-center justify-between p-3 rounded-xl bg-white/3">
                          <div>
                            <p className="text-sm font-bold text-white">{l.title}</p>
                            <p className="text-[10px] text-mist capitalize">{l.vertical}</p>
                          </div>
                          <span className={`px-2 py-0.5 rounded text-[9px] font-black uppercase ${
                            l.status === 'active' ? 'bg-emerald-500/20 text-emerald-400' :
                            l.status === 'pending' ? 'bg-amber-500/20 text-amber-400' : 'bg-white/10 text-mist'
                          }`}>{l.status}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Booking History */}
                <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
                  <h4 className="text-sm font-black text-white uppercase tracking-widest mb-4">
                    Booking History ({detail.bookings.length})
                  </h4>
                  {detail.bookings.length === 0 ? (
                    <p className="text-mist text-sm opacity-50">No bookings yet</p>
                  ) : (
                    <div className="space-y-2">
                      {detail.bookings.map((b: any) => (
                        <div key={b.id} className="flex items-center justify-between p-3 rounded-xl bg-white/3">
                          <div>
                            <p className="text-xs font-bold text-white capitalize">{b.vertical}</p>
                            <p className="text-[10px] text-mist">{new Date(b.created_at).toLocaleDateString()}</p>
                          </div>
                          <div className="flex items-center gap-3">
                            <span className="text-xs font-black text-gold">LKR {(b.total_price || 0).toLocaleString()}</span>
                            <span className={`px-2 py-0.5 rounded text-[9px] font-black uppercase ${
                              b.status === 'confirmed' ? 'bg-emerald-500/20 text-emerald-400' :
                              b.status === 'pending' ? 'bg-amber-500/20 text-amber-400' :
                              b.status === 'cancelled' ? 'bg-ruby/20 text-ruby' : 'bg-white/10 text-mist'
                            }`}>{b.status}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Wallet Transactions */}
                <div className="bg-white/5 rounded-3xl border border-white/10 p-6">
                  <h4 className="text-sm font-black text-white uppercase tracking-widest mb-4">
                    Wallet Transactions ({detail.transactions.length})
                  </h4>
                  {detail.transactions.length === 0 ? (
                    <p className="text-mist text-sm opacity-50">No transactions yet</p>
                  ) : (
                    <div className="space-y-2">
                      {detail.transactions.map((t: any) => (
                        <div key={t.id} className="flex items-center justify-between p-3 rounded-xl bg-white/3">
                          <div>
                            <p className="text-xs font-bold text-white">{t.description || t.type}</p>
                            <p className="text-[10px] text-mist">{new Date(t.created_at).toLocaleDateString()}</p>
                          </div>
                          <span className={`text-sm font-black ${(t.amount || 0) >= 0 ? 'text-emerald-400' : 'text-ruby'}`}>
                            {(t.amount || 0) >= 0 ? '+' : ''}LKR {Math.abs(t.amount || 0).toLocaleString()}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// ── WhatsApp Settings Section ─────────────────────────────
function WhatsAppSettingsSection() {
  const [testPhone, setTestPhone] = useState('');
  const [testMsg, setTestMsg] = useState('');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);

  const handleTest = async () => {
    if (!testPhone.trim() || !testMsg.trim()) return;
    setSending(true);
    setResult(null);
    try {
      const { sendWhatsApp } = await import('@/lib/whatsapp');
      const res = await sendWhatsApp({ type: 'text', to: testPhone.replace(/[^0-9]/g, ''), message: testMsg });
      setResult(res.success ? { type: 'ok', text: 'Message sent successfully!' } : { type: 'err', text: res.error ?? 'Failed to send.' });
    } catch (e) {
      setResult({ type: 'err', text: String(e) });
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="mt-10 p-6 bg-emerald-500/5 border border-emerald-500/20 rounded-3xl">
      <h3 className="text-sm font-black text-emerald-400 uppercase tracking-widest mb-4 flex items-center gap-2">
        💬 WhatsApp Integration (wa-api.me)
      </h3>
      <p className="text-xs text-mist mb-4 leading-relaxed">
        WhatsApp messages are sent via the <code className="text-emerald-400">WA_API_TOKEN</code> Supabase secret.
        Set it in your Supabase project dashboard under <strong>Settings → Edge Functions → Secrets</strong>.
        Messages are delivered through <code className="text-emerald-400">POST /send-whatsapp</code> edge function.
      </p>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <div>
          <label className="block text-[10px] font-black uppercase tracking-widest text-mist mb-1.5">Test Phone (with country code)</label>
          <input value={testPhone} onChange={e => setTestPhone(e.target.value)} placeholder="e.g. 94771234567"
            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-pearl outline-none focus:border-emerald-500/50" />
        </div>
        <div>
          <label className="block text-[10px] font-black uppercase tracking-widest text-mist mb-1.5">Test Message</label>
          <input value={testMsg} onChange={e => setTestMsg(e.target.value)} placeholder="Hello from Pearl Hub admin!"
            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-pearl outline-none focus:border-emerald-500/50" />
        </div>
      </div>
      {result && (
        <div className={`px-4 py-2.5 rounded-lg text-xs font-bold mb-3 ${result.type === 'ok' ? 'bg-emerald-500/10 text-emerald-400' : 'bg-ruby/10 text-ruby'}`}>{result.text}</div>
      )}
      <button onClick={handleTest} disabled={sending || !testPhone.trim() || !testMsg.trim()}
        className="px-5 py-2 rounded-xl bg-emerald-500/20 text-emerald-400 text-xs font-black uppercase tracking-widest hover:bg-emerald-500/30 transition-all disabled:opacity-40">
        {sending ? 'Sending…' : '📤 Send Test Message'}
      </button>
      <div className="mt-4 pt-4 border-t border-white/5">
        <p className="text-[10px] text-mist/50 font-bold uppercase tracking-wider mb-2">Automatic WhatsApp triggers:</p>
        <ul className="text-[11px] text-mist/60 space-y-1">
          <li>✅ Payment confirmed → customer receives receipt</li>
          <li>✅ Booking confirmed → customer & provider notified</li>
          <li>🔜 OTP verification for phone-based sign-in</li>
          <li>🔜 Reminder 24h before check-in</li>
        </ul>
      </div>
    </div>
  );
}

// ── Pages / CMS Panel ─────────────────────────────────────────────────────────
interface SitePage {
  id: string;
  slug: string;
  title: string;
  hero_image: string | null;
  content: string;
  meta_desc: string | null;
  is_published: boolean;
  updated_at: string;
}

function PagesPanel() {
  const [pages, setPages] = useState<SitePage[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<SitePage | null>(null);
  const [saving, setSaving] = useState(false);
  const [draft, setDraft] = useState<Partial<SitePage>>({});
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);

  useEffect(() => {
    db.from('site_pages').select('*').order('slug')
      .then(({ data, error }) => {
        if (!error && data) setPages(data as SitePage[]);
        setLoading(false);
      });
  }, []);

  const openPage = (p: SitePage) => {
    setSelected(p);
    setDraft({ title: p.title, hero_image: p.hero_image ?? '', content: p.content, meta_desc: p.meta_desc ?? '', is_published: p.is_published });
    setMsg(null);
  };

  const handleSave = async () => {
    if (!selected) return;
    setSaving(true);
    setMsg(null);
    const { error } = await db.from('site_pages').update({
      title: draft.title,
      hero_image: (draft.hero_image as string)?.trim() || null,
      content: draft.content,
      meta_desc: (draft.meta_desc as string)?.trim() || null,
      is_published: draft.is_published,
    }).eq('id', selected.id);
    if (error) {
      setMsg({ type: 'err', text: error.message });
    } else {
      setPages(prev => prev.map(p => p.id === selected.id ? { ...p, ...draft } as SitePage : p));
      setSelected(prev => prev ? { ...prev, ...draft } as SitePage : null);
      setMsg({ type: 'ok', text: 'Page saved successfully.' });
    }
    setSaving(false);
  };

  const handleCreate = async () => {
    const slug = prompt('Enter page slug (e.g. "blog", "guides"):');
    if (!slug?.trim()) return;
    const { data, error } = await db.from('site_pages').insert({
      slug: slug.trim().toLowerCase().replace(/\s+/g, '-'),
      title: slug.trim(),
      content: `# ${slug.trim()}\n\nAdd your content here.`,
    }).select().single();
    if (!error && data) {
      setPages(prev => [...prev, data as SitePage]);
      openPage(data as SitePage);
    }
  };

  const SLUG_LABELS: Record<string, string> = {
    home: 'Home Hero', about: 'About Us', contact: 'Contact', terms: 'Terms', privacy: 'Privacy', faq: 'FAQ',
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 min-h-[600px]">
      {/* Page list */}
      <div className="bg-white/5 rounded-2xl border border-white/10 p-4 space-y-2">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-sm font-black text-pearl uppercase tracking-widest">📝 Site Pages</h2>
          <button onClick={handleCreate} className="text-[10px] font-black uppercase tracking-wider bg-primary/20 text-primary px-3 py-1.5 rounded-lg hover:bg-primary/30 transition-all">+ New Page</button>
        </div>
        {loading ? (
          <div className="space-y-2">{[1,2,3,4].map(i => <div key={i} className="h-12 bg-white/5 rounded-xl animate-pulse" />)}</div>
        ) : pages.map(p => (
          <button key={p.id} onClick={() => openPage(p)}
            className={`w-full text-left px-4 py-3 rounded-xl transition-all border ${selected?.id === p.id ? 'bg-primary/20 border-primary/30 text-pearl' : 'bg-white/3 border-transparent text-mist hover:bg-white/8'}`}>
            <div className="text-xs font-black">{SLUG_LABELS[p.slug] || p.title}</div>
            <div className="text-[10px] text-mist/60 mt-0.5">/{p.slug} · {p.is_published ? '✅ Live' : '🔴 Draft'}</div>
          </button>
        ))}
      </div>

      {/* Editor */}
      <div className="lg:col-span-2 bg-white/5 rounded-2xl border border-white/10 p-6">
        {!selected ? (
          <div className="flex flex-col items-center justify-center h-full text-mist/50 py-20">
            <div className="text-4xl mb-3">📝</div>
            <p className="text-sm font-bold">Select a page to edit</p>
          </div>
        ) : (
          <div className="space-y-5">
            {msg && (
              <div className={`px-4 py-2.5 rounded-lg text-xs font-bold ${msg.type === 'ok' ? 'bg-emerald-500/10 text-emerald-400' : 'bg-ruby/10 text-ruby'}`}>{msg.text}</div>
            )}

            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-base font-black text-pearl">{SLUG_LABELS[selected.slug] || selected.title}</h3>
                <p className="text-[11px] text-mist/60 mt-0.5">/{selected.slug} · Last updated {new Date(selected.updated_at).toLocaleDateString()}</p>
              </div>
              <div className="flex items-center gap-3">
                <label className="flex items-center gap-2 text-xs font-bold text-mist cursor-pointer">
                  <input type="checkbox" checked={!!draft.is_published} onChange={e => setDraft(d => ({ ...d, is_published: e.target.checked }))} className="rounded" />
                  Published
                </label>
                <button onClick={handleSave} disabled={saving}
                  className="px-5 py-2 rounded-xl bg-primary text-white text-xs font-black uppercase tracking-widest disabled:opacity-60 hover:bg-primary/90 transition-all">
                  {saving ? 'Saving…' : 'Save Page'}
                </button>
              </div>
            </div>

            <div>
              <label className="block text-[10px] font-black uppercase tracking-widest text-mist mb-1.5">Page Title</label>
              <input value={draft.title ?? ''} onChange={e => setDraft(d => ({ ...d, title: e.target.value }))}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-pearl outline-none focus:border-primary/50 transition-colors" />
            </div>

            <div>
              <label className="block text-[10px] font-black uppercase tracking-widest text-mist mb-1.5">Hero / Banner Image URL</label>
              <input value={draft.hero_image ?? ''} onChange={e => setDraft(d => ({ ...d, hero_image: e.target.value }))}
                placeholder="https://..." className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-pearl outline-none focus:border-primary/50 transition-colors placeholder:text-mist/30" />
              {(draft.hero_image as string)?.startsWith('http') && (
                <img src={draft.hero_image as string} alt="Hero preview" className="mt-2 w-full h-32 object-cover rounded-xl border border-white/10" onError={e => { (e.target as HTMLImageElement).style.display = 'none'; }} />
              )}
            </div>

            <div>
              <label className="block text-[10px] font-black uppercase tracking-widest text-mist mb-1.5">SEO Meta Description</label>
              <input value={draft.meta_desc ?? ''} onChange={e => setDraft(d => ({ ...d, meta_desc: e.target.value }))}
                placeholder="160-char description for search engines" maxLength={160}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-pearl outline-none focus:border-primary/50 transition-colors placeholder:text-mist/30" />
            </div>

            <div>
              <label className="block text-[10px] font-black uppercase tracking-widest text-mist mb-1.5">Page Content (Markdown)</label>
              <textarea value={draft.content ?? ''} onChange={e => setDraft(d => ({ ...d, content: e.target.value }))} rows={14}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-pearl font-mono outline-none focus:border-primary/50 transition-colors resize-none leading-relaxed" />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
