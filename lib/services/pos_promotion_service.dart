import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_promotion_model.dart';
import 'inventory_service.dart';

class PosPromotionService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Promotion Management
  // =============================================

  static Future<List<PosPromotion>> getActivePromotions() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from('pos_promotions')
          .select()
          .eq('is_active', true)
          .or('start_at.is.null,start_at.lte.$now')
          .or('end_at.is.null,end_at.gte.$now');

      return (response as List)
          .map((item) => PosPromotion.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getActivePromotions: $e');
      return [];
    }
  }

  static Future<List<PosPromotion>> getAllPromotions() async {
    try {
      final response = await _client
          .from('pos_promotions')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PosPromotion.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getAllPromotions: $e');
      return [];
    }
  }

  static Future<List<PosPromotion>> getPromotionsByType(String promotionType) async {
    try {
      final response = await _client
          .from('pos_promotions')
          .select()
          .eq('promotion_type', promotionType)
          .eq('is_active', true);

      return (response as List)
          .map((item) => PosPromotion.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getPromotionsByType: $e');
      return [];
    }
  }

  static Future<PosPromotion?> getPromotionById(String id) async {
    try {
      final response = await _client
          .from('pos_promotions')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return PosPromotion.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getPromotionById: $e');
      return null;
    }
  }

  static Future<PosPromotion?> addPromotion({
    required String name,
    String? description,
    required String promotionType,
    String? discountId,
    List<String> applicableUserGroupIds = const [],
    bool isActive = true,
    DateTime? startAt,
    DateTime? endAt,
    // Phase 4: Availability & Procurement Rules
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
  }) async {
    try {
      final payload = {
        'name': name,
        'description': description,
        'promotion_type': promotionType,
        'discount_id': discountId,
        'applicable_user_group_ids': applicableUserGroupIds,
        'start_at': startAt?.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'is_active': isActive,
        // Phase 4: Availability fields
        'require_in_stock': requireInStock,
        'require_sufficient_ingredients': requireSufficientIngredients,
        'include_pending_procurement': includePendingProcurement,
      };

      final response = await _client
          .from('pos_promotions')
          .insert(payload)
          .select()
          .single();

      return PosPromotion.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error addPromotion: $e');
      return null;
    }
  }

  static Future<PosPromotion?> updatePromotion({
    required String id,
    String? name,
    String? description,
    String? promotionType,
    String? discountId,
    List<String>? applicableUserGroupIds,
    bool? isActive,
    DateTime? startAt,
    DateTime? endAt,
    // Phase 4: Availability & Procurement Rules
    bool? requireInStock,
    bool? requireSufficientIngredients,
    bool? includePendingProcurement,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (description != null) payload['description'] = description;
      if (promotionType != null) payload['promotion_type'] = promotionType;
      if (discountId != null) payload['discount_id'] = discountId;
      if (applicableUserGroupIds != null) payload['applicable_user_group_ids'] = applicableUserGroupIds;
      if (isActive != null) payload['is_active'] = isActive;
      if (startAt != null) payload['start_at'] = startAt.toIso8601String();
      if (endAt != null) payload['end_at'] = endAt.toIso8601String();
      // Phase 4: Availability fields
      if (requireInStock != null) payload['require_in_stock'] = requireInStock;
      if (requireSufficientIngredients != null) payload['require_sufficient_ingredients'] = requireSufficientIngredients;
      if (includePendingProcurement != null) payload['include_pending_procurement'] = includePendingProcurement;

      final response = await _client
          .from('pos_promotions')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      return PosPromotion.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error updatePromotion: $e');
      return null;
    }
  }

  static Future<bool> deactivatePromotion(String id) async {
    try {
      await _client
          .from('pos_promotions')
          .update({'is_active': false})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deactivatePromotion: $e');
      return false;
    }
  }

  // =============================================
  // Promotion Items
  // =============================================

  static Future<List<PosPromotionItem>> getPromotionItems(String promotionId) async {
    try {
      final response = await _client
          .from('pos_promotion_items')
          .select()
          .eq('promotion_id', promotionId);

      return (response as List)
          .map((item) => PosPromotionItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getPromotionItems: $e');
      return [];
    }
  }

  static Future<bool> addPromotionItem({
    required String promotionId,
    required String productId,
    int quantityRequired = 1,
  }) async {
    try {
      await _client
          .from('pos_promotion_items')
          .insert({
            'promotion_id': promotionId,
            'product_id': productId,
            'quantity_required': quantityRequired,
          });
      return true;
    } catch (e) {
      debugPrint('Error addPromotionItem: $e');
      return false;
    }
  }

  static Future<bool> removePromotionItem(String promotionItemId) async {
    try {
      await _client
          .from('pos_promotion_items')
          .delete()
          .eq('id', promotionItemId);
      return true;
    } catch (e) {
      debugPrint('Error removePromotionItem: $e');
      return false;
    }
  }

  static Future<bool> removePromotionItemsByPromotionId(String promotionId) async {
    try {
      await _client
          .from('pos_promotion_items')
          .delete()
          .eq('promotion_id', promotionId);
      return true;
    } catch (e) {
      debugPrint('Error removePromotionItemsByPromotionId: $e');
      return false;
    }
  }

  static Future<bool> deletePromotion(String id) async {
    try {
      await _client
          .from('pos_promotions')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deletePromotion: $e');
      return false;
    }
  }

  // =============================================
  // Phase 4: Availability & Procurement Validation
  // =============================================

  /// ตรวจสอบว่าโปรโมชั่นสามารถใช้งานได้ตามกฎ availability หรือไม่
  /// คืนค่า {isValid: true/false, reason: string, unavailableProducts: [...]}
  static Future<Map<String, dynamic>> validatePromotionAvailability(
    String promotionId, {
    List<String>? orderProductIds, // ถ้าระบุ จะเช็คเฉพาะสินค้าใน order
  }) async {
    try {
      // ดึงข้อมูลโปรโมชั่น
      final promotion = await getPromotionById(promotionId);
      if (promotion == null) {
        return {
          'isValid': false,
          'reason': 'ไม่พบโปรโมชั่น',
          'unavailableProducts': <String>[],
        };
      }

      // ถ้าไม่มีกฎ availability ไม่ต้องตรวจสอบ
      if (!promotion.requireInStock &&
          !promotion.requireSufficientIngredients &&
          !promotion.includePendingProcurement) {
        return {
          'isValid': true,
          'reason': 'ไม่มีกฎการตรวจสอบ availability',
          'unavailableProducts': <String>[],
        };
      }

      // ดึงรายการสินค้าในโปรโมชั่น
      final promotionItems = await getPromotionItems(promotionId);
      if (promotionItems.isEmpty) {
        return {
          'isValid': true,
          'reason': 'ไม่มีสินค้าในโปรโมชั่น',
          'unavailableProducts': <String>[],
        };
      }

      // กรองเฉพาะสินค้าที่ต้องการตรวจสอบ
      final checkProductIds = orderProductIds ??
          promotionItems.map((item) => item.productId).toList();

      final unavailableProducts = <Map<String, dynamic>>[];

      // ตรวจสอบแต่ละสินค้า
      for (final productId in checkProductIds) {
        final availability = await InventoryService.checkProductFullAvailability(
          productId,
          requireInStock: promotion.requireInStock,
          requireSufficientIngredients: promotion.requireSufficientIngredients,
          includePendingProcurement: promotion.includePendingProcurement,
        );

        if (availability['is_available'] != true) {
          unavailableProducts.add({
            'productId': productId,
            'reason': availability['disabled_reason'] ?? 'สินค้าไม่พร้อมขาย',
            'availability': availability,
          });
        }
      }

      final isValid = unavailableProducts.isEmpty;

      return {
        'isValid': isValid,
        'reason': isValid
            ? 'สินค้าทั้งหมดพร้อมขาย'
            : 'มี ${unavailableProducts.length} รายการไม่พร้อมขาย',
        'unavailableProducts': unavailableProducts,
        'promotionSettings': {
          'requireInStock': promotion.requireInStock,
          'requireSufficientIngredients': promotion.requireSufficientIngredients,
          'includePendingProcurement': promotion.includePendingProcurement,
        },
      };
    } catch (e) {
      debugPrint('Error validatePromotionAvailability: $e');
      return {
        'isValid': false,
        'reason': 'เกิดข้อผิดพลาด: $e',
        'unavailableProducts': <String>[],
      };
    }
  }

  /// กรองโปรโมชั่นที่สามารถใช้งานได้ (ผ่านการตรวจสอบ availability)
  static Future<List<PosPromotion>> filterAvailablePromotions(
    List<PosPromotion> promotions, {
    List<String>? orderProductIds,
  }) async {
    final availablePromotions = <PosPromotion>[];

    for (final promotion in promotions) {
      // ถ้าไม่มีกฎ availability ถือว่าใช้ได้
      if (!promotion.requireInStock &&
          !promotion.requireSufficientIngredients &&
          !promotion.includePendingProcurement) {
        availablePromotions.add(promotion);
        continue;
      }

      // ตรวจสอบ availability
      final validation = await validatePromotionAvailability(
        promotion.id,
        orderProductIds: orderProductIds,
      );

      if (validation['isValid'] == true) {
        availablePromotions.add(promotion);
      }
    }

    return availablePromotions;
  }

  /// ดึงโปรโมชั่นที่ใช้งานได้สำหรับ POS (พร้อมตรวจสอบ availability)
  static Future<List<PosPromotion>> getApplicablePromotionsForPos({
    List<String>? orderProductIds,
  }) async {
    try {
      // ดึงโปรโมชั่นที่ active
      final activePromotions = await getActivePromotions();

      // กรองตาม availability
      if (orderProductIds != null && orderProductIds.isNotEmpty) {
        return await filterAvailablePromotions(
          activePromotions,
          orderProductIds: orderProductIds,
        );
      }

      return activePromotions;
    } catch (e) {
      debugPrint('Error getApplicablePromotionsForPos: $e');
      return [];
    }
  }
}
