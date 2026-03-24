import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';

class EventsModule {
  final SupabaseClient _supabase;
  EventsModule(this._supabase);

  Future<List<PearlEvent>> list({
    String? location,
    String? category,
    DateTime? fromDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;
    var query = _supabase
        .from('events')
        .select()
        .eq('status', 'active');

    if (location != null) query = query.ilike('location', '%$location%');
    if (category != null) query = query.eq('category', category);
    if (fromDate != null) {
      query = query.gte('start_date', fromDate.toIso8601String());
    }

    final data =
        await query.range(from, from + pageSize - 1) as List<dynamic>;
    return data
        .map((e) => PearlEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PearlEvent> get(String id) async {
    final data = await _supabase
        .from('events')
        .select()
        .eq('id', id)
        .single();
    return PearlEvent.fromJson(data);
  }
}
