import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TableManagementService {
  static final _client = Supabase.instance.client;

  // =============================================
  // ZONES (ร้าน)
  // =============================================

  static Future<List<Map<String, dynamic>>> getZones() async {
    try {
      final response = await _client
          .from('restaurant_zones')
          .select('*, tables:restaurant_tables(count)')
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getZones: $e');
      return [];
    }
  }

  /// Zones พร้อมข้อมูลโต๊ะทั้งหมด (ใช้ในหน้าจองโต๊ะ)
  static Future<List<Map<String, dynamic>>> getZonesWithTables() async {
    try {
      final response = await _client
          .from('restaurant_zones')
          .select('*, tables:restaurant_tables(*)')
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getZonesWithTables: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addZone({
    required String name,
    String? description,
    String? openTime,
    String? closeTime,
  }) async {
    try {
      final response = await _client.from('restaurant_zones').insert({
        'name': name,
        'description': description,
        'open_time': openTime,
        'close_time': closeTime,
        'sort_order': 0,
      }).select().single();
      return response;
    } catch (e) {
      debugPrint('Error addZone: $e');
      return null;
    }
  }

  static Future<bool> updateZone({
    required String id,
    required String name,
    String? description,
    String? openTime,
    String? closeTime,
    bool? isActive,
  }) async {
    try {
      await _client.from('restaurant_zones').update({
        'name': name,
        'description': description,
        'open_time': openTime,
        'close_time': closeTime,
        if (isActive != null) 'is_active': isActive,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updateZone: $e');
      return false;
    }
  }

  static Future<bool> deleteZone(String id) async {
    try {
      await _client.from('restaurant_zones').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleteZone: $e');
      return false;
    }
  }

  static Future<bool> reorderZones(List<String> orderedIds) async {
    try {
      for (int i = 0; i < orderedIds.length; i++) {
        await _client
            .from('restaurant_zones')
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      }
      return true;
    } catch (e) {
      debugPrint('Error reorderZones: $e');
      return false;
    }
  }

  // =============================================
  // TABLES (โต๊ะ)
  // =============================================

  static Future<List<Map<String, dynamic>>> getTablesForZone(String zoneId) async {
    try {
      final response = await _client
          .from('restaurant_tables')
          .select()
          .eq('zone_id', zoneId)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getTablesForZone: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addTable({
    required String zoneId,
    required String name,
    required String tableType,
    required int capacity,
    bool isBookable = true,
    String? notes,
  }) async {
    try {
      final response = await _client.from('restaurant_tables').insert({
        'zone_id': zoneId,
        'name': name,
        'table_type': tableType,
        'capacity': capacity,
        'is_bookable': isBookable,
        'status': 'available',
        'notes': notes,
        'sort_order': 0,
      }).select().single();
      return response;
    } catch (e) {
      debugPrint('Error addTable: $e');
      return null;
    }
  }

  static Future<bool> updateTable({
    required String id,
    required String name,
    required String tableType,
    required int capacity,
    required bool isBookable,
    required String status,
    String? notes,
  }) async {
    try {
      await _client.from('restaurant_tables').update({
        'name': name,
        'table_type': tableType,
        'capacity': capacity,
        'is_bookable': isBookable,
        'status': status,
        'notes': notes,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updateTable: $e');
      return false;
    }
  }

  static Future<bool> deleteTable(String id) async {
    try {
      await _client.from('restaurant_tables').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleteTable: $e');
      return false;
    }
  }

  static Future<bool> reorderTables(List<String> orderedIds) async {
    try {
      for (int i = 0; i < orderedIds.length; i++) {
        await _client
            .from('restaurant_tables')
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      }
      return true;
    } catch (e) {
      debugPrint('Error reorderTables: $e');
      return false;
    }
  }

  static Future<bool> updateTablePosition(String id, double posX, double posY, {String? tableName}) async {
    try {
      await _client
          .from('restaurant_tables')
          .update({'pos_x': posX, 'pos_y': posY})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updateTablePosition (id=$id, name=${tableName ?? ''}): $e');
      return false;
    }
  }

  static Future<bool> setTableStatus(String id, String status) async {
    try {
      await _client
          .from('restaurant_tables')
          .update({'status': status})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error setTableStatus: $e');
      return false;
    }
  }

  // =============================================
  // FLOOR PLAN ELEMENTS (Text & Shapes)
  // =============================================

  static Future<List<Map<String, dynamic>>> getElementsForZone(String zoneId) async {
    try {
      final response = await _client
          .from('floor_plan_elements')
          .select()
          .eq('zone_id', zoneId)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getElementsForZone: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addElement({
    required String zoneId,
    required String elementType,
    String? label,
    required double posX,
    required double posY,
    double width = 0.15,
    double height = 0.08,
    String color = '#607D8B',
    double fontSize = 14,
  }) async {
    try {
      final response = await _client.from('floor_plan_elements').insert({
        'zone_id': zoneId,
        'element_type': elementType,
        'label': label,
        'pos_x': posX,
        'pos_y': posY,
        'width': width,
        'height': height,
        'color': color,
        'font_size': fontSize,
        'sort_order': 0,
      }).select().single();
      return response;
    } catch (e) {
      debugPrint('Error addElement: $e');
      return null;
    }
  }

  static Future<bool> updateElement({
    required String id,
    String? label,
    double? posX,
    double? posY,
    double? width,
    double? height,
    String? color,
    double? fontSize,
    double? rotation,
  }) async {
    try {
      await _client.from('floor_plan_elements').update({
        if (label != null) 'label': label,
        if (posX != null) 'pos_x': posX,
        if (posY != null) 'pos_y': posY,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (color != null) 'color': color,
        if (fontSize != null) 'font_size': fontSize,
        if (rotation != null) 'rotation': rotation,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updateElement: $e');
      return false;
    }
  }

  static Future<bool> deleteElement(String id) async {
    try {
      await _client.from('floor_plan_elements').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleteElement: $e');
      return false;
    }
  }

  static Future<bool> saveAllElements(List<Map<String, dynamic>> elements) async {
    try {
      for (final el in elements) {
        await _client.from('floor_plan_elements').upsert({
          'id': el['id'],
          'zone_id': el['zone_id'],
          'element_type': el['element_type'],
          'label': el['label'],
          'pos_x': (el['pos_x'] as num).toDouble(),
          'pos_y': (el['pos_y'] as num).toDouble(),
          'width': (el['width'] as num?)?.toDouble() ?? 0.15,
          'height': (el['height'] as num?)?.toDouble() ?? 0.08,
          'color': el['color'] ?? '#607D8B',
          'font_size': (el['font_size'] as num?)?.toDouble() ?? 14,
          'rotation': (el['rotation'] as num?)?.toDouble() ?? 0,
          'sort_order': el['sort_order'] ?? 0,
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saveAllElements: $e');
      return false;
    }
  }

  // =============================================
  // TABLE TYPES (ประเภทโต๊ะ)
  // =============================================

  static Future<List<Map<String, dynamic>>> getTableTypes() async {
    try {
      final response = await _client
          .from('restaurant_table_types')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getTableTypes: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addTableType({
    required String name,
    required String shape,
    required String color,
    required int defaultCapacity,
  }) async {
    try {
      final response = await _client.from('restaurant_table_types').insert({
        'name': name,
        'shape': shape,
        'color': color,
        'default_capacity': defaultCapacity,
        'sort_order': 0,
      }).select().single();
      return response;
    } catch (e) {
      debugPrint('Error addTableType: $e');
      return null;
    }
  }

  static Future<bool> updateTableType({
    required String id,
    required String name,
    required String shape,
    required String color,
    required int defaultCapacity,
    bool? isActive,
  }) async {
    try {
      await _client.from('restaurant_table_types').update({
        'name': name,
        'shape': shape,
        'color': color,
        'default_capacity': defaultCapacity,
        if (isActive != null) 'is_active': isActive,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updateTableType: $e');
      return false;
    }
  }

  static Future<bool> deleteTableType(String id) async {
    try {
      await _client.from('restaurant_table_types').update({'is_active': false}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleteTableType: $e');
      return false;
    }
  }

  static Future<bool> reorderTableTypes(List<String> orderedIds) async {
    try {
      for (int i = 0; i < orderedIds.length; i++) {
        await _client.from('restaurant_table_types').update({'sort_order': i}).eq('id', orderedIds[i]);
      }
      return true;
    } catch (e) {
      debugPrint('Error reorderTableTypes: $e');
      return false;
    }
  }
}
