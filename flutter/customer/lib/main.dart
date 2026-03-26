// customer/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'models/user_profile.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/search_results_screen.dart';
import 'screens/stays/stays_list_screen.dart';
import 'screens/stays/stay_detail_screen.dart';
import 'screens/vehicles/vehicles_list_screen.dart';
import 'screens/vehicles/vehicle_detail_screen.dart';
import 'screens/properties/properties_list_screen.dart';
import 'screens/properties/property_detail_screen.dart';
import 'screens/events/events_list_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/social/social_feed_screen.dart';
import 'screens/sme/sme_list_screen.dart';
import 'screens/taxi/taxi_home_screen.dart';
import 'screens/taxi/taxi_active_ride_screen.dart';
import 'screens/taxi/taxi_history_screen.dart';
import 'screens/booking/checkout_screen.dart';
import 'screens/booking/bookings_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/wallet_screen.dart';
import 'screens/profile/pearl_points_screen.dart';
import 'screens/concierge/concierge_screen.dart';
import 'screens/airport_transfer/airport_transfer_screen.dart';
import 'screens/office_transport/office_transport_screen.dart';
import 'screens/parcel/parcel_delivery_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const ProviderScope(child: PearlHubCustomerApp()));
}

class PearlHubCustomerApp extends ConsumerWidget {
  const PearlHubCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PearlHub',
      theme: PearlHubTheme.light,
      darkTheme: PearlHubTheme.dark,
      routerConfig: _buildRouter(ref),
      debugShowCheckedModeBanner: false,
    );
  }

  GoRouter _buildRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isLoggedIn = authState.isAuthenticated;
        final isGoingToAuth = state.matchedLocation.startsWith('/auth');
        final isGoingToSplash = state.matchedLocation == '/splash';

        if (isGoingToSplash) return null;
        if (!isLoggedIn && !isGoingToAuth) return '/auth/login';

        // Block admin/provider roles from customer app
        if (isLoggedIn) {
          final role = authState.profile?.role;
          if (role == UserRole.admin) return '/auth/login';
          // Providers can also use the customer app for booking
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

        // Auth
        GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/auth/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

        // Main shell with bottom nav
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
              routes: [
                GoRoute(path: 'search', builder: (_, s) => SearchResultsScreen(query: s.uri.queryParameters['q'])),
              ],
            ),

            // Verticals
            GoRoute(path: '/stays', builder: (_, __) => const StaysListScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => StayDetailScreen(stayId: s.pathParameters['id']!))]),

            GoRoute(path: '/vehicles', builder: (_, __) => const VehiclesListScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => VehicleDetailScreen(vehicleId: s.pathParameters['id']!))]),

            GoRoute(path: '/properties', builder: (_, __) => const PropertiesListScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => PropertyDetailScreen(propertyId: s.pathParameters['id']!))]),

            GoRoute(path: '/events', builder: (_, __) => const EventsListScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => EventDetailScreen(eventId: s.pathParameters['id']!))]),

            GoRoute(path: '/social', builder: (_, __) => const SocialFeedScreen()),
            GoRoute(path: '/sme', builder: (_, __) => const SMEListScreen()),

            // Transport verticals
            GoRoute(path: '/airport-transfer', builder: (_, __) => const AirportTransferScreen()),
            GoRoute(path: '/office-transport', builder: (_, __) => const OfficeTransportScreen()),
            GoRoute(path: '/parcel', builder: (_, __) => const ParcelDeliveryScreen()),

            // Taxi
            GoRoute(path: '/taxi', builder: (_, __) => const TaxiHomeScreen(),
              routes: [
                GoRoute(path: 'ride/:id', builder: (_, s) => TaxiActiveRideScreen(rideId: s.pathParameters['id']!)),
                GoRoute(path: 'history', builder: (_, __) => const TaxiHistoryScreen()),
              ]),

            // Booking
            GoRoute(path: '/checkout', builder: (_, s) => CheckoutScreen(
              listingId: s.uri.queryParameters['listing_id']!,
              listingType: s.uri.queryParameters['listing_type']!,
            )),
            GoRoute(path: '/bookings', builder: (_, __) => const BookingsListScreen()),

            // Profile
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
            GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
            GoRoute(path: '/pearl-points', builder: (_, __) => const PearlPointsScreen()),

            // AI Concierge
            GoRoute(path: '/concierge', builder: (_, __) => const ConciergeScreen()),
          ],
        ),
      ],
    );
  }
}

// ── Main shell with bottom navigation bar ─────────────────────────────────
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/home');
            case 1: context.go('/taxi');
            case 2: context.go('/bookings');
            case 3: context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.local_taxi_outlined), selectedIcon: Icon(Icons.local_taxi), label: 'Taxi'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── PearlHub Design System ────────────────────────────────────────────────
class PearlHubTheme {
  static const _gold = Color(0xFFB8943F);
  static const _darkGold = Color(0xFF8B6914);
  static const _pearl = Color(0xFFF5F0E8);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.light,
    ).copyWith(primary: _gold, secondary: _darkGold, surface: _pearl),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _gold.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontFamily: 'Inter'),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.dark,
    ).copyWith(primary: _gold),
    fontFamily: 'Inter',
  );
}
