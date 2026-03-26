// shared/lib/models/transport_extended.dart
// Models for: AirportTransfer, OfficeTransport (plans/routes/subscriptions/wallets),
//             ParcelDelivery, ParcelItemType

// ── Helpers ──────────────────────────────────────────────────────────────────

double _d(dynamic v, [double fb = 0]) {
  if (v is num) return v.toDouble();
  return double.tryParse((v ?? '').toString()) ?? fb;
}

int _i(dynamic v, [int fb = 0]) {
  if (v is num) return v.toInt();
  return int.tryParse((v ?? '').toString()) ?? fb;
}

bool _b(dynamic v, [bool fb = false]) {
  if (v is bool) return v;
  final s = (v ?? '').toString().toLowerCase();
  return s == 'true' ? true : s == 'false' ? false : fb;
}

String _s(dynamic v, [String fb = '']) => (v ?? '').toString().isEmpty ? fb : v.toString();

DateTime? _dt(dynamic v) => DateTime.tryParse((v ?? '').toString());

// ── AIRPORT TRANSFER ─────────────────────────────────────────────────────────

enum AirportTransferDirection { toAirport, fromAirport }

enum AirportTransferStatus { pending, confirmed, completed, cancelled }

AirportTransferDirection _parseDirection(dynamic v) =>
    (v ?? '').toString() == 'from_airport'
        ? AirportTransferDirection.fromAirport
        : AirportTransferDirection.toAirport;

AirportTransferStatus _parseTransferStatus(dynamic v) {
  switch ((v ?? '').toString()) {
    case 'confirmed': return AirportTransferStatus.confirmed;
    case 'completed': return AirportTransferStatus.completed;
    case 'cancelled': return AirportTransferStatus.cancelled;
    default: return AirportTransferStatus.pending;
  }
}

class AirportTransfer {
  final String id;
  final String userId;
  final String? vehicleListingId;
  final AirportTransferDirection direction;
  final String airportCode;
  final DateTime? pickupDatetime;
  final String passengerName;
  final String? flightNumber;
  final int passengers;
  final int luggageCount;
  final double fare;
  final AirportTransferStatus status;
  final DateTime? createdAt;

  const AirportTransfer({
    required this.id,
    required this.userId,
    this.vehicleListingId,
    required this.direction,
    required this.airportCode,
    this.pickupDatetime,
    required this.passengerName,
    this.flightNumber,
    required this.passengers,
    required this.luggageCount,
    required this.fare,
    required this.status,
    this.createdAt,
  });

  factory AirportTransfer.fromJson(Map<String, dynamic> json) => AirportTransfer(
        id: _s(json['id']),
        userId: _s(json['user_id']),
        vehicleListingId: json['vehicle_listing_id']?.toString(),
        direction: _parseDirection(json['direction']),
        airportCode: _s(json['airport_code'], 'BIA'),
        pickupDatetime: _dt(json['pickup_datetime']),
        passengerName: _s(json['passenger_name']),
        flightNumber: json['flight_number']?.toString(),
        passengers: _i(json['passengers'], 1),
        luggageCount: _i(json['luggage_count'], 1),
        fare: _d(json['fare']),
        status: _parseTransferStatus(json['status']),
        createdAt: _dt(json['created_at']),
      );

  String get directionLabel =>
      direction == AirportTransferDirection.toAirport ? '→ To Airport' : '← From Airport';

  String get statusLabel {
    switch (status) {
      case AirportTransferStatus.confirmed: return 'Confirmed';
      case AirportTransferStatus.completed: return 'Completed';
      case AirportTransferStatus.cancelled: return 'Cancelled';
      default: return 'Pending';
    }
  }
}

// ── OFFICE TRANSPORT ─────────────────────────────────────────────────────────

class OfficeTransportPlan {
  final String id;
  final String name;
  final String? description;
  final double pricePerMonth;
  final int? tripsPerMonth;
  final bool active;
  final DateTime? createdAt;

  const OfficeTransportPlan({
    required this.id,
    required this.name,
    this.description,
    required this.pricePerMonth,
    this.tripsPerMonth,
    required this.active,
    this.createdAt,
  });

  factory OfficeTransportPlan.fromJson(Map<String, dynamic> json) => OfficeTransportPlan(
        id: _s(json['id']),
        name: _s(json['name']),
        description: json['description']?.toString(),
        pricePerMonth: _d(json['price_per_month']),
        tripsPerMonth: json['trips_per_month'] != null ? _i(json['trips_per_month']) : null,
        active: _b(json['active'], true),
        createdAt: _dt(json['created_at']),
      );
}

class OfficeTransportRoute {
  final String id;
  final String name;
  final String? origin;
  final String? destination;
  final String? departureTime;
  final String? returnTime;
  final bool active;
  final DateTime? createdAt;

  const OfficeTransportRoute({
    required this.id,
    required this.name,
    this.origin,
    this.destination,
    this.departureTime,
    this.returnTime,
    required this.active,
    this.createdAt,
  });

  factory OfficeTransportRoute.fromJson(Map<String, dynamic> json) => OfficeTransportRoute(
        id: _s(json['id']),
        name: _s(json['name']),
        origin: json['origin']?.toString(),
        destination: json['destination']?.toString(),
        departureTime: json['departure_time']?.toString(),
        returnTime: json['return_time']?.toString(),
        active: _b(json['active'], true),
        createdAt: _dt(json['created_at']),
      );
}

class OfficeTransportSubscription {
  final String id;
  final String userId;
  final String? planId;
  final String? routeId;
  final bool active;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final OfficeTransportPlan? plan;
  final OfficeTransportRoute? route;

