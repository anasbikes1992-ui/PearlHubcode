// provider/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'models/user_profile.dart';

import 'screens/provider_login_screen.dart';
import 'screens/dashboard/provider_dashboard_screen.dart';
import 'screens/listings/listings_screen.dart';
import 'screens/listings/create_listing_screen.dart';
import 'screens/bookings/booking_queue_screen.dart';
import 'screens/taxi_driver/driver_home_screen.dart';
import 'screens/earnings/earnings_screen.dart';
import 'screens/crm/crm_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: PearlHubProviderApp()));
}

class PearlHubProviderApp extends ConsumerWidget {
  const PearlHubProviderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PearlHub Provider',
      theme: _providerTheme(),
      routerConfig: _buildRouter(ref),
      debugShowCheckedModeBanner: false,
    );
  }

  GoRouter _buildRouter(WidgetRef ref) => GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isLoggedIn = auth.isAuthenticated;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/dashboard';

      // Ensure only provider roles can access this app
      if (isLoggedIn && !auth.isProvider && !auth.isAdmin) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const ProviderLoginScreen()),
      ShellRoute(
        builder: (context, state, child) => ProviderShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const ProviderDashboardScreen()),
          GoRoute(path: '/listings', builder: (_, __) => const ListingsScreen(),
            routes: [GoRoute(path: 'create', builder: (_, __) => const CreateListingScreen())]),
          GoRoute(path: '/bookings', builder: (_, __) => const BookingQueueScreen()),
          GoRoute(path: '/driver', builder: (_, __) => const DriverHomeScreen()),
          GoRoute(path: '/earnings', builder: (_, __) => const EarningsScreen()),
          GoRoute(path: '/crm', builder: (_, __) => const CRMScreen()),
        ],
      ),
    ],
  );

  ThemeData _providerTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A9F), brightness: Brightness.light),
    fontFamily: 'Inter',
  );
}

class ProviderShell extends ConsumerWidget {
  final Widget child;
  const ProviderShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isDriver = auth.profile?.role == UserRole.vehicleProvider;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (i) {
          final routes = isDriver
              ? ['/dashboard', '/driver', '/earnings', '/crm']
              : ['/dashboard', '/listings', '/bookings', '/earnings', '/crm'];
          context.go(routes[i]);
        },
        destinations: isDriver ? [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.local_taxi_outlined), selectedIcon: Icon(Icons.local_taxi), label: 'Drive'),
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
        ] : [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Listings'),
          const NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Bookings'),
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'CRM'),
        ],
      ),
    );
  }
}
