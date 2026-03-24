import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useAuth } from "@/context/AuthContext";
import { useStore } from "@/store/useStore";
import { useTaxiCategories, validateTaxiPromo } from "@/hooks/useListings";
import { supabase } from "@/integrations/supabase/client";
import LeafletMap from "@/components/LeafletMap";
import TrustBanner from "@/components/TrustBanner";
import { TaxiVehicleCategory } from "@/types";
import {
  Navigation, Search, Package, Car, Plus, X, AlertTriangle,
  Star, CheckCircle, Clock, XCircle, Banknote, CreditCard, MapPin
} from "lucide-react";

const TaxiPage = () => {
  const { user } = useAuth();
  const { addNotification, language } = useStore();
  const { data: categories = [], isLoading: catsLoading } = useTaxiCategories();

  const [mode, setMode] = useState<"ride" | "parcel">("ride");
  const [pickup, setPickup] = useState("Current Location");
  const [stops, setStops] = useState<string[]>([""]);
  const [selectedCat, setSelectedCat] = useState<TaxiVehicleCategory | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<"cash" | "card">("cash");

  const [promoCode, setPromoCode] = useState("");
  const [promoResult, setPromoResult] = useState<{ type: string; amount: number } | null>(null);
  const [promoError, setPromoError] = useState("");
  const [promoId, setPromoId] = useState<string | null>(null);
  const [scheduleTime, setScheduleTime] = useState("");

  const [rideState, setRideState] = useState<"none" | "searching" | "riding" | "rating">("none");
  const [currentRideId, setCurrentRideId] = useState<string | null>(null);
  const [rating, setRating] = useState(0);
  const [tip, setTip] = useState("");

  // Parcel fields
  const [recipient, setRecipient] = useState("");
  const [phone, setPhone] = useState("");
  const [packageSize, setPackageSize] = useState("Medium");

  // Auto-select first category when categories load (must be in useEffect, not render body)
  useEffect(() => {
    if (categories.length > 0 && !selectedCat) {
      setSelectedCat(categories[2] || categories[0]);
    }
  }, [categories]);

  // Server-side promo validation
  const handleValidatePromo = async () => {
    if (!promoCode.trim()) { setPromoResult(null); setPromoError(""); setPromoId(null); return; }
    const result = await validateTaxiPromo(promoCode);
    if (result.valid) {
      setPromoResult({ type: result.discount_type!, amount: result.discount_amount! });
      setPromoId(result.id!);
      setPromoError("");
    } else {
      setPromoResult(null);
      setPromoId(null);
      setPromoError(result.error!);
    }
  };

  // Fare engine
  const calcFare = (cat: TaxiVehicleCategory) => {
    const km = 8; // placeholder — real distance from Directions API
    let fare = cat.base_fare + km * cat.per_km_rate;
    if (promoResult) {
      fare = promoResult.type === "percentage" ? fare * (1 - promoResult.amount / 100) : fare - promoResult.amount;
    }
    return Math.max(fare, cat.base_fare * 0.5);
  };

  // Real ride creation
  const handleBook = async () => {
    if (!selectedCat || !user) { addNotification("Error", "Please sign in and select a vehicle."); return; }
    setRideState("searching");
    const fare = calcFare(selectedCat);
    const rideData: Record<string, any> = {
      customer_id: user.id,
      vehicle_category_id: selectedCat.id,
      pickup_lat: 6.9271, pickup_lng: 79.8612, pickup_address: pickup,
      dropoff_lat: 6.9344, dropoff_lng: 79.8428, dropoff_address: stops[0],
      fare, distance_km: 8, ride_module: mode,
      payment_method: paymentMethod,
      scheduled_for: scheduleTime || null,
      promo_id: promoId,
      stops: stops.length > 1 ? stops.map(s => ({ address: s })) : null,
    };
    if (mode === "parcel") {
      rideData.parcel_details = { recipient_name: recipient, phone, package_size: packageSize };
    }
    const { data, error } = await (supabase as any).from("taxi_rides").insert(rideData).select().single();
    if (error) { addNotification("Error", "Ride creation failed."); setRideState("none"); return; }
    setCurrentRideId(data.id);
    addNotification("Searching", "Finding your driver...");
    setTimeout(() => setRideState("riding"), 3000); // Simulated — production uses Realtime
  };

  const cancelRide = async () => {
    if (currentRideId) await (supabase as any).from("taxi_rides").update({ status: "cancelled" }).eq("id", currentRideId);
    setRideState("none"); setCurrentRideId(null);
  };

  const submitRating = async () => {
    if (currentRideId && user) {
      // Fetch the ride to get the driver_id before inserting the rating
      const { data: rideData } = await (supabase as any).from("taxi_rides").select("driver_id").eq("id", currentRideId).single();
      await (supabase as any).from("taxi_ratings").insert({
        ride_id: currentRideId, reviewer_id: user.id, target_id: rideData?.driver_id ?? user.id,
        rating, tip_amount: parseFloat(tip) || 0,
      });
      await (supabase as any).from("taxi_rides").update({ status: "completed" }).eq("id", currentRideId);
    }
    addNotification("Ride Complete", "Thank you for choosing Pearl Taxi!");
    setRideState("none"); setCurrentRideId(null); setRating(0); setTip("");
  };

  const triggerSOS = async () => {
    if (currentRideId) await (supabase as any).from("taxi_rides").update({ is_emergency_sos: true }).eq("id", currentRideId);
    addNotification("🚨 SOS", "Emergency services have been notified.");
  };

  const isFormValid = pickup !== "" && stops[0] !== "" && selectedCat !== null;
  const mapMarkers = [{ lat: 6.9271, lng: 79.8612, title: "You", location: pickup, emoji: "📍", type: "pickup" as const }];

  return (
    <div className="min-h-screen bg-background">
      {/* Hero */}
      <div className="bg-gradient-to-br from-primary to-primary/70 py-10">
        <div className="container">
          <div className="inline-flex items-center gap-1.5 bg-white/15 text-pearl text-[11px] font-bold uppercase tracking-wider px-3 py-1 rounded-full mb-2">🚕 Ride-Hailing</div>
          <h1 className="text-pearl text-3xl font-display">Pearl Taxi</h1>
          <p className="text-pearl/75 mt-1.5">Moto • TUK TUK • Cars • Vans • Buses • Luxury Coaches</p>
        </div>
      </div>

      <TrustBanner stats={[
        { value: "13+", label: "Vehicle Types", icon: "🚗" },
        { value: "24/7", label: "Available", icon: "⏰" },
        { value: "Live", label: "GPS Tracking", icon: "📍" },
        { value: "SOS", label: "Emergency", icon: "🛡️" },
      ]} />

      <div className="container py-6 grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* Map Column */}
        <div className="lg:col-span-3 rounded-xl overflow-hidden border border-border" style={{ minHeight: "500px" }}>
          <LeafletMap markers={mapMarkers} center={[6.9271, 79.8612]} zoom={13} height="100%" />
        </div>

        {/* Booking Panel */}
        <div className="lg:col-span-2">
          <AnimatePresence mode="wait">
            {rideState === "none" && (
              <motion.div key="booking" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -20 }}
                className="bg-card/80 backdrop-blur-sm rounded-2xl border border-border p-6 shadow-lg">
                {/* Mode Toggle */}
                <div className="flex bg-background rounded-full p-1 mb-5">
                  <button onClick={() => setMode("ride")} className={`flex-1 flex items-center justify-center gap-2 py-2 rounded-full text-sm font-semibold transition-all ${mode === "ride" ? "bg-primary text-primary-foreground" : ""}`}>
                    <Car className="w-4 h-4" /> Ride
                  </button>
                  <button onClick={() => setMode("parcel")} className={`flex-1 flex items-center justify-center gap-2 py-2 rounded-full text-sm font-semibold transition-all ${mode === "parcel" ? "bg-primary text-primary-foreground" : ""}`}>
                    <Package className="w-4 h-4" /> Parcel
                  </button>
                </div>

                {/* Pickup */}
                <div className="flex items-center gap-3 bg-background rounded-lg px-4 py-3 mb-3 border border-border">
                  <Navigation className="w-4 h-4 text-emerald shrink-0" />
                  <input type="text" value={pickup} onChange={e => setPickup(e.target.value)} placeholder="Pickup location"
                    className="flex-1 bg-transparent border-none outline-none text-sm" />
                </div>

                {/* Stops */}
                {stops.map((stop, i) => (
                  <div key={i} className="flex items-center gap-3 bg-background rounded-lg px-4 py-3 mb-3 border border-border">
                    <MapPin className="w-4 h-4 text-primary shrink-0" />
                    <input type="text" value={stop} onChange={e => { const n = [...stops]; n[i] = e.target.value; setStops(n); }}
                      placeholder="Where to?" className="flex-1 bg-transparent border-none outline-none text-sm" />
                    {i > 0 && <button onClick={() => setStops(stops.filter((_, j) => j !== i))} className="text-destructive"><X className="w-4 h-4" /></button>}
                  </div>
                ))}
                {stops.length < 3 && mode === "ride" && (
                  <button onClick={() => setStops([...stops, ""])} className="text-xs text-primary font-semibold flex items-center gap-1 mb-4">
                    <Plus className="w-3 h-3" /> Add stop
                  </button>
                )}

                {/* Parcel extras */}
                {mode === "parcel" && (
                  <div className="grid grid-cols-2 gap-3 mb-4">
                    <input className="rounded-lg border border-input bg-background px-3 py-2 text-sm" placeholder="Recipient" value={recipient} onChange={e => setRecipient(e.target.value)} />
                    <input className="rounded-lg border border-input bg-background px-3 py-2 text-sm" placeholder="Phone" value={phone} onChange={e => setPhone(e.target.value)} />
                    <select className="col-span-2 rounded-lg border border-input bg-background px-3 py-2 text-sm" value={packageSize} onChange={e => setPackageSize(e.target.value)}>
                      <option>Small</option><option>Medium</option><option>Large</option>
                    </select>
                  </div>
                )}

                {/* Payment + Schedule + Promo row */}
                <div className="grid grid-cols-2 gap-3 mb-4 p-3 bg-background/50 rounded-lg border border-border/50">
                  <div>
                    <label className="text-[11px] font-semibold text-muted-foreground block mb-1">Payment</label>
                    <div className="flex gap-1">
                      <button onClick={() => setPaymentMethod("cash")} className={`flex-1 flex items-center justify-center gap-1 text-xs py-1.5 rounded-md border transition-all ${paymentMethod === "cash" ? "border-primary bg-primary/10 text-primary" : "border-input"}`}>
                        <Banknote className="w-3 h-3" /> Cash
                      </button>
                      <button onClick={() => setPaymentMethod("card")} className={`flex-1 flex items-center justify-center gap-1 text-xs py-1.5 rounded-md border transition-all ${paymentMethod === "card" ? "border-primary bg-primary/10 text-primary" : "border-input"}`}>
                        <CreditCard className="w-3 h-3" /> Card
                      </button>
                    </div>
                  </div>
                  <div>
                    <label className="text-[11px] font-semibold text-muted-foreground flex items-center gap-1 mb-1"><Clock className="w-3 h-3" /> Schedule</label>
                    <input type="datetime-local" className="w-full rounded-md border border-input bg-background px-2 py-1.5 text-xs" value={scheduleTime} onChange={e => setScheduleTime(e.target.value)} />
                  </div>
                  <div className="col-span-2">
                    <label className="text-[11px] font-semibold text-muted-foreground block mb-1">Promo Code</label>
                    <div className="flex gap-2">
                      <input className="flex-1 rounded-md border border-input bg-background px-3 py-1.5 text-xs" placeholder="e.g. SAVE20" value={promoCode} onChange={e => setPromoCode(e.target.value)} />
                      <button onClick={handleValidatePromo} className="px-3 py-1.5 text-xs rounded-md bg-primary text-primary-foreground font-semibold">Apply</button>
                    </div>
                    {promoError && <p className="text-[11px] text-destructive mt-1">{promoError}</p>}
                    {promoResult && <p className="text-[11px] text-emerald mt-1">✓ {promoResult.type === "percentage" ? `${promoResult.amount}%` : `Rs. ${promoResult.amount}`} off</p>}
                  </div>
                </div>

                {/* Vehicle Grid */}
                <h4 className="text-sm font-bold mb-3">Choose Vehicle</h4>
                {catsLoading ? (
                  <div className="grid grid-cols-3 gap-2 mb-4">
                    {[1,2,3,4,5,6].map(i => <div key={i} className="h-20 rounded-lg bg-muted/30 animate-pulse" />)}
                  </div>
                ) : (
                  <div className="grid grid-cols-3 gap-2 mb-4 max-h-[280px] overflow-y-auto pr-1">
                    {categories.map((cat: TaxiVehicleCategory) => (
                      <button key={cat.id} onClick={() => setSelectedCat(cat)}
                        className={`p-2 rounded-lg border text-center transition-all hover:-translate-y-0.5 ${selectedCat?.id === cat.id ? "border-primary bg-primary/5 shadow-sm" : "border-border bg-card"}`}>
                        <div className="text-xl mb-0.5">{cat.icon}</div>
                        <div className="text-[11px] font-semibold leading-tight">{cat.name}</div>
                        <div className="text-[10px] text-muted-foreground">{cat.default_seats} seats</div>
                        <div className="text-xs font-bold text-primary mt-0.5">Rs. {Math.round(calcFare(cat)).toLocaleString()}</div>
                      </button>
                    ))}
                  </div>
                )}

                <button onClick={handleBook} disabled={!isFormValid || !user}
                  className="w-full bg-primary hover:bg-primary/90 text-primary-foreground py-3.5 rounded-xl font-bold text-sm transition-all disabled:opacity-50">
                  {!user ? "Sign in to Book" : scheduleTime ? "Schedule Pearl Ride" : `Book Now — Rs. ${selectedCat ? Math.round(calcFare(selectedCat)).toLocaleString() : "0"}`}
                </button>
              </motion.div>
            )}

            {rideState === "searching" && (
              <motion.div key="searching" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}
                className="bg-card/80 backdrop-blur-sm rounded-2xl border border-border p-8 shadow-lg text-center">
                <div className="w-12 h-12 rounded-full border-[3px] border-border border-t-primary animate-spin mx-auto mb-4" />
                <h3 className="text-lg font-bold mb-1">Finding your driver…</h3>
                <p className="text-sm text-muted-foreground mb-6">{paymentMethod === "cash" ? "💵 Cash payment" : "💳 Card payment"} • {selectedCat?.name}</p>
                <button onClick={cancelRide} className="flex items-center justify-center gap-2 mx-auto px-6 py-2.5 rounded-lg border border-destructive text-destructive font-semibold text-sm hover:bg-destructive/5 transition-all">
                  <XCircle className="w-4 h-4" /> Cancel
                </button>
              </motion.div>
            )}

            {rideState === "riding" && (
              <motion.div key="riding" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}
                className="bg-card/80 backdrop-blur-sm rounded-2xl border border-emerald/30 p-6 shadow-lg">
                <div className="flex items-center gap-2 text-emerald font-bold text-lg mb-3"><CheckCircle className="w-5 h-5" /> Ride in Progress</div>
                <p className="text-sm text-muted-foreground mb-6">Your driver is on the way. Share your live link for safety.</p>
                <div className="flex gap-3 mb-4">
                  <button onClick={triggerSOS} className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg bg-destructive text-destructive-foreground font-bold text-sm">
                    <AlertTriangle className="w-4 h-4" /> SOS
                  </button>
                  <button onClick={() => { setRideState("rating"); }} className="flex-1 py-2.5 rounded-lg bg-primary text-primary-foreground font-bold text-sm">Complete</button>
                </div>
              </motion.div>
            )}

            {rideState === "rating" && (
              <motion.div key="rating" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}
                className="bg-card/80 backdrop-blur-sm rounded-2xl border border-border p-8 shadow-lg text-center">
                <CheckCircle className="w-12 h-12 text-emerald mx-auto mb-3" />
                <h3 className="text-lg font-bold mb-4">Rate your ride</h3>
                <div className="flex justify-center gap-2 mb-5">
                  {[1,2,3,4,5].map(s => (
                    <Star key={s} className={`w-8 h-8 cursor-pointer transition-all ${rating >= s ? "text-primary fill-primary" : "text-border"}`}
                      onClick={() => setRating(s)} />
                  ))}
                </div>
                <div className="mb-5">
                  <label className="text-xs font-semibold text-muted-foreground block mb-1">Tip (Optional)</label>
                  <input type="number" className="w-full max-w-[200px] mx-auto rounded-lg border border-input bg-background px-3 py-2 text-sm text-center"
                    placeholder="Rs." value={tip} onChange={e => setTip(e.target.value)} />
                </div>
                <button onClick={submitRating} className="w-full max-w-[200px] bg-primary text-primary-foreground py-2.5 rounded-lg font-bold text-sm">Submit</button>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
};

export default TaxiPage;
