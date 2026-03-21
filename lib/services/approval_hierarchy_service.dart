import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class ApprovalHierarchyService {
  static final SupabaseClient _client = SupabaseService.client;

  static const Map<String, double> _defaultLimitsByRole = {
    'store_manager': 5000,
    'manager': 50000,
    'admin': double.infinity,
  };

  static Future<List<Map<String, dynamic>>> getRules() async {
    final response = await _client
        .from('approval_hierarchy_rules')
        .select('''
          *,
          group:user_groups(id, group_name, sort_order, color, is_active)
        ''')
        .order('priority', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> seedDefaultRulesIfNeeded(List<Map<String, dynamic>> groups) async {
    final existing = await _client
        .from('approval_hierarchy_rules')
        .select('id')
        .limit(1);

    if (existing.isNotEmpty) return;

    for (final group in groups) {
      final groupId = group['id']?.toString();
      final roleKey = _normalizeRole(group['group_name']?.toString() ?? '');
      if (groupId == null || roleKey == null) continue;

      final defaultLimit = _defaultLimitsByRole[roleKey]!;
      await _client.from('approval_hierarchy_rules').upsert({
        'group_id': groupId,
        'max_amount': defaultLimit.isInfinite ? null : defaultLimit,
        'is_unlimited': defaultLimit.isInfinite,
        'priority': _defaultPriority(roleKey),
        'is_active': true,
      }, onConflict: 'group_id');
    }
  }

  static Future<void> upsertRule({
    required String groupId,
    required bool isUnlimited,
    required double? maxAmount,
    required int priority,
    required bool isActive,
  }) async {
    await _client.from('approval_hierarchy_rules').upsert({
      'group_id': groupId,
      'is_unlimited': isUnlimited,
      'max_amount': isUnlimited ? null : maxAmount,
      'priority': priority,
      'is_active': isActive,
    }, onConflict: 'group_id');
  }

  static int _defaultPriority(String roleKey) {
    switch (roleKey) {
      case 'store_manager':
        return 1;
      case 'manager':
        return 2;
      case 'admin':
        return 3;
      default:
        return 99;
    }
  }

  static String? _normalizeRole(String raw) {
    final value = raw.trim().toLowerCase();

    if (value == 'store_manager' ||
        value.contains('หัวหน้าร้าน') ||
        value.contains('store manager')) {
      return 'store_manager';
    }
    if (value == 'manager' || value.contains('ผู้จัดการ')) {
      return 'manager';
    }
    if (value == 'admin' || value.contains('ผู้บริหาร') || value.contains('แอดมิน')) {
      return 'admin';
    }

    return null;
  }
}
