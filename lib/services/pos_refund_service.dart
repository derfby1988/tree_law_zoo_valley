import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_refund_model.dart';

class PosRefundService {
  static final _client = Supabase.instance.client;

  /// สร้าง Void (ยกเลิกบิลทั้งหมด)
  static Future<PosRefund?> voidOrder({
    required String orderId,
    required double orderTotal,
    required String reason,
    required String userId,
    required String userName,
    String? approvedByUserId,
    String? approvedByName,
  }) async {
    try {
      final refundData = {
        'order_id': orderId,
        'refund_type': 'void',
        'refund_amount': orderTotal,
        'refund_method': null,
        'reason': reason,
        'approved_by': approvedByUserId ?? userId,
        'approved_by_name': approvedByName ?? userName,
        'refunded_by': userId,
        'refunded_by_name': userName,
        'status': 'completed',
        'refunded_at': DateTime.now().toIso8601String(),
      };

      final result = await _client
          .from('pos_refunds')
          .insert(refundData)
          .select()
          .single();

      // อัปเดตสถานะบิลเป็น voided
      await _client.from('pos_orders').update({
        'status': 'voided',
        'refund_amount': orderTotal,
        'refund_status': 'voided',
      }).eq('id', orderId);

      // บันทึก status log
      await _logStatusChange(
        orderId: orderId,
        fromStatus: 'completed',
        toStatus: 'voided',
        userId: userId,
        userName: userName,
        reason: reason,
      );

      // คืน stock
      await _returnStock(orderId);

      return PosRefund.fromMap(result);
    } catch (e) {
      debugPrint('Error voidOrder: $e');
      return null;
    }
  }

  /// สร้าง Refund ทั้งบิล
  static Future<PosRefund?> refundFullOrder({
    required String orderId,
    required double orderTotal,
    required String refundMethod,
    required String reason,
    required String userId,
    required String userName,
    String? approvedByUserId,
    String? approvedByName,
  }) async {
    try {
      final refundData = {
        'order_id': orderId,
        'refund_type': 'full',
        'refund_amount': orderTotal,
        'refund_method': refundMethod,
        'reason': reason,
        'approved_by': approvedByUserId ?? userId,
        'approved_by_name': approvedByName ?? userName,
        'refunded_by': userId,
        'refunded_by_name': userName,
        'status': 'completed',
        'refunded_at': DateTime.now().toIso8601String(),
      };

      final result = await _client
          .from('pos_refunds')
          .insert(refundData)
          .select()
          .single();

      // อัปเดตสถานะบิลเป็น refunded
      await _client.from('pos_orders').update({
        'status': 'refunded',
        'refund_amount': orderTotal,
        'refund_status': 'refunded',
      }).eq('id', orderId);

      // บันทึก status log
      await _logStatusChange(
        orderId: orderId,
        fromStatus: 'completed',
        toStatus: 'refunded',
        userId: userId,
        userName: userName,
        reason: reason,
      );

      // คืน stock
      await _returnStock(orderId);

      return PosRefund.fromMap(result);
    } catch (e) {
      debugPrint('Error refundFullOrder: $e');
      return null;
    }
  }

