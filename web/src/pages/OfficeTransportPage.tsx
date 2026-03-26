import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useAuth } from "@/context/AuthContext";
import { db } from "@/integrations/supabase/client";
import TrustBanner from "@/components/TrustBanner";
import { useOfficeTransportPlans, useOfficeTransportRoutes, useUserOfficeWallet, useUserOfficeSubscription } from "@/hooks/useListings";
import { QrCode, Wallet, Bus, Clock, CheckCircle, RefreshCw, MapPin, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

// ── QR Code display using simple SVG encoding ─────────────────────
function QRDisplay({ data, size = 200 }: { data: string; size?: number }) {
  // Creates a simple visual QR pattern using the data as seed
  const seed = data.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  const cells = 21;
  const cell = size / cells;
  const grid: boolean[][] = Array.from({ length: cells }, (_, r) =>
    Array.from({ length: cells }, (_, c) => {
      // Fixed finder patterns
      if (r < 7 && c < 7) return true;
      if (r < 7 && c >= cells - 7) return true;
      if (r >= cells - 7 && c < 7) return true;
      // Data modules (seeded pseudo-random for visual fidelity)
      const n = (seed * (r + 1) * (c + 1)) % 17;
      return n < 8;
    })
  );

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="rounded-xl overflow-hidden">
      <rect width={size} height={size} fill="white" />
      {grid.map((row, r) =>
        row.map((filled, c) =>
          filled ? <rect key={`${r}-${c}`} x={c * cell} y={r * cell} width={cell} height={cell} fill="#1a1a1a" /> : null
        )
      )}
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
const OfficeTransportPage = () => {
  const { user, profile } = useAuth();
  const { data: plans = [], isLoading: plansLoading } = useOfficeTransportPlans();
  const { data: routes = [], isLoading: routesLoading } = useOfficeTransportRoutes();
  const { data: wallet, refetch: refetchWallet } = useUserOfficeWallet(user?.id);
  const { data: subscription, refetch: refetchSub } = useUserOfficeSubscription(user?.id);

  const [tab, setTab] = useState<"routes" | "plans" | "wallet" | "qr">("routes");
  const [selectedRoute, setSelectedRoute] = useState<any | null>(null);
  const [selectedPlan, setSelectedPlan] = useState<any | null>(null);
  const [subscribing, setSubscribing] = useState(false);
  const [topupModal, setTopupModal] = useState(false);
  const [topupAmt, setTopupAmt] = useState(500);
  const [topping, setTopping] = useState(false);
  const [subModal, setSubModal] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const showToast = (msg: string) => { setToast(msg); setTimeout(() => setToast(null), 3500); };

  const handleSubscribe = async () => {
    if (!user || !selectedPlan) return;
    setSubscribing(true);
    const expires = new Date();
    expires.setDate(expires.getDate() + (selectedPlan.duration === 'weekly' ? 7 : 30));
    const { error } = await db.from('office_transport_subscriptions').insert({
      user_id: user.id,
      plan_id: selectedPlan.id,
      route_id: selectedRoute?.id ?? null,
      expires_at: expires.toISOString(),
      status: 'active',
    });
    setSubscribing(false);
    if (error) showToast('❌ Subscription failed: ' + error.message);
    else { showToast('✅ Subscribed to ' + selectedPlan.name); setSubModal(false); refetchSub(); }
  };

  const handleTopup = async () => {
    if (!user || topupAmt <= 0) return;
    setTopping(true);
    const { error } = await db.rpc('topup_office_transport_wallet', {
      p_user_id: user.id,
      p_amount: topupAmt,
      p_reference: 'manual_topup',
    });
    setTopping(false);
    if (error) showToast('❌ Top-up failed: ' + error.message);
    else { showToast(`✅ Wallet topped up by Rs. ${topupAmt.toLocaleString()}`); setTopupModal(false); refetchWallet(); }
  };

  const qrData = user ? `PEARL-OT:${user.id.slice(0, 8)}:${subscription?.id?.slice(0, 8) ?? 'NOSUB'}:${Date.now()}` : '';

  return (
    <div className="min-h-screen bg-background">
      {/* Toast */}
      {toast && (
        <div className="fixed top-6 right-6 z-50 bg-zinc-900 border border-white/10 text-white px-6 py-3 rounded-2xl shadow-2xl text-sm font-bold animate-in slide-in-from-right">{toast}</div>
      )}

      {/* Hero */}
      <div className="bg-gradient-to-br from-sapphire to-sapphire/70 py-10">
        <div className="container">
          <div className="inline-flex items-center gap-1.5 bg-white/15 text-pearl text-[11px] font-bold uppercase tracking-wider px-3 py-1 rounded-full mb-2">🚌 Office Transport</div>
          <h1 className="text-pearl text-3xl font-display">Pearl Bus</h1>
          <p className="text-pearl/75 mt-1.5">Rosa Bus • A/C Bus • Daily Commute Subscriptions • QR-based Boarding</p>
        </div>
      </div>

      <TrustBanner stats={[
        { value: routes.length.toString() || "0", label: "Active Routes", icon: "🛣️" },
        { value: "24/7", label: "Customer Support", icon: "📞" },
        { value: "QR", label: "Contactless Boarding", icon: "📱" },
        { value: "Fixed", label: "Monthly Plans", icon: "📅" },
      ]} />

      {/* Wallet + Subscription Quick Summary */}
      {user && (
        <div className="container py-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="bg-gradient-to-br from-primary/10 to-primary/5 rounded-2xl border border-primary/20 p-6 flex items-center gap-4">
              <div className="w-14 h-14 rounded-2xl bg-primary/20 flex items-center justify-center"><Wallet className="text-primary" size={24} /></div>
              <div>
                <p className="text-muted-foreground text-xs font-bold uppercase tracking-widest">Wallet Balance</p>
                <p className="text-3xl font-black text-primary mt-0.5">Rs. {(wallet?.balance ?? 0).toLocaleString()}</p>
              </div>
              <Button onClick={() => setTopupModal(true)} className="ml-auto bg-primary hover:bg-primary/90 text-white font-black text-xs px-4 h-9 rounded-xl">Top-Up</Button>
            </div>
            <div className="bg-gradient-to-br from-sapphire/10 to-sapphire/5 rounded-2xl border border-sapphire/20 p-6">
              {subscription ? (
                <div className="flex items-center gap-4">
                  <div className="w-14 h-14 rounded-2xl bg-sapphire/20 flex items-center justify-center"><CheckCircle className="text-sapphire" size={24} /></div>
                  <div>
                    <p className="text-muted-foreground text-xs font-bold uppercase tracking-widest">Active Plan</p>
                    <p className="text-lg font-black text-foreground mt-0.5">{subscription.plan?.name}</p>
                    <p className="text-xs text-muted-foreground">Expires {new Date(subscription.expires_at).toLocaleDateString()}</p>
                  </div>
                  <button onClick={() => setTab('qr')} className="ml-auto px-4 py-2 bg-sapphire/10 text-sapphire rounded-xl text-xs font-black hover:bg-sapphire hover:text-white transition-all flex items-center gap-1"><QrCode size={14} /> My QR</button>
                </div>
              ) : (
                <div className="flex items-center gap-4">
                  <div className="w-14 h-14 rounded-2xl bg-muted flex items-center justify-center"><Bus className="text-muted-foreground" size={24} /></div>
                  <div>
                    <p className="text-foreground font-black">No active subscription</p>
                    <p className="text-muted-foreground text-xs mt-1">Subscribe to a plan for unlimited daily travel</p>
                  </div>
                  <Button onClick={() => setTab('plans')} className="ml-auto bg-sapphire hover:bg-sapphire/90 text-white font-black text-xs px-4 h-9 rounded-xl">View Plans</Button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Tab Navigation */}
      <div className="container">
        <div className="flex gap-1 bg-muted/30 rounded-2xl p-1 border border-border w-fit mb-8">
          {[
            { id: 'routes', label: 'Routes', icon: '🛣️' },
            { id: 'plans', label: 'Plans', icon: '📅' },
            { id: 'wallet', label: 'Wallet', icon: '💳' },
            { id: 'qr', label: 'My QR', icon: '📱' },
          ].map(t => (
            <button key={t.id} onClick={() => setTab(t.id as typeof tab)}
              className={`px-5 py-2.5 rounded-xl text-sm font-black transition-all ${tab === t.id ? 'bg-white shadow text-foreground' : 'text-muted-foreground hover:text-foreground'}`}>
              {t.icon} {t.label}
            </button>
          ))}
        </div>

        <AnimatePresence mode="wait">
          {/* Routes Tab */}
          {tab === 'routes' && (
            <motion.div key="routes" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="pb-16">
              <h2 className="text-2xl font-black mb-6">Available Routes</h2>
              {routesLoading ? (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {[1,2,3,4].map(i => <div key={i} className="h-40 bg-muted/30 rounded-2xl animate-pulse" />)}
                </div>
              ) : routes.length === 0 ? (
                <div className="text-center py-20 bg-muted/10 rounded-3xl border border-border">
                  <Bus size={48} className="mx-auto mb-4 text-muted-foreground opacity-40" />
                  <p className="font-black text-xl text-foreground">No active routes yet</p>
                  <p className="text-muted-foreground text-sm mt-2">Routes will appear here when the admin configures them.</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {routes.map((route: any) => (
                    <div key={route.id} onClick={() => setSelectedRoute(route)}
                      className={`bg-card rounded-2xl border p-6 cursor-pointer hover:border-primary/50 transition-all ${selectedRoute?.id === route.id ? 'border-primary bg-primary/5' : 'border-border'}`}>
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <h3 className="font-black text-lg">{route.name}</h3>
                          <p className="text-muted-foreground text-xs mt-1">{(route.days_active || []).join(' · ')}</p>
                        </div>
                        <Badge variant="outline" className="text-xs font-bold uppercase border-emerald-500/30 text-emerald-600">{route.status}</Badge>
                      </div>
                      <div className="flex items-center gap-2 text-sm text-muted-foreground mb-4">
                        <Clock size={14} />
                        <span>{route.departure_time?.slice(0, 5)} depart</span>
                        {route.return_time && <><ArrowRight size={12} /><span>{route.return_time.slice(0, 5)} return</span></>}
                      </div>
                      <div className="flex items-center gap-1 text-muted-foreground text-xs">
                        <MapPin size={12} />
                        <span>{(route.stops || []).length} stops</span>
                        {route.flat_fare && <span className="ml-auto font-black text-primary">Rs. {route.flat_fare} flat</span>}
                        {!route.flat_fare && route.fare_per_km && <span className="ml-auto font-black text-primary">Rs. {route.fare_per_km}/km</span>}
                      </div>
                    </div>
                  ))}
                </div>
              )}
              {selectedRoute && (
                <div className="mt-6 p-6 bg-primary/5 border border-primary/20 rounded-2xl flex items-center gap-4">
                  <div>
                    <p className="text-xs font-black text-muted-foreground uppercase tracking-widest">Selected Route</p>
                    <p className="font-black text-lg">{selectedRoute.name}</p>
                  </div>
                  <Button onClick={() => setTab('plans')} className="ml-auto bg-primary text-white font-black px-6 h-10 rounded-xl">Subscribe →</Button>
                </div>
              )}
            </motion.div>
          )}

          {/* Plans Tab */}
          {tab === 'plans' && (
            <motion.div key="plans" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="pb-16">
              <h2 className="text-2xl font-black mb-6">Subscription Plans</h2>
              {plansLoading ? (
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  {[1,2,3,4].map(i => <div key={i} className="h-48 bg-muted/30 rounded-2xl animate-pulse" />)}
                </div>
              ) : plans.length === 0 ? (
                <div className="text-center py-20 bg-muted/10 rounded-3xl border border-border">
                  <p className="font-black text-xl">No plans configured yet</p>
                  <p className="text-muted-foreground text-sm mt-2">Admin needs to configure subscription plans.</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
                  {plans.map((plan: any) => (
                    <div key={plan.id} className={`rounded-3xl border p-6 flex flex-col cursor-pointer transition-all hover:shadow-lg ${selectedPlan?.id === plan.id ? 'border-primary bg-primary/5 shadow-primary/10' : 'border-border bg-card'}`}
                      onClick={() => setSelectedPlan(plan)}>
                      <Badge variant="outline" className={`w-fit mb-3 text-[10px] font-black uppercase ${plan.duration === 'monthly' ? 'border-primary/30 text-primary' : 'border-sapphire/30 text-sapphire'}`}>{plan.duration}</Badge>
                      <h3 className="font-black text-xl">{plan.name}</h3>
                      <p className="text-3xl font-black mt-3 text-primary">Rs. {plan.price.toLocaleString()}</p>
                      <p className="text-muted-foreground text-xs mt-1">/{plan.duration}</p>
                      <ul className="mt-4 space-y-1 text-xs text-muted-foreground flex-1">
                        {plan.ride_limit ? <li>✓ Up to {plan.ride_limit} rides</li> : <li>✓ Unlimited rides</li>}
                        {plan.km_limit && <li>✓ {plan.km_limit} km included</li>}
                        <li>✓ QR-based boarding</li>
                        <li>✓ Wallet compatible</li>
                      </ul>
                      <Button onClick={() => { setSelectedPlan(plan); setSubModal(true); }} className="mt-5 w-full bg-primary hover:bg-primary/90 text-white font-black rounded-xl">Subscribe</Button>
                    </div>
                  ))}
                </div>
              )}
            </motion.div>
          )}

          {/* Wallet Tab */}
          {tab === 'wallet' && (
            <motion.div key="wallet" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="pb-16">
              <div className="max-w-lg">
                <div className="bg-gradient-to-br from-primary to-primary/60 rounded-3xl p-8 text-white mb-6">
                  <p className="text-white/70 text-xs font-black uppercase tracking-widest">Pearl Bus Wallet</p>
                  <p className="text-5xl font-black mt-2">Rs. {(wallet?.balance ?? 0).toLocaleString()}</p>
                  {wallet?.updated_at && <p className="text-white/50 text-xs mt-2">Updated {new Date(wallet.updated_at).toLocaleString()}</p>}
                  <Button onClick={() => setTopupModal(true)} className="mt-6 bg-white text-primary hover:bg-white/90 font-black px-6 h-10 rounded-xl">Top Up Wallet</Button>
                </div>
                {!user && <p className="text-center text-muted-foreground text-sm py-8">Sign in to access your wallet</p>}
              </div>
            </motion.div>
          )}

          {/* QR Code Tab */}
          {tab === 'qr' && (
            <motion.div key="qr" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="pb-16">
              <div className="max-w-sm mx-auto text-center">
                <h2 className="text-2xl font-black mb-2">Boarding QR Code</h2>
                <p className="text-muted-foreground text-sm mb-8">Show this to the conductor when boarding</p>
                {user && subscription ? (
                  <div className="bg-card rounded-3xl border border-border p-8 shadow-lg">
                    <div className="flex justify-center mb-4">
                      <QRDisplay data={qrData} size={220} />
                    </div>
                    <p className="font-black text-lg mt-4">{profile?.full_name || 'Passenger'}</p>
                    <p className="text-muted-foreground text-xs mt-1">{subscription.plan?.name}</p>
                    <Badge variant="outline" className="mt-2 border-emerald-500/30 text-emerald-600 font-bold uppercase text-[10px]">Active</Badge>
                    <div className="mt-4 p-3 bg-muted/30 rounded-xl font-mono text-xs text-muted-foreground truncate">{qrData}</div>
                    <button onClick={() => window.location.reload()} className="mt-4 flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground transition-colors mx-auto">
                      <RefreshCw size={12} /> Refresh QR
                    </button>
                  </div>
                ) : user ? (
                  <div className="bg-muted/10 rounded-3xl border border-border p-8">
                    <QrCode size={64} className="mx-auto mb-4 text-muted-foreground opacity-30" />
                    <p className="font-black text-xl">No Active Subscription</p>
                    <p className="text-muted-foreground text-sm mt-2 mb-6">Subscribe to a plan to get your boarding QR code.</p>
                    <Button onClick={() => setTab('plans')} className="bg-primary text-white font-black px-8 rounded-xl">View Plans</Button>
                  </div>
                ) : (
                  <div className="bg-muted/10 rounded-3xl border border-border p-8">
                    <p className="font-black text-xl">Sign In Required</p>
                    <p className="text-muted-foreground text-sm mt-2">Sign in to view your boarding QR code.</p>
                  </div>
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Top-Up Modal */}
      <Dialog open={topupModal} onOpenChange={setTopupModal}>
        <DialogContent className="max-w-sm rounded-3xl">
          <DialogHeader><DialogTitle className="font-black text-xl">Top Up Wallet</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <p className="text-muted-foreground text-sm">Current balance: <strong>Rs. {(wallet?.balance ?? 0).toLocaleString()}</strong></p>
            <div className="flex flex-wrap gap-2">
              {[200, 500, 1000, 2000, 5000].map(a => (
                <button key={a} onClick={() => setTopupAmt(a)} className={`px-4 py-2 rounded-xl font-bold text-sm border transition-all ${topupAmt === a ? 'bg-primary text-white border-primary' : 'border-border text-muted-foreground hover:border-primary/50'}`}>Rs. {a}</button>
              ))}
            </div>
            <input type="number" min={100} step={100} value={topupAmt} onChange={e => setTopupAmt(+e.target.value)} className="w-full border border-input rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30" placeholder="Or enter custom amount" />
            <Button onClick={handleTopup} disabled={topping || !user} className="w-full bg-primary text-white font-black rounded-xl h-11">
              {topping ? 'Processing…' : `Top Up Rs. ${topupAmt.toLocaleString()}`}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Subscribe Modal */}
      <Dialog open={subModal} onOpenChange={setSubModal}>
        <DialogContent className="max-w-sm rounded-3xl">
          <DialogHeader><DialogTitle className="font-black text-xl">Confirm Subscription</DialogTitle></DialogHeader>
          {selectedPlan && (
            <div className="space-y-4 py-2">
              <div className="bg-primary/5 border border-primary/20 rounded-2xl p-4">
                <p className="font-black text-lg">{selectedPlan.name}</p>
                <p className="text-primary text-2xl font-black mt-1">Rs. {selectedPlan.price.toLocaleString()} <span className="text-sm text-muted-foreground font-bold">/{selectedPlan.duration}</span></p>
                {selectedRoute && <p className="text-muted-foreground text-xs mt-2">Route: {selectedRoute.name}</p>}
              </div>
              <p className="text-muted-foreground text-xs">Your subscription will start immediately and be valid for {selectedPlan.duration === 'weekly' ? '7 days' : '30 days'}.</p>
              <div className="flex gap-3">
                <Button onClick={() => setSubModal(false)} variant="outline" className="flex-1">Cancel</Button>
                <Button onClick={handleSubscribe} disabled={subscribing || !user} className="flex-1 bg-primary text-white font-black">
                  {subscribing ? 'Subscribing…' : 'Confirm'}
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default OfficeTransportPage;
