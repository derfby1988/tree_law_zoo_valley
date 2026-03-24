import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_held_order_model.dart';

class PosHeldOrderService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Hold Order (พักบิล)
  // =============================================

  static Future<PosHeldOrder?> holdOrder({
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    List<Map<String, dynamic>>? appliedDiscounts,
    String orderType = 'walk_in',
    String? tableId,
    String? tableNumber,
    String? customerId,
    String? customerName,
    String? note,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final user = _client.auth.currentUser;
      final userName = user?.userMetadata?['display_name'] ??
          user?.userMetadata?['full_name'] ??
          user?.email ??
          'พนักงาน';

      // แปลง cart items → JSON-safe format
      final cartData = cartItems.map((item) {
        final product = item['product'] as Map<String, dynamic>;
        return {
          'product_id': product['id'],
          'product_name': product['name'],
          'price': product['price'],
          'qty': item['qty'],
          'unit': product['unit'] is Map
              ? {'name': (product['unit'] as Map)['name'], 'abbreviation': (product['unit'] as Map)['abbreviation']}
              : null,
          'note': item['note'],
          'image_url': product['image_url'],
          'category_id': product['category_id'],
          'tax_rate': product['tax_rate'],
          'is_tax_exempt': product['is_tax_exempt'],
        };
      }).toList();

      final payload = {
        'held_by': userId,
        'held_by_name': userName,
        'order_type': orderType,
        'table_id': tableId,
        'table_number': tableNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'cart_data': cartData,
        'subtotal': subtotal,
        'discount_data': appliedDiscounts,
        'note': note,
        'status': 'held',
        'held_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
      };

      final response = await _client
          .from('pos_held_orders')
          .insert(payload)
          .select()
          .single();

      debugPrint('✅ Order held: ${response['id']}');
      return PosHeldOrder.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('❌ Error holding order: $e');
      return null;
    }
  }

  // =============================================
  // Get Held Orders (ดึงบิลที่พักอยู่)
  // =============================================

  static Future<List<PosHeldOrder>> getHeldOrders() async {
    try {
      final response = await _client
          .from('pos_held_orders')
          .select()
          .eq('status', 'held')
          .order('held_at', ascending: false);

      return (response as List)
          .map((item) => PosHeldOrder.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getHeldOrders: $e');
      return [];
    }
  }

  static Future<int> getHeldOrderCount() async {
    try {
      final response = await _client
          .from('pos_held_orders')
          .select('id')
          .eq('status', 'held');
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getHeldOrderCount: $e');
      return 0;
    }
  }

  // =============================================
  // Resume Order (เรียกบิลกลับมา)
  // =============================================

  static Future<PosHeldOrder?> resumeOrder(String heldOrderId) async {
    try {
      final response = await _client
          .from('pos_held_orders')
          .update({
            'status': 'resumed',
            'resumed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', heldOrderId)
          .select()
          .single();

      debugPrint('✅ Order resumed: $heldOrderId');
      return PosHeldOrder.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('❌ Error resuming order: $e');
      return null;
    }
  }

  // =============================================
  // Cancel Held Order (ยกเลิกบิลที่พัก)
  // =============================================

  static Future<bool> cancelHeldOrder(String heldOrderId) async {
    try {
      await _client
          .from('pos_held_orders')
          .update({'status': 'cancelled'})
          .eq('id', heldOrderId);

      debugPrint('✅ Held order cancelled: $heldOrderId');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling held order: $e');
      return false;
    }
  }

  // =============================================
  // Hold Order for Table (พักบิลอัตโนมัติเมื่อเปลี่ยนโต๊ะ)
  // =============================================

  static Future<PosHeldOrder?> holdOrderForTable({
    required String tableId,
    required String tableNumber,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    List<Map<String, dynamic>>? appliedDiscounts,
    String? customerId,
    String? customerName,
  }) async {
    return holdOrder(
      cartItems: cartItems,
      subtotal: subtotal,
      appliedDiscounts: appliedDiscounts,
      orderType: 'dine_in',
      tableId: tableId,
      tableNumber: tableNumber,
      customerId: customerId,
      customerName: customerName,
      note: 'พักบิลโต๊ะ $tableNumber',
    );
  }

  static Future<PosHeldOrder?> getHeldOrderForTable(String tableId) async {
    try {
      final response = await _client
          .from('pos_held_orders')
          .select()
          .eq('table_id', tableId)
          .eq('status', 'held')
          .order('held_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return PosHeldOrder.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getHeldOrderForTable: $e');
      return null;
    }
  }
}
