class PosPromotion {
  final String id;
  final String name;
  final String? description;
  final String promotionType; // 'bundle', 'seasonal', 'buy_x_get_y'
  final String? discountId;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PosPromotion({
    required this.id,
    required this.name,
    this.description,
    required this.promotionType,
    this.discountId,
    this.isActive = true,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PosPromotion.fromMap(Map<String, dynamic> map) {
    return PosPromotion(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      promotionType: map['promotion_type'] ?? 'bundle',
      discountId: map['discount_id'],
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
      'promotion_type': promotionType,
      'discount_id': discountId,
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
}

class PosPromotionItem {
  final String id;
  final String promotionId;
  final String productId;
  final int quantityRequired;
  final DateTime createdAt;

  PosPromotionItem({
    required this.id,
    required this.promotionId,
    required this.productId,
    this.quantityRequired = 1,
    required this.createdAt,
  });

  factory PosPromotionItem.fromMap(Map<String, dynamic> map) {
    return PosPromotionItem(
      id: map['id'] ?? '',
      promotionId: map['promotion_id'] ?? '',
      productId: map['product_id'] ?? '',
      quantityRequired: map['quantity_required'] ?? 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'promotion_id': promotionId,
      'product_id': productId,
      'quantity_required': quantityRequired,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
