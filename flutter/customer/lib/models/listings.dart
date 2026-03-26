import 'user_profile.dart';

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? fallback;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  final normalized = (value ?? '').toString().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}

List<String> _asStringList(dynamic value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  return const [];
}

Map<String, double> _asPriceMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), _asDouble(val)));
  }
  return const {};
}

enum PropertyType { house, apartment, land, commercial, villa, office }

enum PropertyListingType { sale, rent, lease, wanted }

enum VehicleType {
  car,
  van,
  bus,
  tukTuk,
  motorcycle,
  scooter,
  suv,
  minibus,
  luxuryCoach,
  jeep,
}

enum EventCategory {
  cultural,
  music,
  food,
  sports,
  business,
  adventure,
  religious,
  art,
  educational,
  cinema,
  concert,
}

PropertyType _parsePropertyType(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'apartment':
      return PropertyType.apartment;
    case 'land':
      return PropertyType.land;
    case 'commercial':
      return PropertyType.commercial;
    case 'villa':
      return PropertyType.villa;
    case 'office':
      return PropertyType.office;
    default:
      return PropertyType.house;
  }
}

PropertyListingType _parsePropertyListingType(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'rent':
      return PropertyListingType.rent;
    case 'lease':
      return PropertyListingType.lease;
    case 'wanted':
      return PropertyListingType.wanted;
    default:
      return PropertyListingType.sale;
  }
}

VehicleType _parseVehicleType(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'van':
      return VehicleType.van;
    case 'bus':
      return VehicleType.bus;
    case 'tuk_tuk':
      return VehicleType.tukTuk;
    case 'motorcycle':
      return VehicleType.motorcycle;
    case 'scooter':
      return VehicleType.scooter;
    case 'suv':
      return VehicleType.suv;
    case 'minibus':
      return VehicleType.minibus;
    case 'luxury_coach':
      return VehicleType.luxuryCoach;
    case 'jeep':
      return VehicleType.jeep;
    default:
      return VehicleType.car;
  }
}

EventCategory _parseEventCategory(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'music':
      return EventCategory.music;
    case 'food':
      return EventCategory.food;
    case 'sports':
      return EventCategory.sports;
    case 'business':
      return EventCategory.business;
    case 'adventure':
      return EventCategory.adventure;
    case 'religious':
      return EventCategory.religious;
    case 'art':
      return EventCategory.art;
    case 'educational':
      return EventCategory.educational;
    case 'cinema':
      return EventCategory.cinema;
    case 'concert':
      return EventCategory.concert;
    default:
      return EventCategory.cultural;
  }
}

class Property {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final PropertyType propertyType;
  final PropertyListingType listingType;
  final String location;
  final String address;
  final double lat;
  final double lng;
  final double price;
  final String currency;
  final double areaSqft;
  final int bedrooms;
  final int bathrooms;
  final List<String> images;
  final List<String> features;
  final ListingStatus status;
  final int views;
  final String? adminNote;
  final DateTime? createdAt;

