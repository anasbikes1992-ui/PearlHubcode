double _walletDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? fallback;
}

int _walletInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

enum WalletTransactionType { deposit, withdrawal, commission, refund, fee, pearlPoints }

enum TransactionStatus { pending, completed, failed }

enum BookingStatus { pending, confirmed, cancelled, completed, refunded }

WalletTransactionType _parseWalletTransactionType(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'withdrawal':
      return WalletTransactionType.withdrawal;
    case 'commission':
      return WalletTransactionType.commission;
    case 'refund':
      return WalletTransactionType.refund;
    case 'fee':
      return WalletTransactionType.fee;
    case 'pearl_points':
      return WalletTransactionType.pearlPoints;
    default:
      return WalletTransactionType.deposit;
  }
}

TransactionStatus _parseTransactionStatus(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'completed':
      return TransactionStatus.completed;
    case 'failed':
      return TransactionStatus.failed;
    default:
      return TransactionStatus.pending;
  }
}

BookingStatus _parseBookingStatus(dynamic value) {
  switch ((value ?? '').toString()) {
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'cancelled':
      return BookingStatus.cancelled;
    case 'completed':
      return BookingStatus.completed;
    case 'refunded':
      return BookingStatus.refunded;
    default:
      return BookingStatus.pending;
  }
}

class WalletTransaction {
  final String id;
  final WalletTransactionType type;
  final double amount;
  final String description;
  final DateTime createdAt;
  final TransactionStatus status;
  final String ref;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.status,
    required this.ref,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: (json['id'] ?? '').toString(),
        type: _parseWalletTransactionType(json['type']),
        amount: _walletDouble(json['amount']),
        description: (json['description'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
        status: _parseTransactionStatus(json['status']),
        ref: (json['ref'] ?? '').toString(),
      );
}

class Booking {
  final String id;
  final String userId;
  final String listingId;
  final String listingType;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double amount;
  final String currency;
  final BookingStatus status;
  final String? paymentRef;
  final String? qrCode;
  final String? notes;
  final DateTime? createdAt;

  const Booking({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.listingType,
    this.dateFrom,
    this.dateTo,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentRef,
    this.qrCode,
    this.notes,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: (json['id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        listingId: (json['listing_id'] ?? '').toString(),
        listingType: (json['listing_type'] ?? '').toString(),
        dateFrom: DateTime.tryParse((json['date_from'] ?? '').toString()),
        dateTo: DateTime.tryParse((json['date_to'] ?? '').toString()),
        amount: _walletDouble(json['amount']),
        currency: (json['currency'] ?? 'LKR').toString(),
        status: _parseBookingStatus(json['status']),
        paymentRef: json['payment_ref']?.toString(),
        qrCode: json['qr_code']?.toString(),
        notes: json['notes']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class PearlPointsBalance {
  final int points;
  final int lifetimePoints;
  final String tier;

  const PearlPointsBalance({
    required this.points,
    required this.lifetimePoints,
    required this.tier,
  });

  factory PearlPointsBalance.fromJson(Map<String, dynamic> json) => PearlPointsBalance(
        points: _walletInt(json['points']),
        lifetimePoints: _walletInt(json['lifetime_points']),
        tier: (json['tier'] ?? 'standard').toString(),
      );
}
