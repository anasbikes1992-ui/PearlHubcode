// customer/lib/screens/office_transport/office_transport_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _plansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(supabaseProvider).from('office_transport_plans').select().eq('active', true).order('price_per_month');
  return (data as List).cast<Map<String, dynamic>>();
});

final _routesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.read(supabaseProvider).from('office_transport_routes').select().eq('active', true);
  return (data as List).cast<Map<String, dynamic>>();
});

final _subscriptionProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final data = await ref.read(supabaseProvider)
      .from('office_transport_subscriptions')
      .select('*, office_transport_plans(name, price_per_month), office_transport_routes(name, origin, destination, departure_time)')
      .eq('user_id', userId)
      .eq('active', true)
      .maybeSingle();
  return data;
});

final _walletProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  return await ref.read(supabaseProvider)
      .from('office_transport_wallets')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class OfficeTransportScreen extends ConsumerStatefulWidget {
  const OfficeTransportScreen({super.key});

  @override
  ConsumerState<OfficeTransportScreen> createState() => _OfficeTransportScreenState();
}

class _OfficeTransportScreenState extends ConsumerState<OfficeTransportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _gold = Color(0xFFB8943F);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.user?.id ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Office Transport', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: _gold,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _gold,
          tabs: const [
            Tab(icon: Icon(Icons.route, size: 18), text: 'Routes'),
            Tab(icon: Icon(Icons.card_membership, size: 18), text: 'Plans'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Wallet'),
            Tab(icon: Icon(Icons.qr_code_2, size: 18), text: 'QR Pass'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RoutesTab(),
          _PlansTab(userId: userId),
          _WalletTab(userId: userId),
          _QRTab(userId: userId),
        ],
      ),
    );
  }
}