  const Property({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.listingType,
    required this.location,
    required this.address,
    required this.lat,
    required this.lng,
    required this.price,
    required this.currency,
    required this.areaSqft,
    required this.bedrooms,
    required this.bathrooms,
    required this.images,
    required this.features,
    required this.status,
    required this.views,
    this.adminNote,
    this.createdAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        id: (json['id'] ?? '').toString(),
        ownerId: (json['owner_id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        propertyType: _parsePropertyType(json['property_type']),
        listingType: _parsePropertyListingType(json['listing_type']),
        location: (json['location'] ?? '').toString(),
        address: (json['address'] ?? '').toString(),
        lat: _asDouble(json['lat']),
        lng: _asDouble(json['lng']),
        price: _asDouble(json['price']),
        currency: (json['currency'] ?? 'LKR').toString(),
        areaSqft: _asDouble(json['area_sqft']),
        bedrooms: _asInt(json['bedrooms']),
        bathrooms: _asInt(json['bathrooms']),
        images: _asStringList(json['images']),
        features: _asStringList(json['features']),
        status: parseListingStatus(json['status']),
        views: _asInt(json['views']),
        adminNote: json['admin_note']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class Stay {
  final String id;
  final String providerId;
  final String name;
  final String description;
  final String location;
  final double lat;
  final double lng;
  final double pricePerNight;
  final String currency;
  final List<String> images;
  final List<String> amenities;
  final int bedrooms;
  final int bathrooms;
  final int maxGuests;
  final int stars;
  final double rating;
  final int reviewCount;
  final ListingStatus status;
  final String stayType;
  final bool approved;
  final String? adminNote;
  final DateTime? createdAt;

  const Stay({
    required this.id,
    required this.providerId,
    required this.name,
    required this.description,
    required this.location,
    required this.lat,
    required this.lng,
    required this.pricePerNight,
    required this.currency,
    required this.images,
    required this.amenities,
    required this.bedrooms,
    required this.bathrooms,
    required this.maxGuests,
    required this.stars,
    required this.rating,
    required this.reviewCount,
    required this.status,
    required this.stayType,
    required this.approved,
    this.adminNote,
    this.createdAt,
  });

  factory Stay.fromJson(Map<String, dynamic> json) => Stay(
        id: (json['id'] ?? '').toString(),
        providerId: (json['provider_id'] ?? '').toString(),
        name: (json['name'] ?? json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
        lat: _asDouble(json['lat']),
        lng: _asDouble(json['lng']),
        pricePerNight: _asDouble(json['price_per_night']),
        currency: (json['currency'] ?? 'LKR').toString(),
        images: _asStringList(json['images']),
        amenities: _asStringList(json['amenities']),
        bedrooms: _asInt(json['bedrooms'], 1),
        bathrooms: _asInt(json['bathrooms'], 1),
        maxGuests: _asInt(json['max_guests'], 2),
        stars: _asInt(json['stars'], 3),
        rating: _asDouble(json['rating']),
        reviewCount: _asInt(json['review_count']),
        status: parseListingStatus(json['status']),
        stayType: (json['stay_type'] ?? 'guesthouse').toString(),
        approved: _asBool(json['approved']),
        adminNote: json['admin_note']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class Vehicle {
  final String id;
  final String providerId;
  final String title;
  final String description;
  final VehicleType vehicleType;
  final String make;
  final String model;
  final int year;
  final int seats;
  final double pricePerDay;
  final String currency;
  final List<String> images;
  final List<String> features;
  final bool withDriver;
  final bool insuranceIncluded;
  final String location;
  final double lat;
  final double lng;
  final String fuel;
  final double rating;
  final int trips;
  final bool isFleet;
  final int? fleetSize;
  final ListingStatus status;
  final String? adminNote;
  final DateTime? createdAt;

  const Vehicle({
    required this.id,
    required this.providerId,
    required this.title,
    required this.description,
    required this.vehicleType,
    required this.make,
    required this.model,
    required this.year,
    required this.seats,
    required this.pricePerDay,
    required this.currency,
    required this.images,
    required this.features,
    required this.withDriver,
    required this.insuranceIncluded,
    required this.location,
    required this.lat,
    required this.lng,
    required this.fuel,
    required this.rating,
    required this.trips,
    required this.isFleet,
    this.fleetSize,
    required this.status,
    this.adminNote,
    this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: (json['id'] ?? '').toString(),
        providerId: (json['provider_id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        vehicleType: _parseVehicleType(json['vehicle_type']),
        make: (json['make'] ?? '').toString(),
        model: (json['model'] ?? '').toString(),
        year: _asInt(json['year'], DateTime.now().year),
        seats: _asInt(json['seats'], 4),
        pricePerDay: _asDouble(json['price_per_day']),
        currency: (json['currency'] ?? 'LKR').toString(),
        images: _asStringList(json['images']),
        features: _asStringList(json['features']),
        withDriver: _asBool(json['with_driver']),
        insuranceIncluded: _asBool(json['insurance_included']),
        location: (json['location'] ?? '').toString(),
        lat: _asDouble(json['lat']),
        lng: _asDouble(json['lng']),
        fuel: (json['fuel'] ?? 'petrol').toString(),
        rating: _asDouble(json['rating']),
        trips: _asInt(json['trips']),
        isFleet: _asBool(json['is_fleet']),
        fleetSize: json['fleet_size'] == null ? null : _asInt(json['fleet_size']),
        status: parseListingStatus(json['status']),
        adminNote: json['admin_note']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class PearlEvent {
  final String id;
  final String providerId;
  final String title;
  final String description;
  final EventCategory category;
  final String location;
  final String venue;
  final double lat;
  final double lng;
  final String date;
  final String time;
  final String image;
  final List<String> images;
  final Map<String, double> prices;
  final int totalSeats;
  final int availableSeats;
  final int ticketsSold;
  final bool hasSeatMap;
  final bool qrEnabled;
  final List<String> tags;
  final ListingStatus status;
  final String? adminNote;
  final DateTime? createdAt;

  const PearlEvent({
    required this.id,
    required this.providerId,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.venue,
    required this.lat,
    required this.lng,
    required this.date,
    required this.time,
    required this.image,
    required this.images,
    required this.prices,
    required this.totalSeats,
    required this.availableSeats,
    required this.ticketsSold,
    required this.hasSeatMap,
    required this.qrEnabled,
    required this.tags,
    required this.status,
    this.adminNote,
    this.createdAt,
  });

  factory PearlEvent.fromJson(Map<String, dynamic> json) => PearlEvent(
        id: (json['id'] ?? '').toString(),
        providerId: (json['provider_id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        category: _parseEventCategory(json['category']),
        location: (json['location'] ?? '').toString(),
        venue: (json['venue'] ?? '').toString(),
        lat: _asDouble(json['lat']),
        lng: _asDouble(json['lng']),
        date: (json['date'] ?? '').toString(),
        time: (json['time'] ?? '').toString(),
        image: (json['image'] ?? '').toString(),
        images: _asStringList(json['images']),
        prices: _asPriceMap(json['prices']),
        totalSeats: _asInt(json['total_seats']),
        availableSeats: _asInt(json['available_seats']),
        ticketsSold: _asInt(json['tickets_sold']),
        hasSeatMap: _asBool(json['has_seat_map']),
        qrEnabled: _asBool(json['qr_enabled'], true),
        tags: _asStringList(json['tags']),
        status: parseListingStatus(json['status']),
        adminNote: json['admin_note']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class SMEBusiness {
  final String id;
  final String ownerId;
  final String businessName;
  final String description;
  final String category;
  final String location;
  final double? lat;
  final double? lng;
  final String phone;
  final String email;
  final String? website;
  final List<String> images;
  final bool verified;
  final ListingStatus status;
  final String? adminNote;
  final DateTime? createdAt;
  final List<SMEProduct> products;

  const SMEBusiness({
    required this.id,
    required this.ownerId,
    required this.businessName,
    required this.description,
    required this.category,
    required this.location,
    this.lat,
    this.lng,
    required this.phone,
    required this.email,
    this.website,
    required this.images,
    required this.verified,
    required this.status,
    this.adminNote,
    this.createdAt,
    required this.products,
  });

  factory SMEBusiness.fromJson(Map<String, dynamic> json) => SMEBusiness(
        id: (json['id'] ?? '').toString(),
        ownerId: (json['owner_id'] ?? '').toString(),
        businessName: (json['business_name'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
        lat: json['lat'] == null ? null : _asDouble(json['lat']),
        lng: json['lng'] == null ? null : _asDouble(json['lng']),
        phone: (json['phone'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        website: json['website']?.toString(),
        images: _asStringList(json['images']),
        verified: _asBool(json['verified']),
        status: parseListingStatus(json['status']),
        adminNote: json['admin_note']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
        products: json['products'] is List
            ? (json['products'] as List)
                .map((item) => SMEProduct.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList()
            : const [],
      );
}

class SMEProduct {
  final String id;
  final String businessId;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int quantityAvailable;
  final List<String> images;
  final bool isActive;
  final DateTime? createdAt;

  const SMEProduct({
    required this.id,
    required this.businessId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.quantityAvailable,
    required this.images,
    required this.isActive,
    this.createdAt,
  });

  factory SMEProduct.fromJson(Map<String, dynamic> json) => SMEProduct(
        id: (json['id'] ?? '').toString(),
        businessId: (json['business_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        price: _asDouble(json['price']),
        currency: (json['currency'] ?? 'LKR').toString(),
        quantityAvailable: _asInt(json['quantity_available']),
        images: _asStringList(json['images']),
        isActive: _asBool(json['is_active'], true),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}
