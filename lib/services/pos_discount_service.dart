import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_discount_model.dart';

class PosDiscountService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Discount Management
  // =============================================

  static Future<List<PosDiscount>> getActiveDiscounts() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from('pos_discounts')
          .select()
          .eq('is_active', true)
          .or('start_at.is.null,start_at.lte.$now')
          .or('end_at.is.null,end_at.gte.$now');

      return (response as List)
          .map((item) => PosDiscount.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getActiveDiscounts: $e');
      return [];
    }
  }

  static Future<List<PosDiscount>> getAllDiscounts() async {
    try {
      final response = await _client
          .from('pos_discounts')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PosDiscount.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getAllDiscounts: $e');
      return [];
    }
  }

  static Future<List<PosDiscount>> getDiscountsByScope(String scope) async {
    try {
      final response = await _client
          .from('pos_discounts')
          .select()
          .eq('scope', scope)
          .eq('is_active', true);

      return (response as List)
          .map((item) => PosDiscount.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getDiscountsByScope: $e');
      return [];
    }
  }

  static Future<PosDiscount?> getDiscountById(String id) async {
    try {
      final response = await _client
          .from('pos_discounts')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return PosDiscount.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getDiscountById: $e');
      return null;
    }
  }

  static Future<PosDiscount?> addDiscount({
    required String name,
    String? description,
    required String discountType,
    required String scope,
    required double value,
    double? maxDiscount,
    double? minAmount,
    bool stackable = false,
    bool isActive = true,
    int priority = 0,
    List<String> applicableCategoryIds = const [],
    List<String> applicableProductIds = const [],
    String? customerGroupId,
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    int usageLimitPerOrder = 1,
    String targetingMode = 'manual',
    Map<String, dynamic> targetingRule = const {},
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
    String lifecycleStatus = 'active',
    List<String> applicableChannels = const [],
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    try {
      final payload = {
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
        'usage_limit_per_customer': usageLimitPerCustomer,
        'usage_limit_per_day': usageLimitPerDay,
        'usage_limit_per_order': usageLimitPerOrder,
        'targeting_mode': targetingMode,
        'targeting_rule': targetingRule,
        'require_in_stock': requireInStock,
        'require_sufficient_ingredients': requireSufficientIngredients,
        'include_pending_procurement': includePendingProcurement,
        'lifecycle_status': lifecycleStatus,
        'applicable_channels': applicableChannels,
        'start_at': startAt?.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'is_active': isActive,
      };

      final response = await _client
          .from('pos_discounts')
          .insert(payload)
          .select()
          .single();

      return PosDiscount.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error addDiscount: $e');
      return null;
    }
  }

  static Future<PosDiscount?> updateDiscount({
    required String id,
    String? name,
    String? description,
    String? discountType,
    String? scope,
    double? value,
    double? maxDiscount,
    double? minAmount,
    bool? stackable,
    bool? isActive,
    int? priority,
    List<String>? applicableCategoryIds,
    List<String>? applicableProductIds,
    String? customerGroupId,
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    int? usageLimitPerOrder,
    String? targetingMode,
    Map<String, dynamic>? targetingRule,
    bool? requireInStock,
    bool? requireSufficientIngredients,
    bool? includePendingProcurement,
    String? lifecycleStatus,
    List<String>? applicableChannels,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (description != null) payload['description'] = description;
      if (discountType != null) payload['discount_type'] = discountType;
      if (scope != null) payload['scope'] = scope;
      if (value != null) payload['value'] = value;
      if (maxDiscount != null) payload['max_discount'] = maxDiscount;
      if (minAmount != null) payload['min_amount'] = minAmount;
      if (stackable != null) payload['stackable'] = stackable;
      if (isActive != null) payload['is_active'] = isActive;
      if (priority != null) payload['priority'] = priority;
      if (applicableCategoryIds != null) payload['applicable_category_ids'] = applicableCategoryIds;
      if (applicableProductIds != null) payload['applicable_product_ids'] = applicableProductIds;
      if (customerGroupId != null) payload['customer_group_id'] = customerGroupId;
      if (couponCode != null) payload['coupon_code'] = couponCode;
      if (usageLimit != null) payload['usage_limit'] = usageLimit;
      if (usageLimitPerCustomer != null) payload['usage_limit_per_customer'] = usageLimitPerCustomer;
      if (usageLimitPerDay != null) payload['usage_limit_per_day'] = usageLimitPerDay;
      if (usageLimitPerOrder != null) payload['usage_limit_per_order'] = usageLimitPerOrder;
      if (targetingMode != null) payload['targeting_mode'] = targetingMode;
      if (targetingRule != null) payload['targeting_rule'] = targetingRule;
      if (requireInStock != null) payload['require_in_stock'] = requireInStock;
      if (requireSufficientIngredients != null) payload['require_sufficient_ingredients'] = requireSufficientIngredients;
      if (includePendingProcurement != null) payload['include_pending_procurement'] = includePendingProcurement;
      if (lifecycleStatus != null) payload['lifecycle_status'] = lifecycleStatus;
      if (applicableChannels != null) payload['applicable_channels'] = applicableChannels;
      if (startAt != null) payload['start_at'] = startAt.toIso8601String();
      if (endAt != null) payload['end_at'] = endAt.toIso8601String();

      final response = await _client
          .from('pos_discounts')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      return PosDiscount.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error updateDiscount: $e');
      return null;
    }
  }

  static Future<bool> deactivateDiscount(String id) async {
    try {
      await _client
          .from('pos_discounts')
          .update({'is_active': false})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deactivateDiscount: $e');
      return false;
    }
  }

  // =============================================
  // Order Discounts
  // =============================================

  static Future<List<Map<String, dynamic>>> getOrderDiscounts(String orderId) async {
    try {
      final response = await _client
          .from('pos_order_discounts')
          .select('*, pos_discounts(*)')
          .eq('order_id', orderId);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error getOrderDiscounts: $e');
      return [];
    }
  }

  static Future<bool> applyDiscountToOrder({
    required String orderId,
    required String discountId,
    required double discountAmount,
  }) async {
    try {
      await _client
          .from('pos_order_discounts')
          .insert({
            'order_id': orderId,
            'discount_id': discountId,
            'discount_amount': discountAmount,
          });
      return true;
    } catch (e) {
      debugPrint('Error applyDiscountToOrder: $e');
      return false;
    }
  }

  static Future<bool> removeDiscountFromOrder(String orderId, String discountId) async {
    try {
      await _client
          .from('pos_order_discounts')
          .delete()
          .eq('order_id', orderId)
          .eq('discount_id', discountId);
      return true;
    } catch (e) {
      debugPrint('Error removeDiscountFromOrder: $e');
      return false;
    }
  }

  static Future<bool> deleteDiscount(String id) async {
    try {
      await _client
          .from('pos_discounts')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleteDiscount: $e');
      return false;
    }
  }
}
