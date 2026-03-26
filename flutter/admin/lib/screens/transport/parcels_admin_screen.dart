// admin/lib/screens/transport/parcels_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final _parcelsAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(supabaseProvider)
      .from('parcel_deliveries')
      .select('*, parcel_item_types(name, icon)')
      .order('created_at', ascending: false)
      .limit(200);
  return (data as List).cast<Map<String, dynamic>>();
});

final _parcelItemTypesAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(supabaseProvider).from('parcel_item_types').select().order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

const List<String> _pipeline = ['pending', 'confirmed', 'picked_up', 'in_transit', 'delivered', 'cancelled'];

class ParcelsAdminScreen extends ConsumerStatefulWidget {
  const ParcelsAdminScreen({super.key});

  @override
  ConsumerState<ParcelsAdminScreen> createState() => _ParcelsAdminScreenState();
}

class _ParcelsAdminScreenState extends ConsumerState<ParcelsAdminScreen>
    with SingleTickerProviderStateMixin {
  static const _gold   = Color(0xFFB8943F);
  static const _orange = Color(0xFFE65100);
  static const _bg     = Color(0xFF0A0A0F);
  late final TabController _tabs;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('Parcel Deliveries', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _gold), onPressed: () {
            ref.invalidate(_parcelsAdminProvider);
            ref.invalidate(_parcelItemTypesAdminProvider);
          }),
          IconButton(icon: const Icon(Icons.add_box_outlined, color: _gold), onPressed: () => _showItemTypeForm(context)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _orange,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _orange,
          tabs: const [Tab(text: 'Deliveries'), Tab(text: 'Item Types')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DeliveriesTab(filter: _filter, onFilterChanged: (f) => setState(() => _filter = f)),
          const _ItemTypesTab(),
        ],
      ),
    );
  }

  void _showItemTypeForm(BuildContext context) {
    final nameCtrl  = TextEditingController();
    final iconCtrl  = TextEditingController(text: '📦');
    final priceCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A26),
        title: const Text('New Item Type', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(nameCtrl, 'Name (e.g. Documents)', Colors.white),
          _field(iconCtrl, 'Emoji Icon', Colors.white),
          _field(priceCtrl, 'Base Price (LKR)', Colors.white, type: TextInputType.number),
          _field(weightCtrl, 'Max Weight (kg)', Colors.white, type: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            onPressed: () async {
              try {
                await ref.read(supabaseProvider).from('parcel_item_types').insert({
                  'name': nameCtrl.text.trim(),
                  'icon': iconCtrl.text.trim(),
                  'base_price': double.tryParse(priceCtrl.text) ?? 350,
                  'max_weight_kg': double.tryParse(weightCtrl.text) ?? 5.0,
                  'active': true,
                });
                ref.invalidate(_parcelItemTypesAdminProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, Color color, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c, keyboardType: type,
      style: TextStyle(color: color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _orange)),
      ),
    ),
  );
}

