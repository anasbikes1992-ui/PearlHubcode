// customer/lib/screens/taxi/taxi_home_screen.dart
// Real-time taxi booking — replaces the mock RealTimeTracker in the web app

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../models/taxi.dart';
import '../../services/taxi_service.dart';
import '../../services/auth_service.dart';

// Vehicle categories provider
final taxiCategoriesProvider = FutureProvider<List<TaxiVehicleCategory>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('taxi_vehicle_categories')
      .select()
      .eq('is_active', true)
      .order('base_fare');
  return (data as List).map((e) => TaxiVehicleCategory.fromJson(e)).toList();
});

class TaxiHomeScreen extends ConsumerStatefulWidget {
  const TaxiHomeScreen({super.key});

  @override
  ConsumerState<TaxiHomeScreen> createState() => _TaxiHomeScreenState();
}

class _TaxiHomeScreenState extends ConsumerState<TaxiHomeScreen> {
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _mapController = MapController();

  LatLng _pickup = const LatLng(6.9271, 79.8612); // Colombo default
  LatLng? _dropoff;
  String? _selectedCategoryId;
  bool _isPickupMode = true;

  // Sri Lanka bounds
  static const _sriLankaBounds = LatLngBounds(
    LatLng(5.9, 79.5),
    LatLng(9.9, 81.9),
  );

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestRide() async {
    if (_dropoff == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a destination and select a vehicle type')),
      );
      return;
    }

    final ride = await ref.read(taxiRideProvider.notifier).requestRide(
      pickupLat: _pickup.latitude,
      pickupLng: _pickup.longitude,
      pickupAddress: _pickupCtrl.text,
      dropoffLat: _dropoff!.latitude,
      dropoffLng: _dropoff!.longitude,
      dropoffAddress: _dropoffCtrl.text,
      vehicleCategoryId: _selectedCategoryId!,
    );

    if (ride != null && mounted) {
      context.push('/taxi/ride/${ride.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(taxiRideProvider);
    final categoriesAsync = ref.watch(taxiCategoriesProvider);
    final theme = Theme.of(context);

    // If there's an active ride redirect automatically
    if (rideState.activeRide != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.push('/taxi/ride/${rideState.activeRide!.id}');
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup,
              initialZoom: 13,
              cameraConstraint: CameraConstraint.containCenter(bounds: _sriLankaBounds),
              onTap: (tapPosition, point) {
                setState(() {
                  if (_isPickupMode) {
                    _pickup = point;
                  } else {
                    _dropoff = point;
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pearlhub.customer',
              ),
              MarkerLayer(
                markers: [
                  // Pickup marker
                  Marker(
                    point: _pickup,
                    width: 40, height: 40,
                    child: const Icon(Icons.trip_origin, color: Color(0xFF4CAF50), size: 30),
                  ),
                  // Dropoff marker
                  if (_dropoff != null)
                    Marker(
                      point: _dropoff!,
                      width: 40, height: 40,
                      child: const Icon(Icons.location_on, color: Color(0xFFF44336), size: 36),
                    ),
                ],
              ),
              // Route polyline between pickup and dropoff
              if (_dropoff != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_pickup, _dropoff!],
                      strokeWidth: 4,
                      color: const Color(0xFFB8943F),
                    ),
                  ],
                ),
            ],
          ),

          // ── Top safe area ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Map mode toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ModeButton(label: 'Pickup', active: _isPickupMode, color: const Color(0xFF4CAF50),
                            onTap: () => setState(() => _isPickupMode = true)),
                          _ModeButton(label: 'Dropoff', active: !_isPickupMode, color: const Color(0xFFF44336),
                            onTap: () => setState(() => _isPickupMode = false)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // History button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: () => context.push('/taxi/history'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom sheet panel ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 2)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  Text('Book a ride', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Address inputs
                  _AddressField(
                    controller: _pickupCtrl,
                    hintText: 'Pickup location',
                    icon: Icons.trip_origin,
                    iconColor: const Color(0xFF4CAF50),
                    onTap: () => setState(() => _isPickupMode = true),
                  ),
                  const SizedBox(height: 12),
                  _AddressField(
                    controller: _dropoffCtrl,
                    hintText: 'Where to?',
                    icon: Icons.location_on,
                    iconColor: const Color(0xFFF44336),
                    onTap: () => setState(() => _isPickupMode = false),
                  ),
                  const SizedBox(height: 20),

                  // Vehicle categories
                  Text('Choose vehicle', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading categories: $e'),
                    data: (categories) => SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, i) {
                          final cat = categories[i];
                          final selected = _selectedCategoryId == cat.id;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategoryId = cat.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFB8943F) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected ? const Color(0xFFB8943F) : Colors.grey.shade300,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(cat.icon, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text(cat.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                    color: selected ? Colors.white : Colors.black87)),
                                  Text('LKR ${cat.baseFare.toStringAsFixed(0)}', style: TextStyle(fontSize: 10,
                                    color: selected ? Colors.white70 : Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Book button
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: rideState.searching ? null : _requestRide,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB8943F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: rideState.searching
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.local_taxi, color: Colors.white),
                      label: Text(rideState.searching ? 'Finding driver...' : 'Book ride',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: active ? color : Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _AddressField({required this.controller, required this.hintText, required this.icon, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
