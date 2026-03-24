import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_payment_split_model.dart';

class PosPaymentSplitService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Save Payment Splits
  // =============================================

  static Future<List<PosPaymentSplit>?> savePaymentSplits({
    required String orderId,
    required List<Map<String, dynamic>> splits,
  }) async {
    try {
      if (splits.isEmpty) return null;

      final payload = splits.map((split) {
        return {
          'order_id': orderId,
          'payment_method': split['payment_method'],
          'amount': (split['amount'] ?? 0).toDouble(),
          'reference_number': split['reference_number'],
          'note': split['note'],
          'paid_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      final response = await _client
          .from('pos_payment_splits')
          .insert(payload)
          .select();

      debugPrint('✅ Payment splits saved: ${splits.length} methods');
      return (response as List)
          .map((item) => PosPaymentSplit.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error saving payment splits: $e');
      return null;
    }
  }

  // =============================================
  // Get Payment Splits for Order
  // =============================================

  static Future<List<PosPaymentSplit>> getPaymentSplitsForOrder(String orderId) async {
    try {
      final response = await _client
          .from('pos_payment_splits')
          .select()
          .eq('order_id', orderId)
          .order('paid_at', ascending: true);

      return (response as List)
          .map((item) => PosPaymentSplit.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getPaymentSplitsForOrder: $e');
      return [];
    }
  }

  // =============================================
  // Validate Split Payment
  // =============================================

  static bool validateSplits(List<Map<String, dynamic>> splits, double totalAmount) {
    if (splits.isEmpty) return false;

    double totalPaid = 0;
    for (final split in splits) {
      final amount = (split['amount'] ?? 0).toDouble();
      if (amount <= 0) return false;
      totalPaid += amount;
    }

    // ยอมรับความแตกต่างน้อยกว่า 0.01 บาท (rounding error)
    return (totalPaid - totalAmount).abs() < 0.01;
  }

  // =============================================
  // Calculate Payment Summary
  // =============================================

  static Map<String, dynamic> summarizeSplits(List<Map<String, dynamic>> splits) {
    final summary = <String, double>{};
    double totalAmount = 0;

    for (final split in splits) {
      final method = split['payment_method'] as String;
      final amount = (split['amount'] ?? 0).toDouble();
      summary[method] = (summary[method] ?? 0) + amount;
      totalAmount += amount;
    }

    return {
      'by_method': summary,
      'total': totalAmount,
      'count': splits.length,
    };
  }
}
