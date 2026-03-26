import { useState } from "react";
import { motion } from "framer-motion";
import { useAuth } from "@/context/AuthContext";
import { db } from "@/integrations/supabase/client";
import { useVehicles } from "@/hooks/useListings";
import LeafletMap from "@/components/LeafletMap";
import TrustBanner from "@/components/TrustBanner";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Plane, MapPin, Clock, Users, CheckCircle, Shield } from "lucide-react";

const AIRPORTS = [
  { id: "BIA", name: "Bandaranaike Intl Airport", city: "Katunayake", lat: 7.1807, lng: 79.8842 },
  { id: "RIA", name: "Mattala Rajapaksa Intl Airport", city: "Hambantota", lat: 6.2844, lng: 81.1246 },
];

const AirportTransferPage = () => {
  const { user, profile } = useAuth();
  const { data: airportVehicles = [], isLoading } = useVehicles({ listing_subtype: "airport_transfer" });

  const [direction, setDirection] = useState<"to_airport" | "from_airport">("to_airport");
  const [airport, setAirport] = useState(AIRPORTS[0]);
  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  const [passengerName, setPassengerName] = useState(profile?.full_name ?? "");
  const [flightNo, setFlightNo] = useState("");
  const [passengers, setPassengers] = useState(1);
  const [luggage, setLuggage] = useState(1);
  const [selectedVehicle, setSelectedVehicle] = useState<any | null>(null);
  const [bookingModal, setBookingModal] = useState(false);
  const [booking, setBooking] = useState(false);
  const [booked, setBooked] = useState<any | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const showToast = (msg: string) => { setToast(msg); setTimeout(() => setToast(null), 3000); };

  const handleBook = async () => {
    if (!user) { showToast("Please sign in to book."); return; }
    if (!selectedVehicle || !date || !time) { showToast("Please complete all required fields."); return; }
    setBooking(true);
    const { data, error } = await db.from("airport_transfers").insert({
      user_id: user.id,
      vehicle_listing_id: selectedVehicle.id,
      direction,
      airport_code: airport.id,
      pickup_datetime: new Date(`${date}T${time}`).toISOString(),
      passenger_name: passengerName || profile?.full_name || "Passenger",
      flight_number: flightNo || null,
      passengers,
      luggage_count: luggage,
      fare: selectedVehicle.price_per_day ?? 0,
      status: "pending",
    }).select().single();
    setBooking(false);
    if (error) showToast("❌ Booking failed: " + error.message);
    else { setBooked(data); setBookingModal(false); showToast("✅ Booking confirmed!"); }
  };

  const mapCenter: [number, number] = [airport.lat, airport.lng];
  const mapMarkers = [
    { lat: airport.lat, lng: airport.lng, title: airport.name, location: airport.city, emoji: "✈️", type: "vehicle" as const },
  ];

  return (
    <div className="min-h-screen bg-background">
      {/* Toast */}
      {toast && <div className="fixed top-6 right-6 z-50 bg-zinc-900 text-white px-6 py-3 rounded-2xl shadow-2xl text-sm font-bold border border-white/10">{toast}</div>}

      {/* Hero */}
      <div className="bg-gradient-to-br from-primary to-primary/70 py-10">
        <div className="container">
          <div className="inline-flex items-center gap-1.5 bg-white/15 text-pearl text-[11px] font-bold uppercase tracking-wider px-3 py-1 rounded-full mb-2">✈️ Airport Transfer</div>
          <h1 className="text-pearl text-3xl font-display">Pearl Airport Transfer</h1>
          <p className="text-pearl/75 mt-1.5">Pre-book your transfer to/from BIA · Luxury & Economy vehicles available</p>
        </div>
      </div>

      <TrustBanner stats={[
        { value: "BIA", label: "Bandaranaike Airport", icon: "✈️" },
        { value: "24/7", label: "Pickups Available", icon: "🕐" },
        { value: "Meet &", label: "Greet Service", icon: "🙋" },
        { value: "Fixed", label: "Fare Guarantee", icon: "💰" },
      ]} />

      {/* Booking Confirmed Banner */}
      {booked && (
        <div className="container my-6">
          <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-2xl p-6 flex items-center gap-4">
            <CheckCircle className="text-emerald-500" size={32} />
            <div>
              <p className="font-black text-foreground text-lg">Booking Confirmed!</p>
              <p className="text-muted-foreground text-sm mt-0.5">Ref: {booked.id.slice(0, 8).toUpperCase()} · {direction === 'to_airport' ? 'To' : 'From'} {airport.name}</p>
            </div>
          </div>
        </div>
      )}

      <div className="container py-8 grid grid-cols-1 lg:grid-cols-5 gap-8">
        {/* Booking Form */}
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-card rounded-3xl border border-border p-6 shadow-sm">
            <h2 className="font-black text-xl mb-6">Book Airport Transfer</h2>

            {/* Direction */}
            <div className="grid grid-cols-2 gap-2 mb-5">
              {[
                { id: "to_airport", label: "To Airport", icon: "→✈️" },
                { id: "from_airport", label: "From Airport", icon: "✈️→" },
              ].map(d => (
                <button key={d.id} onClick={() => setDirection(d.id as typeof direction)}
                  className={`p-3 rounded-xl border font-bold text-sm transition-all ${direction === d.id ? 'bg-primary/10 border-primary text-primary' : 'border-border text-muted-foreground hover:border-primary/30'}`}>
                  {d.icon} {d.label}
                </button>
              ))}
            </div>

            {/* Airport Selection */}
            <div className="mb-4">
              <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Airport</label>
              <div className="space-y-2">
                {AIRPORTS.map(a => (
                  <button key={a.id} onClick={() => setAirport(a)}
                    className={`w-full text-left p-3 rounded-xl border transition-all flex items-center gap-3 ${airport.id === a.id ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/30'}`}>
                    <Plane size={16} className={airport.id === a.id ? 'text-primary' : 'text-muted-foreground'} />
                    <div>
                      <p className="font-bold text-sm">{a.name}</p>
                      <p className="text-muted-foreground text-xs">{a.city}</p>
                    </div>
                    {airport.id === a.id && <CheckCircle size={16} className="text-primary ml-auto" />}
                  </button>
                ))}
              </div>
            </div>

            {/* Date/Time */}
            <div className="grid grid-cols-2 gap-3 mb-4">
              <div>
                <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Date *</label>
                <input type="date" value={date} onChange={e => setDate(e.target.value)} min={new Date().toISOString().split('T')[0]}
                  className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" />
              </div>
              <div>
                <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Time *</label>
                <input type="time" value={time} onChange={e => setTime(e.target.value)}
                  className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" />
              </div>
            </div>

            {/* Passenger & Luggage */}
            <div className="grid grid-cols-2 gap-3 mb-4">
              <div>
                <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block flex items-center gap-1"><Users size={11} /> Passengers</label>
                <input type="number" min={1} max={20} value={passengers} onChange={e => setPassengers(+e.target.value)}
                  className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" />
              </div>
              <div>
                <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Luggage</label>
                <input type="number" min={0} max={30} value={luggage} onChange={e => setLuggage(+e.target.value)}
                  className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" />
              </div>
            </div>

            {/* Passenger Name */}
            <div className="mb-4">
              <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Passenger Name</label>
              <input type="text" value={passengerName} onChange={e => setPassengerName(e.target.value)}
                className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="Name on boarding pass" />
            </div>

            {/* Flight Number */}
            <div className="mb-6">
              <label className="text-xs font-black text-muted-foreground uppercase tracking-widest mb-2 block">Flight Number (optional)</label>
              <input type="text" value={flightNo} onChange={e => setFlightNo(e.target.value)}
                className="w-full border border-input rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-background" placeholder="e.g., UL123" />
            </div>

            {selectedVehicle ? (
              <div className="bg-primary/5 border border-primary/20 rounded-2xl p-4 mb-4 flex items-center gap-3">
                <div className="flex-1">
                  <p className="font-black text-sm">{selectedVehicle.title}</p>
                  <p className="text-primary font-black">Rs. {(selectedVehicle.price_per_day || 0).toLocaleString()}</p>
                </div>
                <button onClick={() => setSelectedVehicle(null)} className="text-muted-foreground hover:text-foreground">✕</button>
              </div>
            ) : (
              <p className="text-muted-foreground text-sm text-center mb-4">👇 Select a vehicle from the list below</p>
            )}

            <Button onClick={() => setBookingModal(true)} disabled={!selectedVehicle || !date || !time}
              className="w-full bg-primary hover:bg-primary/90 text-white font-black h-12 rounded-xl text-sm">
              Confirm Booking
            </Button>
          </div>

          {/* Trust */}
          <div className="bg-card rounded-2xl border border-border p-4">
            <div className="flex items-center gap-2 mb-3"><Shield size={14} className="text-primary" /><span className="text-xs font-black uppercase tracking-widest text-muted-foreground">Why Book With Us</span></div>
            <ul className="space-y-2 text-sm text-muted-foreground">
              {["Fixed fare – no surge pricing", "Meet & Greet service available", "Flight tracking included", "24/7 customer support", "Free cancellation up to 4 hrs before"].map(f => (
                <li key={f} className="flex items-center gap-2"><CheckCircle size={12} className="text-emerald-500 flex-shrink-0" />{f}</li>
              ))}
            </ul>
          </div>
        </div>

        {/* Map + Vehicle List */}
        <div className="lg:col-span-3 space-y-6">
          <div className="rounded-2xl overflow-hidden border border-border h-64 lg:h-80">
            <LeafletMap markers={mapMarkers} center={mapCenter} zoom={11} height="100%" />
          </div>

          <div>
            <h3 className="font-black text-xl mb-4">Available Vehicles</h3>
            {isLoading ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {[1,2,3,4].map(i => <div key={i} className="h-32 bg-muted/30 rounded-2xl animate-pulse" />)}
              </div>
            ) : airportVehicles.length === 0 ? (
              <div className="text-center py-16 bg-muted/10 rounded-2xl border border-border">
                <Plane size={40} className="mx-auto mb-3 text-muted-foreground opacity-30" />
                <p className="font-black text-lg">No airport transfer vehicles yet</p>
                <p className="text-muted-foreground text-sm mt-1">The admin needs to add vehicles with type "Airport Transfer".</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {airportVehicles.map((v: any) => (
                  <motion.div key={v.id} whileHover={{ y: -2 }} onClick={() => setSelectedVehicle(v)}
                    className={`bg-card rounded-2xl border p-5 cursor-pointer transition-all ${selectedVehicle?.id === v.id ? 'border-primary shadow-lg shadow-primary/10' : 'border-border hover:border-primary/30'}`}>
                    <div className="flex items-start justify-between mb-3">
                      <div>
                        <h4 className="font-black">{v.title}</h4>
                        <p className="text-muted-foreground text-xs mt-0.5">{v.vehicle_type} · {v.capacity || 4} seats</p>
                      </div>
                      <Badge variant="outline" className="text-xs font-bold border-primary/30 text-primary">
                        Rs. {(v.price_per_day || 0).toLocaleString()}
                      </Badge>
                    </div>
                    <div className="flex flex-wrap gap-1.5 mb-3">
                      {v.with_driver && <span className="text-[10px] bg-emerald-500/10 text-emerald-600 px-2 py-1 rounded-full font-bold">With Driver</span>}
                      {(v.features || []).slice(0, 3).map((f: string) => (
                        <span key={f} className="text-[10px] bg-muted px-2 py-1 rounded-full text-muted-foreground">{f}</span>
                      ))}
                    </div>
                    {selectedVehicle?.id === v.id && (
                      <div className="flex items-center gap-1 text-primary text-xs font-black mt-1">
                        <CheckCircle size={12} /> Selected
                      </div>
                    )}
                  </motion.div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Booking Confirm Modal */}
      <Dialog open={bookingModal} onOpenChange={setBookingModal}>
        <DialogContent className="max-w-sm rounded-3xl">
          <DialogHeader><DialogTitle className="font-black text-xl">Confirm Transfer Booking</DialogTitle></DialogHeader>
          {selectedVehicle && (
            <div className="space-y-4 py-2">
              <div className="bg-primary/5 border border-primary/20 rounded-2xl p-4 space-y-2 text-sm">
                <div className="flex justify-between"><span className="text-muted-foreground">Direction</span><span className="font-bold">{direction === 'to_airport' ? '→ To Airport' : '← From Airport'}</span></div>
                <div className="flex justify-between"><span className="text-muted-foreground">Airport</span><span className="font-bold">{airport.name}</span></div>
                <div className="flex justify-between"><span className="text-muted-foreground">Date & Time</span><span className="font-bold">{date} {time}</span></div>
                <div className="flex justify-between"><span className="text-muted-foreground">Vehicle</span><span className="font-bold">{selectedVehicle.title}</span></div>
                {flightNo && <div className="flex justify-between"><span className="text-muted-foreground">Flight</span><span className="font-bold">{flightNo}</span></div>}
                <div className="flex justify-between border-t border-border pt-2 mt-2"><span className="font-black">Total</span><span className="font-black text-primary">Rs. {(selectedVehicle.price_per_day || 0).toLocaleString()}</span></div>
              </div>
              <div className="flex gap-3">
                <Button onClick={() => setBookingModal(false)} variant="outline" className="flex-1">Cancel</Button>
                <Button onClick={handleBook} disabled={booking} className="flex-1 bg-primary text-white font-black">{booking ? 'Booking…' : 'Confirm'}</Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default AirportTransferPage;
