import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pearlhub_shared/services/listings_service.dart';

class StayDetailScreen extends ConsumerStatefulWidget {
  final String stayId;
  const StayDetailScreen({super.key, required this.stayId});

  @override
  ConsumerState<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends ConsumerState<StayDetailScreen> {
  int _currentImage = 0;

  @override
  Widget build(BuildContext context) {
    final stayAsync = ref.watch(stayDetailProvider(widget.stayId));
    return stayAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFB8943F)))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (stay) => Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: const Color(0xFF0A0A0F),
              leading: GestureDetector(
                onTap: () => context.pop(),
                child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Colors.white)),
              ),
              actions: [
                GestureDetector(
                  onTap: () {},
                  child: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.favorite_border, color: Colors.white)),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: stay.images.isNotEmpty
                    ? PageView.builder(
                        itemCount: stay.images.length,
                        onPageChanged: (i) => setState(() => _currentImage = i),
                        itemBuilder: (_, i) => Image.network(stay.images[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.hotel_outlined, size: 48, color: Colors.white24))),
                      )
                    : Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.hotel_outlined, size: 64, color: Colors.white24)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Image dots
                  if (stay.images.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(stay.images.length, (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentImage ? 20 : 6, height: 6,
                        decoration: BoxDecoration(
                          color: i == _currentImage ? const Color(0xFFB8943F) : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                    ),
                  const SizedBox(height: 16),
                  // Name + Rating
                  Row(
                    children: [
                      Expanded(child: Text(stay.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                      Row(children: [
                        const Icon(Icons.star, color: Color(0xFFB8943F), size: 18),
                        const SizedBox(width: 4),
                        Text(stay.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFFB8943F), size: 16),
                    const SizedBox(width: 4),
                    Expanded(child: Text(stay.location, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                  ]),
                  const SizedBox(height: 20),
                  // Divider
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  // Price
                  Row(children: [
                    Text('LKR ${stay.pricePerNight.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB8943F), fontSize: 26, fontWeight: FontWeight.bold)),
                    const Text(' / night', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ]),
                  const SizedBox(height: 20),
                  // Description
                  const Text('About this stay', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(stay.description.isEmpty ? 'A beautiful stay in Sri Lanka.' : stay.description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
                  const SizedBox(height: 20),
                  // Amenities
                  if (stay.amenities.isNotEmpty) ...[
                    const Text('Amenities', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: stay.amenities.map((a) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(a, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
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
              onPressed: () => context.push('/checkout?listing_id=${stay.id}&listing_type=stay'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB8943F),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Book for LKR ${stay.pricePerNight.toStringAsFixed(0)} / night', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stayAsync = ref.watch(stayDetailProvider(stayId));
    return Scaffold(
      appBar: AppBar(title: const Text('Stay details')),
      body: stayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stay) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: stay.images.isNotEmpty
                  ? Image.network(stay.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12, child: Icon(Icons.hotel_outlined, size: 48)))
                  : const ColoredBox(color: Colors.black12, child: Icon(Icons.hotel_outlined, size: 48)),
            ),
            const SizedBox(height: 16),
            Text(stay.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(stay.location),
            const SizedBox(height: 12),
            Text(stay.description),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => context.push('/checkout?listing_id=${stay.id}&listing_type=stay'), child: Text('Book for LKR ${stay.pricePerNight.toStringAsFixed(0)} / night')),
          ],
        ),
      ),
    );
  }
}