  const OfficeTransportSubscription({
    required this.id,
    required this.userId,
    this.planId,
    this.routeId,
    required this.active,
    this.expiresAt,
    this.createdAt,
    this.plan,
    this.route,
  });

  factory OfficeTransportSubscription.fromJson(Map<String, dynamic> json) =>
      OfficeTransportSubscription(
        id: _s(json['id']),
        userId: _s(json['user_id']),
        planId: json['plan_id']?.toString(),
        routeId: json['route_id']?.toString(),
        active: _b(json['active'], true),
        expiresAt: _dt(json['expires_at']),
        createdAt: _dt(json['created_at']),
        plan: json['office_transport_plans'] != null
            ? OfficeTransportPlan.fromJson(json['office_transport_plans'] as Map<String, dynamic>)
            : null,
        route: json['office_transport_routes'] != null
            ? OfficeTransportRoute.fromJson(json['office_transport_routes'] as Map<String, dynamic>)
            : null,
      );
}

class OfficeTransportWallet {
  final String id;
  final String userId;
  final double balance;
  final DateTime? updatedAt;

  const OfficeTransportWallet({
    required this.id,
    required this.userId,
    required this.balance,
    this.updatedAt,
  });

  factory OfficeTransportWallet.fromJson(Map<String, dynamic> json) => OfficeTransportWallet(
        id: _s(json['id']),
        userId: _s(json['user_id']),
        balance: _d(json['balance']),
        updatedAt: _dt(json['updated_at']),
      );
}

// ── PARCEL DELIVERY ───────────────────────────────────────────────────────────

enum ParcelStatus { pending, confirmed, pickedUp, inTransit, delivered, cancelled }

ParcelStatus _parseParcelStatus(dynamic v) {
  switch ((v ?? '').toString()) {
    case 'confirmed': return ParcelStatus.confirmed;
    case 'picked_up': return ParcelStatus.pickedUp;
    case 'in_transit': return ParcelStatus.inTransit;
    case 'delivered': return ParcelStatus.delivered;
    case 'cancelled': return ParcelStatus.cancelled;
    default: return ParcelStatus.pending;
  }
}

const _parcelStatusLabels = {
  ParcelStatus.pending: 'Pending',
  ParcelStatus.confirmed: 'Confirmed',
  ParcelStatus.pickedUp: 'Picked Up',
  ParcelStatus.inTransit: 'In Transit',
  ParcelStatus.delivered: 'Delivered',
  ParcelStatus.cancelled: 'Cancelled',
};

class ParcelItemType {
  final String id;
  final String name;
  final String? icon;
  final double basePrice;
  final double? maxWeightKg;
  final bool active;

  const ParcelItemType({
    required this.id,
    required this.name,
    this.icon,
    required this.basePrice,
    this.maxWeightKg,
    required this.active,
  });

  factory ParcelItemType.fromJson(Map<String, dynamic> json) => ParcelItemType(
        id: _s(json['id']),
        name: _s(json['name']),
        icon: json['icon']?.toString(),
        basePrice: _d(json['base_price'], 350),
        maxWeightKg: json['max_weight_kg'] != null ? _d(json['max_weight_kg']) : null,
        active: _b(json['active'], true),
      );
}

class ParcelDelivery {
  final String id;
  final String? senderUserId;
  final String? itemTypeId;
  final String? senderName;
  final String senderPhone;
  final String? recipientName;
  final String recipientPhone;
  final String pickupAddress;
  final String dropoffAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final bool fragile;
  final bool insured;
  final String? notes;
  final double fare;
  final double insuranceFee;
  final ParcelStatus status;
  final DateTime? createdAt;
  final ParcelItemType? itemType;

  const ParcelDelivery({
    required this.id,
    this.senderUserId,
    this.itemTypeId,
    this.senderName,
    required this.senderPhone,
    this.recipientName,
    required this.recipientPhone,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    required this.fragile,
    required this.insured,
    this.notes,
    required this.fare,
    required this.insuranceFee,
    required this.status,
    this.createdAt,
    this.itemType,
  });

  factory ParcelDelivery.fromJson(Map<String, dynamic> json) => ParcelDelivery(
        id: _s(json['id']),
        senderUserId: json['sender_user_id']?.toString(),
        itemTypeId: json['item_type_id']?.toString(),
        senderName: json['sender_name']?.toString(),
        senderPhone: _s(json['sender_phone']),
        recipientName: json['recipient_name']?.toString(),
        recipientPhone: _s(json['recipient_phone']),
        pickupAddress: _s(json['pickup_address']),
        dropoffAddress: _s(json['dropoff_address']),
        pickupLat: json['pickup_lat'] != null ? _d(json['pickup_lat']) : null,
        pickupLng: json['pickup_lng'] != null ? _d(json['pickup_lng']) : null,
        dropoffLat: json['dropoff_lat'] != null ? _d(json['dropoff_lat']) : null,
        dropoffLng: json['dropoff_lng'] != null ? _d(json['dropoff_lng']) : null,
        fragile: _b(json['fragile']),
        insured: _b(json['insured']),
        notes: json['notes']?.toString(),
        fare: _d(json['fare']),
        insuranceFee: _d(json['insurance_fee']),
        status: _parseParcelStatus(json['status']),
        createdAt: _dt(json['created_at']),
        itemType: json['parcel_item_types'] != null
            ? ParcelItemType.fromJson(json['parcel_item_types'] as Map<String, dynamic>)
            : null,
      );

  String get statusLabel => _parcelStatusLabels[status] ?? 'Unknown';

  bool get isActive =>
      status != ParcelStatus.delivered && status != ParcelStatus.cancelled;
}
