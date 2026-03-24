class Vehicle {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final double pricePerDay;
  final String vehicleType;
  final bool withDriver;
  final List<String> images;
  final String? make;
  final String? model;
  final int? year;
  final int? seats;
  final String status;
  final String providerId;
  final DateTime createdAt;

  const Vehicle({
    required this.id,
    required this.title,
    this.description,
    this.location,
    required this.pricePerDay,
    required this.vehicleType,
    required this.withDriver,
    required this.images,
    this.make,
    this.model,
    this.year,
    this.seats,
    required this.status,
    required this.providerId,
    required this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        location: json['location'] as String?,
        pricePerDay: (json['price_per_day'] as num).toDouble(),
        vehicleType: json['vehicle_type'] as String,
        withDriver: json['with_driver'] as bool? ?? false,
        images: List<String>.from(json['images'] ?? []),
        make: json['make'] as String?,
        model: json['model'] as String?,
        year: json['year'] as int?,
        seats: json['seats'] as int?,
        status: json['status'] as String,
        providerId: json['provider_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'price_per_day': pricePerDay,
        'vehicle_type': vehicleType,
        'with_driver': withDriver,
        'images': images,
        'make': make,
        'model': model,
        'year': year,
        'seats': seats,
        'status': status,
        'provider_id': providerId,
        'created_at': createdAt.toIso8601String(),
      };
}
