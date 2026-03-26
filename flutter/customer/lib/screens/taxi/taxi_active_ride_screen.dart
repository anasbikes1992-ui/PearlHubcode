// customer/lib/screens/taxi/taxi_active_ride_screen.dart
// Real-time ride tracking via Supabase Realtime — this is the core fix

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../models/taxi.dart';
import '../../services/taxi_service.dart';

class TaxiActiveRideScreen extends ConsumerWidget {
  final String rideId;
  const TaxiActiveRideScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideState = ref.watch(taxiRideProvider);
    final ride = rideState.activeRide;

    if (ride == null) {
      return Scaffold(body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF4CAF50)),
          const SizedBox(height: 16),
          const Text('Ride completed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.go('/taxi'), child: const Text('Back to taxi')),
        ],
      )));
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(ride.pickupLat, ride.pickupLng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pearlhub.customer'),
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(ride.pickupLat, ride.pickupLng),
                  width: 40, height: 40,
                  child: const Icon(Icons.trip_origin, color: Color(0xFF4CAF50), size: 28),
                ),
                Marker(
                  point: LatLng(ride.dropoffLat, ride.dropoffLng),
                  width: 40, height: 40,
                  child: const Icon(Icons.location_on, color: Color(0xFFF44336), size: 36),
                ),
              ]),
              PolylineLayer(polylines: [
                Polyline(
                  points: [
                    LatLng(ride.pickupLat, ride.pickupLng),
                    LatLng(ride.dropoffLat, ride.dropoffLng),
                  ],
                  strokeWidth: 4,
                  color: const Color(0xFFB8943F),
                ),
              ]),
            ],
          ),

          // ── Status pill ──────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _StatusPill(status: ride.status),
              ),
            ),
          ),

          // ── Bottom panel ─────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  // Status message
                  _StatusMessage(status: ride.status),
                  const SizedBox(height: 16),

                  // Route summary
                  _RouteSummaryRow(
                    pickupAddress: ride.pickupAddress ?? 'Pickup location',
                    dropoffAddress: ride.dropoffAddress ?? 'Destination',
                  ),
                  const Divider(height: 24),

                  // Fare estimate
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated fare', style: TextStyle(color: Colors.grey)),
                      Text(
                        ride.fare != null ? 'LKR ${ride.fare!.toStringAsFixed(0)}' : 'Calculating...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),

                  if (ride.surgeMultiplier > 1.0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Surge pricing', style: TextStyle(color: Colors.orange, fontSize: 12)),
                        Text('${ride.surgeMultiplier}x', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Chat + Cancel buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showChat(context, ref, ride.id),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (ride.status == TaxiRideStatus.searching)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await ref.read(taxiRideProvider.notifier).cancelRide(ride.id);
                              if (context.mounted) context.go('/taxi');
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChat(BuildContext context, WidgetRef ref, String rideId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaxiChatSheet(rideId: rideId),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TaxiRideStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaxiRideStatus.searching => ('Searching for driver...', const Color(0xFF2196F3)),
      TaxiRideStatus.accepted => ('Driver accepted!', const Color(0xFF4CAF50)),
      TaxiRideStatus.arrived => ('Driver has arrived', const Color(0xFFFF9800)),
      TaxiRideStatus.inTransit => ('On the way', const Color(0xFFB8943F)),
      TaxiRideStatus.completed => ('Ride completed', const Color(0xFF4CAF50)),
      TaxiRideStatus.cancelled => ('Ride cancelled', const Color(0xFFF44336)),
    };

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == TaxiRideStatus.searching)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            if (status == TaxiRideStatus.searching) const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final TaxiRideStatus status;
  const _StatusMessage({required this.status});

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (status) {
      TaxiRideStatus.searching => ('Finding your driver', 'Please wait while we match you with the nearest driver'),
      TaxiRideStatus.accepted => ('Driver on the way!', 'Your driver has accepted the ride and is heading to you'),
      TaxiRideStatus.arrived => ('Driver arrived!', 'Your driver is waiting at the pickup location'),
      TaxiRideStatus.inTransit => ('Enjoy your ride!', 'You are on your way to your destination'),
      TaxiRideStatus.completed => ('Ride completed', 'Thank you for riding with PearlHub'),
      TaxiRideStatus.cancelled => ('Ride cancelled', 'Your ride has been cancelled'),
    };
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }
}

class _RouteSummaryRow extends StatelessWidget {
  final String pickupAddress;
  final String dropoffAddress;

  const _RouteSummaryRow({required this.pickupAddress, required this.dropoffAddress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            const Icon(Icons.trip_origin, color: Color(0xFF4CAF50), size: 16),
            Container(width: 2, height: 20, color: Colors.grey.shade300),
            const Icon(Icons.location_on, color: Color(0xFFF44336), size: 16),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickupAddress, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Text(dropoffAddress, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ── In-ride chat sheet ─────────────────────────────────────────────────────
class _TaxiChatSheet extends ConsumerStatefulWidget {
  final String rideId;
  const _TaxiChatSheet({required this.rideId});

  @override
  ConsumerState<_TaxiChatSheet> createState() => _TaxiChatSheetState();
}

class _TaxiChatSheetState extends ConsumerState<_TaxiChatSheet> {
  final _msgCtrl = TextEditingController();

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    final supabase = ref.read(supabaseProvider);
    final senderId = supabase.auth.currentUser!.id;
    await supabase.from('taxi_chat_messages').insert({
      'ride_id': widget.rideId,
      'sender_id': senderId,
      'content': _msgCtrl.text.trim(),
    });
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(taxiChatProvider(widget.rideId));
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Chat with driver', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == myId;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFFB8943F) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(msg.content, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFB8943F),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
