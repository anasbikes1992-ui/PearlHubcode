import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

final adminUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase.from('profiles').select('id, full_name, email, role, verified').order('created_at', ascending: false).limit(100);
  return List<Map<String, dynamic>>.from(data);
});

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _search = '';
  String _roleFilter = 'all';

  Future<void> _suspend(String userId, bool suspended) async {
    await ref.read(supabaseProvider).from('profiles').update({'suspended': !suspended}).eq('id', userId);
    ref.invalidate(adminUsersProvider);
  }

  Future<void> _verify(String userId) async {
    await ref.read(supabaseProvider).from('profiles').update({'verified': true}).eq('id', userId);
    ref.invalidate(adminUsersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFB8943F)), onPressed: () => ref.invalidate(adminUsersProvider))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'customer', 'provider', 'admin'].map((r) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _roleFilter = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _roleFilter == r ? const Color(0xFFB8943F).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _roleFilter == r ? const Color(0xFFB8943F) : Colors.transparent),
                      ),
                      child: Text(r.toUpperCase(), style: TextStyle(color: _roleFilter == r ? const Color(0xFFB8943F) : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFB8943F))),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
              data: (items) {
                final filtered = items.where((u) {
                  if (_roleFilter != 'all' && u['role'] != _roleFilter) return false;
                  if (_search.isNotEmpty) {
                    final name = (u['full_name'] ?? '').toString().toLowerCase();
                    final email = (u['email'] ?? '').toString().toLowerCase();
                    if (!name.contains(_search) && !email.contains(_search)) return false;
                  }
                  return true;
                }).toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final verified = u['verified'] == true;
                    final suspended = u['suspended'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: suspended ? const Color(0xFFEF4444).withOpacity(0.3) : Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFB8943F).withOpacity(0.15),
                          child: Text(
                            (u['full_name'] ?? '?').toString().isNotEmpty ? (u['full_name'] ?? '?').toString()[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text((u['full_name'] ?? 'No name').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            if (verified) const SizedBox(width: 4),
                            if (verified) const Icon(Icons.verified, color: Color(0xFF3B82F6), size: 14),
                          ]),
                          Text((u['email'] ?? '').toString(), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFB8943F).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text((u['role'] ?? '').toString().toUpperCase(), style: const TextStyle(color: Color(0xFFB8943F), fontSize: 9, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 6),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!verified) GestureDetector(
                              onTap: () => _verify(u['id'].toString()),
                              child: const Icon(Icons.verified_user_outlined, color: Color(0xFF22C55E), size: 18),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _suspend(u['id'].toString(), suspended),
                              child: Icon(suspended ? Icons.lock_open_outlined : Icons.block_outlined, color: suspended ? const Color(0xFF22C55E) : const Color(0xFFEF4444), size: 18),
                            ),
                          ]),
                        ]),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
