double _taxiDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? fallback;
}

int _taxiInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

bool _taxiBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  final normalized = (value ?? '').toString().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}

enum TaxiRideStatus { searching, accepted, arrived, inTransit, completed, cancelled }

enum TaxiPaymentMethod { cash, wallet, card }

TaxiRideStatus _parseTaxiRideStatus(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'accepted':
      return TaxiRideStatus.accepted;
    case 'arrived':
      return TaxiRideStatus.arrived;
    case 'in_transit':
      return TaxiRideStatus.inTransit;
    case 'completed':
      return TaxiRideStatus.completed;
    case 'cancelled':
      return TaxiRideStatus.cancelled;
    default:
      return TaxiRideStatus.searching;
  }
}

class TaxiVehicleCategory {
  final String id;
  final String name;
  final bool isActive;
  final int defaultSeats;
  final double baseFare;
  final double perKmRate;
  final String icon;
  final DateTime? createdAt;

  const TaxiVehicleCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.defaultSeats,
    required this.baseFare,
    required this.perKmRate,
    required this.icon,
    this.createdAt,
  });

  factory TaxiVehicleCategory.fromJson(Map<String, dynamic> json) => TaxiVehicleCategory(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        isActive: _taxiBool(json['is_active'], true),
        defaultSeats: _taxiInt(json['default_seats']),
        baseFare: _taxiDouble(json['base_fare']),
        perKmRate: _taxiDouble(json['per_km_rate']),
        icon: (json['icon'] ?? '🚕').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class TaxiRide {
  final String id;
  final String customerId;
  final String? providerId;
  final String? vehicleCategoryId;
  final double pickupLat;
  final double pickupLng;
  final String? pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String? dropoffAddress;
  final TaxiRideStatus status;
  final double? fare;
  final double? distanceKm;
  final String rideModule;
  final String paymentMethod;
  final String paymentStatus;
  final double surgeMultiplier;
  final DateTime? scheduledFor;
  final bool isEmergencySos;
  final String? promoId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaxiRide({
    required this.id,
    required this.customerId,
    this.providerId,
    this.vehicleCategoryId,
    required this.pickupLat,
    required this.pickupLng,
    this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    this.dropoffAddress,
    required this.status,
    this.fare,
    this.distanceKm,
    required this.rideModule,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.surgeMultiplier,
    this.scheduledFor,
    required this.isEmergencySos,
    this.promoId,
    this.createdAt,
    this.updatedAt,
  });

  factory TaxiRide.fromJson(Map<String, dynamic> json) => TaxiRide(
        id: (json['id'] ?? '').toString(),
        customerId: (json['customer_id'] ?? '').toString(),
        providerId: json['provider_id']?.toString(),
        vehicleCategoryId: json['vehicle_category_id']?.toString(),
        pickupLat: _taxiDouble(json['pickup_lat']),
        pickupLng: _taxiDouble(json['pickup_lng']),
        pickupAddress: json['pickup_address']?.toString(),
        dropoffLat: _taxiDouble(json['dropoff_lat']),
        dropoffLng: _taxiDouble(json['dropoff_lng']),
        dropoffAddress: json['dropoff_address']?.toString(),
        status: _parseTaxiRideStatus(json['status']),
        fare: json['fare'] == null ? null : _taxiDouble(json['fare']),
        distanceKm: json['distance_km'] == null ? null : _taxiDouble(json['distance_km']),
        rideModule: (json['ride_module'] ?? 'standard').toString(),
        paymentMethod: (json['payment_method'] ?? 'cash').toString(),
        paymentStatus: (json['payment_status'] ?? 'pending').toString(),
        surgeMultiplier: _taxiDouble(json['surge_multiplier'], 1),
        scheduledFor: DateTime.tryParse((json['scheduled_for'] ?? '').toString()),
        isEmergencySos: _taxiBool(json['is_emergency_sos']),
        promoId: json['promo_id']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
        updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      );
}

class TaxiKYC {
  final String id;
  final String providerId;
  final String? nicNumber;
  final String? licenseNumber;
  final String verificationStatus;
  final DateTime? submittedAt;

  const TaxiKYC({
    required this.id,
    required this.providerId,
    this.nicNumber,
    this.licenseNumber,
    required this.verificationStatus,
    this.submittedAt,
  });

  factory TaxiKYC.fromJson(Map<String, dynamic> json) => TaxiKYC(
        id: (json['id'] ?? '').toString(),
        providerId: (json['provider_id'] ?? '').toString(),
        nicNumber: json['nic_number']?.toString(),
        licenseNumber: json['license_number']?.toString(),
        verificationStatus: (json['verification_status'] ?? 'pending').toString(),
        submittedAt: DateTime.tryParse((json['submitted_at'] ?? '').toString()),
      );
}

class TaxiChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String content;
  final DateTime? createdAt;

  const TaxiChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.content,
    this.createdAt,
  });

  factory TaxiChatMessage.fromJson(Map<String, dynamic> json) => TaxiChatMessage(
        id: (json['id'] ?? '').toString(),
        rideId: (json['ride_id'] ?? '').toString(),
        senderId: (json['sender_id'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class TaxiRating {
  final String id;
  final String rideId;
  final String reviewerId;
  final String targetId;
  final int rating;
  final String feedback;
  final double tipAmount;
  final DateTime? createdAt;

  const TaxiRating({
    required this.id,
    required this.rideId,
    required this.reviewerId,
    required this.targetId,
    required this.rating,
    required this.feedback,
    required this.tipAmount,
    this.createdAt,
  });

  factory TaxiRating.fromJson(Map<String, dynamic> json) => TaxiRating(
        id: (json['id'] ?? '').toString(),
        rideId: (json['ride_id'] ?? '').toString(),
        reviewerId: (json['reviewer_id'] ?? '').toString(),
        targetId: (json['target_id'] ?? '').toString(),
        rating: _taxiInt(json['rating'], 5),
        feedback: (json['feedback'] ?? '').toString(),
        tipAmount: _taxiDouble(json['tip_amount']),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class TaxiPromo {
  final String id;
  final String code;
  final String discountType;
  final double discountAmount;
  final int maxUses;
  final int usesCount;
  final DateTime? validUntil;
  final bool isActive;

  const TaxiPromo({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountAmount,
    required this.maxUses,
    required this.usesCount,
    this.validUntil,
    required this.isActive,
  });

  factory TaxiPromo.fromJson(Map<String, dynamic> json) => TaxiPromo(
        id: (json['id'] ?? '').toString(),
        code: (json['code'] ?? '').toString(),
        discountType: (json['discount_type'] ?? '').toString(),
        discountAmount: _taxiDouble(json['discount_amount']),
        maxUses: _taxiInt(json['max_uses']),
        usesCount: _taxiInt(json['uses_count']),
        validUntil: DateTime.tryParse((json['valid_until'] ?? '').toString()),
        isActive: _taxiBool(json['is_active'], true),
      );
}
