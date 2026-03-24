import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking.dart';

class BookingsModule {
  final SupabaseClient _supabase;
  BookingsModule(this._supabase);

  Future<Booking> create({
    required String listingType,
    required String listingId,
    required String providerId,
    required DateTime startDate,
    DateTime? endDate,
    int? guests,
    required double totalAmount,
    String? notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final data = await _supabase
        .from('bookings')
        .insert({
          'listing_type': listingType,
          'listing_id': listingId,
          'provider_id': providerId,
          'customer_id': user.id,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'guests': guests,
          'total_amount': totalAmount,
          'status': 'pending',
          'notes': notes,
        })
        .select()
        .single();
    return Booking.fromJson(data);
  }

  Future<List<Booking>> listMine({String? status}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    var query = _supabase
        .from('bookings')
        .select()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);

    if (status != null) query = query.eq('status', status);

    final data = await query as List<dynamic>;
    return data
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancel(String id) async {
    await _supabase
        .from('bookings')
        .update({'status': 'cancelled'}).eq('id', id);
  }
}
