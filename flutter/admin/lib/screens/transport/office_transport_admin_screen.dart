// admin/lib/screens/transport/office_transport_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final _officeAdminDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final plans  = await supabase.from('office_transport_plans').select().order('created_at');
  final routes = await supabase.from('office_transport_routes').select().order('name');
  final subs   = await supabase.from('office_transport_subscriptions')
      .select('*, office_transport_plans!plan_id(name), office_transport_routes!route_id(name, departure_time)')
      .order('created_at', ascending: false).limit(100);
  return {
    'plans':  List<Map<String, dynamic>>.from(plans),
    'routes': List<Map<String, dynamic>>.from(routes),
    'subs':   List<Map<String, dynamic>>.from(subs),
  };
});

class OfficeTransportAdminScreen extends ConsumerStatefulWidget {
  const OfficeTransportAdminScreen({super.key});

  @override
  ConsumerState<OfficeTransportAdminScreen> createState() => _OfficeTransportAdminScreenState();
}

class _OfficeTransportAdminScreenState extends ConsumerState<OfficeTransportAdminScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFB8943F);
  static const _bg   = Color(0xFF0A0A0F);
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_officeAdminDataProvider);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('Office Transport', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: _gold), onPressed: () => ref.invalidate(_officeAdminDataProvider)),
          IconButton(icon: const Icon(Icons.add, color: _gold), onPressed: () => _showCreateDialog(context)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _gold,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _gold,
          tabs: const [Tab(text: 'Plans'), Tab(text: 'Routes'), Tab(text: 'Subscriptions')],
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
        data: (data) => TabBarView(
          controller: _tabs,
          children: [
            _PlansTab(plans: data['plans'], onChanged: () => ref.invalidate(_officeAdminDataProvider)),
            _RoutesTab(routes: data['routes'], onChanged: () => ref.invalidate(_officeAdminDataProvider)),
            _SubsTab(subs: data['subs']),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A26),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        const Text('Create New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.loyalty, color: _gold),
          title: const Text('New Plan', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(context); _showPlanForm(context); },
        ),
        ListTile(
          leading: const Icon(Icons.route, color: _gold),
          title: const Text('New Route', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(context); _showRouteForm(context); },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _showPlanForm(BuildContext ctx) {
    final nameCtrl  = TextEditingController();
    final descCtrl  = TextEditingController();
    final priceCtrl = TextEditingController();
    final tripsCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A26),
        title: const Text('New Plan', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(nameCtrl, 'Plan Name', Colors.white),
          _field(descCtrl, 'Description', Colors.white),
          _field(priceCtrl, 'Price / Month (LKR)', Colors.white, type: TextInputType.number),
          _field(tripsCtrl, 'Trips / Month', Colors.white, type: TextInputType.number),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            onPressed: () async {
              try {
                await ref.read(supabaseProvider).from('office_transport_plans').insert({
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'price_per_month': double.tryParse(priceCtrl.text) ?? 0,
                  'trips_per_month': int.tryParse(tripsCtrl.text) ?? 0,
                  'active': true,
                });
                ref.invalidate(_officeAdminDataProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRouteForm(BuildContext ctx) {
    final nameCtrl    = TextEditingController();
    final originCtrl  = TextEditingController();
    final destCtrl    = TextEditingController();
    final depCtrl     = TextEditingController(text: '07:30');
    final retCtrl     = TextEditingController(text: '18:00');
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A26),
        title: const Text('New Route', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(nameCtrl, 'Route Name', Colors.white),
          _field(originCtrl, 'Origin', Colors.white),
          _field(destCtrl, 'Destination', Colors.white),
          _field(depCtrl, 'Departure time (HH:MM)', Colors.white),
          _field(retCtrl, 'Return time (HH:MM)', Colors.white),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            onPressed: () async {
              try {
                await ref.read(supabaseProvider).from('office_transport_routes').insert({
                  'name': nameCtrl.text.trim(),
                  'origin': originCtrl.text.trim(),
                  'destination': destCtrl.text.trim(),
                  'departure_time': depCtrl.text.trim(),
                  'return_time': retCtrl.text.trim(),
                  'active': true,
                });
                ref.invalidate(_officeAdminDataProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
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
        hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _gold)),
      ),
    ),
  );
}

// ── Plans tab ─────────────────────────────────────────────────────────────────
class _PlansTab extends ConsumerWidget {
  final List<Map<String, dynamic>> plans;
  final VoidCallback onChanged;
  const _PlansTab({required this.plans, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plans.isEmpty) return const Center(child: Text('No plans configured', style: TextStyle(color: Colors.white38)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = plans[i];
        final active = p['active'] as bool? ?? true;
        return ListTile(
          tileColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFB8943F).withOpacity(0.15),
            child: const Icon(Icons.loyalty, color: Color(0xFFB8943F), size: 20),
          ),
          title: Text(p['name'] ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Rs. ${p['price_per_month']} / month  ·  ${p['trips_per_month']} trips',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Switch(
            value: active,
            activeColor: const Color(0xFFB8943F),
            onChanged: (v) async {
              await ref.read(supabaseProvider).from('office_transport_plans').update({'active': v}).eq('id', p['id']);
              onChanged();
            },
          ),
        );
      },
    );
  }
}

// ── Routes tab ────────────────────────────────────────────────────────────────
class _RoutesTab extends ConsumerWidget {
  final List<Map<String, dynamic>> routes;
  final VoidCallback onChanged;
  const _RoutesTab({required this.routes, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routes.isEmpty) return const Center(child: Text('No routes configured', style: TextStyle(color: Colors.white38)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = routes[i];
        final active = r['active'] as bool? ?? true;
        return ListTile(
          tileColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF26A69A).withOpacity(0.15),
            child: const Icon(Icons.route, color: Color(0xFF26A69A), size: 20),
          ),
          title: Text(r['name'] ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${r['origin'] ?? '?'} → ${r['destination'] ?? '?'}\n🕖 ${r['departure_time'] ?? '—'}  ·  🏠 ${r['return_time'] ?? '—'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          isThreeLine: true,
          trailing: Switch(
            value: active,
            activeColor: const Color(0xFF26A69A),
            onChanged: (v) async {
              await ref.read(supabaseProvider).from('office_transport_routes').update({'active': v}).eq('id', r['id']);
              onChanged();
            },
          ),
        );
      },
    );
  }
}

// ── Subscriptions tab ─────────────────────────────────────────────────────────
class _SubsTab extends StatelessWidget {
  final List<Map<String, dynamic>> subs;
  const _SubsTab({required this.subs});

  @override
  Widget build(BuildContext context) {
    if (subs.isEmpty) return const Center(child: Text('No subscriptions yet', style: TextStyle(color: Colors.white38)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: subs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = subs[i];
        final plan  = s['office_transport_plans'];
        final route = s['office_transport_routes'];
        final active = s['active'] as bool? ?? false;
        final expires = (s['expires_at'] ?? '').toString().split('T')[0];
        return ListTile(
          tileColor: const Color(0xFF1A1A26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: CircleAvatar(
            backgroundColor: active ? const Color(0xFF22C55E).withOpacity(0.15) : Colors.white10,
            child: Icon(Icons.card_membership, color: active ? const Color(0xFF22C55E) : Colors.white38, size: 20),
          ),
          title: Text(plan != null ? plan['name'] as String : 'Unknown plan',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${route != null ? route['name'] as String : '—'}  ·  Exp: $expires',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF22C55E).withOpacity(0.12) : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(active ? 'Active' : 'Inactive',
                style: TextStyle(color: active ? const Color(0xFF22C55E) : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
