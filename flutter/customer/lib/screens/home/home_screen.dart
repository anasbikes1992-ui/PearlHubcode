// customer/lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/listings_service.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/vertical_category_chip.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                const Icon(Icons.diamond, color: Color(0xFFB8943F), size: 24),
                const SizedBox(width: 8),
                Text('PearlHub', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFB8943F).withOpacity(0.15),
                    child: Text(
                      auth.profile?.fullName.isNotEmpty == true
                          ? auth.profile!.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero section ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFB8943F).withOpacity(0.08),
                        const Color(0xFF8B6914).withOpacity(0.04),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_greeting()}, ${auth.profile?.fullName.split(' ').first ?? 'there'} 👋',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Where to in Sri Lanka?',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 1,
                        child: TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (q) => context.push('/home/search?q=$q'),
                          decoration: InputDecoration(
                            hintText: 'Search stays, venues, vehicles...',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.tune_outlined, color: Color(0xFFB8943F)),
                              onPressed: () {},
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Vertical categories ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 0, 8),
                  child: Text('Explore', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  height: 104,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      VerticalCategoryChip(icon: Icons.hotel_outlined, label: 'Stays', color: const Color(0xFF2196F3), onTap: () => context.push('/stays')),
                      VerticalCategoryChip(icon: Icons.directions_car_outlined, label: 'Vehicles', color: const Color(0xFF4CAF50), onTap: () => context.push('/vehicles')),
                      VerticalCategoryChip(icon: Icons.home_outlined, label: 'Property', color: const Color(0xFFFF9800), onTap: () => context.push('/properties')),
                      VerticalCategoryChip(icon: Icons.local_taxi_outlined, label: 'Taxi', color: const Color(0xFFF44336), onTap: () => context.push('/taxi')),
                      VerticalCategoryChip(icon: Icons.event_outlined, label: 'Events', color: const Color(0xFF9C27B0), onTap: () => context.push('/events')),
                      VerticalCategoryChip(icon: Icons.people_outline, label: 'Social', color: const Color(0xFF00BCD4), onTap: () => context.push('/social')),
                      VerticalCategoryChip(icon: Icons.storefront_outlined, label: 'SME', color: const Color(0xFFB8943F), onTap: () => context.push('/sme')),
                    ],
                  ),
                ),

                // ── Featured stays ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Featured Stays', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      TextButton(onPressed: () => context.push('/stays'), child: const Text('See all')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Stays horizontal list ─────────────────────────────────────
          SliverToBoxAdapter(child: _FeaturedStaysList()),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AI Concierge promo card ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: () => context.push('/concierge'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFFB8943F), size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('AI Concierge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Let AI plan your perfect Sri Lanka trip', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Color(0xFFB8943F), size: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Featured events ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Upcoming Events', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      TextButton(onPressed: () => context.push('/events'), child: const Text('See all')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(child: _FeaturedEventsList()),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ── Featured stays horizontal scroll ─────────────────────────────────────
class _FeaturedStaysList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staysAsync = ref.watch(staysProvider(null));
    return SizedBox(
      height: 220,
      child: staysAsync.when(
        loading: () => _shimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stays) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: stays.take(10).length,
          itemBuilder: (context, i) => StayCard(
            stay: stays[i],
            onTap: () => context.push('/stays/${stays[i].id}'),
          ),
        ),
      ),
    );
  }

  Widget _shimmerList() => ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: 4,
    itemBuilder: (_, __) => const _ShimmerCard(),
  );
}

class _FeaturedEventsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider(null));
    return SizedBox(
      height: 180,
      child: eventsAsync.when(
        loading: () => _shimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.take(10).length,
          itemBuilder: (context, i) => EventCard(
            event: events[i],
            onTap: () => context.push('/events/${events[i].id}'),
          ),
        ),
      ),
    );
  }

  Widget _shimmerList() => ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: 4,
    itemBuilder: (_, __) => const _ShimmerCard(),
  );
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
