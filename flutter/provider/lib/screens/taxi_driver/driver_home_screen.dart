// provider/lib/screens/taxi_driver/driver_home_screen.dart
// Real-time incoming ride requests via Supabase Realtime subscriptions

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pearlhub_shared/services/auth_service.dart';
import 'package:pearlhub_shared/services/taxi_service.dart';
import 'package:pearlhub_shared/models/taxi.dart';

// Driver online status (local state — could also persist to DB for dispatch)
final driverOnlineProvider = StateProvider<bool>((ref) => false);

// Today's earnings for driver
final todayEarningsProvider = FutureProvider<double>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser!.id;
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final data = await supabase
      .from('earnings')
      .select('amount')
      .eq('provider_id', userId)
      .gte('created_at', '${today}T00:00:00');
  return (data as List).fold<double>(0, (sum, e) => sum + (e['amount'] as num).toDouble());
});

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  // Colombo, Sri Lanka
  final LatLng _driverLocation = const LatLng(6.9271, 79.8612);

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineProvider);
    final rideState = ref.watch(taxiRideProvider);
    final earningsAsync = ref.watch(todayEarningsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            options: MapOptions(initialCenter: _driverLocation, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pearlhub.provider',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _driverLocation,
                  width: 48, height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.local_taxi, color: Colors.white, size: 22),
                  ),
                ),
              ]),
            ],
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Online/offline toggle
                    GestureDetector(
                      onTap: () {
                        final going = !isOnline;
                        ref.read(driverOnlineProvider.notifier).state = going;
                        if (going) {
                          // Start listening for incoming rides
                          final providerId = ref.read(supabaseProvider).auth.currentUser!.id;
                          ref.read(taxiRideProvider.notifier).subscribeToIncomingRides(providerId);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF4CAF50) : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isOnline ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: isOnline ? Colors.white : Colors.grey, size: 16),
                            const SizedBox(width: 8),
                            Text(isOnline ? 'Online' : 'Go Online',
                              style: TextStyle(
                                color: isOnline ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              )),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Today's earnings card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                      ),
                      child: earningsAsync.when(
                        loading: () => const Text('LKR ...', style: TextStyle(fontWeight: FontWeight.bold)),
                        error: (_, __) => const Text('LKR 0'),
                        data: (v) => Text(
                          'LKR ${v.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB8943F)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Incoming ride card ───────────────────────────────────────────
          if (isOnline && rideState.activeRide != null && rideState.activeRide!.status == TaxiRideStatus.searching)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: _IncomingRideCard(
                ride: rideState.activeRide!,
                onAccept: () async {
                  await ref.read(taxiRideProvider.notifier).acceptRide(rideState.activeRide!.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ride accepted. Continue managing it from the driver screen.')),
                    );
                  }
                },
                onDecline: () async {
                  await ref.read(taxiRideProvider.notifier).cancelRide(rideState.activeRide!.id);
                },
              ),
            ),

          // ── Offline overlay ──────────────────────────────────────────────
          if (!isOnline)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.local_taxi_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text("You're offline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Tap "Go Online" to start receiving ride requests',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: null, // handled by ProviderShell
    );
  }
}

// ── Incoming ride card ─────────────────────────────────────────────────────
class _IncomingRideCard extends StatelessWidget {
  final TaxiRide ride;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingRideCard({required this.ride, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final distance = ride.distanceKm;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
        border: Border.all(color: const Color(0xFFB8943F).withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8943F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('New Ride Request', style: TextStyle(color: Color(0xFFB8943F), fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const Spacer(),
              if (distance != null)
                Text('${distance.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),

          // Route
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.trip_origin, color: Color(0xFF4CAF50), size: 14),
                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                  const Icon(Icons.location_on, color: Color(0xFFF44336), size: 14),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.pickupAddress ?? 'Pickup location', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Text(ride.dropoffAddress ?? 'Destination', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (ride.fare != null)
                Text('LKR ${ride.fare!.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFB8943F))),
            ],
          ),

          if (ride.surgeMultiplier > 1.0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text('Surge pricing: ${ride.surgeMultiplier}x', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Accept/Decline
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Accept Ride', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
