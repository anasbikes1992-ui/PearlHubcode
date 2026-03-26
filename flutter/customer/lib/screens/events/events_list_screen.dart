import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/listings_service.dart';
import '../../widgets/listing_card.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(eventsProvider(null));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'music', 'cultural', 'food', 'sports', 'arts', 'tech'].map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _category == c ? const Color(0xFFB8943F) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c == 'all' ? 'All' : c[0].toUpperCase() + c.substring(1), style: TextStyle(color: _category == c ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
              data: (events) {
                final filtered = _category == 'all' ? events : events.where((e) => (e.category ?? '') == _category).toList();
                if (filtered.isEmpty) return const Center(child: Text('No events found', style: TextStyle(color: Colors.white38)));
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EventCard(event: filtered[i], onTap: () => context.push('/events/${filtered[i].id}')),
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
