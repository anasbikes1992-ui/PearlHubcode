import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/listings_service.dart';
import '../../widgets/listing_card.dart';

class StaysListScreen extends ConsumerStatefulWidget {
  const StaysListScreen({super.key});

  @override
  ConsumerState<StaysListScreen> createState() => _StaysListScreenState();
}

class _StaysListScreenState extends ConsumerState<StaysListScreen> {
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final staysAsync = ref.watch(staysProvider(null));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Stays', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'hotel', 'villa', 'guesthouse', 'apartment', 'resort'].map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _type == t ? const Color(0xFFB8943F) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t == 'all' ? 'All' : t[0].toUpperCase() + t.substring(1), style: TextStyle(color: _type == t ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: staysAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
              data: (stays) {
                final filtered = _type == 'all' ? stays : stays.where((s) => s.propertyType == _type).toList();
                if (filtered.isEmpty) return const Center(child: Text('No stays found', style: TextStyle(color: Colors.white38)));
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.74, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => StayCard(stay: filtered[i], onTap: () => context.push('/stays/${filtered[i].id}')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