  /// สร้าง Refund บางรายการ
  static Future<PosRefund?> refundPartialOrder({
    required String orderId,
    required List<Map<String, dynamic>> refundLines,
    required String refundMethod,
    required String reason,
    required String userId,
    required String userName,
    String? approvedByUserId,
    String? approvedByName,
  }) async {
    try {
      double totalRefundAmount = 0;
      for (final line in refundLines) {
        totalRefundAmount += (line['refund_amount'] as double);
      }

      final refundData = {
        'order_id': orderId,
        'refund_type': 'partial',
        'refund_amount': totalRefundAmount,
        'refund_method': refundMethod,
        'reason': reason,
        'approved_by': approvedByUserId ?? userId,
        'approved_by_name': approvedByName ?? userName,
        'refunded_by': userId,
        'refunded_by_name': userName,
        'status': 'completed',
        'refunded_at': DateTime.now().toIso8601String(),
      };

      final result = await _client
          .from('pos_refunds')
          .insert(refundData)
          .select()
          .single();

      final refundId = result['id'] as String;

      // สร้าง refund items
      final refundItems = refundLines.map((line) => {
        'refund_id': refundId,
        'order_line_id': line['order_line_id'],
        'quantity': line['quantity'],
        'refund_amount': line['refund_amount'],
      }).toList();

      await _client.from('pos_refund_items').insert(refundItems);

      // อัปเดต refund_amount ของบิล
      final existingOrder = await _client
          .from('pos_orders')
          .select('refund_amount')
          .eq('id', orderId)
          .single();

      final existingRefund = (existingOrder['refund_amount'] ?? 0).toDouble();
      await _client.from('pos_orders').update({
        'refund_amount': existingRefund + totalRefundAmount,
        'refund_status': 'partial_refund',
      }).eq('id', orderId);

      // บันทึก status log
      await _logStatusChange(
        orderId: orderId,
        fromStatus: 'completed',
        toStatus: 'partial_refund',
        userId: userId,
        userName: userName,
        reason: reason,
      );

      // คืน stock เฉพาะรายการที่ refund
      await _returnPartialStock(refundLines);

      return PosRefund.fromMap(result);
    } catch (e) {
      debugPrint('Error refundPartialOrder: $e');
      return null;
    }
  }

  /// ดึงประวัติ refund ของ order
  static Future<List<PosRefund>> getRefundsByOrderId(String orderId) async {
    try {
      final result = await _client
          .from('pos_refunds')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);
      return (result as List).map((e) => PosRefund.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error getRefundsByOrderId: $e');
      return [];
    }
  }

  // =============================================
  // Private helpers
  // =============================================

  static Future<void> _logStatusChange({
    required String orderId,
    required String fromStatus,
    required String toStatus,
    required String userId,
    required String userName,
    String? reason,
  }) async {
    try {
      await _client.from('pos_order_status_log').insert({
        'order_id': orderId,
        'from_status': fromStatus,
        'to_status': toStatus,
        'changed_by': userId,
        'changed_by_name': userName,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('Error _logStatusChange: $e');
    }
  }

  /// คืน stock ทั้งบิล
  static Future<void> _returnStock(String orderId) async {
    try {
      final lines = await _client
          .from('pos_order_lines')
          .select('product_id, qty')
          .eq('order_id', orderId);

      for (final line in (lines as List)) {
        final productId = line['product_id'];
        final qty = (line['qty'] ?? 0).toDouble();
        if (productId == null || qty <= 0) continue;

        // ดึง stock ปัจจุบัน
        final product = await _client
            .from('products')
            .select('stock_quantity')
            .eq('id', productId)
            .maybeSingle();

        if (product != null) {
          final currentStock = (product['stock_quantity'] ?? 0).toDouble();
          await _client.from('products').update({
            'stock_quantity': currentStock + qty,
          }).eq('id', productId);
        }
      }
    } catch (e) {
      debugPrint('Error _returnStock: $e');
    }
  }

  /// คืน stock เฉพาะบางรายการ
  static Future<void> _returnPartialStock(List<Map<String, dynamic>> refundLines) async {
    try {
      for (final line in refundLines) {
        final orderLineId = line['order_line_id'];
        final qty = (line['quantity'] ?? 0).toDouble();
        if (orderLineId == null || qty <= 0) continue;

        // ดึง product_id จาก order line
        final orderLine = await _client
            .from('pos_order_lines')
            .select('product_id')
            .eq('id', orderLineId)
            .maybeSingle();

        if (orderLine == null) continue;
        final productId = orderLine['product_id'];
        if (productId == null) continue;

        final product = await _client
            .from('products')
            .select('stock_quantity')
            .eq('id', productId)
            .maybeSingle();

        if (product != null) {
          final currentStock = (product['stock_quantity'] ?? 0).toDouble();
          await _client.from('products').update({
            'stock_quantity': currentStock + qty,
          }).eq('id', productId);
        }
      }
    } catch (e) {
      debugPrint('Error _returnPartialStock: $e');
    }
  }
}
