import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_daily_settlement_model.dart';
import '../models/pos_shift_model.dart';
import 'pos_shift_service.dart';

class PosEodService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Calculate Daily Summary
  // =============================================

  static Future<Map<String, dynamic>> calculateDailySummary(DateTime date) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final shifts = await _client
          .from('pos_shifts')
          .select()
          .eq('status', 'closed')
          .gte('closed_at', dayStart.toIso8601String())
          .lt('closed_at', dayEnd.toIso8601String())
          .order('opened_at', ascending: true);

      if ((shifts as List).isEmpty) {
        return _emptySummary();
      }

      final shiftIds = <String>[];
      double totalSales = 0;
      double totalCash = 0;
      double totalCashless = 0;
      double totalRefunds = 0;
      double totalVoids = 0;
      double totalDiscounts = 0;
      double totalLoyaltyRedeemed = 0;
      double totalTax = 0;
      double totalServiceCharge = 0;
      double totalOpeningCash = 0;

      for (final s in shifts) {
        final shift = PosShift.fromMap(Map<String, dynamic>.from(s));
        shiftIds.add(shift.id);
        totalSales += shift.totalSales;
        totalDiscounts += shift.totalDiscounts;
        totalRefunds += shift.totalRefunds;
        totalOpeningCash += shift.openingCash;

        final summary = await PosShiftService.getShiftSummary(shift.id);
        totalCash += (summary['cash_sales'] ?? 0).toDouble();
        totalCashless += totalSales - totalCash;

        final orders = await _client
            .from('pos_orders')
            .select('tax_amount, service_charge_amount, loyalty_discount_amount, status')
            .eq('shift_id', shift.id);

        for (final o in (orders as List)) {
          totalTax += (o['tax_amount'] ?? 0).toDouble();
          totalServiceCharge += (o['service_charge_amount'] ?? 0).toDouble();
          totalLoyaltyRedeemed += (o['loyalty_discount_amount'] ?? 0).toDouble();
          if (o['status'] == 'voided') {
            totalVoids += (o['net_total'] ?? 0).toDouble();
          }
        }
      }

      final expectedCash = totalOpeningCash + totalCash - totalRefunds;

      return {
        'settlement_date': dayStart.toIso8601String().split('T')[0],
        'shift_ids': shiftIds,
        'shift_count': shiftIds.length,
        'total_sales': totalSales,
        'total_cash': totalCash,
        'total_cashless': totalCashless,
        'total_refunds': totalRefunds,
        'total_voids': totalVoids,
        'total_discounts': totalDiscounts,
        'total_loyalty_redeemed': totalLoyaltyRedeemed,
        'total_tax': totalTax,
        'total_service_charge': totalServiceCharge,
        'expected_cash': expectedCash,
      };
    } catch (e) {
      debugPrint('Error calculateDailySummary: $e');
      return _emptySummary();
    }
  }

  static Map<String, dynamic> _emptySummary() {
    return {
      'total_sales': 0.0,
      'total_cash': 0.0,
      'total_cashless': 0.0,
      'total_refunds': 0.0,
      'total_voids': 0.0,
      'total_discounts': 0.0,
      'total_loyalty_redeemed': 0.0,
      'total_tax': 0.0,
      'total_service_charge': 0.0,
      'expected_cash': 0.0,
      'shift_ids': <String>[],
      'shift_count': 0,
    };
  }

  // =============================================
  // Create Draft Settlement
  // =============================================

  static Future<PosDailySettlement?> createSettlement({
    required DateTime date,
    String? storeId,
  }) async {
    try {
      final existing = await getSettlementByDate(date);
      if (existing != null) {
        debugPrint('⚠️ Settlement already exists for ${date.toIso8601String().split('T')[0]}');
        return existing;
      }

      final summary = await calculateDailySummary(date);

      final payload = {
        'settlement_date': date.toIso8601String().split('T')[0],
        'store_id': storeId,
        'total_sales': summary['total_sales'],
        'total_cash': summary['total_cash'],
        'total_cashless': summary['total_cashless'],
        'total_refunds': summary['total_refunds'],
        'total_voids': summary['total_voids'],
        'total_discounts': summary['total_discounts'],
        'total_loyalty_redeemed': summary['total_loyalty_redeemed'],
        'total_tax': summary['total_tax'],
        'total_service_charge': summary['total_service_charge'],
        'expected_cash': summary['expected_cash'],
        'shift_ids': summary['shift_ids'],
        'status': 'draft',
      };

      final response = await _client
          .from('pos_daily_settlements')
          .insert(payload)
          .select()
          .single();

      debugPrint('✅ Settlement draft created for ${payload['settlement_date']}');
      return PosDailySettlement.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('❌ Error createSettlement: $e');
      return null;
    }
  }

  // =============================================
  // Close Settlement
  // =============================================

  static Future<PosDailySettlement?> closeSettlement({
    required String settlementId,
    required double countedCash,
    required String userId,
    required String userName,
    String? note,
  }) async {
    try {
      final existing = await _client
          .from('pos_daily_settlements')
          .select()
          .eq('id', settlementId)
          .single();

      final expectedCash = (existing['expected_cash'] ?? 0).toDouble();
      final cashDifference = countedCash - expectedCash;

      final payload = {
        'counted_cash': countedCash,
        'cash_difference': cashDifference,
        'status': 'closed',
        'closed_by': userId,
        'closed_by_name': userName,
        'closed_at': DateTime.now().toIso8601String(),
        'note': note,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('pos_daily_settlements')
          .update(payload)
          .eq('id', settlementId)
          .select()
          .single();

      debugPrint('✅ Settlement closed: ${existing['settlement_date']}');
      return PosDailySettlement.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('❌ Error closeSettlement: $e');
      return null;
    }
  }

  // =============================================
  // Reopen Settlement (admin only)
  // =============================================

  static Future<PosDailySettlement?> reopenSettlement({
    required String settlementId,
    required String userId,
    required String userName,
    String? note,
  }) async {
    try {
      final payload = {
        'status': 'reopened',
        'note': note,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('pos_daily_settlements')
          .update(payload)
          .eq('id', settlementId)
          .select()
          .single();

      debugPrint('⚠️ Settlement reopened: $settlementId by $userName');
      return PosDailySettlement.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('❌ Error reopenSettlement: $e');
      return null;
    }
  }

  // =============================================
  // Get Settlement by Date
  // =============================================

  static Future<PosDailySettlement?> getSettlementByDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await _client
          .from('pos_daily_settlements')
          .select()
          .eq('settlement_date', dateStr)
          .maybeSingle();

      if (response == null) return null;
      return PosDailySettlement.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getSettlementByDate: $e');
      return null;
    }
  }

  // =============================================
  // Get Settlement History
  // =============================================

  static Future<List<PosDailySettlement>> getSettlementHistory({int limit = 30}) async {
    try {
      final response = await _client
          .from('pos_daily_settlements')
          .select()
          .order('settlement_date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => PosDailySettlement.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getSettlementHistory: $e');
      return [];
    }
  }

  // =============================================
  // Validation: Check if all shifts are closed
  // =============================================

  static Future<Map<String, dynamic>> validateBeforeClose(DateTime date) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final openShifts = await _client
          .from('pos_shifts')
          .select('id, shift_number, opened_by_name')
          .eq('status', 'open')
          .gte('opened_at', dayStart.toIso8601String())
          .lt('opened_at', dayEnd.toIso8601String());

      final pendingOrders = await _client
          .from('pos_orders')
          .select('id, order_number')
          .inFilter('status', ['pending', 'held'])
          .gte('created_at', dayStart.toIso8601String())
          .lt('created_at', dayEnd.toIso8601String());

      final openShiftList = (openShifts as List);
      final pendingOrderList = (pendingOrders as List);

      return {
        'can_close': openShiftList.isEmpty && pendingOrderList.isEmpty,
        'open_shifts': openShiftList,
        'pending_orders': pendingOrderList,
        'errors': [
          if (openShiftList.isNotEmpty) 'มี ${openShiftList.length} กะที่ยังไม่ได้ปิด',
          if (pendingOrderList.isNotEmpty) 'มี ${pendingOrderList.length} บิลที่ยังค้างอยู่',
        ],
      };
    } catch (e) {
      debugPrint('Error validateBeforeClose: $e');
      return {'can_close': false, 'errors': ['ไม่สามารถตรวจสอบสถานะได้: $e']};
    }
  }
}
