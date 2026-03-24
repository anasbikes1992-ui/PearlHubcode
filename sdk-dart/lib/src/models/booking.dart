class Booking {
  final String id;
  final String listingType;
  final String listingId;
  final String customerId;
  final String providerId;
  final DateTime startDate;
  final DateTime? endDate;
  final int? guests;
  final double totalAmount;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.listingType,
    required this.listingId,
    required this.customerId,
    required this.providerId,
    required this.startDate,
    this.endDate,
    this.guests,
    required this.totalAmount,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        listingType: json['listing_type'] as String,
        listingId: json['listing_id'] as String,
        customerId: json['customer_id'] as String,
        providerId: json['provider_id'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        guests: json['guests'] as int?,
        totalAmount: (json['total_amount'] as num).toDouble(),
        status: json['status'] as String,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_type': listingType,
        'listing_id': listingId,
        'customer_id': customerId,
        'provider_id': providerId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'guests': guests,
        'total_amount': totalAmount,
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}
