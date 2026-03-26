import { useState } from "react";
import { motion } from "framer-motion";
import { useAuth } from "@/context/AuthContext";
import { db } from "@/integrations/supabase/client";
import { useParcelItemTypes } from "@/hooks/useListings";
import LeafletMap from "@/components/LeafletMap";
import TrustBanner from "@/components/TrustBanner";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Package, Search, MapPin, CheckCircle, Clock, Truck } from "lucide-react";

const STATUS_STEPS = ["pending", "confirmed", "picked_up", "in_transit", "delivered"];
const STATUS_LABELS: Record<string, string> = {
  pending: "Pending",
  confirmed: "Confirmed",
  picked_up: "Picked Up",
  in_transit: "In Transit",
  delivered: "Delivered",
  cancelled: "Cancelled",
};
const STATUS_ICONS: Record<string, string> = {
  pending: "🕐",
  confirmed: "✅",
  picked_up: "📦",
  in_transit: "🚚",
  delivered: "🏠",
  cancelled: "❌",
};

const ParcelTrackingPage = () => {
  const { user } = useAuth();
  const { data: itemTypes = [] } = useParcelItemTypes();

  // Send form
  const [tab, setTab] = useState<"send" | "track">("send");
  const [pickupAddress, setPickupAddress] = useState("");
  const [dropAddress, setDropAddress] = useState("");
  const [pickupCoords, setPickupCoords] = useState<[number, number] | null>(null);
  const [dropCoords, setDropCoords] = useState<[number, number] | null>(null);
  const [selectingPin, setSelectingPin] = useState<"pickup" | "drop" | null>(null);
  const [senderName, setSenderName] = useState("");
  const [senderPhone, setSenderPhone] = useState("");
  const [recipientName, setRecipientName] = useState("");
  const [recipientPhone, setRecipientPhone] = useState("");
  const [itemTypeId, setItemTypeId] = useState("");
  const [fragile, setFragile] = useState(false);
  const [insured, setInsured] = useState(false);
  const [notes, setNotes] = useState("");

  // Track form
  const [trackingId, setTrackingId] = useState("");
  const [tracked, setTracked] = useState<any | null>(null);
  const [tracking, setTracking] = useState(false);
  const [trackError, setTrackError] = useState<string | null>(null);

  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState<any | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const showToast = (msg: string) => { setToast(msg); setTimeout(() => setToast(null), 3500); };

  const handleSend = async () => {
    if (!user) { showToast("Please sign in to send a parcel."); return; }
    if (!pickupAddress || !dropAddress || !senderPhone || !recipientPhone) { showToast("Please fill in all required fields."); return; }
    setSending(true);
    const selectedType = itemTypes.find((t: any) => t.id === itemTypeId) as any;
    const baseFare = selectedType ? (selectedType.base_price || 350) : 350;
    const insuranceFee = insured ? 150 : 0;
    const { data, error } = await db.from("parcel_deliveries").insert({
      sender_user_id: user.id,
      item_type_id: itemTypeId || null,
      sender_name: senderName || null,
      sender_phone: senderPhone,
      recipient_name: recipientName || null,
      recipient_phone: recipientPhone,
      pickup_address: pickupAddress,
      dropoff_address: dropAddress,
      pickup_lat: pickupCoords?.[0] ?? null,
      pickup_lng: pickupCoords?.[1] ?? null,
      dropoff_lat: dropCoords?.[0] ?? null,
      dropoff_lng: dropCoords?.[1] ?? null,
      fragile,
      insured,
      notes: notes || null,
      fare: baseFare + insuranceFee,
      insurance_fee: insuranceFee,
      status: "pending",
    }).select().single();
    setSending(false);
    if (error) showToast("❌ Could not place order: " + error.message);
    else { setSent(data); showToast("✅ Parcel request submitted!"); }
  };

  const handleTrack = async () => {
    if (!trackingId.trim()) return;
    setTracking(true); setTracked(null); setTrackError(null);
    const { data, error } = await db.from("parcel_deliveries")
      .select("*, parcel_item_types(name)")
      .eq("id", trackingId.trim())
      .single();
    setTracking(false);
    if (error || !data) setTrackError("No parcel found with that ID.");
    else setTracked(data);
  };

  const handleMapSelect = (lat: number, lng: number, address?: string) => {
    if (selectingPin === "pickup") {
      setPickupCoords([lat, lng]);
      if (address) setPickupAddress(address);
      setSelectingPin(null);
    } else if (selectingPin === "drop") {
      setDropCoords([lat, lng]);
      if (address) setDropAddress(address);
      setSelectingPin(null);
    }
  };

  const mapCenter: [number, number] = pickupCoords ?? [6.9271, 79.8612];
  const mapMarkers = [
    ...(pickupCoords ? [{ lat: pickupCoords[0], lng: pickupCoords[1], title: "Pickup", location: pickupAddress, emoji: "📦", type: "vehicle" as const }] : []),
    ...(dropCoords ? [{ lat: dropCoords[0], lng: dropCoords[1], title: "Drop-off", location: dropAddress, emoji: "🏠", type: "vehicle" as const }] : []),
  ];

  return (
    <div className="min-h-screen bg-background">
      {toast && <div className="fixed top-6 right-6 z-50 bg-zinc-900 text-white px-6 py-3 rounded-2xl shadow-2xl text-sm font-bold border border-white/10">{toast}</div>}

      {/* Hero */}
      <div className="bg-gradient-to-br from-orange-600 to-orange-400 py-10">
        <div className="container">
          <div className="inline-flex items-center gap-1.5 bg-white/15 text-white text-[11px] font-bold uppercase tracking-wider px-3 py-1 rounded-full mb-2">📦 Parcel Delivery</div>
          <h1 className="text-white text-3xl font-display">Pearl Parcel Service</h1>
          <p className="text-white/80 mt-1.5">Same-day door-to-door delivery across Sri Lanka</p>
        </div>
      </div>

      <TrustBanner stats={[
        { value: "Same", label: "Day Delivery", icon: "⚡" },
        { value: "Live", label: "Parcel Tracking", icon: "📍" },
        { value: "OTP", label: "Secure Handover", icon: "🔐" },
        { value: "Rs. 350", label: "Starting Fare", icon: "💰" },
      ]} />

      {/* Tabs */}
      <div className="container pt-6">
        <div className="flex gap-2 mb-8">
          {[
            { id: "send", label: "📦 Send a Parcel" },
            { id: "track", label: "🔍 Track Parcel" },
          ].map(t => (
            <button key={t.id} onClick={() => setTab(t.id as typeof tab)}
              className={`px-5 py-2.5 rounded-xl font-bold text-sm transition-all ${tab === t.id ? 'bg-primary text-white shadow' : 'bg-muted text-muted-foreground hover:bg-muted/80'}`}>
              {t.label}
            </button>
          ))}
        </div>

        {/* SEND TAB */}
        {tab === "send" && (
          <div className="grid grid-cols-1 lg:grid-cols-5 gap-8 pb-12">
            <div className="lg:col-span-2 space-y-6">
              {sent ? (
                <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-2xl p-6">
                  <CheckCircle className="text-emerald-500 mb-3" size={32} />
                  <h3 className="font-black text-lg">Parcel Submitted!</h3>
                  <p className="text-muted-foreground text-sm mt-1">Tracking ID:</p>
                  <p className="font-mono font-black text-primary text-base bg-primary/5 border border-primary/20 rounded-xl px-3 py-2 mt-2 break-all">{sent.id}</p>
                  <p className="text-muted-foreground text-xs mt-3">Save this ID to track your parcel.</p>
                  <Button onClick={() => { setSent(null); }} variant="outline" className="mt-4 w-full">Send Another</Button>
                </div>
              ) : (
                <div className="bg-card rounded-3xl border border-border p-6 shadow-sm space-y-4">
                  <h2 className="font-black text-xl">Parcel Details</h2>

                  {/* Item type */}
                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Item Type</label>
                    <select value={itemTypeId} onChange={e => setItemTypeId(e.target.value)}
                      className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background">
                      <option value="">Select item type</option>
                      {(itemTypes as any[]).map((t: any) => (
                        <option key={t.id} value={t.id}>{t.icon ? `${t.icon} ` : ""}{t.name} {t.base_price ? `— Rs. ${t.base_price}` : ""}</option>
                      ))}
                    </select>
                  </div>

                  {/* Sender */}
                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Sender Name</label>
                    <input value={senderName} onChange={e => setSenderName(e.target.value)}
                      className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="Your name" />
                  </div>
                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Sender Phone *</label>
                    <input value={senderPhone} onChange={e => setSenderPhone(e.target.value)}
                      className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="+94 77 000 0000" type="tel" />
                  </div>

                  {/* Recipient */}
                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Recipient Name</label>
                    <input value={recipientName} onChange={e => setRecipientName(e.target.value)}
                      className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="Recipient name" />
                  </div>
                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Recipient Phone *</label>
                    <input value={recipientPhone} onChange={e => setRecipientPhone(e.target.value)}
                      className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="+94 77 000 0000" type="tel" />
                  </div>

                  {/* Addresses */}
                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Pickup Address *</label>
                    <div className="flex gap-2">
                      <input value={pickupAddress} onChange={e => setPickupAddress(e.target.value)}
                        className="flex-1 border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="Type or pin on map" />
                      <button onClick={() => setSelectingPin("pickup")}
                        className={`px-3 rounded-xl border text-sm font-bold transition-all ${selectingPin === 'pickup' ? 'bg-primary text-white border-primary' : 'border-border text-muted-foreground hover:border-primary/40'}`}>
                        <MapPin size={16} />
                      </button>
                    </div>
                  </div>
                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Drop-off Address *</label>
                    <div className="flex gap-2">
                      <input value={dropAddress} onChange={e => setDropAddress(e.target.value)}
                        className="flex-1 border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="Type or pin on map" />
                      <button onClick={() => setSelectingPin("drop")}
                        className={`px-3 rounded-xl border text-sm font-bold transition-all ${selectingPin === 'drop' ? 'bg-orange-500 text-white border-orange-500' : 'border-border text-muted-foreground hover:border-orange-400'}`}>
                        <MapPin size={16} />
                      </button>
                    </div>
                  </div>

                  {/* Options */}
                  <div className="flex gap-4">
                    <label className="flex items-center gap-2 cursor-pointer text-sm">
                      <input type="checkbox" checked={fragile} onChange={e => setFragile(e.target.checked)} className="accent-primary w-4 h-4" />
                      <span className="font-semibold">Fragile</span>
                    </label>
                    <label className="flex items-center gap-2 cursor-pointer text-sm">
                      <input type="checkbox" checked={insured} onChange={e => setInsured(e.target.checked)} className="accent-primary w-4 h-4" />
                      <span className="font-semibold">Insured <span className="text-muted-foreground text-xs">(+Rs. 150)</span></span>
                    </label>
                  </div>

                  <div>
                    <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Notes for driver</label>
                    <textarea value={notes} onChange={e => setNotes(e.target.value)} rows={2}
                      className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background resize-none" placeholder="Any special instructions…" />
                  </div>

                  <Button onClick={handleSend} disabled={sending}
                    className="w-full bg-orange-500 hover:bg-orange-600 text-white font-black h-12 rounded-xl">
                    {sending ? "Submitting…" : "🚀 Send Parcel"}
                  </Button>
                </div>
              )}
            </div>

            <div className="lg:col-span-3 space-y-4">
              {selectingPin && (
                <div className={`px-4 py-2.5 rounded-xl text-sm font-bold text-white text-center ${selectingPin === 'pickup' ? 'bg-primary' : 'bg-orange-500'}`}>
                  Click the map to set {selectingPin === 'pickup' ? 'pickup 📦' : 'drop-off 🏠'} location
                </div>
              )}
              <div className="rounded-2xl overflow-hidden border border-border h-72 lg:h-[28rem]">
                <LeafletMap markers={mapMarkers} center={mapCenter} zoom={12} height="100%" onSelectLocation={handleMapSelect} />
              </div>
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div className="bg-muted/30 rounded-xl p-3">
                  <p className="text-muted-foreground text-xs mb-1">Pickup</p>
                  <p className="font-semibold truncate">{pickupAddress || "Not set"}</p>
                </div>
                <div className="bg-muted/30 rounded-xl p-3">
                  <p className="text-muted-foreground text-xs mb-1">Drop-off</p>
                  <p className="font-semibold truncate">{dropAddress || "Not set"}</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TRACK TAB */}
        {tab === "track" && (
          <div className="max-w-xl mx-auto pb-12">
            <div className="bg-card rounded-3xl border border-border p-6 shadow-sm">
              <h2 className="font-black text-xl mb-6 flex items-center gap-2"><Search size={20} /> Track Parcel</h2>
              <div className="flex gap-3 mb-6">
                <input value={trackingId} onChange={e => setTrackingId(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && handleTrack()}
                  className="flex-1 border border-input rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background font-mono" placeholder="Paste your tracking ID…" />
                <Button onClick={handleTrack} disabled={tracking} className="bg-primary text-white font-black px-5">
                  {tracking ? "…" : "Track"}
                </Button>
              </div>

              {trackError && <div className="bg-destructive/10 border border-destructive/30 text-destructive text-sm rounded-xl p-4 text-center">{trackError}</div>}

              {tracked && (
                <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="space-y-4">
                  {/* Status */}
                  <div className="bg-primary/5 border border-primary/20 rounded-2xl p-5">
                    <div className="flex items-center gap-3 mb-4">
                      <span className="text-3xl">{STATUS_ICONS[tracked.status] ?? "📦"}</span>
                      <div>
                        <p className="font-black text-lg">{STATUS_LABELS[tracked.status] ?? tracked.status}</p>
                        <p className="text-muted-foreground text-xs">{new Date(tracked.created_at).toLocaleString()}</p>
                      </div>
                      <Badge className="ml-auto font-bold">{tracked.status}</Badge>
                    </div>
                    {/* Progress bar */}
                    <div className="flex items-center gap-1 mt-2">
                      {STATUS_STEPS.map((s, i) => {
                        const currentIdx = STATUS_STEPS.indexOf(tracked.status);
                        const done = i <= currentIdx;
                        return (
                          <div key={s} className="flex-1 flex flex-col items-center gap-1">
                            <div className={`w-full h-1.5 rounded-full transition-all ${done ? 'bg-primary' : 'bg-muted'}`} />
                            <span className="text-[9px] text-muted-foreground font-semibold">{STATUS_LABELS[s]}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Details */}
                  <div className="bg-muted/30 rounded-2xl p-4 space-y-2 text-sm">
                    <div className="flex justify-between"><span className="text-muted-foreground">From</span><span className="font-semibold text-right max-w-[60%] truncate">{tracked.pickup_address}</span></div>
                    <div className="flex justify-between"><span className="text-muted-foreground">To</span><span className="font-semibold text-right max-w-[60%] truncate">{tracked.dropoff_address}</span></div>
                    <div className="flex justify-between"><span className="text-muted-foreground">Recipient</span><span className="font-semibold">{tracked.recipient_phone}</span></div>
                    {tracked.parcel_item_types?.name && <div className="flex justify-between"><span className="text-muted-foreground">Item Type</span><span className="font-semibold">{tracked.parcel_item_types.name}</span></div>}
                    <div className="flex justify-between"><span className="text-muted-foreground">Fare</span><span className="font-black text-primary">Rs. {(tracked.fare || 0).toLocaleString()}</span></div>
                    {tracked.insured && <div className="flex justify-between"><span className="text-muted-foreground">Insurance</span><span className="font-semibold text-emerald-600">✅ Covered</span></div>}
                  </div>
                </motion.div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default ParcelTrackingPage;
