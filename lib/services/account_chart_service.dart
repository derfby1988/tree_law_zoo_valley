import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'package:flutter/foundation.dart';

/// Service สำหรับดึงข้อมูลผังบัญชีมาตรฐาน
class AccountChartService {
  static final SupabaseClient _client = SupabaseService.client;

  static List<Map<String, dynamic>> _cache = [];
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  static Future<List<Map<String, dynamic>>> getAccounts({String? type}) async {
    if (_cache.isNotEmpty && _cacheTime != null && DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _filterByType(_cache, type);
    }

    try {
      final response = await _client
          .from('account_chart')
          .select('id, code, name_th, name_en, type, level, parent_id, is_active')
          .order('code');
      _cache = List<Map<String, dynamic>>.from(response);
      _cacheTime = DateTime.now();
      return _filterByType(_cache, type);
    } catch (e) {
      debugPrint('AccountChartService.getAccounts error: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _filterByType(List<Map<String, dynamic>> list, String? type) {
    if (type == null || type.isEmpty) return list;
    return list.where((item) => (item['type'] as String?) == type).toList();
  }

  static Future<void> clearCache() async {
    _cache = [];
    _cacheTime = null;
  }
}
