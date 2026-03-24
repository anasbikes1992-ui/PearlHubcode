class Property {
  final String id;
  final String title;
  final String? description;
  final String location;
  final double price;
  final String listingType;
  final int? bedrooms;
  final int? bathrooms;
  final double? areaSqft;
  final List<String> images;
  final String status;
  final String providerId;
  final DateTime createdAt;

  const Property({
    required this.id,
    required this.title,
    this.description,
    required this.location,
    required this.price,
    required this.listingType,
    this.bedrooms,
    this.bathrooms,
    this.areaSqft,
    required this.images,
    required this.status,
    required this.providerId,
    required this.createdAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        location: json['location'] as String,
        price: (json['price'] as num).toDouble(),
        listingType: json['listing_type'] as String,
        bedrooms: json['bedrooms'] as int?,
        bathrooms: json['bathrooms'] as int?,
        areaSqft: json['area_sqft'] != null
            ? (json['area_sqft'] as num).toDouble()
            : null,
        images: List<String>.from(json['images'] ?? []),
        status: json['status'] as String,
        providerId: json['provider_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'price': price,
        'listing_type': listingType,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'area_sqft': areaSqft,
        'images': images,
        'status': status,
        'provider_id': providerId,
        'created_at': createdAt.toIso8601String(),
      };
}
