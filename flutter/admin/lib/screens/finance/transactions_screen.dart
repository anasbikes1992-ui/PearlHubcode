import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

final adminTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('bookings')
      .select('id, total_amount, currency, status, created_at, listing_type')
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(data);
});

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _fs = 'all';

  static const Map<String, Color> _sc = {
    'confirmed': Color(0xFF22C55E),
    'pending':   Color(0xFFF59E0B),
    'cancelled': Color(0xFFEF4444),
    'completed': Color(0xFF3B82F6),
    'refunded':  Color(0xFF8B5CF6),
  };

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(adminTransactionsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFB8943F)), onPressed: () => ref.invalidate(adminTransactionsProvider))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'pending', 'confirmed', 'cancelled', 'refunded'].map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _fs = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _fs == s ? const Color(0xFFB8943F).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _fs == s ? const Color(0xFFB8943F) : Colors.transparent),
                      ),
                      child: Text(s.toUpperCase(), style: TextStyle(color: _fs == s ? const Color(0xFFB8943F) : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
          rows.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFB8943F)))),
            error: (e, _) => Expanded(child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54)))),
            data: (items) {
              final filtered = _fs == 'all' ? items : items.where((t) => t['status'] == _fs).toList();
              final total = filtered.fold<double>(0, (sum, t) => sum + ((t['total_amount'] ?? 0) as num).toDouble());
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8943F).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFB8943F).withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Text('Total (filtered)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const Spacer(),
                        Text('LKR ${total.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Text('${filtered.length} txns', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ]),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final t = filtered[i];
                          final status = (t['status'] ?? 'pending').toString();
                          final color = _sc[status] ?? Colors.white38;
                          final dt = t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) : null;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
                            child: Row(children: [
                              Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long_outlined, color: Color(0xFFB8943F), size: 18)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text((t['listing_type'] ?? 'Transaction').toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                if (dt != null) Text('${dt.day}/${dt.month}/${dt.year}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('LKR ${t['total_amount'] ?? 0}', style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 4),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
                              ]),
                            ]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}