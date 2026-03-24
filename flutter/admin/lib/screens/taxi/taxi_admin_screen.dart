import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

final taxiAdminSnapshotProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final categories = await supabase.from('taxi_vehicle_categories').select();
  final rides = await supabase.from('taxi_rides').select('id, status, fare, created_at').order('created_at', ascending: false).limit(100);
  return {
    'categories': List<Map<String, dynamic>>.from(categories),
    'rides': List<Map<String, dynamic>>.from(rides),
  };
});

class TaxiAdminScreen extends ConsumerStatefulWidget {
  const TaxiAdminScreen({super.key});

  @override
  ConsumerState<TaxiAdminScreen> createState() => _TaxiAdminScreenState();
}

class _TaxiAdminScreenState extends ConsumerState<TaxiAdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(taxiAdminSnapshotProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Taxi Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFB8943F)), onPressed: () => ref.invalidate(taxiAdminSnapshotProvider))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Row(
            children: ['Live Rides', 'Categories'].asMap().entries.map((e) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == e.key ? const Color(0xFFB8943F) : Colors.transparent, width: 2))),
                  child: Text(e.value, textAlign: TextAlign.center, style: TextStyle(color: _tab == e.key ? const Color(0xFFB8943F) : Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            )).toList(),
          ),
        ),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
        data: (snapshot) {
          final categories = snapshot['categories'] as List<Map<String, dynamic>>;
          final rides = snapshot['rides'] as List<Map<String, dynamic>>;
          final activeCount = rides.where((r) => ['searching', 'accepted', 'in_transit'].contains(r['status'])).length;
          if (_tab == 0) return _buildRides(rides, activeCount);
          return _buildCategories(categories);
        },
      ),
    );
  }

  Widget _buildRides(List<Map<String, dynamic>> rides, int activeCount) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          _KpiCard('Active Rides', activeCount.toString(), Icons.local_taxi, const Color(0xFF22C55E)),
          const SizedBox(width: 12),
          _KpiCard('Total Today', rides.length.toString(), Icons.receipt_outlined, const Color(0xFFB8943F)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: rides.length,
          itemBuilder: (_, i) {
            final r = rides[i];
            final status = r['status']?.toString() ?? '';
            Color sc = status == 'completed' ? const Color(0xFF3B82F6) : status == 'in_transit' ? const Color(0xFF22C55E) : status == 'searching' ? const Color(0xFFF59E0B) : Colors.white38;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Row(children: [
                const Icon(Icons.local_taxi_outlined, color: Color(0xFFB8943F), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(r['id'].toString().substring(0, 8) + '...', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                Text('LKR ${r['fare'] ?? 0}', style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: TextStyle(color: sc, fontSize: 9, fontWeight: FontWeight.bold))),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildCategories(List<Map<String, dynamic>> categories) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final c = categories[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.07))),
          child: Row(children: [
            const Icon(Icons.directions_car_outlined, color: Color(0xFFB8943F), size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((c['name'] ?? '').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Base fare: LKR ${c['base_fare'] ?? 0}  •  Per km: LKR ${c['per_km_rate'] ?? 0}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ])),
            Switch(
              value: c['is_active'] == true,
              activeColor: const Color(0xFFB8943F),
              onChanged: (v) async {
                await ref.read(supabaseProvider).from('taxi_vehicle_categories').update({'is_active': v}).eq('id', c['id']);
                ref.invalidate(taxiAdminSnapshotProvider);
              },
            ),
          ]),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }
}