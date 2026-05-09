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
  final int priority;
  final List<String> applicableCategoryIds;
  final List<String> applicableProductIds;
  final String? customerGroupId;
  final String? couponCode;
  final int? usageLimit;
  final int usedCount;
  final int? usageLimitPerCustomer;
  final int? usageLimitPerDay;
  final int usageLimitPerOrder;
  final String targetingMode;
  final Map<String, dynamic> targetingRule;
  final bool requireInStock;
  final bool requireSufficientIngredients;
  final bool includePendingProcurement;
  final String lifecycleStatus;
  final bool showInCouponTab;
  final bool showInPosDiscountDialog;
  final List<String> applicableChannels;
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
    this.priority = 0,
    this.applicableCategoryIds = const [],
    this.applicableProductIds = const [],
    this.customerGroupId,
    this.couponCode,
    this.usageLimit,
    this.usedCount = 0,
    this.usageLimitPerCustomer,
    this.usageLimitPerDay,
    this.usageLimitPerOrder = 1,
    this.targetingMode = 'manual',
    this.targetingRule = const {},
    this.requireInStock = false,
    this.requireSufficientIngredients = false,
    this.includePendingProcurement = false,
    this.lifecycleStatus = 'active',
    this.showInCouponTab = false,
    this.showInPosDiscountDialog = false,
    this.applicableChannels = const [],
    this.isActive = true,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.where((e) => e != null).map((e) => e.toString()).toList();
    return [];
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

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
      priority: map['priority'] ?? 0,
      applicableCategoryIds: _stringList(map['applicable_category_ids']),
      applicableProductIds: _stringList(map['applicable_product_ids']),
      customerGroupId: map['customer_group_id'],
      couponCode: map['coupon_code'],
      usageLimit: map['usage_limit'],
      usedCount: map['used_count'] ?? 0,
      usageLimitPerCustomer: map['usage_limit_per_customer'],
      usageLimitPerDay: map['usage_limit_per_day'],
      usageLimitPerOrder: map['usage_limit_per_order'] ?? 1,
      targetingMode: map['targeting_mode'] ?? 'manual',
      targetingRule: _mapValue(map['targeting_rule']),
      requireInStock: map['require_in_stock'] ?? false,
      requireSufficientIngredients: map['require_sufficient_ingredients'] ?? false,
      includePendingProcurement: map['include_pending_procurement'] ?? false,
      lifecycleStatus: map['lifecycle_status'] ?? 'active',
      showInCouponTab: map['show_in_coupon_tab'] ?? false,
      showInPosDiscountDialog: map['show_in_pos_discount_dialog'] ?? false,
      applicableChannels: _stringList(map['applicable_channels']),
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
      'priority': priority,
      'applicable_category_ids': applicableCategoryIds,
      'applicable_product_ids': applicableProductIds,
      'customer_group_id': customerGroupId,
      'coupon_code': couponCode,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'usage_limit_per_customer': usageLimitPerCustomer,
      'usage_limit_per_day': usageLimitPerDay,
      'usage_limit_per_order': usageLimitPerOrder,
      'targeting_mode': targetingMode,
      'targeting_rule': targetingRule,
      'require_in_stock': requireInStock,
      'require_sufficient_ingredients': requireSufficientIngredients,
      'include_pending_procurement': includePendingProcurement,
      'lifecycle_status': lifecycleStatus,
      'show_in_coupon_tab': showInCouponTab,
      'show_in_pos_discount_dialog': showInPosDiscountDialog,
      'applicable_channels': applicableChannels,
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
    if (lifecycleStatus == 'draft' || lifecycleStatus == 'paused' || lifecycleStatus == 'archived') return false;
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
