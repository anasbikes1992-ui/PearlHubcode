import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final taxiHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await supabase
      .from('taxi_rides')
      .select('id, status, fare, pickup_address, dropoff_address, created_at, distance_km')
      .eq('rider_id', userId)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data as List);
});

class TaxiHistoryScreen extends ConsumerWidget {
  const TaxiHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(taxiHistoryProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Ride History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: rides.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.local_taxi_outlined, size: 56, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No rides yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Book your first taxi ride',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: const Color(0xFFB8943F),
            onRefresh: () => ref.refresh(taxiHistoryProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final r = items[i];
                final status = r['status']?.toString() ?? 'completed';
                Color sc = status == 'completed'
                    ? const Color(0xFF3B82F6)
                    : status == 'cancelled'
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E);
                final dt = r['created_at'] != null
                    ? DateTime.tryParse(r['created_at'].toString())
                    : null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_taxi_outlined,
                              color: Color(0xFFB8943F), size: 20),
                          const SizedBox(width: 10),
                          if (dt != null)
                            Text(
                                '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: sc.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(status.toUpperCase(),
                                  style: TextStyle(
                                      color: sc,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AddressRow(Icons.radio_button_checked,
                          const Color(0xFF22C55E),
                          (r['pickup_address'] ?? 'Pickup').toString()),
                      const Padding(
                        padding: EdgeInsets.only(left: 11),
                        child: SizedBox(
                            height: 10,
                            child: VerticalDivider(
                                color: Colors.white24, width: 1)),
                      ),
                      _AddressRow(Icons.location_on_outlined,
                          const Color(0xFFEF4444),
                          (r['dropoff_address'] ?? 'Dropoff').toString()),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (r['distance_km'] != null) ...[
                            const Icon(Icons.straighten,
                                size: 14, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text('${r['distance_km']} km',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            const SizedBox(width: 16),
                          ],
                          const Spacer(),
                          Text('LKR ${r['fare'] ?? 0}',
                              style: const TextStyle(
                                  color: Color(0xFFB8943F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
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
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AddressRow(this.icon, this.color, this.text);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ],
      );
}
