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

  // =============================================
  // Coupon Code Validation
  // =============================================

  /// Validate coupon code and return discount if valid
  static Future<PosDiscount?> validateCouponCode({
    required String couponCode,
    required double orderAmount,
    String? customerId,
    String channel = 'pos',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Find discount by coupon code
      final response = await _client
          .from('pos_discounts')
          .select()
          .eq('coupon_code', couponCode)
          .maybeSingle();

      if (response == null) {
        debugPrint('Coupon code not found: $couponCode');
        return null;
      }

      final discount = PosDiscount.fromMap(Map<String, dynamic>.from(response));

      // Validate lifecycle status
      if (discount.lifecycleStatus == 'draft') {
        debugPrint('Coupon is in draft status');
        return null;
      }
      if (discount.lifecycleStatus == 'paused') {
        debugPrint('Coupon is paused');
        return null;
      }
      if (discount.lifecycleStatus == 'archived') {
        debugPrint('Coupon is archived');
        return null;
      }

      // Validate active status
      if (!discount.isActive) {
        debugPrint('Coupon is not active');
        return null;
      }

      // Validate date/time
      if (discount.startAt != null && DateTime.now().isBefore(discount.startAt!)) {
        debugPrint('Coupon not yet started');
        return null;
      }
      if (discount.endAt != null && DateTime.now().isAfter(discount.endAt!)) {
        debugPrint('Coupon has expired');
        return null;
      }

      // Validate minimum amount
      if (discount.minAmount != null && orderAmount < discount.minAmount!) {
        debugPrint('Order amount below minimum: $orderAmount < ${discount.minAmount}');
        return null;
      }

      // Validate usage limit
      if (discount.usageLimit != null && discount.usedCount >= discount.usageLimit!) {
        debugPrint('Usage limit reached: ${discount.usedCount}/${discount.usageLimit}');
        return null;
      }

      // Validate channel
      if (discount.applicableChannels.isNotEmpty &&
          !discount.applicableChannels.contains(channel)) {
        debugPrint('Channel not allowed: $channel');
        return null;
      }

      // TODO: Validate per-customer limit (needs usage history query)
      // TODO: Validate per-day limit (needs usage history query)

      return discount;
    } catch (e) {
      debugPrint('Error validateCouponCode: $e');
      return null;
    }
  }

  // =============================================
  // Usage Logging
  // =============================================

  /// Record discount usage for an order
  static Future<bool> recordDiscountUsage({
    required String orderId,
    required String discountId,
    required double discountAmount,
    required String appliedBy,
    String? orderLineId,
    String? promotionId,
    String? couponCode,
    String discountName = '',
    String discountType = 'fixed',
    double discountValue = 0,
  }) async {
    try {
      final payload = {
        'order_id': orderId,
        'discount_id': discountId,
        'discount_amount': discountAmount,
        'applied_by': appliedBy,
        'applied_at': DateTime.now().toIso8601String(),
        'order_line_id': orderLineId,
        'promotion_id': promotionId,
        'coupon_code': couponCode,
        'discount_name': discountName,
        'discount_type': discountType,
        'discount_value': discountValue,
      };

      await _client.from('pos_order_discounts').insert(payload);

      // Increment used_count on the discount
      await _client.rpc('increment_discount_usage', params: {'p_discount_id': discountId});

      return true;
    } catch (e) {
      debugPrint('Error recordDiscountUsage: $e');
      return false;
    }
  }

  /// Get usage statistics for a discount
  static Future<Map<String, dynamic>> getDiscountUsageStats(String discountId) async {
    try {
      final response = await _client
          .from('pos_order_discounts')
          .select()
          .eq('discount_id', discountId);

      final usages = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();

      final totalUses = usages.length;
      final totalDiscountAmount = usages.fold<double>(
        0,
        (sum, u) => sum + ((u['discount_amount'] ?? 0) as num).toDouble(),
      );

      // Get unique customers
      final customerIds = usages
          .where((u) => u['order'] != null && u['order']['customer_id'] != null)
          .map((u) => u['order']['customer_id'])
          .toSet();

      return {
        'total_uses': totalUses,
        'total_discount_amount': totalDiscountAmount,
        'unique_customers': customerIds.length,
        'last_used_at': usages.isNotEmpty ? usages.last['applied_at'] : null,
      };
    } catch (e) {
      debugPrint('Error getDiscountUsageStats: $e');
      return {
        'total_uses': 0,
        'total_discount_amount': 0.0,
        'unique_customers': 0,
        'last_used_at': null,
      };
    }
  }

  // =============================================
  // Phase 7: Analytics Methods
  // =============================================

  /// Get analytics summary for dashboard cards
  static Future<Map<String, dynamic>> getAnalyticsSummary({
    DateTime? startDate,
    DateTime? endDate,
    String? discountId,
    String? promotionId,
  }) async {
    try {
      // Use basic query to get summary data
      var query = _client
          .from('pos_order_discounts')
          .select('''
            discount_id,
            promotion_id,
            discount_amount,
            applied_at,
            order_id,
            pos_orders!inner(
              customer_id
            )
          ''');

      // Apply date filters
      if (startDate != null) {
        query = query.gte('applied_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('applied_at', endDate.toIso8601String());
      }
      if (discountId != null) {
        query = query.eq('discount_id', discountId);
      }
      if (promotionId != null) {
        query = query.eq('promotion_id', promotionId);
      }

      final response = await query;
      final discounts = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      // Calculate summary
      final totalUsage = discounts.length;
      final totalDiscount = discounts.fold<double>(
        0,
        (sum, d) => sum + ((d['discount_amount'] ?? 0) as num).toDouble(),
      );
      final totalOrders = discounts.map((d) => d['order_id']).toSet().length;
      final totalCustomers = discounts
          .where((d) => d['pos_orders'] != null && d['pos_orders']['customer_id'] != null)
          .map((d) => d['pos_orders']['customer_id'])
          .toSet()
          .length;
      final couponUsage = discounts.where((d) => d['discount_id'] != null).length;
      final promotionUsage = discounts.where((d) => d['promotion_id'] != null).length;
      final couponDiscount = discounts
          .where((d) => d['discount_id'] != null)
          .fold<double>(0, (sum, d) => sum + ((d['discount_amount'] ?? 0) as num).toDouble());
      final promotionDiscount = discounts
          .where((d) => d['promotion_id'] != null)
          .fold<double>(0, (sum, d) => sum + ((d['discount_amount'] ?? 0) as num).toDouble());

      return {
        'total_usage': totalUsage,
        'total_discount': totalDiscount,
        'total_orders': totalOrders,
        'total_customers': totalCustomers,
        'coupon_usage': couponUsage,
        'promotion_usage': promotionUsage,
        'coupon_discount': couponDiscount,
        'promotion_discount': promotionDiscount,
      };
    } catch (e) {
      debugPrint('Error getAnalyticsSummary: $e');
      return {
        'total_usage': 0,
        'total_discount': 0.0,
        'total_orders': 0,
        'total_customers': 0,
        'coupon_usage': 0,
        'promotion_usage': 0,
        'coupon_discount': 0.0,
        'promotion_discount': 0.0,
      };
    }
  }

  /// Get detailed usage analytics for table
  static Future<List<Map<String, dynamic>>> getUsageAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? discountId,
    String? promotionId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      // Use basic query with joins to get usage data
      final response = await _client
          .from('pos_order_discounts')
          .select('''
            discount_id,
            promotion_id,
            discount_name,
            discount_amount,
            applied_at,
            pos_discounts!inner(
              name,
              discount_type
            ),
            pos_promotions!inner(
              name,
              min_quantity,
              free_quantity
            )
          ''')
          .order('applied_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) {
            final data = Map<String, dynamic>.from(item);
            // Determine type and name
            final isCoupon = data['discount_id'] != null;
            data['type'] = isCoupon ? 'coupon' : 'promotion';
            data['name'] = isCoupon 
                ? (data['pos_discounts']?['name'] ?? data['discount_name'] ?? 'Unknown')
                : (data['pos_promotions']?['name'] ?? data['discount_name'] ?? 'Unknown');
            return data;
          })
          .toList();
    } catch (e) {
      debugPrint('Error getUsageAnalytics: $e');
      return [];
    }
  }

  /// Get order details for a specific discount/promotion
  static Future<List<Map<String, dynamic>>> getOrderDetailsForDiscount({
    String? discountId,
    String? promotionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Use basic query without views for now
      final response = await _client
          .from('pos_order_discounts')
          .select('''
            id,
            discount_id,
            promotion_id,
            discount_name,
            discount_type,
            discount_value,
            discount_amount,
            applied_at,
            applied_by,
            order_id,
            pos_orders!inner(
              order_number,
              total_amount,
              final_amount,
              created_at,
              customer_id,
              pos_customers!inner(
                display_name
              )
            )
          ''')
          .order('applied_at', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error getOrderDetailsForDiscount: $e');
      return [];
    }
  }

  /// Get top performing discounts
  static Future<List<Map<String, dynamic>>> getTopPerformingDiscounts({
    String? type, // 'coupon' or 'promotion'
    int limit = 10,
  }) async {
    try {
      var query = _client
          .from('top_performing_discounts')
          .select();

      if (type != null) {
        query = query.eq('type', type);
      }

      final response = await query.order('usage_rank', ascending: true).limit(limit);
      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error getTopPerformingDiscounts: $e');
      return [];
    }
  }

  /// Get customer usage patterns
  static Future<List<Map<String, dynamic>>> getCustomerUsagePatterns({
    String? customerId,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('customer_discount_usage')
          .select();

      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }

      final response = await query.order('total_discount_received', ascending: false).limit(limit);
      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error getCustomerUsagePatterns: $e');
      return [];
    }
  }

}
