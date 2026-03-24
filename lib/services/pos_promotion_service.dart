import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_promotion_model.dart';

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
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    try {
      final payload = {
        'name': name,
        'description': description,
        'promotion_type': promotionType,
        'discount_id': discountId,
        'start_at': startAt?.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'is_active': true,
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
    bool? isActive,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (description != null) payload['description'] = description;
      if (promotionType != null) payload['promotion_type'] = promotionType;
      if (discountId != null) payload['discount_id'] = discountId;
      if (isActive != null) payload['is_active'] = isActive;
      if (startAt != null) payload['start_at'] = startAt.toIso8601String();
      if (endAt != null) payload['end_at'] = endAt.toIso8601String();

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
}
