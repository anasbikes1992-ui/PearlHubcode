import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

final walletTransactionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await supabase
      .from('wallet_transactions')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data as List);
});

final walletBalanceProvider = FutureProvider<double>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return 0.0;
  final data = await supabase
      .from('profiles')
      .select('wallet_balance')
      .eq('id', userId)
      .single();
  return ((data['wallet_balance'] ?? 0) as num).toDouble();
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletBalanceProvider);
    final transactions = ref.watch(walletTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Wallet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFFB8943F)),
              onPressed: () {
                ref.invalidate(walletBalanceProvider);
                ref.invalidate(walletTransactionsProvider);
              }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Balance hero
          balance.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
            error: (_, __) => const SizedBox.shrink(),
            data: (bal) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB8943F).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Balance',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('LKR ${bal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFFB8943F),
                          fontSize: 36,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Top Up'),
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB8943F),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Transfer'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.2)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Transaction History',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          transactions.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFB8943F))),
            error: (e, _) =>
                Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
            data: (txs) => txs.isEmpty
                ? const Text('No transactions yet',
                    style: TextStyle(color: Colors.white38))
                : Column(
                    children: txs.map((t) {
                      final amount = ((t['amount'] ?? 0) as num).toDouble();
                      final isCredit = amount >= 0;
                      final dt = t['created_at'] != null
                          ? DateTime.tryParse(t['created_at'].toString())
                          : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.06))),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: (isCredit
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFFEF4444))
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(
                                  isCredit
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isCredit
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFEF4444),
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      (t['description'] ??
                                              t['type'] ??
                                              'Transaction')
                                          .toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13)),
                                  if (dt != null)
                                    Text(
                                        '${dt.day}/${dt.month}/${dt.year}',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(
                                '${isCredit ? '+' : ''}LKR ${amount.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: isCredit
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
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
}
