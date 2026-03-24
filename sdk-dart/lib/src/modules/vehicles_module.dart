import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';

class VehiclesModule {
  final SupabaseClient _supabase;
  VehiclesModule(this._supabase);

  Future<List<Vehicle>> list({
    String? location,
    String? vehicleType,
    bool? withDriver,
    double? maxPricePerDay,
    int page = 1,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;
    var query = _supabase
        .from('vehicles')
        .select()
        .eq('status', 'active');

    if (location != null) query = query.ilike('location', '%$location%');
    if (vehicleType != null) query = query.eq('vehicle_type', vehicleType);
    if (withDriver != null) query = query.eq('with_driver', withDriver);
    if (maxPricePerDay != null) {
      query = query.lte('price_per_day', maxPricePerDay);
    }

    final data =
        await query.range(from, from + pageSize - 1) as List<dynamic>;
    return data
        .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Vehicle> get(String id) async {
    final data = await _supabase
        .from('vehicles')
        .select()
        .eq('id', id)
        .single();
    return Vehicle.fromJson(data);
  }
}
