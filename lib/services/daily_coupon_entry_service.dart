import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyCouponEntryService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<bool> hasLoggedEntry(String idempotencyKey) async {
    try {
      if (idempotencyKey.trim().isEmpty) return false;

      final response = await _client
          .from('daily_coupon_entry_logs')
          .select('id')
          .contains('metadata', {'idempotency_key': idempotencyKey})
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error hasLoggedEntry: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getEntryLogs({
    required String discountId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('daily_coupon_entry_logs')
          .select()
          .eq('discount_id', discountId)
          .order('scanned_at', ascending: false)
          .limit(limit);

      var logs = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (startDate != null) {
        logs = logs.where((log) {
          final scannedAt = DateTime.tryParse(log['scanned_at']?.toString() ?? '');
          return scannedAt == null || !scannedAt.isBefore(startDate);
        }).toList();
      }
      if (endDate != null) {
        logs = logs.where((log) {
          final scannedAt = DateTime.tryParse(log['scanned_at']?.toString() ?? '');
          return scannedAt == null || !scannedAt.isAfter(endDate);
        }).toList();
      }

      return logs;
    } catch (e) {
      debugPrint('Error getEntryLogs: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getEntrySummary({
    required String discountId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _client
          .from('daily_coupon_entry_summary')
          .select()
          .eq('discount_id', discountId)
          .order('usage_day', ascending: false)
          .limit(30);
      var rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (startDate != null) {
        rows = rows.where((row) {
          final usageDay = DateTime.tryParse(row['usage_day']?.toString() ?? '');
          return usageDay == null || !usageDay.isBefore(startDate);
        }).toList();
      }
      if (endDate != null) {
        rows = rows.where((row) {
          final usageDay = DateTime.tryParse(row['usage_day']?.toString() ?? '');
          return usageDay == null || !usageDay.isAfter(endDate);
        }).toList();
      }

      final totalEntries = rows.fold<int>(0, (sum, row) => sum + (row['total_entries'] as int? ?? 0));
      final totalExits = rows.fold<int>(0, (sum, row) => sum + (row['total_exits'] as int? ?? 0));
      final totalDenied = rows.fold<int>(0, (sum, row) => sum + (row['total_denied'] as int? ?? 0));

      return {
        'rows': rows,
        'total_entries': totalEntries,
        'total_exits': totalExits,
        'total_denied': totalDenied,
      };
    } catch (e) {
      debugPrint('Error getEntrySummary: $e');
      return {'rows': [], 'total_entries': 0, 'total_exits': 0, 'total_denied': 0};
    }
  }

  static Future<bool> logEntry({
    required String discountId,
    String? couponCode,
    String? couponAudience,
    String? memberIdentifier,
    required String entryArea,
    String? gateId,
    String direction = 'enter',
    String status = 'pending',
    String? reasonCode,
    String? scannedBy,
    Map<String, dynamic>? deviceInfo,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    try {
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        final alreadyLogged = await hasLoggedEntry(idempotencyKey);
        if (alreadyLogged) {
          return true;
        }
      }

      final mergedMetadata = <String, dynamic>{
        if (metadata != null) ...metadata,
        if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'idempotency_key': idempotencyKey,
      };

      final payload = {
        'discount_id': discountId,
        'coupon_code': couponCode,
        'coupon_audience': couponAudience,
        'member_identifier': memberIdentifier,
        'entry_area': entryArea,
        'gate_id': gateId,
        'direction': direction,
        'status': status,
        'reason_code': reasonCode,
        'scanned_by': scannedBy,
        'device_info': deviceInfo,
        'metadata': mergedMetadata.isEmpty ? null : mergedMetadata,
      }..removeWhere((key, value) => value == null);

      await _client.from('daily_coupon_entry_logs').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Error logEntry: $e');
      return false;
    }
  }
}
