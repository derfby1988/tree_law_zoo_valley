class PosLoyaltyProgram {
  final String id;
  final String name;
  final String? description;
  final double pointsPerBaht;
  final int? pointsExpiryDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PosLoyaltyProgram({
    required this.id,
    required this.name,
    this.description,
    this.pointsPerBaht = 1,
    this.pointsExpiryDays,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PosLoyaltyProgram.fromMap(Map<String, dynamic> map) {
    return PosLoyaltyProgram(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      pointsPerBaht: (map['points_per_baht'] ?? 1).toDouble(),
      pointsExpiryDays: map['points_expiry_days'],
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'points_per_baht': pointsPerBaht,
      'points_expiry_days': pointsExpiryDays,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PosCustomerLoyaltyWallet {
  final String id;
  final String customerId;
  final String loyaltyProgramId;
  final double totalPoints;
  final double redeemedPoints;
  final double availablePoints;
  final DateTime? lastTransactionAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PosCustomerLoyaltyWallet({
    required this.id,
    required this.customerId,
    required this.loyaltyProgramId,
    this.totalPoints = 0,
    this.redeemedPoints = 0,
    this.availablePoints = 0,
    this.lastTransactionAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PosCustomerLoyaltyWallet.fromMap(Map<String, dynamic> map) {
    return PosCustomerLoyaltyWallet(
      id: map['id'] ?? '',
      customerId: map['customer_id'] ?? '',
      loyaltyProgramId: map['loyalty_program_id'] ?? '',
      totalPoints: (map['total_points'] ?? 0).toDouble(),
      redeemedPoints: (map['redeemed_points'] ?? 0).toDouble(),
      availablePoints: (map['available_points'] ?? 0).toDouble(),
      lastTransactionAt: map['last_transaction_at'] != null ? DateTime.parse(map['last_transaction_at']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'loyalty_program_id': loyaltyProgramId,
      'total_points': totalPoints,
      'redeemed_points': redeemedPoints,
      'available_points': availablePoints,
      'last_transaction_at': lastTransactionAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PosLoyaltyTransaction {
  final String id;
  final String walletId;
  final String? orderId;
  final String transactionType; // 'earn', 'redeem', 'expire', 'adjust'
  final double points;
  final String? reason;
  final DateTime? expiresAt;
  final DateTime createdAt;

  PosLoyaltyTransaction({
    required this.id,
    required this.walletId,
    this.orderId,
    required this.transactionType,
    required this.points,
    this.reason,
    this.expiresAt,
    required this.createdAt,
  });

  factory PosLoyaltyTransaction.fromMap(Map<String, dynamic> map) {
    return PosLoyaltyTransaction(
      id: map['id'] ?? '',
      walletId: map['wallet_id'] ?? '',
      orderId: map['order_id'],
      transactionType: map['transaction_type'] ?? 'earn',
      points: (map['points'] ?? 0).toDouble(),
      reason: map['reason'],
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wallet_id': walletId,
      'order_id': orderId,
      'transaction_type': transactionType,
      'points': points,
      'reason': reason,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