// ── Routes tab ────────────────────────────────────────────────────────────────
class _RoutesTab extends ConsumerWidget {
  const _RoutesTab();
  static const _gold = Color(0xFFB8943F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_routesProvider);
    return async.when(
      data: (routes) => routes.isEmpty
          ? _empty('No routes available yet', Icons.route)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: routes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final r = routes[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: _gold.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.directions_bus, color: _gold),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('${r['origin'] ?? ''} → ${r['destination'] ?? ''}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        if (r['departure_time'] != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.schedule, size: 12, color: Color(0xFFB8943F)),
                            const SizedBox(width: 4),
                            Text('Departs ${r['departure_time']}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFB8943F), fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Active', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Plans tab ────────────────────────────────────────────────────────────────
class _PlansTab extends ConsumerStatefulWidget {
  final String userId;
  const _PlansTab({required this.userId});

  @override
  ConsumerState<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends ConsumerState<_PlansTab> {
  static const _gold = Color(0xFFB8943F);
  bool _subscribing = false;

  Future<void> _subscribe(String planId, String planName, BuildContext ctx) async {
    if (widget.userId.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      return;
    }
    // Pick a route first
    final routes = ref.read(_routesProvider).value ?? [];
    if (routes.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No routes available.')));
      return;
    }
    String? routeId = routes.first['id'] as String?;
    if (routes.length > 1) {
      routeId = await showDialog<String>(
        context: ctx,
        builder: (dCtx) => AlertDialog(
          title: const Text('Select Route', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: routes.map<Widget>((r) => ListTile(
              title: Text(r['name'] ?? ''),
              subtitle: Text('${r['origin'] ?? ''} → ${r['destination'] ?? ''}'),
              onTap: () => Navigator.of(dCtx).pop(r['id'] as String?),
            )).toList(),
          ),
        ),
      );
      if (routeId == null) return;
    }

    setState(() => _subscribing = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final expires = DateTime.now().add(const Duration(days: 30));
      await supabase.from('office_transport_subscriptions').insert({
        'user_id': widget.userId,
        'plan_id': planId,
        'route_id': routeId,
        'active': true,
        'expires_at': expires.toIso8601String(),
      });
      if (mounted) {
        ref.refresh(_subscriptionProvider(widget.userId));
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('✅ Subscribed to $planName!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(_plansProvider);
    final subAsync = ref.watch(_subscriptionProvider(widget.userId));

    return plansAsync.when(
      data: (plans) => plans.isEmpty
          ? _empty('No plans available yet', Icons.card_membership)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final p = plans[i];
                final isSubbed = subAsync.value?['plan_id'] == p['id'];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isSubbed ? _gold : Colors.grey.shade200),
                  ),
                  elevation: isSubbed ? 3 : 1,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        if (isSubbed) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Active', style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ]),
                      if (p['description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(p['description'], style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        Text('Rs. ${((p['price_per_month'] ?? 0) as num).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: _gold)),
                        Text(' / month', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        if (p['trips_per_month'] != null) ...[
                          const Spacer(),
                          Text('${p['trips_per_month']} trips', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubbed || _subscribing ? null : () => _subscribe(p['id'] as String, p['name'] ?? '', ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSubbed ? Colors.grey.shade200 : _gold,
                            foregroundColor: isSubbed ? Colors.grey : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(isSubbed ? 'Subscribed' : 'Subscribe',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Wallet tab ────────────────────────────────────────────────────────────────
class _WalletTab extends ConsumerStatefulWidget {
  final String userId;
  const _WalletTab({required this.userId});

  @override
  ConsumerState<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<_WalletTab> {
  static const _gold = Color(0xFFB8943F);
  final _amountCtrl = TextEditingController();
  bool _topping = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    final amt = double.tryParse(_amountCtrl.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    setState(() => _topping = true);
    try {
      await ref.read(supabaseProvider).rpc('topup_office_transport_wallet', params: {
        'p_user_id': widget.userId,
        'p_amount': amt,
        'p_reference': 'APP_TOPUP_${DateTime.now().millisecondsSinceEpoch}',
      });
      ref.refresh(_walletProvider(widget.userId));
      _amountCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Added Rs. ${amt.toStringAsFixed(0)} to wallet.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(_walletProvider(widget.userId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: const Color(0xFF1A1A2E),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Transport Wallet', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              walletAsync.when(
                data: (w) => Text(
                  'Rs. ${((w?['balance'] ?? 0) as num).toStringAsFixed(2)}',
                  style: const TextStyle(color: _gold, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                loading: () => const SizedBox(height: 36, child: CircularProgressIndicator(color: _gold)),
                error: (_, __) => const Text('Rs. 0.00', style: TextStyle(color: _gold, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              const Text('Available Balance', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Top-up
        const Text('Top Up Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Row(children: [
          ...([500, 1000, 2000, 5000].map((amt) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _amountCtrl.text = amt.toString(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.08),
                  border: Border.all(color: _gold.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Rs. $amt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _gold)),
              ),
            ),
          ))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Custom amount',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _topping ? null : _topUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
            ),
            child: _topping
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Top Up', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ],
    );
  }
}

// ── QR Tab ────────────────────────────────────────────────────────────────────
class _QRTab extends ConsumerWidget {
  final String userId;
  const _QRTab({required this.userId});
  static const _gold = Color(0xFFB8943F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(_subscriptionProvider(userId));

    return subAsync.when(
      data: (sub) => sub == null
          ? _empty('No active subscription', Icons.qr_code_2,
              subtitle: 'Subscribe to a plan to get your QR boarding pass.')
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Your Boarding QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(sub['office_transport_plans']?['name'] ?? 'Plan',
                    style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Center(child: _QrWidget(seed: sub['id'] as String? ?? userId)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.06),
                    border: Border.all(color: _gold.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    _infoRow(Icons.route, 'Route',
                        sub['office_transport_routes']?['name'] ?? '—'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.schedule, 'Departure',
                        sub['office_transport_routes']?['departure_time'] ?? '—'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.calendar_today, 'Valid Until',
                        sub['expires_at'] != null
                            ? DateTime.parse(sub['expires_at']).toLocal().toString().split(' ')[0]
                            : '—'),
                  ]),
                ),
              ],
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 16, color: _gold),
    const SizedBox(width: 8),
    Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
    Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
  ]);
}

// ── Deterministic QR widget ───────────────────────────────────────────────────
class _QrWidget extends StatelessWidget {
  final String seed;
  const _QrWidget({required this.seed});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: _QrPainter(seed: seed),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String seed;
  const _QrPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed.codeUnits.fold(0, (p, c) => p * 31 + c));
    const cells = 21;
    final cell = size.width / cells;
    final paint = Paint()..color = Colors.black;
    // Corner markers
    for (final pos in [const Offset(0, 0), Offset(cells - 7.0, 0), Offset(0, cells - 7.0)]) {
      canvas.drawRect(
          Rect.fromLTWH(pos.dx * cell, pos.dy * cell, 7 * cell, 7 * cell), paint);
      canvas.drawRect(
          Rect.fromLTWH((pos.dx + 1) * cell, (pos.dy + 1) * cell, 5 * cell, 5 * cell),
          Paint()..color = Colors.white);
      canvas.drawRect(
          Rect.fromLTWH((pos.dx + 2) * cell, (pos.dy + 2) * cell, 3 * cell, 3 * cell), paint);
    }
    // Random data cells
    for (int r = 0; r < cells; r++) {
      for (int c = 0; c < cells; c++) {
        if (_isCorner(r, c)) continue;
        if (rng.nextBool()) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell - 0.5, cell - 0.5), paint);
        }
      }
    }
  }

  bool _isCorner(int r, int c) {
    const cells = 21;
    if (r < 7 && c < 7) return true;
    if (r < 7 && c >= cells - 7) return true;
    if (r >= cells - 7 && c < 7) return true;
    return false;
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.seed != seed;
}

// Shared util
Widget _empty(String message, IconData icon, {String? subtitle}) => Center(
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 64, color: Colors.grey.shade300),
    const SizedBox(height: 16),
    Text(message, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
    if (subtitle != null) ...[
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 13), textAlign: TextAlign.center),
      ),
    ],
  ]),
);
