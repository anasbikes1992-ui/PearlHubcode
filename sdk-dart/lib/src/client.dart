import 'package:supabase_flutter/supabase_flutter.dart';
import 'modules/auth_module.dart';
import 'modules/stays_module.dart';
import 'modules/vehicles_module.dart';
import 'modules/events_module.dart';
import 'modules/properties_module.dart';
import 'modules/bookings_module.dart';

class PearlHubClient {
  final SupabaseClient _supabase;

  late final AuthModule auth;
  late final StaysModule stays;
  late final VehiclesModule vehicles;
  late final EventsModule events;
  late final PropertiesModule properties;
  late final BookingsModule bookings;

  PearlHubClient({required String supabaseUrl, required String supabaseKey})
      : _supabase = SupabaseClient(supabaseUrl, supabaseKey) {
    auth = AuthModule(_supabase);
    stays = StaysModule(_supabase);
    vehicles = VehiclesModule(_supabase);
    events = EventsModule(_supabase);
    properties = PropertiesModule(_supabase);
    bookings = BookingsModule(_supabase);
  }
}
