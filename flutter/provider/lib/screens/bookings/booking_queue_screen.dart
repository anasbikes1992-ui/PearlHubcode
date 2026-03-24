import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pearlhub_shared/services/auth_service.dart';

final providerBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase.rpc('get_provider_bookings', params: {'p_limit': 100});
  return List<Map<String, dynamic>>.from(data as List);
});

class BookingQueueScreen extends ConsumerStatefulWidget {
  const BookingQueueScreen({super.key});

  @override
  ConsumerState<BookingQueueScreen> createState() => _BookingQueueScreenState();
}

class _BookingQueueScreenState extends ConsumerState<BookingQueueScreen> {
  String _tab = 'pending';
  String? _processingId;

  Future<void> _confirm(String id) async {
    setState(() => _processingId = id);
    await ref.read(supabaseProvider).from('bookings').update({'status': 'confirmed'}).eq('id', id);
    ref.invalidate(providerBookingsProvider);
    setState(() => _processingId = null);
  }

  Future<void> _decline(String id) async {
    setState(() => _processingId = id);
    await ref.read(supabaseProvider).from('bookings').update({'status': 'cancelled'}).eq('id', id);
    ref.invalidate(providerBookingsProvider);
    setState(() => _processingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(providerBookingsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Booking Queue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFFB8943F)),
              onPressed: () => ref.invalidate(providerBookingsProvider)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['pending', 'confirmed', 'completed', 'all']
                  .map((t) => Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = t),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tab == t
                                  ? const Color(0xFFB8943F)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(t.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _tab == t
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: bookings.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white70))),
              data: (items) {
                final filtered =
                    _tab == 'all' ? items : items.where((b) => b['status'] == _tab).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 56, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text('No $_tab bookings',
                            style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: const Color(0xFFB8943F),
                  onRefresh: () => ref.refresh(providerBookingsProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final b = filtered[i];
                      final id = b['id']?.toString() ?? '';
                      final status = b['status']?.toString() ?? 'pending';
                      final isPending = status == 'pending';
                      final dt = b['created_at'] != null
                          ? DateTime.tryParse(b['created_at'].toString())
                          : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isPending
                                  ? const Color(0xFFB8943F).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_outlined,
                                    color: Color(0xFFB8943F), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        (b['listing_type'] ?? b['vertical'] ?? 'Booking')
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14))),
                                Text('LKR ${b['total_price'] ?? b['total_amount'] ?? 0}',
                                    style: const TextStyle(
                                        color: Color(0xFFB8943F),
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (b['check_in'] != null)
                              Row(children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 12, color: Colors.white38),
                                const SizedBox(width: 4),
                                Text('${b['check_in']} to ${b['check_out'] ?? '?'}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                              ]),
                            if (dt != null)
                              Text('Requested ${dt.day}/${dt.month}/${dt.year}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                            if (isPending) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _processingId == id
                                          ? null
                                          : () => _decline(id),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFEF4444),
                                          side: const BorderSide(
                                              color: Color(0xFFEF4444)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      child: const Text('Decline',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _processingId == id
                                          ? null
                                          : () => _confirm(id),
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF22C55E),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      child: _processingId == id
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Text('Confirm',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}