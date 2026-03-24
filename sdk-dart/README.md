# pearlhub_sdk

Dart SDK for PearlHub Pro — the Sri Lanka multi-vertical travel & lifestyle platform.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  pearlhub_sdk:
    path: ../sdk-dart   # or git / pub.dev path
```

## Quick start

```dart
import 'package:pearlhub_sdk/pearlhub_sdk.dart';

final client = PearlHubClient(
  supabaseUrl: 'https://your-project.supabase.co',
  supabaseKey: 'your-anon-key',
);

// Auth
await client.auth.signIn('user@example.com', 'password');
final profile = await client.auth.getProfile();

// Browse stays
final stays = await client.stays.list(location: 'Colombo', guests: 2);

// Browse vehicles
final vehicles = await client.vehicles.list(vehicleType: 'car', withDriver: true);

// Create a booking
final booking = await client.bookings.create(
  listingType: 'stay',
  listingId: stays.first.id,
  providerId: stays.first.providerId,
  startDate: DateTime(2025, 1, 1),
  endDate: DateTime(2025, 1, 5),
  guests: 2,
  totalAmount: 50000,
);
```

## Modules

| Module | Methods |
|--------|---------|
| `auth` | `signUp`, `signIn`, `signOut`, `getProfile`, `updateProfile` |
| `stays` | `list(...)`, `get(id)` |
| `vehicles` | `list(...)`, `get(id)` |
| `events` | `list(...)`, `get(id)` |
| `properties` | `list(...)`, `get(id)` |
| `bookings` | `create(...)`, `listMine({status})`, `cancel(id)` |
