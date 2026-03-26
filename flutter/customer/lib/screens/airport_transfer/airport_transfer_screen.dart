// customer/lib/screens/airport_transfer/airport_transfer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

// ── Airport data ──────────────────────────────────────────────────────────────
class _Airport {
  final String id;
  final String name;
  final String city;
  final double lat;
  final double lng;
  const _Airport({
    required this.id, required this.name, required this.city,
    required this.lat, required this.lng,
  });
}

const _airports = [
  _Airport(id: 'BIA', name: 'Bandaranaike Intl Airport', city: 'Katunayake', lat: 7.1807, lng: 79.8842),
  _Airport(id: 'RIA', name: 'Mattala Rajapaksa Intl', city: 'Hambantota', lat: 6.2844, lng: 81.1246),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _airportVehiclesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('vehicles_listings')
      .select()
      .eq('listing_subtype', 'airport_transfer')
      .eq('moderation_status', 'approved')
      .eq('active', true);
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class AirportTransferScreen extends ConsumerStatefulWidget {
  const AirportTransferScreen({super.key});

  @override
  ConsumerState<AirportTransferScreen> createState() => _AirportTransferScreenState();
}

class _AirportTransferScreenState extends ConsumerState<AirportTransferScreen> {
  _Airport _airport = _airports[0];
  String _direction = 'to_airport'; // 'to_airport' | 'from_airport'
  final _nameCtrl = TextEditingController();
  final _flightCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 0);
  int _passengers = 1;
  int _luggage = 1;
  Map<String, dynamic>? _selectedVehicle;
  bool _booking = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _flightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _book() async {
    if (_selectedVehicle == null) {
      _toast('Please select a vehicle first.');
      return;
    }
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) { _toast('Please sign in to book.'); return; }

    setState(() => _booking = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      await supabase.from('airport_transfers').insert({
        'user_id': auth.user!.id,
        'vehicle_listing_id': _selectedVehicle!['id'],
        'direction': _direction,
        'airport_code': _airport.id,
        'pickup_datetime': dt.toIso8601String(),
        'passenger_name': _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (auth.profile?.fullName ?? 'Passenger'),
        'flight_number': _flightCtrl.text.isNotEmpty ? _flightCtrl.text : null,
        'passengers': _passengers,
        'luggage_count': _luggage,
        'fare': (_selectedVehicle!['price_per_day'] ?? 0).toDouble(),
        'status': 'pending',
      });
      if (mounted) {
        _toast('✅ Booking confirmed!');
        // Go to bookings list
        Navigator.of(context).pop();
      }
    } catch (e) {
      _toast('❌ Booking failed: $e');
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(_airportVehiclesProvider);
    final theme = Theme.of(context);
    const gold = Color(0xFFB8943F);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Airport Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.book_outlined, color: gold),
            label: const Text('My Bookings', style: TextStyle(color: gold)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Map
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_airport.lat, _airport.lng),
                  initialZoom: 10,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.pearlhub.customer',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(_airport.lat, _airport.lng),
                      width: 40, height: 40,
                      child: Container(
                        decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                        child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 22),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Direction toggle
                  Row(
                    children: [
                      _directionBtn('to_airport', '→ To Airport', Icons.flight_takeoff),
                      const SizedBox(width: 8),
                      _directionBtn('from_airport', '← From Airport', Icons.flight_land),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Airport selector
                  _sectionTitle('Airport'),
                  ...List.generate(_airports.length, (i) {
                    final a = _airports[i];
                    final selected = _airport.id == a.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setState(() => _airport = a),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: selected ? gold : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: selected ? gold.withOpacity(0.06) : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.flight, color: selected ? gold : Colors.grey, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.name, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? gold : null)),
                                  Text(a.city, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              )),
                              if (selected) const Icon(Icons.check_circle, color: gold, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  // Date + Time
                  Row(children: [
                    Expanded(child: _fieldBtn(
                      label: 'Date',
                      value: '${_date.day}/${_date.month}/${_date.year}',
                      icon: Icons.calendar_today,
                      onTap: _pickDate,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _fieldBtn(
                      label: 'Time',
                      value: _time.format(context),
                      icon: Icons.access_time,
                      onTap: _pickTime,
                    )),
                  ]),
                  const SizedBox(height: 12),

                  // Passengers + Luggage
                  Row(children: [
                    Expanded(child: _counterField('Passengers', _passengers, 1, 20,
                        (v) => setState(() => _passengers = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _counterField('Luggage', _luggage, 0, 30,
                        (v) => setState(() => _luggage = v))),
                  ]),
                  const SizedBox(height: 12),

                  // Name + Flight
                  _input(_nameCtrl, 'Passenger Name', Icons.person_outline),
                  const SizedBox(height: 8),
                  _input(_flightCtrl, 'Flight Number (optional)', Icons.confirmation_number_outlined),

                  const SizedBox(height: 24),
                  _sectionTitle('Select Vehicle'),
                ],
              ),
            ),
          ),

          // Vehicle list
          vehiclesAsync.when(
            data: (vehicles) => vehicles.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.directions_car_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No airport transfer vehicles yet',
                                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Admin needs to add vehicles with "Airport Transfer" type.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _VehicleCard(
                        vehicle: vehicles[i],
                        selected: _selectedVehicle?['id'] == vehicles[i]['id'],
                        onTap: () => setState(() => _selectedVehicle = vehicles[i]),
                      ),
                      childCount: vehicles.length,
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Error: $e'))),
            ),
          ),

          // Book button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: ElevatedButton(
                onPressed: _booking ? null : _book,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _booking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _selectedVehicle != null
                            ? 'Confirm — Rs. ${((_selectedVehicle!["price_per_day"] ?? 0) as num).toStringAsFixed(0)}'
                            : 'Select a vehicle to book',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _directionBtn(String id, String label, IconData icon) {
    const gold = Color(0xFFB8943F);
    final sel = _direction == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _direction = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? gold.withOpacity(0.1) : Colors.grey.shade50,
            border: Border.all(color: sel ? gold : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: sel ? gold : Colors.grey),
              const SizedBox(width: 6),
              Flexible(child: Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? gold : Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
  );

  Widget _fieldBtn({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(icon, size: 14, color: const Color(0xFFB8943F)),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
    );
  }

  Widget _counterField(String label, int value, int min, int max, void Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: value > min ? () => onChanged(value - 1) : null,
              color: const Color(0xFFB8943F),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: value < max ? () => onChanged(value + 1) : null,
              color: const Color(0xFFB8943F),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleCard({required this.vehicle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFB8943F);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? gold : Colors.grey.shade200, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(14),
            color: selected ? gold.withOpacity(0.04) : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: gold.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_car, color: gold, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(vehicle['title']?.toString() ?? 'Vehicle',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${vehicle['vehicle_type'] ?? ''} · ${vehicle['capacity'] ?? 4} seats',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Rs. ${((vehicle['price_per_day'] ?? 0) as num).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: gold)),
                if (selected) const Icon(Icons.check_circle, color: gold, size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
