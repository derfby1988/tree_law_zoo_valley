class PosPromotion {
  final String id;
  final String name;
  final String? description;
  final String promotionType; // 'bundle', 'seasonal', 'buy_x_get_y'
  final String? discountId;
  final List<String> applicableUserGroupIds;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Phase 4: Availability & Procurement Rules
  final bool requireInStock;
  final bool requireSufficientIngredients;
  final bool includePendingProcurement;
  // QR Code support
  final String? code;
  final String? qrCode;
  final String? qrSignature;
  final DateTime? qrGeneratedAt;

  PosPromotion({
    required this.id,
    required this.name,
    this.description,
    required this.promotionType,
    this.discountId,
    this.applicableUserGroupIds = const [],
    this.isActive = true,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
    // Phase 4: default to false (no availability restrictions by default)
    this.requireInStock = false,
    this.requireSufficientIngredients = false,
    this.includePendingProcurement = false,
    // QR Code support
    this.code,
    this.qrCode,
    this.qrSignature,
    this.qrGeneratedAt,
  });

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.where((e) => e != null).map((e) => e.toString()).toList();
    return [];
  }

  factory PosPromotion.fromMap(Map<String, dynamic> map) {
    return PosPromotion(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      promotionType: map['promotion_type'] ?? 'bundle',
      discountId: map['discount_id'],
      applicableUserGroupIds: _stringList(map['applicable_user_group_ids']),
      isActive: map['is_active'] ?? true,
      startAt: map['start_at'] != null ? DateTime.parse(map['start_at']) : null,
      endAt: map['end_at'] != null ? DateTime.parse(map['end_at']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      // Phase 4: Availability fields
      requireInStock: map['require_in_stock'] ?? false,
      requireSufficientIngredients: map['require_sufficient_ingredients'] ?? false,
      includePendingProcurement: map['include_pending_procurement'] ?? false,
      // QR Code support
      code: map['code'],
      qrCode: map['qr_code'],
      qrSignature: map['qr_signature'],
      qrGeneratedAt: map['qr_generated_at'] != null ? DateTime.parse(map['qr_generated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'promotion_type': promotionType,
      'discount_id': discountId,
      'applicable_user_group_ids': applicableUserGroupIds,
      'is_active': isActive,
      'start_at': startAt?.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Phase 4: Availability fields
      'require_in_stock': requireInStock,
      'require_sufficient_ingredients': requireSufficientIngredients,
      'include_pending_procurement': includePendingProcurement,
      // QR Code support
      'code': code,
      'qr_code': qrCode,
      'qr_signature': qrSignature,
      'qr_generated_at': qrGeneratedAt?.toIso8601String(),
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
