// admin/lib/screens/moderation/listings_moderation_screen.dart
// Full listing moderation — mirrors AdminDashboard.tsx StatusControlModal in Flutter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/models/user_profile.dart';
import 'package:pearlhub_shared/services/auth_service.dart';
import 'package:pearlhub_shared/services/listings_service.dart';

// Dynamic provider for any vertical's listings
final verticalListingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, vertical) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from(_tableFor(vertical))
      .select()
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(data);
});

String _tableFor(String vertical) => switch (vertical) {
  'stays' => 'stays',
  'vehicles' => 'vehicles',
  'properties' => 'properties',
  'events' => 'events',
  'sme' => 'sme_businesses',
  'social' => 'social_posts',
  _ => 'stays',
};

class ListingsModerationScreen extends ConsumerStatefulWidget {
  final String vertical;
  const ListingsModerationScreen({super.key, required this.vertical});

  @override
  ConsumerState<ListingsModerationScreen> createState() => _ListingsModerationScreenState();
}

class _ListingsModerationScreenState extends ConsumerState<ListingsModerationScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(verticalListingsProvider(widget.vertical));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_verticalLabel(widget.vertical)} Moderation',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(verticalListingsProvider(widget.vertical)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status filter chips ────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: ['all', 'pending', 'active', 'paused', 'off', 'rejected'].map((s) {
                final selected = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s == 'all' ? 'All' : s.capitalize()),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = s),
                    selectedColor: _statusColor(s).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: selected ? _statusColor(s) : Colors.grey.shade700,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Listings list ──────────────────────────────────────────────
          Expanded(
            child: listingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
              data: (items) {
                final filtered = _statusFilter == 'all'
                    ? items
                    : items.where((i) => i['status'] == _statusFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('No ${_statusFilter == 'all' ? '' : _statusFilter} listings',
                          style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _ListingModerationCard(
                    item: filtered[i],
                    vertical: widget.vertical,
                    onStatusChanged: () => ref.invalidate(verticalListingsProvider(widget.vertical)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _verticalLabel(String v) => switch (v) {
    'stays' => 'Stays',
    'vehicles' => 'Vehicles',
    'properties' => 'Properties',
    'events' => 'Events',
    'sme' => 'SME',
    'social' => 'Social',
    _ => v,
  };

  Color _statusColor(String s) => switch (s) {
    'active' => Colors.green,
    'pending' => Colors.blue,
    'paused' => Colors.orange,
    'off' => Colors.grey,
    'rejected' => Colors.red,
    _ => Colors.grey,
  };
}

// ── Individual listing moderation card ────────────────────────────────────
class _ListingModerationCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final String vertical;
  final VoidCallback onStatusChanged;

  const _ListingModerationCard({
    required this.item,
    required this.vertical,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = item['status'] ?? 'pending';
    final title = item['title'] ?? item['name'] ?? item['business_name'] ?? 'Untitled';
    final location = item['location'] ?? '';
    final createdAt = item['created_at']?.toString().substring(0, 10) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: item['images'] != null && (item['images'] as List).isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(item['images'][0], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, color: Colors.grey)),
                        )
                      : const Icon(Icons.image_outlined, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(location, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ],
                      const SizedBox(height: 4),
                      Text('Listed: $createdAt', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),

            // Admin note
            if (item['admin_note'] != null && (item['admin_note'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note_outlined, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item['admin_note'], style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action buttons — mirrors StatusControlModal in web app
            Row(
              children: [
                _StatusButton(label: 'Active', current: status, value: 'active', color: Colors.green,
                  onTap: () => _changeStatus(context, ref, 'active')),
                const SizedBox(width: 8),
                _StatusButton(label: 'Pause', current: status, value: 'paused', color: Colors.orange,
                  onTap: () => _changeStatus(context, ref, 'paused')),
                const SizedBox(width: 8),
                _StatusButton(label: 'Off', current: status, value: 'off', color: Colors.red,
                  onTap: () => _changeStatus(context, ref, 'off')),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _showStatusModal(context, ref),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  child: const Text('Note', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, String newStatus) async {
    final supabase = ref.read(supabaseProvider);
    final table = _tableFor(vertical);
    await supabase.from(table).update({'status': newStatus}).eq('id', item['id']);
    onStatusChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showStatusModal(BuildContext context, WidgetRef ref) async {
    final noteCtrl = TextEditingController(text: item['admin_note'] ?? '');
    String selectedStatus = item['status'] ?? 'pending';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Moderation Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                // Status options
                ...['active', 'paused', 'off', 'rejected'].map((s) => RadioListTile<String>(
                  title: Text(s.capitalize(), style: TextStyle(color: _colorForStatus(s))),
                  value: s,
                  groupValue: selectedStatus,
                  onChanged: (v) => setModal(() => selectedStatus = v!),
                  activeColor: _colorForStatus(s),
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Admin note (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final supabase = ref.read(supabaseProvider);
                    final table = _tableFor(vertical);
                    await supabase.from(table).update({
                      'status': selectedStatus,
                      'admin_note': noteCtrl.text.trim(),
                    }).eq('id', item['id']);
                    onStatusChanged();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorForStatus(String s) => switch (s) {
    'active' => Colors.green,
    'paused' => Colors.orange,
    'off' || 'rejected' => Colors.red,
    _ => Colors.blue,
  };
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => Colors.green,
      'pending' => Colors.blue,
      'paused' => Colors.orange,
      'off' => Colors.grey,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final String current;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({required this.label, required this.current, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.grey.shade200),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: active ? color : Colors.grey, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

extension StringX on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
