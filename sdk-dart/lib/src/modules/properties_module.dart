import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property.dart';

class PropertiesModule {
  final SupabaseClient _supabase;
  PropertiesModule(this._supabase);

  Future<List<Property>> list({
    String? location,
    String? listingType,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;
    var query = _supabase
        .from('properties')
        .select()
        .eq('status', 'active');

    if (location != null) query = query.ilike('location', '%$location%');
    if (listingType != null) query = query.eq('listing_type', listingType);
    if (minPrice != null) query = query.gte('price', minPrice);
    if (maxPrice != null) query = query.lte('price', maxPrice);

    final data =
        await query.range(from, from + pageSize - 1) as List<dynamic>;
    return data
        .map((e) => Property.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Property> get(String id) async {
    final data = await _supabase
        .from('properties')
        .select()
        .eq('id', id)
        .single();
    return Property.fromJson(data);
  }
}
