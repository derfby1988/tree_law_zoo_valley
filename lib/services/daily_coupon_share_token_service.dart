import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_coupon_share_token_model.dart';
import '../models/pos_discount_model.dart';

class DailyCouponShareTokenService {
  static final SupabaseClient _client = Supabase.instance.client;

  static DailyCouponShareToken? _decodeTokenResponse(dynamic response) {
    if (response == null) return null;
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      if ((map['id']?.toString() ?? '').isEmpty && (map['share_token']?.toString() ?? '').isEmpty) {
        return null;
      }
      return DailyCouponShareToken.fromMap(map);
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      final map = Map<String, dynamic>.from(response.first as Map);
      if ((map['id']?.toString() ?? '').isEmpty && (map['share_token']?.toString() ?? '').isEmpty) {
        return null;
      }
      return DailyCouponShareToken.fromMap(map);
    }
    return null;
  }

  static Map<String, dynamic> _targetingRule(PosDiscount coupon) {
    return coupon.targetingRule;
  }

  static bool isGroupShareable(PosDiscount coupon) {
    final rule = _targetingRule(coupon);
    return rule['daily_unified_enabled'] == true && (rule['coupon_audience'] ?? 'individual').toString() == 'group';
  }

  static int? _groupSize(PosDiscount coupon) {
    final rule = _targetingRule(coupon);
    final value = rule['group_size'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime _resolveExpiry(PosDiscount coupon) {
    final rule = _targetingRule(coupon);
    final now = DateTime.now();
    if (coupon.endAt != null) {
      return coupon.endAt!;
    }

    if (rule['reset_at_local_midnight'] == true) {
      return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    }

    return now.add(const Duration(days: 1));
  }

  static String buildShareClipboardText(
    DailyCouponShareToken token, {
    PosDiscount? coupon,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('คูปองรายวัน${coupon != null ? ' • ${coupon.name}' : ''}');
    buffer.writeln('รหัสแชร์: ${token.shareToken}');
    buffer.writeln('โควตา: ${token.usesCount}/${token.maxUses}');
    buffer.writeln('สมาชิกต่อกลุ่ม: ${token.groupSize} คน');
    buffer.writeln('หมดอายุ: ${_formatDate(token.expiresAt)}');
    return buffer.toString().trim();
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static Future<DailyCouponShareToken?> getActiveShareToken(String discountId) async {
    try {
      final response = await _client.rpc(
        'get_active_daily_coupon_share_token',
        params: {'p_discount_id': discountId},
      );
      return _decodeTokenResponse(response);
    } catch (e) {
      debugPrint('Error getActiveShareToken: $e');
      return null;
    }
  }

  static Future<DailyCouponShareToken?> createOrRefreshShareToken({
    required PosDiscount coupon,
    String? createdBy,
    bool forceNew = false,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!isGroupShareable(coupon)) {
      return null;
    }

    final groupSize = _groupSize(coupon);
    if (groupSize == null || groupSize < 2) {
      return null;
    }

    final rule = _targetingRule(coupon);
    final expiresAt = _resolveExpiry(coupon);
    final payload = {
      'p_discount_id': coupon.id,
      'p_coupon_code': coupon.couponCode ?? coupon.id,
      'p_coupon_audience': rule['coupon_audience']?.toString() ?? 'group',
      'p_group_size': groupSize,
      'p_expires_at': expiresAt.toIso8601String(),
      'p_created_by': createdBy ?? _client.auth.currentUser?.id,
      'p_metadata': {
        'source': 'share_button',
        'daily_unified_enabled': true,
        ...metadata,
      },
      'p_force_new': forceNew,
    };

    try {
      final response = await _client.rpc(
        'create_or_refresh_daily_coupon_share_token',
        params: payload,
      );
      return _decodeTokenResponse(response);
    } catch (e) {
      debugPrint('Error createOrRefreshShareToken: $e');
      return null;
    }
  }

  static Future<DailyCouponShareToken?> consumeShareToken({
    required String shareToken,
    String? memberIdentifier,
    String? channel,
    String? scannedBy,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final response = await _client.rpc(
        'consume_daily_coupon_share_token',
        params: {
          'p_share_token': shareToken,
          'p_member_identifier': memberIdentifier,
          'p_channel': channel,
          'p_metadata': {
            'scanned_by': scannedBy,
            ...metadata,
          },
        },
      );
      return _decodeTokenResponse(response);
    } catch (e) {
      debugPrint('Error consumeShareToken: $e');
      return null;
    }
  }
}
