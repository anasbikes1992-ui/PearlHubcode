// lib/services/listings_service.dart
// Riverpod providers for fetching all 7 verticals — mirrors useListings.ts hooks

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listings.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

// ── STAYS ─────────────────────────────────────────────────────────────────
final staysProvider = FutureProvider.family<List<Stay>, StayFilter?>((ref, filter) async {
  final supabase = ref.read(supabaseProvider);
  var query = supabase
      .from('stays')
      .select()
      .eq('status', 'active')
      .eq('approved', true);

  if (filter?.location != null) {
    query = query.ilike('location', '%${filter!.location}%');
  }
  if (filter?.maxPrice != null) {
    query = query.lte('price_per_night', filter!.maxPrice!);
  }
  if (filter?.stayType != null) {
    query = query.eq('stay_type', filter!.stayType!);
  }

  final data = await query.order('rating', ascending: false).limit(50);
  return (data as List).map((e) => Stay.fromJson(e)).toList();
});

// Provider for a single stay's details
final stayDetailProvider = FutureProvider.family<Stay, String>((ref, id) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase.from('stays').select().eq('id', id).single();
  return Stay.fromJson(data);
});

// Provider listing (provider-specific — mirrors useProviderStays hook)
final providerStaysProvider = FutureProvider<List<Stay>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await supabase
      .from('stays')
      .select()
      .eq('provider_id', userId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => Stay.fromJson(e)).toList();
});

// ── VEHICLES ──────────────────────────────────────────────────────────────
final vehiclesProvider = FutureProvider.family<List<Vehicle>, VehicleFilter?>((ref, filter) async {
  final supabase = ref.read(supabaseProvider);
  var query = supabase.from('vehicles').select().eq('status', 'active');

  if (filter?.vehicleType != null) {
    query = query.eq('vehicle_type', filter!.vehicleType!.name);
  }
  if (filter?.withDriver != null) {
    query = query.eq('with_driver', filter!.withDriver!);
  }
  if (filter?.maxPrice != null) {
    query = query.lte('price_per_day', filter!.maxPrice!);
  }

  final data = await query.order('rating', ascending: false).limit(50);
  return (data as List).map((e) => Vehicle.fromJson(e)).toList();
});

final providerVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await supabase
      .from('vehicles')
      .select()
      .eq('provider_id', userId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => Vehicle.fromJson(e)).toList();
});

final vehicleDetailProvider = FutureProvider.family<Vehicle, String>((ref, id) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase.from('vehicles').select().eq('id', id).single();
  return Vehicle.fromJson(data);
});

// ── PROPERTIES ────────────────────────────────────────────────────────────
final propertiesProvider =
    FutureProvider.family<List<Property>, PropertyFilter?>((ref, filter) async {
  final supabase = ref.read(supabaseProvider);
  var query = supabase.from('properties').select().eq('status', 'active');

  if (filter?.listingType != null) {
    query = query.eq('listing_type', filter!.listingType!.name);
  }
  if (filter?.propertyType != null) {
    query = query.eq('property_type', filter!.propertyType!.name);
  }
  if (filter?.minBedrooms != null) {
    query = query.gte('bedrooms', filter!.minBedrooms!);
  }

  final data = await query.order('created_at', ascending: false).limit(50);
  return (data as List).map((e) => Property.fromJson(e)).toList();
});

final propertyDetailProvider = FutureProvider.family<Property, String>((ref, id) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase.from('properties').select().eq('id', id).single();
  return Property.fromJson(data);
});

// ── EVENTS ────────────────────────────────────────────────────────────────
final eventsProvider =
    FutureProvider.family<List<PearlEvent>, EventFilter?>((ref, filter) async {
  final supabase = ref.read(supabaseProvider);
  var query = supabase
      .from('events')
      .select()
      .eq('status', 'active')
      .gte('date', DateTime.now().toIso8601String().substring(0, 10));

  if (filter?.category != null) {
    query = query.eq('category', filter!.category!.name);
  }

  final data = await query.order('date').limit(50);
  return (data as List).map((e) => PearlEvent.fromJson(e)).toList();
});

final eventDetailProvider = FutureProvider.family<PearlEvent, String>((ref, id) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase.from('events').select().eq('id', id).single();
  return PearlEvent.fromJson(data);
});

final smeBusinessesProvider = FutureProvider<List<SMEBusiness>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final data = await supabase
      .from('sme_businesses')
      .select()
      .eq('status', 'active')
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).map((e) => SMEBusiness.fromJson(e)).toList();
});

// ── UPDATE LISTING STATUS (admin + provider) ─────────────────────────────
Future<void> updateListingStatus({
  required String table,
  required String id,
  required ListingStatus status,
  String? adminNote,
  required SupabaseClient supabase,
}) async {
  await supabase.from(table).update({
    'status': status.name,
    if (adminNote != null) 'admin_note': adminNote,
  }).eq('id', id);
}

// ── FILTER CLASSES ────────────────────────────────────────────────────────
class StayFilter {
  final String? location;
  final double? maxPrice;
  final String? stayType;
  final int? minBedrooms;

  const StayFilter({this.location, this.maxPrice, this.stayType, this.minBedrooms});
}

class VehicleFilter {
  final VehicleType? vehicleType;
  final bool? withDriver;
  final double? maxPrice;

  const VehicleFilter({this.vehicleType, this.withDriver, this.maxPrice});
}

class PropertyFilter {
  final PropertyListingType? listingType;
  final PropertyType? propertyType;
  final int? minBedrooms;
  final double? maxPrice;

  const PropertyFilter({this.listingType, this.propertyType, this.minBedrooms, this.maxPrice});
}

class EventFilter {
  final EventCategory? category;
  final String? location;

  const EventFilter({this.category, this.location});
}
