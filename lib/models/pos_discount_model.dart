class PosDiscount {
  final String id;
  final String name;
  final String? description;
  final String discountType; // 'fixed', 'percentage'
  final String scope; // 'order', 'item', 'category'
  final double value;
  final double? maxDiscount;
  final double? minAmount;
  final bool stackable;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PosDiscount({
    required this.id,
    required this.name,
    this.description,
    required this.discountType,
    required this.scope,
    required this.value,
    this.maxDiscount,
    this.minAmount,
    this.stackable = false,
    this.isActive = true,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PosDiscount.fromMap(Map<String, dynamic> map) {
    return PosDiscount(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      discountType: map['discount_type'] ?? 'fixed',
      scope: map['scope'] ?? 'order',
      value: (map['value'] ?? 0).toDouble(),
      maxDiscount: map['max_discount'] != null ? (map['max_discount']).toDouble() : null,
      minAmount: map['min_amount'] != null ? (map['min_amount']).toDouble() : null,
      stackable: map['stackable'] ?? false,
      isActive: map['is_active'] ?? true,
      startAt: map['start_at'] != null ? DateTime.parse(map['start_at']) : null,
      endAt: map['end_at'] != null ? DateTime.parse(map['end_at']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'discount_type': discountType,
      'scope': scope,
      'value': value,
      'max_discount': maxDiscount,
      'min_amount': minAmount,
      'stackable': stackable,
      'is_active': isActive,
      'start_at': startAt?.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isValid {
    final now = DateTime.now();
    if (!isActive) return false;
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  double calculateDiscount(double amount) {
    if (!isValid) return 0;
    if (minAmount != null && amount < minAmount!) return 0;

    double discount = 0;
    if (discountType == 'percentage') {
      discount = (amount * value) / 100;
      if (maxDiscount != null && discount > maxDiscount!) {
        discount = maxDiscount!;
      }
    } else {
      discount = value;
    }
    return discount;
  }
}
