// admin/lib/screens/overview/admin_overview_screen.dart
// Real stats from Supabase — replaces the hardcoded mock data in AdminDashboard.tsx

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

// ── Live platform stats provider ──────────────────────────────────────────
final platformStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final results = await Future.wait([
    supabase.from('stays').select('id', const FetchOptions(count: CountOption.exact, head: true)),
    supabase.from('vehicles').select('id', const FetchOptions(count: CountOption.exact, head: true)),
    supabase.from('events').select('id', const FetchOptions(count: CountOption.exact, head: true)),
    supabase.from('properties').select('id', const FetchOptions(count: CountOption.exact, head: true)),
    supabase.from('profiles').select('id', const FetchOptions(count: CountOption.exact, head: true)),
    supabase.from('bookings').select('id', const FetchOptions(count: CountOption.exact, head: true)),
    // Pending moderation counts
    supabase.from('stays').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('status', 'pending'),
    supabase.from('taxi_rides').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('status', 'searching'),
  ]);
  return {
    'stays': results[0].count ?? 0,
    'vehicles': results[1].count ?? 0,
    'events': results[2].count ?? 0,
    'properties': results[3].count ?? 0,
    'users': results[4].count ?? 0,
    'bookings': results[5].count ?? 0,
    'pending_moderation': results[6].count ?? 0,
    'active_rides': results[7].count ?? 0,
  };
});

// Recent activity feed
final recentActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('admin_actions')
      .select()
      .order('created_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(data);
});

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsProvider);
    final activityAsync = ref.watch(recentActivityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Color(0xFFB8943F), size: 22),
            SizedBox(width: 8),
            Text('Platform Overview', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(platformStatsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(platformStatsProvider);
          ref.invalidate(recentActivityProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Alert banner if pending items ──────────────────────────
              statsAsync.maybeWhen(
                data: (stats) {
                  final pending = stats['pending_moderation'] ?? 0;
                  if (pending == 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pending_outlined, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('$pending listings awaiting moderation',
                            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500)),
                        ),
                        TextButton(
                          onPressed: () => context.go('/moderation?vertical=stays'),
                          child: const Text('Review'),
                        ),
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

              // ── KPI grid ──────────────────────────────────────────────
              Text('Platform Stats', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => _StatsGridSkeleton(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (stats) => _StatsGrid(stats: stats),
              ),
              const SizedBox(height: 24),

              // ── Quick actions ─────────────────────────────────────────
              Text('Quick Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _QuickActionChip(icon: Icons.hotel_outlined, label: 'Stays', onTap: () => context.go('/moderation?vertical=stays')),
                  _QuickActionChip(icon: Icons.directions_car_outlined, label: 'Vehicles', onTap: () => context.go('/moderation?vertical=vehicles')),
                  _QuickActionChip(icon: Icons.event_outlined, label: 'Events', onTap: () => context.go('/moderation?vertical=events')),
                  _QuickActionChip(icon: Icons.home_outlined, label: 'Properties', onTap: () => context.go('/moderation?vertical=properties')),
                  _QuickActionChip(icon: Icons.verified_user_outlined, label: 'KYC', onTap: () => context.go('/users/kyc')),
                  _QuickActionChip(icon: Icons.local_taxi_outlined, label: 'Taxi', onTap: () => context.go('/taxi-admin')),
                  _QuickActionChip(icon: Icons.people_outlined, label: 'Users', onTap: () => context.go('/users')),
                ],
              ),
              const SizedBox(height: 24),

              // ── Recent activity ───────────────────────────────────────
              Text('Recent Activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              activityAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (items) => items.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No recent activity', style: TextStyle(color: Colors.grey))))
                    : Column(
                        children: items.map((item) => _ActivityTile(item: item)).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Stays', stats['stays'] ?? 0, Icons.hotel_outlined, Colors.blue),
      ('Vehicles', stats['vehicles'] ?? 0, Icons.directions_car_outlined, Colors.green),
      ('Properties', stats['properties'] ?? 0, Icons.home_outlined, Colors.orange),
      ('Events', stats['events'] ?? 0, Icons.event_outlined, Colors.purple),
      ('Users', stats['users'] ?? 0, Icons.people_outline, Colors.teal),
      ('Bookings', stats['bookings'] ?? 0, Icons.book_outlined, const Color(0xFFB8943F)),
      ('Pending', stats['pending_moderation'] ?? 0, Icons.pending_outlined, Colors.orange),
      ('Live Rides', stats['active_rides'] ?? 0, Icons.local_taxi_outlined, Colors.red),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: items.map((e) => _StatCard(label: e.$1, value: e.$2, icon: e.$3, color: e.$4)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: List.generate(8, (_) => Container(
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
      )),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFFB8943F)),
      ),
      title: Text(item['action_type']?.toString() ?? 'Action', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(item['created_at']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 12)),
      trailing: Text(item['target_type']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
