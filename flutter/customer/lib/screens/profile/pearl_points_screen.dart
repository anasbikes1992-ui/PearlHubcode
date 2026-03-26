import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final pearlPointsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;
  // pearl_points is a separate table, not a column on profiles
  final data = await supabase
      .from('pearl_points')
      .select('total_earned, total_redeemed, balance')
      .eq('user_id', userId)
      .maybeSingle();
  return data == null ? {'total_earned': 0, 'total_redeemed': 0, 'balance': 0} : Map<String, dynamic>.from(data);
});

final pointsHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await supabase
      .from('pearl_points_transactions')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(30);
  return List<Map<String, dynamic>>.from(data as List);
});

class PearlPointsScreen extends ConsumerWidget {
  const PearlPointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pearlPointsProvider);
    final history = ref.watch(pointsHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Pearl Points', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Balance card
          points.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A1F00), Color(0xFF1A1208)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB8943F).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFFB8943F), size: 48),
                  const SizedBox(height: 12),
                  Text('${data?['balance'] ?? 0}', style: const TextStyle(color: Color(0xFFB8943F), fontSize: 52, fontWeight: FontWeight.bold)),
                  const Text('Pearl Points Balance', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PointStat('Earned', '${data?['total_earned'] ?? 0}'),
                      Container(width: 1, height: 36, color: Colors.white12),
                      _PointStat('Redeemed', '${data?['total_redeemed'] ?? 0}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // How to earn
          const Text('How to earn points', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._earnMethods.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFB8943F).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(m['icon'] as IconData, color: const Color(0xFFB8943F), size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text(m['label'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                Text('+${m['pts']} pts', style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          )),
          const SizedBox(height: 24),
          // History
          const Text('Transaction History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          history.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
            error: (_, __) => const SizedBox.shrink(),
            data: (txs) => txs.isEmpty
                ? const Text('No transactions yet', style: TextStyle(color: Colors.white38))
                : Column(
                    children: txs.map((t) {
                      final amount = t['amount'] as int? ?? 0;
                      final isCredit = amount >= 0;
                      final dt = t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: (isCredit ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Icon(isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline, color: isCredit ? const Color(0xFF22C55E) : const Color(0xFFEF4444), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text((t['description'] ?? t['type'] ?? 'Transaction').toString(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                              if (dt != null) Text('${dt.day}/${dt.month}/${dt.year}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ])),
                            Text('${isCredit ? '+' : ''}$amount pts', style: TextStyle(color: isCredit ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  static const _earnMethods = [
    {'icon': Icons.hotel_outlined, 'label': 'Complete a stay booking', 'pts': 50},
    {'icon': Icons.directions_car_outlined, 'label': 'Book a vehicle', 'pts': 30},
    {'icon': Icons.event_outlined, 'label': 'Attend an event', 'pts': 20},
    {'icon': Icons.star_outline, 'label': 'Leave a review', 'pts': 10},
    {'icon': Icons.person_add_outlined, 'label': 'Refer a friend', 'pts': 100},
  ];
}

class _PointStat extends StatelessWidget {
  final String label, value;
  const _PointStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}
