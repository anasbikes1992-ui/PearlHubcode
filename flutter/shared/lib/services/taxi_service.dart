// lib/services/taxi_service.dart
// This is the KEY fix — the web app uses mock data for RealTimeTracker.
// This wires real Supabase Realtime channels for taxi rides.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/taxi.dart';
import 'auth_service.dart';

class TaxiRideState {
  final TaxiRide? activeRide;
  final List<TaxiRide> rideHistory;
  final bool searching;
  final String? error;

  const TaxiRideState({
    this.activeRide,
    this.rideHistory = const [],
    this.searching = false,
    this.error,
  });

  TaxiRideState copyWith({
    TaxiRide? activeRide,
    List<TaxiRide>? rideHistory,
    bool? searching,
    String? error,
    bool clearActiveRide = false,
  }) =>
      TaxiRideState(
        activeRide: clearActiveRide ? null : (activeRide ?? this.activeRide),
        rideHistory: rideHistory ?? this.rideHistory,
        searching: searching ?? this.searching,
        error: error,
      );
}

class TaxiRideNotifier extends StateNotifier<TaxiRideState> {
  final SupabaseClient _supabase;
  RealtimeChannel? _rideChannel;
  RealtimeChannel? _chatChannel;

  TaxiRideNotifier(this._supabase) : super(const TaxiRideState());

  // ── Request a ride (customer) ─────────────────────────────────────────────
  Future<TaxiRide?> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String vehicleCategoryId,
    String paymentMethod = 'cash',
    String? promoId,
  }) async {
    state = state.copyWith(searching: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      // Calculate estimated fare via RPC
      final fareResult = await _supabase.rpc('calculate_fare', params: {
        'p_pickup_lat': pickupLat,
        'p_pickup_lng': pickupLng,
        'p_dropoff_lat': dropoffLat,
        'p_dropoff_lng': dropoffLng,
        'p_category_id': vehicleCategoryId,
      });

      final data = await _supabase.from('taxi_rides').insert({
        'customer_id': userId,
        'vehicle_category_id': vehicleCategoryId,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup_address': pickupAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'dropoff_address': dropoffAddress,
        'status': 'searching',
        'payment_method': paymentMethod,
        'fare': fareResult,
        if (promoId != null) 'promo_id': promoId,
      }).select().single();

      final ride = TaxiRide.fromJson(data);
      state = state.copyWith(activeRide: ride, searching: false);

      // Subscribe to this ride's status changes via Realtime
      _subscribeToRide(ride.id);
      return ride;
    } catch (e) {
      state = state.copyWith(searching: false, error: e.toString());
      return null;
    }
  }

  // ── Subscribe to ride Realtime channel (THE FIX for web mock data) ────────
  void _subscribeToRide(String rideId) {
    _rideChannel?.unsubscribe();

    _rideChannel = _supabase
        .channel('taxi-ride-$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'taxi_rides',
          filter: PostgresChangeFilter(
            type: FilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            final updatedRide = TaxiRide.fromJson(payload.newRecord);
            state = state.copyWith(activeRide: updatedRide);

            // Auto-clear completed/cancelled rides after a delay
            if (updatedRide.status == TaxiRideStatus.completed ||
                updatedRide.status == TaxiRideStatus.cancelled) {
              Future.delayed(const Duration(seconds: 3), () {
                state = state.copyWith(clearActiveRide: true);
                _rideChannel?.unsubscribe();
              });
            }
          },
        )
        .subscribe();
  }

  // ── Driver: subscribe to incoming ride requests ───────────────────────────
  void subscribeToIncomingRides(String providerId) {
    _rideChannel?.unsubscribe();
    _rideChannel = _supabase
        .channel('provider-rides-$providerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'taxi_rides',
          callback: (payload) {
            // New ride request — notify driver
            final ride = TaxiRide.fromJson(payload.newRecord);
            if (ride.status == TaxiRideStatus.searching) {
              state = state.copyWith(activeRide: ride);
            }
          },
        )
        .subscribe();
  }

  // ── Driver: accept a ride ─────────────────────────────────────────────────
  Future<void> acceptRide(String rideId) async {
    final providerId = _supabase.auth.currentUser!.id;
    await _supabase.from('taxi_rides').update({
      'provider_id': providerId,
      'status': 'accepted',
    }).eq('id', rideId);
    _subscribeToRide(rideId);
  }

  // ── Driver: update ride status ────────────────────────────────────────────
  Future<void> updateRideStatus(String rideId, TaxiRideStatus status) async {
    await _supabase.from('taxi_rides').update({
      'status': status.name,
    }).eq('id', rideId);
  }

  // ── Complete ride with fare ───────────────────────────────────────────────
  Future<void> completeRide(String rideId, double finalFare) async {
    await _supabase.from('taxi_rides').update({
      'status': 'completed',
      'fare': finalFare,
    }).eq('id', rideId);
  }

  // ── Cancel ride ───────────────────────────────────────────────────────────
  Future<void> cancelRide(String rideId) async {
    await _supabase.from('taxi_rides').update({
      'status': 'cancelled',
    }).eq('id', rideId);
    state = state.copyWith(clearActiveRide: true);
    _rideChannel?.unsubscribe();
  }

  // ── Load ride history ─────────────────────────────────────────────────────
  Future<void> loadHistory() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('taxi_rides')
        .select()
        .or('customer_id.eq.$userId,provider_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(50);
    state = state.copyWith(
      rideHistory: (data as List).map((e) => TaxiRide.fromJson(e)).toList(),
    );
  }

  @override
  void dispose() {
    _rideChannel?.unsubscribe();
    _chatChannel?.unsubscribe();
    super.dispose();
  }
}

final taxiRideProvider =
    StateNotifierProvider<TaxiRideNotifier, TaxiRideState>((ref) {
  return TaxiRideNotifier(ref.read(supabaseProvider));
});

// ── Taxi chat messages ─────────────────────────────────────────────────────
final taxiChatProvider =
    StreamProvider.family<List<TaxiChatMessage>, String>((ref, rideId) {
  final supabase = ref.read(supabaseProvider);
  return supabase
      .from('taxi_chat_messages')
      .stream(primaryKey: ['id'])
      .eq('ride_id', rideId)
      .order('created_at')
      .map((rows) => rows.map((r) => TaxiChatMessage.fromJson(r)).toList());
});
