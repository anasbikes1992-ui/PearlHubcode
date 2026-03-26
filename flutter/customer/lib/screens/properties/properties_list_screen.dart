import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/listings_service.dart';

class PropertiesListScreen extends ConsumerStatefulWidget {
  const PropertiesListScreen({super.key});

  @override
  ConsumerState<PropertiesListScreen> createState() => _PropertiesListScreenState();
}

class _PropertiesListScreenState extends ConsumerState<PropertiesListScreen> {
  String _listingType = 'all';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(propertiesProvider(null));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Properties', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'sale', 'rent', 'lease'].map((lt) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _listingType = lt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _listingType == lt ? const Color(0xFFB8943F) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(lt == 'all' ? 'All' : lt[0].toUpperCase() + lt.substring(1), style: TextStyle(color: _listingType == lt ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
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
              data: (properties) {
                final filtered = _listingType == 'all' ? properties : properties.where((p) => (p.listingType ?? '') == _listingType).toList();
                if (filtered.isEmpty) return const Center(child: Text('No properties found', style: TextStyle(color: Colors.white38)));
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return GestureDetector(
                      onTap: () => context.push('/properties/${p.id}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: p.images.isNotEmpty
                                ? Image.network(p.images.first, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: Colors.white.withOpacity(0.05), child: const Icon(Icons.home_outlined, color: Colors.white24)))
                                : Container(width: 72, height: 72, color: Colors.white.withOpacity(0.05), child: const Icon(Icons.home_outlined, color: Colors.white24)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(p.location ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('LKR ${p.price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFB8943F).withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text((p.listingType ?? 'sale').toUpperCase(), style: const TextStyle(color: Color(0xFFB8943F), fontSize: 9, fontWeight: FontWeight.bold))),
                            ]),
                          ])),
                        ]),
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
              subtitle: Text('${properties[i].location} • LKR ${properties[i].price.toStringAsFixed(0)}'),
              onTap: () => context.push('/properties/${properties[i].id}'),
            ),
          ),
        ),
      ),
    );
  }
}
