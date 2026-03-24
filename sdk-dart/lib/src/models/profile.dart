class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String role;
  final int pearlPoints;
  final double walletBalance;
  final bool isVerified;
  final bool isSuspended;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.phone,
    required this.role,
    required this.pearlPoints,
    required this.walletBalance,
    required this.isVerified,
    required this.isSuspended,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'customer',
        pearlPoints: json['pearl_points'] as int? ?? 0,
        walletBalance: (json['wallet_balance'] as num? ?? 0).toDouble(),
        isVerified: json['is_verified'] as bool? ?? false,
        isSuspended: json['is_suspended'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'phone': phone,
        'role': role,
        'pearl_points': pearlPoints,
        'wallet_balance': walletBalance,
        'is_verified': isVerified,
        'is_suspended': isSuspended,
        'created_at': createdAt.toIso8601String(),
      };
}
