// Main entry point for @pearlhub/sdk
export { PearlHubClient } from './client.js';
export type { PearlHubClientOptions } from './client.js';

export type {
  Profile,
  Stay,
  Vehicle,
  PearlEvent,
  Property,
  SMEBusiness,
  Booking,
  Transaction,
  ListingStatus,
  BookingStatus,
  VehicleType,
  PropertyListingType,
  UserRole,
  StayFilters,
  VehicleFilters,
  EventFilters,
  PropertyFilters,
  PaginationOptions,
} from './types/index.js';

export { AuthModule } from './modules/auth.js';
export { StaysModule } from './modules/stays.js';
export { VehiclesModule } from './modules/vehicles.js';
export { EventsModule } from './modules/events.js';
export { PropertiesModule } from './modules/properties.js';
export { BookingsModule } from './modules/bookings.js';
export type { CreateBookingInput } from './modules/bookings.js';
