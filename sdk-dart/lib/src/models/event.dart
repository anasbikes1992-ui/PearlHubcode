class PearlEvent {
  final String id;
  final String title;
  final String? description;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final double ticketPrice;
  final int? capacity;
  final String? category;
  final List<String> images;
  final String status;
  final String providerId;
  final DateTime createdAt;

  const PearlEvent({
    required this.id,
    required this.title,
    this.description,
    required this.location,
    required this.startDate,
    this.endDate,
    required this.ticketPrice,
    this.capacity,
    this.category,
    required this.images,
    required this.status,
    required this.providerId,
    required this.createdAt,
  });

  factory PearlEvent.fromJson(Map<String, dynamic> json) => PearlEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        location: json['location'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        ticketPrice: (json['ticket_price'] as num).toDouble(),
        capacity: json['capacity'] as int?,
        category: json['category'] as String?,
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
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'ticket_price': ticketPrice,
        'capacity': capacity,
        'category': category,
        'images': images,
        'status': status,
        'provider_id': providerId,
        'created_at': createdAt.toIso8601String(),
      };
}
