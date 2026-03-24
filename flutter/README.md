# PearlHub Flutter — Three-App Architecture

Sri Lanka's premier multi-vertical marketplace, converted from React/Web to Flutter.

---

## Project Structure

```
pearlhub_flutter/
├── shared/                    # Dart package — models, services, Supabase client
│   └── lib/
│       ├── models/
│       │   ├── user_profile.dart     # UserProfile, UserRole, ListingStatus
│       │   ├── listings.dart         # Property, Stay, Vehicle, PearlEvent, SME
│       │   ├── taxi.dart             # TaxiRide, TaxiKYC, TaxiPromo, TaxiRating
│       │   └── wallet.dart           # WalletTransaction, Booking, PearlPoints
│       └── services/
│           ├── auth_service.dart     # Supabase auth (mirrors AuthContext.tsx)
│           ├── taxi_service.dart     # Realtime taxi (fixes web mock data)
│           └── listings_service.dart # Riverpod providers for all 7 verticals
│
├── customer/                  # Customer app (iOS + Android)
│   └── lib/
│       ├── main.dart                 # App + GoRouter + PearlHubTheme
│       └── screens/
│           ├── auth/login_screen.dart
│           ├── home/home_screen.dart
│           ├── taxi/taxi_home_screen.dart         # Map + ride booking
│           ├── taxi/taxi_active_ride_screen.dart  # Real-time tracking + chat
│           └── concierge/concierge_screen.dart    # AI via Edge Function
│
├── provider/                  # Provider app (iOS + Android)
│   └── lib/
│       ├── main.dart                 # Role-aware router
│       └── screens/
│           ├── dashboard/provider_dashboard_screen.dart  # Real earnings chart
│           ├── taxi_driver/driver_home_screen.dart       # Online/offline + rides
│           └── listings/create_listing_screen.dart       # Role-aware form
│
├── admin/                     # Admin app (tablet + mobile)
│   └── lib/
│       ├── main.dart                 # Side-drawer shell
│       └── screens/
│           ├── overview/admin_overview_screen.dart          # Live platform stats
│           └── moderation/listings_moderation_screen.dart   # Full moderation UI
│
└── supabase/
    └── functions/
        ├── ai-concierge/index.ts      # Fixes API key exposure (critical fix)
        └── payment-webhook/index.ts   # Fixes missing payment confirmation
```

---

## Setup

### 1. Environment variables

Each Flutter app uses compile-time env vars (not runtime .env):

```bash
# Build with Supabase credentials
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

For VS Code, add to `.vscode/launch.json`:
```json
{
  "configurations": [{
    "name": "PearlHub Customer",
    "request": "launch",
    "type": "dart",
    "args": [
      "--dart-define=SUPABASE_URL=https://your-project.supabase.co",
      "--dart-define=SUPABASE_ANON_KEY=your-anon-key"
    ]
  }]
}
```

### 2. Deploy Edge Functions

```bash
# Set secrets (these never go in client code)
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set PAYHERE_MERCHANT_SECRET=your_payhere_secret
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Deploy both functions
supabase functions deploy ai-concierge
supabase functions deploy payment-webhook
```

### 3. Flutter setup

```bash
# Install dependencies for each app
cd shared && flutter pub get
cd ../customer && flutter pub get
cd ../provider && flutter pub get
cd ../admin && flutter pub get
```

### 4. Run

```bash
# Customer app
cd customer
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Provider app
cd provider
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Admin app
cd admin
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

---

## Key Design Decisions

### Why 3 separate apps?

1. **Security** — Admin app never ships to public app stores. Provider app enforces role checks at router level. Customer app can't accidentally access admin routes.
2. **App store presence** — Customer and Provider apps can be separate Play Store / App Store listings with different review paths.
3. **Bundle size** — Each app only includes the code it needs (no admin moderation code in the customer build).
4. **Role clarity** — Providers sign up knowing they're getting a "provider app" experience, not the customer browsing flow.

### Realtime taxi (the core fix)

The web app's `RealTimeTracker` component renders a `<div>` with hardcoded mock coordinates. The Flutter taxi service wires actual Supabase Realtime channels:

```
Customer books ride → INSERT into taxi_rides
  ↓
Flutter: supabase.channel('taxi-ride-{id}').onPostgresChanges(UPDATE)
  ↓
Any status change (searching → accepted → arrived → in_transit → completed)
  ↓
Flutter UI updates in real time — no polling
```

### AI Concierge (security fix)

| Location | Web app (broken) | Flutter app (fixed) |
|---|---|---|
| API key | `VITE_ANTHROPIC_API_KEY` in browser bundle | `ANTHROPIC_API_KEY` Supabase secret |
| API call | Direct from browser JS | Via `supabase.functions.invoke('ai-concierge')` |
| Auth check | None | JWT verified in Edge Function |

### Provider earnings chart (data fix)

| Web app | Flutter app |
|---|---|
| Hardcoded `[30, 45, 38, 52, 60, 58, 70, 85, 92, 88]` bar heights | Real query against `earnings` table grouped by day |
| No actual data binding | `FutureProvider<Map>` fetches last 30 days from Supabase |
| Always shows same fake trend | Shows provider's actual revenue curve |

---

## Screens Still Needed (Phase 2+)

### Customer app
- `StayDetailScreen` — gallery, amenities, availability calendar, book button
- `VehicleDetailScreen` — specs, features, date picker
- `EventDetailScreen` — seat map picker, ticket type selection
- `CheckoutScreen` — booking summary, date selection, payment
- `WalletScreen` — balance, top-up, Pearl Points, transaction history
- `BookingsListScreen` — upcoming and past bookings with status
- `RegisterScreen` — email/password + role selection
- `ProfileScreen` — edit profile, NIC, verification

### Provider app
- `ListingsScreen` — list all provider's listings with edit/delete
- `BookingQueueScreen` — pending bookings with accept/decline
- `AvailabilityCalendarScreen` — block dates, set minimum stay
- `EarningsScreen` — detailed earnings breakdown, withdrawal
- `CRMScreen` — customer list, conversation history

### Admin app
- `AdminLoginScreen` — login with admin role verification
- `UsersScreen` — search/filter users, change role, verify
- `KYCReviewScreen` — taxi driver KYC document approval
- `TaxiAdminScreen` — categories, promo codes, surge settings
- `TransactionsScreen` — all platform transactions
- `PlatformSettingsScreen` — feature toggles, commission rates

---

## Firebase Push Notifications Setup

```bash
# Add to each app's pubspec.yaml
firebase_core: ^3.1.0
firebase_messaging: ^15.0.2

# Initialize in main()
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
final fcm = FirebaseMessaging.instance;
await fcm.requestPermission();
final token = await fcm.getToken();
# Store token in profiles table: supabase.from('profiles').update({'fcm_token': token})
```

Trigger notifications from Supabase via a DB function or Edge Function on booking status change.
