import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// บริการ Multi-store / Multi-device Sync
///
/// จัดการ:
/// - การเลือกร้าน/สาขา (store_id) สำหรับอุปกรณ์ปัจจุบัน
/// - การลงทะเบียนอุปกรณ์ (device registration)
/// - ดึงรายการร้าน/สาขาทั้งหมด
/// - รับ real-time updates เมื่อมีออเดอร์ใหม่จากอุปกรณ์อื่น
class MultiStoreSyncService {
  static final _client = Supabase.instance.client;

  /// ดึงรายการร้าน/สาขาทั้งหมด
  static Future<List<Map<String, dynamic>>> getStores() async {
    try {
      final response = await _client
          .from('stores')
          .select('id, name, code, address, phone, is_active')
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getStores: $e');
      return [];
    }
  }

  /// ดึงร้าน/สาขาที่เลือกสำหรับอุปกรณ์ปัจจุบัน
  static Future<String?> getCurrentStoreId() async {
    try {
      final deviceId = await _getDeviceId();
      final response = await _client
          .from('pos_device_registrations')
          .select('store_id')
          .eq('device_id', deviceId)
          .maybeSingle();
      return response?['store_id'] as String?;
    } catch (e) {
      debugPrint('Error getCurrentStoreId: $e');
      return null;
    }
  }

  /// ตั้งค่าร้าน/สาขาสำหรับอุปกรณ์ปัจจุบัน
  static Future<bool> setCurrentStore(String storeId, String storeName) async {
    try {
      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();
      final user = _client.auth.currentUser;

      await _client.from('pos_device_registrations').upsert({
        'device_id': deviceId,
        'device_name': deviceName,
        'store_id': storeId,
        'store_name': storeName,
        'user_id': user?.id,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
        'is_active': true,
      }, onConflict: 'device_id');

      return true;
    } catch (e) {
      debugPrint('Error setCurrentStore: $e');
      return false;
    }
  }

  /// ดึงรายการอุปกรณ์ทั้งหมดในร้าน/สาขา
  static Future<List<Map<String, dynamic>>> getDevicesForStore(String storeId) async {
    try {
      final response = await _client
          .from('pos_device_registrations')
          .select('device_id, device_name, store_name, user_id, last_active_at, is_active')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('last_active_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getDevicesForStore: $e');
      return [];
    }
  }

  /// สร้าง realtime subscription สำหรับออเดอร์ใหม่ในร้านเดียวกัน
  ///
  /// คืน callback ที่เรียกเมื่อมีออเดอร์ใหม่ พร้อมข้อมูลออเดอร์
  static RealtimeChannel subscribeToStoreOrders({
    required String storeId,
    required void Function(Map<String, dynamic> order) onNewOrder,
  }) {
    return _client
        .channel('store_orders_$storeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pos_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            onNewOrder(Map<String, dynamic>.from(newRecord));
          },
        )
        .subscribe();
  }

  /// สร้าง realtime subscription สำหรับการเปลี่ยนแปลงสต็อก
  static RealtimeChannel subscribeToStockChanges({
    required String storeId,
    required void Function(String productId, double newQty) onStockChange,
  }) {
    return _client
        .channel('stock_changes_$storeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'inventory_products',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final productId = newRecord['id']?.toString();
            final newQty = (newRecord['quantity'] ?? 0).toDouble();
            if (productId != null) {
              onStockChange(productId, newQty);
            }
          },
        )
        .subscribe();
  }

  /// สร้าง realtime subscription สำหรับการเปลี่ยนสถานะโต๊ะ
  static RealtimeChannel subscribeToTableStatusChanges({
    required void Function(String tableId, String newStatus) onTableStatusChange,
  }) {
    return _client
        .channel('table_status_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'restaurant_tables',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final tableId = newRecord['id']?.toString();
            final newStatus = newRecord['status']?.toString() ?? '';
            if (tableId != null) {
              onTableStatusChange(tableId, newStatus);
            }
          },
        )
        .subscribe();
  }

  /// ดึง device ID ของอุปกรณ์ปัจจุบัน
  static String? _cachedDeviceId;

  static Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final user = _client.auth.currentUser;
      final deviceName = await _getDeviceName();
      _cachedDeviceId = '${user?.id ?? 'anon'}_${deviceName.hashCode.abs()}';
      return _cachedDeviceId!;
    } catch (e) {
      return 'unknown_device';
    }
  }

  static Future<String> _getDeviceName() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) return 'iOS Device';
      if (defaultTargetPlatform == TargetPlatform.android) return 'Android Device';
      if (defaultTargetPlatform == TargetPlatform.macOS) return 'macOS';
      if (defaultTargetPlatform == TargetPlatform.windows) return 'Windows';
      if (defaultTargetPlatform == TargetPlatform.linux) return 'Linux';
      if (kIsWeb) return 'Web Browser';
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }
}
