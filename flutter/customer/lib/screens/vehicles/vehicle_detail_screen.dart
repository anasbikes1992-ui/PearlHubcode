import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/listings_service.dart';

class VehicleDetailScreen extends ConsumerWidget {
  final String vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    return vehicleAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFB8943F)))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (vehicle) => Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: const Color(0xFF0A0A0F),
              leading: GestureDetector(
                onTap: () => context.pop(),
                child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Colors.white)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: vehicle.images.isNotEmpty
                    ? Image.network(vehicle.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.directions_car_outlined, size: 64, color: Colors.white24)))
                    : Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.directions_car_outlined, size: 64, color: Colors.white24)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Expanded(child: Text(vehicle.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                      if (vehicle.rating > 0) Row(children: [
                        const Icon(Icons.star, color: Color(0xFFB8943F), size: 18),
                        const SizedBox(width: 4),
                        Text(vehicle.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${vehicle.make} ${vehicle.model} • ${vehicle.year}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFFB8943F), size: 16),
                    const SizedBox(width: 4),
                    Expanded(child: Text(vehicle.location, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  // Specs row
                  Row(
                    children: [
                      _SpecChip(icon: Icons.people, label: '${vehicle.seatingCapacity} Seats'),
                      const SizedBox(width: 8),
                      if (vehicle.withDriver) _SpecChip(icon: Icons.person, label: 'With Driver'),
                      if (vehicle.hasAc) ...[ const SizedBox(width: 8), const _SpecChip(icon: Icons.ac_unit, label: 'A/C')],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Text('LKR ${vehicle.pricePerDay.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB8943F), fontSize: 26, fontWeight: FontWeight.bold)),
                    const Text(' / day', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(vehicle.description.isEmpty ? 'A well-maintained vehicle available for hire.' : vehicle.description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => context.push('/checkout?listing_id=${vehicle.id}&listing_type=vehicle'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB8943F),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Reserve for LKR ${vehicle.pricePerDay.toStringAsFixed(0)} / day', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SpecChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xFFB8943F)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle details')),
      body: vehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (vehicle) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(vehicle.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${vehicle.make} ${vehicle.model} • ${vehicle.year}'),
            const SizedBox(height: 8),
            Text(vehicle.description),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => context.push('/checkout?listing_id=${vehicle.id}&listing_type=vehicle'), child: Text('Reserve for LKR ${vehicle.pricePerDay.toStringAsFixed(0)} / day')),
          ],
        ),
      ),
    );
  }
}
