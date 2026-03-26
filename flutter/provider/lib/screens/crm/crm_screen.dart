import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final crmProfilesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('profiles')
      .select('id, full_name, email, role')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data);
});

class CRMScreen extends ConsumerStatefulWidget {
  const CRMScreen({super.key});

  @override
  ConsumerState<CRMScreen> createState() => _CRMScreenState();
}

class _CRMScreenState extends ConsumerState<CRMScreen> {
  String _search = '';
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = false;

  Future<void> _loadBookings(String customerId) async {
    setState(() => _loadingBookings = true);
    final supabase = ref.read(supabaseProvider);
    final data = await supabase
        .from('bookings')
        .select('id, listing_type, status, total_price, created_at')
        .eq('user_id', customerId)
        .order('created_at', ascending: false)
        .limit(10);
    setState(() {
      _bookings = List<Map<String, dynamic>>.from(data);
      _loadingBookings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(crmProfilesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Customer CRM',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search customers...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) =>
                  Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
              data: (items) {
                final filtered = _search.isEmpty
                    ? items
                    : items
                        .where((u) =>
                            (u['full_name'] ?? '').toString().toLowerCase().contains(_search) ||
                            (u['email'] ?? '').toString().toLowerCase().contains(_search))
                        .toList();
                return Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final u = filtered[i];
                          final isSelected = _selected?['id'] == u['id'];
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selected = u;
                                _bookings = [];
                              });
                              _loadBookings(u['id'].toString());
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFB8943F).withOpacity(0.15)
                                    : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFB8943F).withOpacity(0.4)
                                        : Colors.transparent),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        const Color(0xFFB8943F).withOpacity(0.15),
                                    child: Text(
                                        (u['full_name'] ?? '?')
                                                .toString()
                                                .isNotEmpty
                                            ? (u['full_name'] ?? '?')
                                                .toString()[0]
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Color(0xFFB8943F),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            (u['full_name'] ?? 'No name').toString(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Text((u['email'] ?? '').toString(),
                                            style: const TextStyle(
                                                color: Colors.white38, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.white12),
                    Expanded(
                      child: _selected == null
                          ? const Center(
                              child: Text('Select a customer',
                                  style: TextStyle(color: Colors.white38)))
                          : _buildDetail(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final u = _selected!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFB8943F).withOpacity(0.15),
                child: Text(
                    (u['full_name'] ?? '?').toString().isNotEmpty
                        ? (u['full_name'] ?? '?').toString()[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFFB8943F),
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((u['full_name'] ?? 'No name').toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text((u['email'] ?? '').toString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFB8943F).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text((u['role'] ?? 'customer').toString().toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFFB8943F),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Recent Bookings',
              style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_loadingBookings)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFB8943F)))
          else if (_bookings.isEmpty)
            const Text('No bookings found',
                style: TextStyle(color: Colors.white38))
          else
            ..._bookings.map((b) {
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
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
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
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          if (b['created_at'] != null)
                            Text(b['created_at'].toString().substring(0, 10),
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('LKR ${b['total_price'] ?? 0}',
                        style: const TextStyle(
                            color: Color(0xFFB8943F),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: sc.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10)),
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
      ),
    );
  }
}