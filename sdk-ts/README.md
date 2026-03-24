# @pearlhub/sdk

TypeScript SDK for PearlHub Pro — the Sri Lanka multi-vertical travel & lifestyle platform.

## Installation

```bash
npm install @pearlhub/sdk @supabase/supabase-js
```

## Quick start

```typescript
import { PearlHubClient } from '@pearlhub/sdk';

const client = new PearlHubClient({
  supabaseUrl: 'https://your-project.supabase.co',
  supabaseKey: 'your-anon-key',
});

// Auth
await client.auth.signIn('user@example.com', 'password');
const profile = await client.auth.getProfile();

// Browse stays
const stays = await client.stays.list({ location: 'Colombo', guests: 2 });

// Browse vehicles
const vehicles = await client.vehicles.list({ vehicleType: 'car', withDriver: true });

// Browse events
const events = await client.events.list({ category: 'music' });

// Create a booking
const booking = await client.bookings.create({
  listingType: 'stay',
  listingId: stays[0].id,
  providerId: stays[0].provider_id,
  startDate: '2025-01-01',
  endDate: '2025-01-05',
  guests: 2,
  totalAmount: 50000,
});
```

## Modules

| Module | Methods |
|--------|---------|
| `auth` | `signUp`, `signIn`, `signOut`, `getProfile`, `updateProfile` |
| `stays` | `list(filters?)`, `get(id)` |
| `vehicles` | `list(filters?)`, `get(id)` |
| `events` | `list(filters?)`, `get(id)` |
| `properties` | `list(filters?)`, `get(id)` |
| `bookings` | `create(input)`, `listMine(status?)`, `cancel(id)` |

## Building

```bash
npm install
npm run build
```
