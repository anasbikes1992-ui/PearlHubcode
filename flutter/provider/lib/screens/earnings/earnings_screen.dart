import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final providerEarningsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  final supabase = ref.read(supabaseProvider);
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();
  final bookings = await supabase
      .from('bookings')
      .select('id, total_price, commission_amount, status, created_at, listing_type')
      .eq('provider_id', uid)
      .gte('created_at', since)
      .order('created_at', ascending: false);
  final rows = List<Map<String, dynamic>>.from(bookings);
  final gross = rows.fold<double>(0, (s, b) => s + ((b['total_price'] ?? 0) as num).toDouble());
  final commission = rows.fold<double>(0, (s, b) => s + ((b['commission_amount'] ?? 0) as num).toDouble());
  return {'bookings': rows, 'gross': gross, 'commission': commission, 'net': gross - commission};
});

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(providerEarningsProvider(_days));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Earnings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: data.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFB8943F))),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
        data: (snap) {
          final rows = (snap['bookings'] as List<Map<String, dynamic>>?) ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Period selector
              Row(
                children: [7, 30, 90].map((d) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _days = d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _days == d
                            ? const Color(0xFFB8943F)
                            : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${d}d',
                          style: TextStyle(
                              color: _days == d ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              // KPI cards
              Row(
                children: [
                  _EarnCard('Gross',
                      'LKR ${(snap['gross'] as double? ?? 0).toStringAsFixed(0)}',
                      const Color(0xFFB8943F)),
                  const SizedBox(width: 10),
                  _EarnCard('Commission',
                      'LKR ${(snap['commission'] as double? ?? 0).toStringAsFixed(0)}',
                      const Color(0xFFEF4444)),
                  const SizedBox(width: 10),
                  _EarnCard('Net',
                      'LKR ${(snap['net'] as double? ?? 0).toStringAsFixed(0)}',
                      const Color(0xFF22C55E)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Transactions',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text('No bookings in this period',
                    style: TextStyle(color: Colors.white38))
              else
                ...rows.map((b) {
                  final status = b['status']?.toString() ?? 'pending';
                  Color sc = status == 'confirmed'
                      ? const Color(0xFF22C55E)
                      : status == 'cancelled'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  (b['listing_type'] ?? 'Booking')
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              if (b['created_at'] != null)
                                Text(
                                    b['created_at'].toString().substring(0, 10),
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('LKR ${b['total_price'] ?? 0}',
                            style: const TextStyle(
                                color: Color(0xFFB8943F),
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                                color: sc.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(status.toUpperCase(),
                                style: TextStyle(
                                    color: sc,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _EarnCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _EarnCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ),
      );
}
