import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/listings_service.dart';

class PropertyDetailScreen extends ConsumerWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyAsync = ref.watch(propertyDetailProvider(propertyId));
    return propertyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFB8943F)))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (property) => Scaffold(
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
                background: property.images.isNotEmpty
                    ? Image.network(property.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.home_outlined, size: 64, color: Colors.white24)))
                    : Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.home_outlined, size: 64, color: Colors.white24)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Expanded(child: Text(property.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFB8943F).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(property.listingType.name.toUpperCase(), style: const TextStyle(color: Color(0xFFB8943F), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFFB8943F), size: 16),
                    const SizedBox(width: 4),
                    Expanded(child: Text(property.location, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  // Price
                  Text('LKR ${property.price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB8943F), fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  // Specs
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      if (property.bedrooms > 0) _Chip('${property.bedrooms} beds', Icons.bed_outlined),
                      if (property.bathrooms > 0) _Chip('${property.bathrooms} baths', Icons.bathtub_outlined),
                      if (property.landSizeSqFt > 0) _Chip('${property.landSizeSqFt.toStringAsFixed(0)} sqft', Icons.square_foot),
                      _Chip(property.propertyType.name, Icons.home_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Description', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(property.description.isEmpty ? 'A property listing in Sri Lanka.' : property.description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
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
              onPressed: () => context.push('/checkout?listing_id=${property.id}&listing_type=property'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB8943F),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Send Inquiry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
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
    final propertyAsync = ref.watch(propertyDetailProvider(propertyId));
    return Scaffold(
      appBar: AppBar(title: const Text('Property details')),
      body: propertyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (property) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(property.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(property.location),
            const SizedBox(height: 8),
            Text(property.description),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => context.push('/checkout?listing_id=${property.id}&listing_type=property'), child: Text('Inquire for LKR ${property.price.toStringAsFixed(0)}')),
          ],
        ),
      ),
    );
  }
}
