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
        'start_at': startAt?.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'is_active': true,
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
}
