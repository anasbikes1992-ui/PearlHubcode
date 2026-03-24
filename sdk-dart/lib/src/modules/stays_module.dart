import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stay.dart';

class StaysModule {
  final SupabaseClient _supabase;
  StaysModule(this._supabase);

  Future<List<Stay>> list({
    String? location,
    String? stayType,
    double? minPrice,
    double? maxPrice,
    int? guests,
    int page = 1,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;
    var query = _supabase
        .from('stays')
        .select()
        .eq('status', 'active');

    if (location != null) query = query.ilike('location', '%$location%');
    if (stayType != null) query = query.eq('stay_type', stayType);
    if (minPrice != null) query = query.gte('price_per_night', minPrice);
    if (maxPrice != null) query = query.lte('price_per_night', maxPrice);
    if (guests != null) query = query.gte('max_guests', guests);

    final data =
        await query.range(from, from + pageSize - 1) as List<dynamic>;
    return data
        .map((e) => Stay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Stay> get(String id) async {
    final data = await _supabase
        .from('stays')
        .select()
        .eq('id', id)
        .single();
    return Stay.fromJson(data);
  }
}
