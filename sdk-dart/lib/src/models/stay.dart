class Stay {
  final String id;
  final String title;
  final String? description;
  final String location;
  final double pricePerNight;
  final String stayType;
  final List<String> amenities;
  final List<String> images;
  final int maxGuests;
  final int? bedrooms;
  final int? bathrooms;
  final String status;
  final String providerId;
  final DateTime createdAt;

  const Stay({
    required this.id,
    required this.title,
    this.description,
    required this.location,
    required this.pricePerNight,
    required this.stayType,
    required this.amenities,
    required this.images,
    required this.maxGuests,
    this.bedrooms,
    this.bathrooms,
    required this.status,
    required this.providerId,
    required this.createdAt,
  });

  factory Stay.fromJson(Map<String, dynamic> json) => Stay(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        location: json['location'] as String,
        pricePerNight: (json['price_per_night'] as num).toDouble(),
        stayType: json['stay_type'] as String,
        amenities: List<String>.from(json['amenities'] ?? []),
        images: List<String>.from(json['images'] ?? []),
        maxGuests: json['max_guests'] as int,
        bedrooms: json['bedrooms'] as int?,
        bathrooms: json['bathrooms'] as int?,
        status: json['status'] as String,
        providerId: json['provider_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'price_per_night': pricePerNight,
        'stay_type': stayType,
        'amenities': amenities,
        'images': images,
        'max_guests': maxGuests,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'status': status,
        'provider_id': providerId,
        'created_at': createdAt.toIso8601String(),
      };
}
