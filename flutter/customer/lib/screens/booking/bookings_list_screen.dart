import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

final customerBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return const [];
  final data = await supabase.from('bookings').select().eq('user_id', userId).order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

class BookingsListScreen extends ConsumerStatefulWidget {
  const BookingsListScreen({super.key});

  @override
  ConsumerState<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends ConsumerState<BookingsListScreen> {
  String _filter = 'all';

  static const _statusColors = {
    'confirmed': Color(0xFF22C55E),
    'pending':   Color(0xFFF59E0B),
    'cancelled': Color(0xFFEF4444),
    'completed': Color(0xFF3B82F6),
  };

  static const _verticalIcons = {
    'stay':     Icons.hotel_outlined,
    'vehicle':  Icons.directions_car_outlined,
    'event':    Icons.event_outlined,
    'property': Icons.home_outlined,
    'taxi':     Icons.local_taxi_outlined,
    'sme':      Icons.store_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(customerBookingsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('My Bookings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'pending', 'confirmed', 'completed', 'cancelled']
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(s.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _filter == s ? Colors.white : Colors.white54)),
                            selected: _filter == s,
                            onSelected: (_) => setState(() => _filter = s),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            selectedColor: const Color(0xFFB8943F).withOpacity(0.2),
                            side: BorderSide(
                                color: _filter == s
                                    ? const Color(0xFFB8943F)
                                    : Colors.transparent),
                            showCheckmark: false,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) =>
                  Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
              data: (bookings) {
                final filtered = _filter == 'all'
                    ? bookings
                    : bookings.where((b) => b['status'] == _filter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.bookmark_border, size: 56, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('No bookings found',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Book stays, vehicles, events & more',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: const Color(0xFFB8943F),
                  onRefresh: () => ref.refresh(customerBookingsProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final b = filtered[i];
                      final status   = (b['status']       ?? 'pending').toString();
                      final vertical = (b['listing_type'] ?? '').toString();
                      final statusColor = _statusColors[status] ?? Colors.white38;
                      final icon = _verticalIcons[vertical] ?? Icons.receipt_outlined;
                      final createdAt = b['created_at'] != null
                          ? DateTime.tryParse(b['created_at'].toString())
                          : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.07)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFB8943F).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(icon,
                                  color: const Color(0xFFB8943F), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      vertical.isEmpty
                                          ? 'Booking'
                                          : vertical[0].toUpperCase() +
                                              vertical.substring(1),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  if (createdAt != null)
                                    Text(
                                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                                        style: const TextStyle(
                                            color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    'LKR ${b['total_price'] ?? b['total_amount'] ?? 0}',
                                    style: const TextStyle(
                                        color: Color(0xFFB8943F),
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(status.toUpperCase(),
                                      style: TextStyle(
                                          color: statusColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}