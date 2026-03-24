import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PosCustomerService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Customer Management
  // =============================================

  static Future<List<Map<String, dynamic>>> getAllCustomers() async {
    try {
      final response = await _client
          .from('pos_customers')
          .select()
          .eq('is_active', true)
          .order('display_name', ascending: true);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error getAllCustomers: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    try {
      final response = await _client
          .from('pos_customers')
          .select()
          .eq('is_active', true)
          .or('display_name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
          .order('display_name', ascending: true);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error searchCustomers: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCustomerById(String id) async {
    try {
      final response = await _client
          .from('pos_customers')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error getCustomerById: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCustomerByUserId(String userId) async {
    try {
      final response = await _client
          .from('pos_customers')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error getCustomerByUserId: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> addCustomer({
    required String displayName,
    String? phone,
    String? email,
    String? notes,
    String? userId,
    String customerType = 'walk_in',
  }) async {
    try {
      final payload = {
        'display_name': displayName,
        'phone': phone,
        'email': email,
        'notes': notes,
        'user_id': userId,
        'customer_type': customerType,
        'is_active': true,
      };

      final response = await _client
          .from('pos_customers')
          .insert(payload)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error addCustomer: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateCustomer({
    required String id,
    String? displayName,
    String? phone,
    String? email,
    String? notes,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (displayName != null) payload['display_name'] = displayName;
      if (phone != null) payload['phone'] = phone;
      if (email != null) payload['email'] = email;
      if (notes != null) payload['notes'] = notes;
      if (isActive != null) payload['is_active'] = isActive;

      final response = await _client
          .from('pos_customers')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error updateCustomer: $e');
      return null;
    }
  }

  static Future<bool> deactivateCustomer(String id) async {
    try {
      await _client
          .from('pos_customers')
          .update({'is_active': false})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deactivateCustomer: $e');
      return false;
    }
  }

  // =============================================
  // Customer Purchase History
  // =============================================

  static Future<List<Map<String, dynamic>>> getCustomerOrders(String customerId) async {
    try {
      final response = await _client
          .from('pos_orders')
          .select('*, pos_order_lines(*)')
          .eq('customer_user_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error getCustomerOrders: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCustomerStats(String customerId) async {
    try {
      final orders = await getCustomerOrders(customerId);

      if (orders.isEmpty) {
        return {
          'total_orders': 0,
          'total_spent': 0.0,
          'average_order_value': 0.0,
          'last_order_date': null,
        };
      }

      double totalSpent = 0;
      DateTime? lastOrderDate;

      for (var order in orders) {
        totalSpent += (order['net_total'] ?? 0).toDouble();
        final createdAt = order['created_at'];
        if (createdAt != null) {
          final orderDate = DateTime.parse(createdAt);
          if (lastOrderDate == null || orderDate.isAfter(lastOrderDate)) {
            lastOrderDate = orderDate;
          }
        }
      }

      return {
        'total_orders': orders.length,
        'total_spent': totalSpent,
        'average_order_value': totalSpent / orders.length,
        'last_order_date': lastOrderDate?.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getCustomerStats: $e');
      return null;
    }
  }

  // =============================================
  // Get Customers from User Groups (for HRM integration)
  // =============================================

  static Future<List<Map<String, dynamic>>> getCustomerGroupUsers() async {
    try {
      // Get users from groups marked as customer groups
      final response = await _client
          .from('users')
          .select('*, user_groups(*)')
          .order('display_name', ascending: true);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error getCustomerGroupUsers: $e');
      return [];
    }
  }
}
