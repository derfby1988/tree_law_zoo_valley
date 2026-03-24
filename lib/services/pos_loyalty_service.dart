import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_loyalty_model.dart';

class PosLoyaltyService {
  static final _client = Supabase.instance.client;

  // =============================================
  // Loyalty Program Management
  // =============================================

  static Future<List<PosLoyaltyProgram>> getActiveLoyaltyPrograms() async {
    try {
      final response = await _client
          .from('pos_loyalty_programs')
          .select()
          .eq('is_active', true);

      return (response as List)
          .map((item) => PosLoyaltyProgram.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getActiveLoyaltyPrograms: $e');
      return [];
    }
  }

  static Future<PosLoyaltyProgram?> getLoyaltyProgramById(String id) async {
    try {
      final response = await _client
          .from('pos_loyalty_programs')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return PosLoyaltyProgram.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getLoyaltyProgramById: $e');
      return null;
    }
  }

  static Future<PosLoyaltyProgram?> addLoyaltyProgram({
    required String name,
    String? description,
    double pointsPerBaht = 1,
    int? pointsExpiryDays,
  }) async {
    try {
      final payload = {
        'name': name,
        'description': description,
        'points_per_baht': pointsPerBaht,
        'points_expiry_days': pointsExpiryDays,
        'is_active': true,
      };

      final response = await _client
          .from('pos_loyalty_programs')
          .insert(payload)
          .select()
          .single();

      return PosLoyaltyProgram.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error addLoyaltyProgram: $e');
      return null;
    }
  }

  // =============================================
  // Customer Loyalty Wallet
  // =============================================

  static Future<PosCustomerLoyaltyWallet?> getCustomerWallet(
    String customerId,
    String loyaltyProgramId,
  ) async {
    try {
      final response = await _client
          .from('pos_customer_loyalty_wallets')
          .select()
          .eq('customer_id', customerId)
          .eq('loyalty_program_id', loyaltyProgramId)
          .maybeSingle();

      if (response == null) return null;
      return PosCustomerLoyaltyWallet.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error getCustomerWallet: $e');
      return null;
    }
  }

  static Future<PosCustomerLoyaltyWallet?> createOrGetWallet(
    String customerId,
    String loyaltyProgramId,
  ) async {
    try {
      // Try to get existing wallet
      var wallet = await getCustomerWallet(customerId, loyaltyProgramId);
      if (wallet != null) return wallet;

      // Create new wallet
      final payload = {
        'customer_id': customerId,
        'loyalty_program_id': loyaltyProgramId,
        'total_points': 0,
        'redeemed_points': 0,
        'available_points': 0,
      };

      final response = await _client
          .from('pos_customer_loyalty_wallets')
          .insert(payload)
          .select()
          .single();

      return PosCustomerLoyaltyWallet.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error createOrGetWallet: $e');
      return null;
    }
  }

  // =============================================
  // Loyalty Transactions
  // =============================================

  static Future<List<PosLoyaltyTransaction>> getWalletTransactions(String walletId) async {
    try {
      final response = await _client
          .from('pos_loyalty_transactions')
          .select()
          .eq('wallet_id', walletId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => PosLoyaltyTransaction.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getWalletTransactions: $e');
      return [];
    }
  }

  static Future<bool> earnPoints({
    required String walletId,
    required double points,
    String? orderId,
    String? reason,
    int? expiryDays,
  }) async {
    try {
      final expiresAt = expiryDays != null
          ? DateTime.now().add(Duration(days: expiryDays))
          : null;

      // Add transaction
      await _client
          .from('pos_loyalty_transactions')
          .insert({
            'wallet_id': walletId,
            'order_id': orderId,
            'transaction_type': 'earn',
            'points': points,
            'reason': reason,
            'expires_at': expiresAt?.toIso8601String(),
          });

      // Update wallet
      final wallet = await _client
          .from('pos_customer_loyalty_wallets')
          .select()
          .eq('id', walletId)
          .single();

      final currentTotal = (wallet['total_points'] ?? 0).toDouble();
      final currentAvailable = (wallet['available_points'] ?? 0).toDouble();

      await _client
          .from('pos_customer_loyalty_wallets')
          .update({
            'total_points': currentTotal + points,
            'available_points': currentAvailable + points,
            'last_transaction_at': DateTime.now().toIso8601String(),
          })
          .eq('id', walletId);

      return true;
    } catch (e) {
      debugPrint('Error earnPoints: $e');
      return false;
    }
  }

  static Future<bool> redeemPoints({
    required String walletId,
    required double points,
    String? reason,
  }) async {
    try {
      final wallet = await _client
          .from('pos_customer_loyalty_wallets')
          .select()
          .eq('id', walletId)
          .single();

      final currentAvailable = (wallet['available_points'] ?? 0).toDouble();
      if (currentAvailable < points) {
        debugPrint('Insufficient points to redeem');
        return false;
      }

      // Add transaction
      await _client
          .from('pos_loyalty_transactions')
          .insert({
            'wallet_id': walletId,
            'transaction_type': 'redeem',
            'points': points,
            'reason': reason,
          });

      // Update wallet
      final currentRedeemed = (wallet['redeemed_points'] ?? 0).toDouble();

      await _client
          .from('pos_customer_loyalty_wallets')
          .update({
            'available_points': currentAvailable - points,
            'redeemed_points': currentRedeemed + points,
            'last_transaction_at': DateTime.now().toIso8601String(),
          })
          .eq('id', walletId);

      return true;
    } catch (e) {
      debugPrint('Error redeemPoints: $e');
      return false;
    }
  }

  static Future<bool> adjustPoints({
    required String walletId,
    required double points,
    required String reason,
  }) async {
    try {
      final wallet = await _client
          .from('pos_customer_loyalty_wallets')
          .select()
          .eq('id', walletId)
          .single();

      final currentTotal = (wallet['total_points'] ?? 0).toDouble();
      final currentAvailable = (wallet['available_points'] ?? 0).toDouble();

      // Add transaction
      await _client
          .from('pos_loyalty_transactions')
          .insert({
            'wallet_id': walletId,
            'transaction_type': 'adjust',
            'points': points,
            'reason': reason,
          });

      // Update wallet
      await _client
          .from('pos_customer_loyalty_wallets')
          .update({
            'total_points': currentTotal + points,
            'available_points': currentAvailable + points,
            'last_transaction_at': DateTime.now().toIso8601String(),
          })
          .eq('id', walletId);

      return true;
    } catch (e) {
      debugPrint('Error adjustPoints: $e');
      return false;
    }
  }
}
