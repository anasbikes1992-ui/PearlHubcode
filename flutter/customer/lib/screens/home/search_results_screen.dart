import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

final searchResultsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final supabase = ref.read(supabaseProvider);
  final q = '%${query.trim()}%';
  final results = <Map<String, dynamic>>[];

  final futures = await Future.wait([
    supabase.from('stays').select('id, name, location, price_per_night, images, rating').ilike('name', q).eq('status', 'active').limit(5),
    supabase.from('vehicles').select('id, name, location, price_per_day, images, rating').ilike('name', q).eq('status', 'active').limit(5),
    supabase.from('events').select('id, title, location, ticket_price, images').ilike('title', q).eq('status', 'active').limit(5),
    supabase.from('properties').select('id, title, location, price, images').ilike('title', q).eq('status', 'active').limit(5),
  ]);

  for (final item in futures[0] as List) {
    results.add({...Map<String, dynamic>.from(item as Map), '_vertical': 'stays', '_display_name': item['name']});
  }
  for (final item in futures[1] as List) {
    results.add({...Map<String, dynamic>.from(item as Map), '_vertical': 'vehicles', '_display_name': item['name']});
  }
  for (final item in futures[2] as List) {
    results.add({...Map<String, dynamic>.from(item as Map), '_vertical': 'events', '_display_name': item['title']});
  }
  for (final item in futures[3] as List) {
    results.add({...Map<String, dynamic>.from(item as Map), '_vertical': 'properties', '_display_name': item['title']});
  }

  return results;
});

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String? query;
  const SearchResultsScreen({super.key, this.query});

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late TextEditingController _ctrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.query ?? '';
    _ctrl = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap(Map<String, dynamic> item) {
    final vertical = item['_vertical'] as String;
    final id = item['id']?.toString() ?? '';
    switch (vertical) {
      case 'stays':
        context.push('/stays/$id');
        break;
      case 'vehicles':
        context.push('/vehicles/$id');
        break;
      case 'events':
        context.push('/events/$id');
        break;
      case 'properties':
        context.push('/properties/$id');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: TextField(
          controller: _ctrl,
          autofocus: _query.isEmpty,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search stays, vehicles, events…',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          onSubmitted: (v) => setState(() => _query = v.trim()),
        ),
      ),
      body: _query.isEmpty
          ? _buildEmptySearch()
          : resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
              data: (items) => items.isEmpty
                  ? _buildNoResults()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ResultTile(item: items[i], onTap: () => _onTap(items[i])),
                    ),
            ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search, size: 64, color: Color(0xFFB8943F)),
          SizedBox(height: 16),
          Text('Search PearlHub', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Find stays, vehicles, events & more across Sri Lanka', style: TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text('No results for "$_query"', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Try different keywords or browse by category', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _ResultTile({required this.item, required this.onTap});

  static const _verticalIcons = {
    'stays': Icons.hotel_outlined,
    'vehicles': Icons.directions_car_outlined,
    'events': Icons.event_outlined,
    'properties': Icons.home_outlined,
    'sme': Icons.store_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final vertical = item['_vertical'] as String;
    final name = item['_display_name']?.toString() ?? 'Item';
    final location = item['location']?.toString() ?? '';
    final images = (item['images'] as List?)?.cast<String>() ?? [];
    final icon = _verticalIcons[vertical] ?? Icons.category_outlined;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: images.isNotEmpty
                  ? Image.network(images.first, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: const Color(0xFF2A2A3E), child: Icon(icon, color: Colors.white38)))
                  : Container(width: 64, height: 64, color: const Color(0xFF2A2A3E), child: Icon(icon, color: Colors.white38)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (location.isNotEmpty) ...
                    [const SizedBox(height: 4), Text(location, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8943F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(vertical.toUpperCase(), style: const TextStyle(color: Color(0xFFB8943F), fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
