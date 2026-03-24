import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { AuthModule } from './modules/auth.js';
import { StaysModule } from './modules/stays.js';
import { VehiclesModule } from './modules/vehicles.js';
import { EventsModule } from './modules/events.js';
import { PropertiesModule } from './modules/properties.js';
import { BookingsModule } from './modules/bookings.js';

export interface PearlHubClientOptions {
  supabaseUrl: string;
  supabaseKey: string;
}

export class PearlHubClient {
  private readonly supabase: SupabaseClient;

  readonly auth: AuthModule;
  readonly stays: StaysModule;
  readonly vehicles: VehiclesModule;
  readonly events: EventsModule;
  readonly properties: PropertiesModule;
  readonly bookings: BookingsModule;

  constructor(options: PearlHubClientOptions) {
    this.supabase = createClient(options.supabaseUrl, options.supabaseKey);
    this.auth = new AuthModule(this.supabase);
    this.stays = new StaysModule(this.supabase);
    this.vehicles = new VehiclesModule(this.supabase);
    this.events = new EventsModule(this.supabase);
    this.properties = new PropertiesModule(this.supabase);
    this.bookings = new BookingsModule(this.supabase);
  }
}