// ── Deliveries tab ────────────────────────────────────────────────────────────
class _DeliveriesTab extends ConsumerWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;
  const _DeliveriesTab({required this.filter, required this.onFilterChanged});

  static const _orange = Color(0xFFE65100);

  Color _statusColor(String s) => switch (s) {
    'confirmed'  => const Color(0xFF22C55E),
    'picked_up'  => const Color(0xFFF59E0B),
    'in_transit' => const Color(0xFF3B82F6),
    'delivered'  => const Color(0xFF10B981),
    'cancelled'  => const Color(0xFFEF4444),
    _            => const Color(0xFFD1D5DB),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(_parcelsAdminProvider);
    return Column(children: [
      // Filter chips
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          for (final s in ['all', ..._pipeline])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s == 'picked_up' ? 'Picked Up' : s == 'in_transit' ? 'In Transit' : s[0].toUpperCase() + s.substring(1)),
                selected: filter == s,
                onSelected: (_) => onFilterChanged(s),
                selectedColor: _orange,
                labelStyle: TextStyle(color: filter == s ? Colors.white : Colors.white60, fontSize: 11),
                backgroundColor: Colors.white10,
              ),
            ),
        ]),
      ),

      Expanded(
        child: deliveriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _orange)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
          data: (deliveries) {
            final filtered = filter == 'all' ? deliveries : deliveries.where((d) => d['status'] == filter).toList();
            if (filtered.isEmpty) return Center(child: Text('No $filter deliveries', style: const TextStyle(color: Colors.white38)));
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final d = filtered[i];
                final status = d['status']?.toString() ?? 'pending';
                final itemType = d['parcel_item_types'];
                return Card(
                  color: const Color(0xFF1A1A26),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _statusColor(status).withOpacity(0.3))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(
                          itemType != null ? '${itemType['icon'] ?? '📦'} ${itemType['name']}' : '📦 Parcel',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(status.replaceAll('_', ' '),
                              style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      _row('From', '${d['pickup_address'] ?? '—'}\n📞 ${d['sender_phone'] ?? '—'}'),
                      _row('To', '${d['dropoff_address'] ?? '—'}\n📞 ${d['recipient_phone'] ?? '—'}'),
                      _row('Fare', 'Rs. ${((d['fare'] ?? 0) as num).toStringAsFixed(0)}${d['insured'] == true ? '  (insured)' : ''}'),
                      if (d['fragile'] == true) _row('', '⚠️ Fragile'),
                      const SizedBox(height: 8),
                      // Status pipeline buttons
                      _StatusPipeline(deliveryId: d['id'] as String, currentStatus: status,
                          onChanged: () => ref.invalidate(_parcelsAdminProvider)),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 50, child: Text(k, style: const TextStyle(color: Colors.white38, fontSize: 12))),
      Expanded(child: Text(v, style: const TextStyle(color: Colors.white70, fontSize: 12))),
    ]),
  );
}

class _StatusPipeline extends ConsumerWidget {
  final String deliveryId;
  final String currentStatus;
  final VoidCallback onChanged;
  const _StatusPipeline({required this.deliveryId, required this.currentStatus, required this.onChanged});

  static const _orange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _pipeline.indexOf(currentStatus);
    if (currentStatus == 'delivered' || currentStatus == 'cancelled') return const SizedBox.shrink();
    final nextStatuses = _pipeline.sublist((currentIndex + 1).clamp(0, _pipeline.length), _pipeline.length);
    final actionable = nextStatuses.where((s) => s != 'cancelled' || currentStatus != 'delivered').take(2).toList();
    if (actionable.isEmpty) return const SizedBox.shrink();

    return Row(children: actionable.map((s) => Expanded(child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: s == 'cancelled' ? const Color(0xFFEF4444) : _orange, width: 1),
          foregroundColor: s == 'cancelled' ? const Color(0xFFEF4444) : _orange,
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () async {
          try {
            await ref.read(supabaseProvider).from('parcel_deliveries').update({'status': s}).eq('id', deliveryId);
            onChanged();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        },
        child: Text(s.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    ))).toList());
  }
}

// ── Item types tab ────────────────────────────────────────────────────────────
class _ItemTypesTab extends ConsumerWidget {
  const _ItemTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(_parcelItemTypesAdminProvider);
    return typesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
      data: (types) {
        if (types.isEmpty) return const Center(child: Text('No item types configured', style: TextStyle(color: Colors.white38)));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: types.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final t = types[i];
            final active = t['active'] as bool? ?? true;
            return ListTile(
              tileColor: const Color(0xFF1A1A26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Text(t['icon'] ?? '📦', style: const TextStyle(fontSize: 24)),
              title: Text(t['name'] ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Rs. ${t['base_price']}  ·  Max ${t['max_weight_kg']} kg', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: Switch(
                value: active,
                activeColor: const Color(0xFFE65100),
                onChanged: (v) async {
                  await ref.read(supabaseProvider).from('parcel_item_types').update({'active': v}).eq('id', t['id']);
                  ref.invalidate(_parcelItemTypesAdminProvider);
                },
              ),
            );
          },
        );
      },
    );
  }
}
