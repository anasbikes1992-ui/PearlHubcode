// admin/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'models/user_profile.dart';

import 'screens/admin_login_screen.dart';
import 'screens/overview/admin_overview_screen.dart';
import 'screens/moderation/listings_moderation_screen.dart';
import 'screens/users/users_screen.dart';
import 'screens/users/kyc_review_screen.dart';
import 'screens/taxi/taxi_admin_screen.dart';
import 'screens/transport/airport_admin_screen.dart';
import 'screens/transport/office_transport_admin_screen.dart';
import 'screens/transport/parcels_admin_screen.dart';
import 'screens/finance/transactions_screen.dart';
import 'screens/settings/platform_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: PearlHubAdminApp()));
}

class PearlHubAdminApp extends ConsumerWidget {
  const PearlHubAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PearlHub Admin',
      theme: _adminTheme(),
      routerConfig: _buildRouter(ref),
      debugShowCheckedModeBanner: false,
    );
  }

  GoRouter _buildRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final isLoggedIn = auth.isAuthenticated;
        final isGoingToLogin = state.matchedLocation == '/login';

        if (!isLoggedIn && !isGoingToLogin) return '/login';

        // Strict admin-only access — mirrors RequireAuth roles={['admin']} in web
        if (isLoggedIn && auth.profile?.role != UserRole.admin) {
          return '/login'; // redirect non-admins away
        }

        if (isLoggedIn && isGoingToLogin) return '/overview';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const AdminLoginScreen()),

        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(path: '/overview', builder: (_, __) => const AdminOverviewScreen()),
            GoRoute(
              path: '/moderation',
              builder: (_, s) => ListingsModerationScreen(
                vertical: s.uri.queryParameters['vertical'] ?? 'stays',
              ),
            ),
            GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
            GoRoute(path: '/users/kyc', builder: (_, __) => const KYCReviewScreen()),
            GoRoute(path: '/taxi-admin', builder: (_, __) => const TaxiAdminScreen()),
            GoRoute(path: '/airport-admin', builder: (_, __) => const AirportAdminScreen()),
            GoRoute(path: '/office-transport-admin', builder: (_, __) => const OfficeTransportAdminScreen()),
            GoRoute(path: '/parcels-admin', builder: (_, __) => const ParcelsAdminScreen()),
            GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
            GoRoute(path: '/settings', builder: (_, __) => const PlatformSettingsScreen()),
          ],
        ),
      ],
    );
  }

  ThemeData _adminTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB8943F), brightness: Brightness.light),
    fontFamily: 'Inter',
    drawerTheme: const DrawerThemeData(width: 260),
  );
}

// ── Admin side-drawer shell ───────────────────────────────────────────────
class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      drawer: NavigationDrawer(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.diamond, color: Color(0xFFB8943F), size: 32),
                const SizedBox(height: 12),
                const Text('PearlHub Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(auth.profile?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Divider(),
          _NavItem(icon: Icons.dashboard_outlined, label: 'Overview', path: '/overview'),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text('MODERATION', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.2))),
          _NavItem(icon: Icons.hotel_outlined, label: 'Stays', path: '/moderation?vertical=stays'),
          _NavItem(icon: Icons.directions_car_outlined, label: 'Vehicles', path: '/moderation?vertical=vehicles'),
          _NavItem(icon: Icons.home_outlined, label: 'Properties', path: '/moderation?vertical=properties'),
          _NavItem(icon: Icons.event_outlined, label: 'Events', path: '/moderation?vertical=events'),
          _NavItem(icon: Icons.storefront_outlined, label: 'SME', path: '/moderation?vertical=sme'),
          _NavItem(icon: Icons.people_outline, label: 'Social', path: '/moderation?vertical=social'),
          const Divider(),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text('MANAGEMENT', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.2))),
          _NavItem(icon: Icons.people_outlined, label: 'Users', path: '/users'),
          _NavItem(icon: Icons.verified_user_outlined, label: 'KYC Reviews', path: '/users/kyc'),
          _NavItem(icon: Icons.local_taxi_outlined, label: 'Taxi Admin', path: '/taxi-admin'),
          _NavItem(icon: Icons.flight_outlined, label: 'Airport Transfers', path: '/airport-admin'),
          _NavItem(icon: Icons.directions_bus_outlined, label: 'Office Transport', path: '/office-transport-admin'),
          _NavItem(icon: Icons.local_shipping_outlined, label: 'Parcel Deliveries', path: '/parcels-admin'),
          _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Transactions', path: '/transactions'),
          _NavItem(icon: Icons.settings_outlined, label: 'Settings', path: '/settings'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: child,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;

  const _NavItem({required this.icon, required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    final isActive = current.startsWith(path.split('?').first);
    return ListTile(
      leading: Icon(icon, color: isActive ? const Color(0xFFB8943F) : null),
      title: Text(label, style: TextStyle(
        color: isActive ? const Color(0xFFB8943F) : null,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      )),
      selected: isActive,
      selectedTileColor: const Color(0xFFB8943F).withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () => context.go(path),
    );
  }
}
