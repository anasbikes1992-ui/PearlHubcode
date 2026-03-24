import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pearlhub_shared/services/listings_service.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    return eventAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFB8943F)))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (event) => Scaffold(
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
                background: event.images.isNotEmpty
                    ? Image.network(event.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.event_outlined, size: 64, color: Colors.white24)))
                    : Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.event_outlined, size: 64, color: Colors.white24)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.calendar_today_outlined, text: event.date),
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.access_time_outlined, text: event.time),
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.location_on_outlined, text: '${event.venue}, ${event.location}'),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Ticket Price', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('LKR ${event.ticketPrice.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB8943F), fontSize: 26, fontWeight: FontWeight.bold)),
                    ]),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Available', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('${event.availableTickets}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                  const SizedBox(height: 20),
                  const Text('About', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(event.description.isEmpty ? 'An exciting event in Sri Lanka.' : event.description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
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
              onPressed: event.availableTickets > 0 ? () => context.push('/checkout?listing_id=${event.id}&listing_type=event') : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB8943F),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(event.availableTickets > 0 ? 'Book Tickets \u2022 LKR ${event.ticketPrice.toStringAsFixed(0)}' : 'Sold Out', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }


class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: const Color(0xFFB8943F), size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
    ]);
  }
}
