import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/listings_service.dart';

class SMEListScreen extends ConsumerStatefulWidget {
  const SMEListScreen({super.key});

  @override
  ConsumerState<SMEListScreen> createState() => _SMEListScreenState();
}

class _SMEListScreenState extends ConsumerState<SMEListScreen> {
  String _category = 'all';

  static const _categories = [
    'all',
    'food',
    'fashion',
    'beauty',
    'craft',
    'tech',
    'other'
  ];

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(smeBusinessesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('SME Marketplace',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _category = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _category == c
                                    ? const Color(0xFFB8943F)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                  c == 'all'
                                      ? 'All'
                                      : c[0].toUpperCase() + c.substring(1),
                                  style: TextStyle(
                                      color: _category == c
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white54))),
              data: (businesses) {
                final filtered = businesses
                    .where((b) =>
                        _category == 'all' ||
                        (b.category ?? '').toLowerCase() ==
                            _category.toLowerCase())
                    .toList();
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No businesses found',
                          style: TextStyle(color: Colors.white38)));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.88),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final b = filtered[i];
                    final initials = (b.businessName.isNotEmpty
                            ? b.businessName
                                .trim()
                                .split(' ')
                                .take(2)
                                .map((w) => w[0].toUpperCase())
                                .join()
                            : '?');
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.06))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                const Color(0xFFB8943F).withOpacity(0.18),
                            radius: 28,
                            child: Text(initials,
                                style: const TextStyle(
                                    color: Color(0xFFB8943F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ),
                          const SizedBox(height: 10),
                          Text(b.businessName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFB8943F).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(
                                (b.category ?? 'Other')[0].toUpperCase() +
                                    (b.category ?? 'Other').substring(1),
                                style: const TextStyle(
                                    color: Color(0xFFB8943F),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 11, color: Colors.white38),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(b.location ?? '',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
