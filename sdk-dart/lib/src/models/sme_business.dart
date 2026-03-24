class SMEBusiness {
  final String id;
  final String businessName;
  final String? description;
  final String? category;
  final String? location;
  final String? contactEmail;
  final String? contactPhone;
  final String? websiteUrl;
  final List<String> images;
  final bool isVerified;
  final String ownerId;
  final DateTime createdAt;

  const SMEBusiness({
    required this.id,
    required this.businessName,
    this.description,
    this.category,
    this.location,
    this.contactEmail,
    this.contactPhone,
    this.websiteUrl,
    required this.images,
    required this.isVerified,
    required this.ownerId,
    required this.createdAt,
  });

  factory SMEBusiness.fromJson(Map<String, dynamic> json) => SMEBusiness(
        id: json['id'] as String,
        businessName: json['business_name'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        location: json['location'] as String?,
        contactEmail: json['contact_email'] as String?,
        contactPhone: json['contact_phone'] as String?,
        websiteUrl: json['website_url'] as String?,
        images: List<String>.from(json['images'] ?? []),
        isVerified: json['is_verified'] as bool? ?? false,
        ownerId: json['owner_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_name': businessName,
        'description': description,
        'category': category,
        'location': location,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'website_url': websiteUrl,
        'images': images,
        'is_verified': isVerified,
        'owner_id': ownerId,
        'created_at': createdAt.toIso8601String(),
      };
}
