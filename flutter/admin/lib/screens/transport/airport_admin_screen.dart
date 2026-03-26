// admin/lib/screens/transport/airport_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final _airportBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(supabaseProvider)
      .from('airport_transfers')
      .select('*, vehicles_listings(title, vehicle_type)')
      .order('created_at', ascending: false)
      .limit(150);
  return (data as List).cast<Map<String, dynamic>>();
});

class AirportAdminScreen extends ConsumerStatefulWidget {
  const AirportAdminScreen({super.key});

  @override
  ConsumerState<AirportAdminScreen> createState() => _AirportAdminScreenState();
}

class _AirportAdminScreenState extends ConsumerState<AirportAdminScreen> {
  static const _gold = Color(0xFFB8943F);
  static const _bg   = Color(0xFF0A0A0F);

  String _filter = 'all'; // all | pending | confirmed | completed | cancelled

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(_airportBookingsProvider);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('Airport Transfers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _gold),
            onPressed: () => ref.invalidate(_airportBookingsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              for (final s in ['all', 'pending', 'confirmed', 'completed', 'cancelled'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                    selectedColor: _gold,
                    labelStyle: TextStyle(color: _filter == s ? Colors.black : Colors.white, fontSize: 12),
                    backgroundColor: Colors.white10,
                  ),
                ),
            ]),
          ),

          Expanded(
            child: bookingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
              data: (bookings) {
                final filtered = _filter == 'all' ? bookings : bookings.where((b) => b['status'] == _filter).toList();
                if (filtered.isEmpty) {
                  return Center(child: Text('No $_filter bookings', style: const TextStyle(color: Colors.white38)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _BookingCard(booking: filtered[i], onChanged: () => ref.invalidate(_airportBookingsProvider)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onChanged;
  const _BookingCard({required this.booking, required this.onChanged});

  static const _gold = Color(0xFFB8943F);

  Color _statusColor(String s) {
    return switch (s) {
      'confirmed'  => const Color(0xFF22C55E),
      'completed'  => const Color(0xFF3B82F6),
      'cancelled'  => const Color(0xFFEF4444),
      _            => const Color(0xFFF59E0B),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = booking['status']?.toString() ?? 'pending';
    final vehicle = booking['vehicles_listings'];
    final direction = booking['direction'] ?? 'to_airport';

    return Card(
      color: const Color(0xFF1A1A26),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _statusColor(status).withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(direction == 'to_airport' ? Icons.flight_takeoff : Icons.flight_land, color: _gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                direction == 'to_airport' ? '→ To Airport' : '← From Airport',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          _row('Airport', booking['airport_code'] ?? '—'),
          _row('Pickup', (booking['pickup_datetime'] ?? '—').toString().replaceFirst('T', ' ').substring(0, 16)),
          _row('Passenger', '${booking['passenger_name'] ?? '—'}  ·  ${booking['passengers'] ?? 1} pax  ·  ${booking['luggage_count'] ?? 0} bags'),
          if (booking['flight_number'] != null) _row('Flight', booking['flight_number'].toString()),
          _row('Vehicle', vehicle != null ? '${vehicle['title']} (${vehicle['vehicle_type']})' : 'Not assigned'),
          _row('Fare', 'Rs. ${((booking['fare'] ?? 0) as num).toStringAsFixed(0)}'),
          const SizedBox(height: 10),
          if (status == 'pending')
            Row(children: [
              _actionBtn('Confirm', const Color(0xFF22C55E), () => _updateStatus(context, ref, 'confirmed')),
              const SizedBox(width: 8),
              _actionBtn('Cancel', const Color(0xFFEF4444), () => _updateStatus(context, ref, 'cancelled')),
            ])
          else if (status == 'confirmed')
            _actionBtn('Mark Completed', const Color(0xFF3B82F6), () => _updateStatus(context, ref, 'completed')),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 80, child: Text(k, style: const TextStyle(color: Colors.white38, fontSize: 12))),
      Expanded(child: Text(v, style: const TextStyle(color: Colors.white70, fontSize: 12))),
    ]),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    ),
  );

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(supabaseProvider).from('airport_transfers').update({'status': status}).eq('id', booking['id']);
      onChanged();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
