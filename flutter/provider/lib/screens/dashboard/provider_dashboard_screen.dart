// provider/lib/screens/dashboard/provider_dashboard_screen.dart
// Real earnings from DB — fixes the hardcoded PredictiveRevenueChart in web app

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/auth_service.dart';
import '../../services/listings_service.dart';
import '../../models/user_profile.dart';

// ── Real earnings provider — fixes the hardcoded chart in web app ──────────
final earningsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser!.id;

  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  // Total earnings
  final earnings = await supabase
      .from('earnings')
      .select('amount, created_at')
      .eq('provider_id', userId)
      .gte('created_at', thirtyDaysAgo.toIso8601String());

  // Bookings count
  final bookings = await supabase
      .from('bookings')
      .select('id, status, created_at, amount')
      .eq('user_id', userId)
      .gte('created_at', thirtyDaysAgo.toIso8601String());

  // Group earnings by day for chart
  final Map<String, double> dailyEarnings = {};
  for (final e in earnings as List) {
    final day = (e['created_at'] as String).substring(0, 10);
    dailyEarnings[day] = (dailyEarnings[day] ?? 0) + (e['amount'] as num).toDouble();
  }

  final total = (earnings as List)
      .fold<double>(0, (sum, e) => sum + (e['amount'] as num).toDouble());

  final confirmedBookings = (bookings as List)
      .where((b) => b['status'] == 'confirmed')
      .length;

  return {
    'total_earnings': total,
    'booking_count': confirmedBookings,
    'daily': dailyEarnings,
  };
});

// ── Provider stats ─────────────────────────────────────────────────────────
final providerStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser!.id;

  final stays = await supabase
      .from('stays')
      .select('id', const FetchOptions(count: CountOption.exact, head: true))
      .eq('provider_id', userId);

  final vehicles = await supabase
      .from('vehicles')
      .select('id', const FetchOptions(count: CountOption.exact, head: true))
      .eq('provider_id', userId);

  final pendingBookings = await supabase
      .from('bookings')
      .select('id', const FetchOptions(count: CountOption.exact, head: true))
      .eq('user_id', userId)
      .eq('status', 'pending');

  return {
    'stays': stays.count ?? 0,
    'vehicles': vehicles.count ?? 0,
    'pending_bookings': pendingBookings.count ?? 0,
  };
});

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final earningsAsync = ref.watch(earningsProvider);
    final statsAsync = ref.watch(providerStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Provider Dashboard', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(auth.profile?.role.label ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              // Tier badge
              _TierBadge(tier: _calcTier(earningsAsync.valueOrNull?['booking_count'] ?? 0)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Quick action buttons ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/listings/create'),
                          icon: const Icon(Icons.add),
                          label: const Text('New Listing'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      statsAsync.maybeWhen(
                        data: (s) => s['pending_bookings']! > 0
                            ? Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.go('/bookings'),
                                  icon: const Icon(Icons.pending_outlined),
                                  label: Text('${s['pending_bookings']} Pending'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    foregroundColor: Colors.orange.shade700,
                                    side: BorderSide(color: Colors.orange.shade300),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Earnings chart — REAL DATA (not hardcoded) ────────
                  Text('Revenue (last 30 days)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  earningsAsync.when(
                    loading: () => _ChartSkeleton(),
                    error: (e, _) => _ErrCard(e.toString()),
                    data: (data) => _EarningsChart(dailyEarnings: data['daily'] as Map<String, double>? ?? {}),
                  ),
                  const SizedBox(height: 20),

                  // ── KPI cards ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: earningsAsync.when(
                          loading: () => _KpiSkeleton(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (d) => _KpiCard(
                            label: 'Total Earnings',
                            value: 'LKR ${_fmt(d['total_earnings'] as double)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: const Color(0xFFB8943F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: earningsAsync.when(
                          loading: () => _KpiSkeleton(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (d) => _KpiCard(
                            label: 'Bookings',
                            value: '${d['booking_count']}',
                            icon: Icons.book_outlined,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: statsAsync.when(
                          loading: () => _KpiSkeleton(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (s) => _KpiCard(
                            label: 'Stays',
                            value: '${s['stays']}',
                            icon: Icons.hotel_outlined,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: statsAsync.when(
                          loading: () => _KpiSkeleton(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (s) => _KpiCard(
                            label: 'Vehicles',
                            value: '${s['vehicles']}',
                            icon: Icons.directions_car_outlined,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Recent listings ───────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Listings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      TextButton(onPressed: () => context.go('/listings'), child: const Text('See all')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _RecentListings(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  ProviderTier _calcTier(int bookings) {
    if (bookings >= 100) return ProviderTier.elite;
    if (bookings >= 50) return ProviderTier.pro;
    if (bookings >= 5) return ProviderTier.verified;
    return ProviderTier.standard;
  }
}

// ── Real earnings chart ────────────────────────────────────────────────────
class _EarningsChart extends StatelessWidget {
  final Map<String, double> dailyEarnings;
  const _EarningsChart({required this.dailyEarnings});

  @override
  Widget build(BuildContext context) {
    if (dailyEarnings.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('No earnings data yet', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Build last 14 days bar data
    final today = DateTime.now();
    final bars = List.generate(14, (i) {
      final day = today.subtract(Duration(days: 13 - i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final value = dailyEarnings[key] ?? 0;
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: value,
          width: 14,
          color: const Color(0xFFB8943F),
          borderRadius: BorderRadius.circular(4),
        ),
      ]);
    });

    final maxY = dailyEarnings.values.fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final day = today.subtract(Duration(days: 13 - value.toInt()));
                  if (value.toInt() % 4 != 0) return const SizedBox.shrink();
                  return Text('${day.day}/${day.month}', style: const TextStyle(fontSize: 9, color: Colors.grey));
                },
                reservedSize: 20,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, _) => Text(
                  value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}K' : value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                'LKR ${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentListings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staysAsync = ref.watch(providerStaysProvider);
    return staysAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (stays) => stays.isEmpty
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.add_circle_outline, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No listings yet', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => context.push('/listings/create'),
                      child: const Text('Create your first listing'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: stays.take(3).map((s) => _ListingRow(
                name: s.name,
                status: s.status.name,
                price: 'LKR ${s.pricePerNight.toStringAsFixed(0)}/night',
                imageUrl: s.images.isNotEmpty ? s.images.first : null,
              )).toList(),
            ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  final String name;
  final String status;
  final String price;
  final String? imageUrl;

  const _ListingRow({required this.name, required this.status, required this.price, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      'active' => Colors.green,
      'pending' => Colors.blue,
      'paused' => Colors.orange,
      _ => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover) : null,
            ),
            child: imageUrl == null ? const Icon(Icons.image_outlined, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(price, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final ProviderTier tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      ProviderTier.elite => ('♛ Elite', Colors.green),
      ProviderTier.pro => ('★ Pro', const Color(0xFFB8943F)),
      ProviderTier.verified => ('✓ Verified', Colors.blue),
      ProviderTier.standard => ('Standard', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
  );
}

class _ChartSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
  );
}

class _ErrCard extends StatelessWidget {
  final String msg;
  const _ErrCard(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
    child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)),
  );
}
