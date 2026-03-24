import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_shift_model.dart';

class PosShiftService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Open Shift
  // =============================================

  static Future<PosShift?> openShift({
    required String userId,
    required String userName,
    required double openingCash,
  }) async {
    try {
      // ตรวจว่ามี shift เปิดอยู่แล้วหรือไม่
      final existing = await getCurrentOpenShift();
      if (existing != null) {
        debugPrint('⚠️ Shift already open: ${existing.shiftNumber}');
        return existing;
      }

      final payload = {
        'opened_by': userId,
        'opened_by_name': userName,
        'opening_cash': openingCash,
        'status': 'open',
        'opened_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('pos_shifts')
          .insert(payload)
          .select()
          .single();

      final shift = PosShift.fromMap(Map<String, dynamic>.from(response));
      debugPrint('✅ Shift opened: ${shift.shiftNumber}');
      return shift;
    } catch (e) {
      debugPrint('❌ Error opening shift: $e');
      return null;
    }
  }

  // =============================================
  // Close Shift
  // =============================================

  static Future<PosShift?> closeShift({
    required String shiftId,
    required String userId,
    required String userName,
    required double closingCash,
    String? notes,
  }) async {
    try {
      // คำนวณสรุปจาก orders ในกะนี้
      final summary = await getShiftSummary(shiftId);

      final totalSales = (summary['total_sales'] ?? 0).toDouble();
      final totalOrders = (summary['total_orders'] ?? 0) as int;
      final totalRefunds = (summary['total_refunds'] ?? 0).toDouble();
      final totalDiscounts = (summary['total_discounts'] ?? 0).toDouble();
      final cashSales = (summary['cash_sales'] ?? 0).toDouble();

      // ดึง opening_cash ของกะนี้
      final shiftData = await _client
          .from('pos_shifts')
          .select('opening_cash')
          .eq('id', shiftId)
          .single();
      final openingCash = (shiftData['opening_cash'] ?? 0).toDouble();

      final expectedCash = openingCash + cashSales - totalRefunds;
      final cashDifference = closingCash - expectedCash;

      final payload = {
        'closed_by': userId,
        'closed_by_name': userName,
        'closing_cash': closingCash,
        'expected_cash': expectedCash,
        'cash_difference': cashDifference,
        'total_sales': totalSales,
        'total_orders': totalOrders,
        'total_refunds': totalRefunds,
        'total_discounts': totalDiscounts,
        'status': 'closed',
        'notes': notes,
        'closed_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('pos_shifts')
          .update(payload)
          .eq('id', shiftId)
          .select()
          .single();

      final shift = PosShift.fromMap(Map<String, dynamic>.from(response));
      debugPrint('✅ Shift closed: ${shift.shiftNumber}');
      return shift;
    } catch (e) {
      debugPrint('❌ Error closing shift: $e');
      return null;
    }
  }

  // =============================================
  // Get Current Open Shift
  // =============================================

  static Future<PosShift?> getCurrentOpenShift() async {
    try {
      final response = await _client
          .from('pos_shifts')
          .select()
          .eq('status', 'open')
          .order('opened_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return PosShift.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getCurrentOpenShift: $e');
      return null;
    }
  }

  // =============================================
  // Get Shift Summary (from orders in this shift)
  // =============================================

  static Future<Map<String, dynamic>> getShiftSummary(String shiftId) async {
    try {
      final orders = await _client
          .from('pos_orders')
          .select('net_total, discount_amount, payment_method, refund_amount, status')
          .eq('shift_id', shiftId);

      double totalSales = 0;
      int totalOrders = 0;
      double totalRefunds = 0;
      double totalDiscounts = 0;
      double cashSales = 0;

      for (final order in (orders as List)) {
        final status = order['status'] ?? '';
        if (status == 'voided') continue;

        final netTotal = (order['net_total'] ?? 0).toDouble();
        final discount = (order['discount_amount'] ?? 0).toDouble();
        final refund = (order['refund_amount'] ?? 0).toDouble();
        final method = order['payment_method'] ?? '';

        totalSales += netTotal;
        totalOrders++;
        totalDiscounts += discount;
        totalRefunds += refund;

        if (method == 'cash') {
          cashSales += netTotal;
        }
      }

      return {
        'total_sales': totalSales,
        'total_orders': totalOrders,
        'total_refunds': totalRefunds,
        'total_discounts': totalDiscounts,
        'cash_sales': cashSales,
      };
    } catch (e) {
      debugPrint('Error getShiftSummary: $e');
      return {
        'total_sales': 0.0,
        'total_orders': 0,
        'total_refunds': 0.0,
        'total_discounts': 0.0,
        'cash_sales': 0.0,
      };
    }
  }

  // =============================================
  // Check if shift is open (quick check)
  // =============================================

  static Future<bool> isShiftOpen() async {
    final shift = await getCurrentOpenShift();
    return shift != null;
  }

  // =============================================
  // Get Shift History
  // =============================================

  static Future<List<PosShift>> getShiftHistory({int limit = 20}) async {
    try {
      final response = await _client
          .from('pos_shifts')
          .select()
          .order('opened_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => PosShift.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getShiftHistory: $e');
      return [];
    }
  }
}
