enum UserRole {
  admin,
  customer,
  owner,
  broker,
  stayProvider,
  vehicleProvider,
  eventOrganizer,
  sme,
}

extension UserRoleX on UserRole {
  bool get isProvider => [
        UserRole.owner,
        UserRole.broker,
        UserRole.stayProvider,
        UserRole.vehicleProvider,
        UserRole.eventOrganizer,
        UserRole.sme,
      ].contains(this);

  bool get isAdmin => this == UserRole.admin;
  bool get isCustomer => this == UserRole.customer;

  String get dbValue => switch (this) {
        UserRole.admin => 'admin',
        UserRole.customer => 'customer',
        UserRole.owner => 'owner',
        UserRole.broker => 'broker',
        UserRole.stayProvider => 'stay_provider',
        UserRole.vehicleProvider => 'vehicle_provider',
        UserRole.eventOrganizer => 'event_organizer',
        UserRole.sme => 'sme',
      };

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.customer => 'Customer',
        UserRole.owner => 'Property Owner',
        UserRole.broker => 'Property Broker',
        UserRole.stayProvider => 'Stay Provider',
        UserRole.vehicleProvider => 'Vehicle Provider',
        UserRole.eventOrganizer => 'Event Organizer',
        UserRole.sme => 'SME Business',
      };
}

UserRole _parseUserRole(dynamic value) {
  switch ((value ?? 'customer').toString()) {
    case 'admin':
      return UserRole.admin;
    case 'owner':
      return UserRole.owner;
    case 'broker':
      return UserRole.broker;
    case 'stay_provider':
      return UserRole.stayProvider;
    case 'vehicle_provider':
      return UserRole.vehicleProvider;
    case 'event_organizer':
    case 'event_provider':
      return UserRole.eventOrganizer;
    case 'sme':
      return UserRole.sme;
    default:
      return UserRole.customer;
  }
}

enum ProviderTier {
  standard,
  verified,
  pro,
  elite,
}

ProviderTier _parseProviderTier(dynamic value) {
  switch ((value ?? 'standard').toString()) {
    case 'verified':
      return ProviderTier.verified;
    case 'pro':
      return ProviderTier.pro;
    case 'elite':
      return ProviderTier.elite;
    default:
      return ProviderTier.standard;
  }
}

enum ListingStatus {
  active,
  paused,
  off,
  pending,
  rejected,
}

ListingStatus parseListingStatus(dynamic value) {
  switch ((value ?? 'pending').toString()) {
    case 'active':
      return ListingStatus.active;
    case 'paused':
      return ListingStatus.paused;
    case 'off':
      return ListingStatus.off;
    case 'rejected':
      return ListingStatus.rejected;
    default:
      return ListingStatus.pending;
  }
}

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final String? avatarUrl;
  final String? nic;
  final bool verified;
  final DateTime? createdAt;
  final List<String> verificationBadges;
  final bool phoneVerified;
  final bool twoFactorEnabled;
  final String? fcmToken;
  final DateTime? lastLoginAt;
  final ProviderTier providerTier;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.nic,
    required this.verified,
    this.createdAt,
    this.verificationBadges = const [],
    this.phoneVerified = false,
    this.twoFactorEnabled = false,
    this.fcmToken,
    this.lastLoginAt,
    this.providerTier = ProviderTier.standard,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final badges = json['verification_badges'];
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      role: _parseUserRole(json['role']),
      avatarUrl: json['avatar_url']?.toString(),
      nic: json['nic']?.toString(),
      verified: json['verified'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      verificationBadges: badges is List ? badges.map((item) => item.toString()).toList() : const [],
      phoneVerified: json['phone_verified'] == true,
      twoFactorEnabled: json['two_factor_enabled'] == true,
      fcmToken: json['fcm_token']?.toString(),
      lastLoginAt: DateTime.tryParse((json['last_login_at'] ?? '').toString()),
      providerTier: _parseProviderTier(json['provider_tier']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'role': role.dbValue,
        'avatar_url': avatarUrl,
        'nic': nic,
        'verified': verified,
        'created_at': createdAt?.toIso8601String(),
        'verification_badges': verificationBadges,
        'phone_verified': phoneVerified,
        'two_factor_enabled': twoFactorEnabled,
        'fcm_token': fcmToken,
        'last_login_at': lastLoginAt?.toIso8601String(),
        'provider_tier': providerTier.name,
      };
}
