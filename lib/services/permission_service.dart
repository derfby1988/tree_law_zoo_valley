import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// PermissionService - ตรวจสอบสิทธิ์การเข้าถึงหน้า, Tab, และปุ่ม
/// 
/// ใช้งาน:
/// ```dart
/// // ตรวจสอบสิทธิ์หน้า
/// final canAccessInventory = await PermissionService.canAccessPage('inventory');
/// 
/// // ตรวจสอบสิทธิ์ Tab
/// final canAccessProducts = await PermissionService.canAccessTab('inventory_products');
/// 
/// // ตรวจสอบสิทธิ์ปุ่ม
/// final canAddProduct = await PermissionService.canAccessAction('inventory_products_add');
/// ```
class PermissionService {
  // Cache สิทธิ์เพื่อไม่ต้อง query ทุกครั้ง
  static Set<String> _cachedPagePermissions = {};
  static Set<String> _cachedTabPermissions = {};
  static Set<String> _cachedActionPermissions = {};
  static String? _cachedUserId;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// โหลดสิทธิ์ทั้งหมดของ user ปัจจุบัน (ผ่านกลุ่มที่สังกัด)
  static Future<void> loadPermissions({bool forceRefresh = false}) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _clearCache();
      return;
    }

    // ใช้ cache ถ้ายังไม่หมดอายุ
    if (!forceRefresh &&
        _cachedUserId == currentUser.id &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return;
    }

    try {
      // หากลุ่มที่ user สังกัด
      final memberResponse = await SupabaseService.client
          .from('user_group_members')
          .select('group_id')
          .eq('user_id', currentUser.id);

      final groupIds = List<Map<String, dynamic>>.from(memberResponse)
          .map((m) => m['group_id'] as String)
          .toList();

      if (groupIds.isEmpty) {
        _clearCache();
        _cachedUserId = currentUser.id;
        _cacheTime = DateTime.now();
        return;
      }

      // โหลดสิทธิ์หน้า
      final pageResponse = await SupabaseService.client
          .from('group_page_permissions')
          .select('page_id')
          .inFilter('group_id', groupIds)
          .eq('can_access', true);
      _cachedPagePermissions = List<Map<String, dynamic>>.from(pageResponse)
          .map((p) => p['page_id'] as String)
          .toSet();

      // โหลดสิทธิ์ Tab
      try {
        final tabResponse = await SupabaseService.client
            .from('group_tab_permissions')
            .select('tab_id')
            .inFilter('group_id', groupIds)
            .eq('can_access', true);
        _cachedTabPermissions = List<Map<String, dynamic>>.from(tabResponse)
            .map((p) => p['tab_id'] as String)
            .toSet();
      } catch (_) {
        _cachedTabPermissions = {};
      }

      // โหลดสิทธิ์ Action/ปุ่ม
      try {
        final actionResponse = await SupabaseService.client
            .from('group_action_permissions')
            .select('action_id')
            .inFilter('group_id', groupIds)
            .eq('can_access', true);
        _cachedActionPermissions = List<Map<String, dynamic>>.from(actionResponse)
            .map((p) => p['action_id'] as String)
            .toSet();
      } catch (_) {
        _cachedActionPermissions = {};
      }

      _cachedUserId = currentUser.id;
      _cacheTime = DateTime.now();
    } catch (e) {
      print('❌ PermissionService.loadPermissions error: $e');
    }
  }

  /// ตรวจสอบสิทธิ์การเข้าถึงหน้า
  static Future<bool> canAccessPage(String pageId) async {
    await loadPermissions();
    // ถ้าไม่มี permission data เลย ให้เข้าถึงได้ทั้งหมด (กรณียังไม่ได้ตั้งค่า)
    if (_cachedPagePermissions.isEmpty && _cachedTabPermissions.isEmpty && _cachedActionPermissions.isEmpty) {
      return true;
    }
    return _cachedPagePermissions.contains(pageId);
  }

  /// ตรวจสอบสิทธิ์การเข้าถึง Tab
  static Future<bool> canAccessTab(String tabId) async {
    await loadPermissions();
    if (_cachedTabPermissions.isEmpty) return true;
    return _cachedTabPermissions.contains(tabId);
  }

  /// ตรวจสอบสิทธิ์การใช้งานปุ่ม/Action
  static Future<bool> canAccessAction(String actionId) async {
    await loadPermissions();
    if (_cachedActionPermissions.isEmpty) return true;
    return _cachedActionPermissions.contains(actionId);
  }

  /// ตรวจสอบสิทธิ์แบบ sync (ใช้ cache ที่โหลดไว้แล้ว)
  static bool canAccessPageSync(String pageId) {
    if (_cachedPagePermissions.isEmpty && _cachedTabPermissions.isEmpty && _cachedActionPermissions.isEmpty) {
      return true;
    }
    return _cachedPagePermissions.contains(pageId);
  }

  static bool canAccessTabSync(String tabId) {
    if (_cachedTabPermissions.isEmpty) return true;
    return _cachedTabPermissions.contains(tabId);
  }

  static bool canAccessActionSync(String actionId) {
    if (_cachedActionPermissions.isEmpty) return true;
    return _cachedActionPermissions.contains(actionId);
  }

  /// ล้าง cache (เรียกเมื่อ logout หรือเปลี่ยน user)
  static void clearCache() {
    _clearCache();
  }

  static void _clearCache() {
    _cachedPagePermissions = {};
    _cachedTabPermissions = {};
    _cachedActionPermissions = {};
    _cachedUserId = null;
    _cacheTime = null;
  }

  /// รีเฟรชสิทธิ์ (เรียกหลังจากแก้ไขสิทธิ์)
  static Future<void> refreshPermissions() async {
    await loadPermissions(forceRefresh: true);
  }
}
