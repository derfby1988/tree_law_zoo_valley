import 'package:postgres/postgres.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class PostgreSQLService {
  static Connection? _connection;
  static bool _isConnected = false;
  
  // Configuration สำหรับ External SSD PostgreSQL
  static const String _host = 'localhost';
  static const int _port = 5432;
  static const String _database = 'tree_law_zoo_valley';
  static const String _username = 'dave_macmini';
  
  // เชื่อมต่อกับ database
  static Future<void> connect() async {
    if (_isConnected && _connection != null) {
      return; // เชื่อมต่ออยู่แล้ว
    }
    
    try {
      _connection = await Connection.open(
        Endpoint(
          host: _host,
          port: _port,
          database: _database,
          username: _username,
        ),
      );
      
      _isConnected = true;
      
      debugPrint('✅ PostgreSQL connected successfully');
      debugPrint('📍 Database: $_database');
      debugPrint('💾 External SSD: /Volumes/PostgreSQL/postgresql-data-valley');
      
    } catch (e) {
      debugPrint('❌ Failed to connect to PostgreSQL: $e');
      _isConnected = false;
      rethrow;
    }
  }
  
  // ตรวจสอบสถานะการเชื่อมต่อ
  static bool get isConnected => _isConnected;
  
  // ดึงข้อมูลโต๊ะทั้งหมด
  static Future<List<Map<String, dynamic>>> getTables() async {
    await connect();
    
    try {
      final results = await _connection!.execute('''
        SELECT id, table_number, status, capacity, location, description, 
               last_updated, updated_by, created_at
        FROM tables 
        ORDER BY table_number
      ''');
      
      return results.map((row) => {
        'id': row[0] as int,
        'table_number': row[1] as int,
        'status': row[2] as String,
        'capacity': row[3] as int,
        'location': row[4] as String?,
        'description': row[5] as String?,
        'last_updated': row[6] as DateTime?,
        'updated_by': row[7] as String?,
        'created_at': row[8] as DateTime,
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get tables: $e');
      rethrow;
    }
  }
  
  // ดึงข้อมูลเมนูอาหาร
  static Future<List<Map<String, dynamic>>> getMenuItems({int? categoryId}) async {
    await connect();
    
    try {
      String query = '''
        SELECT mi.id, mi.category_id, mi.name_th, mi.name_en, 
               mi.description_th, mi.description_en, mi.price, 
               mi.original_price, mi.image_url, mi.thumbnail_url,
               mi.preparation_time, mi.is_available, mi.is_featured,
               mi.sort_order, mi.created_at, mi.updated_at,
               c.name_th as category_name
        FROM menu_items mi
        LEFT JOIN categories c ON mi.category_id = c.id
        WHERE mi.is_available = true
      ''';
      
      if (categoryId != null) {
        query += " AND mi.category_id = @categoryId";
      }
      
      query += " ORDER BY mi.category_id, mi.sort_order, mi.name_th";
      
      final results = categoryId != null 
        ? await _connection!.execute(query, parameters: [categoryId])
        : await _connection!.execute(query);
      
      return results.map((row) => {
        'id': row[0] as int,
        'category_id': row[1] as int?,
        'name_th': row[2] as String,
        'name_en': row[3] as String?,
        'description_th': row[4] as String?,
        'description_en': row[5] as String?,
        'price': (row[6] as num).toDouble(),
        'original_price': row[7] as num?,
        'image_url': row[8] as String?,
        'thumbnail_url': row[9] as String?,
        'preparation_time': row[10] as int?,
        'is_available': row[11] as bool,
        'is_featured': row[12] as bool,
        'sort_order': row[13] as int,
        'created_at': row[14] as DateTime,
        'updated_at': row[15] as DateTime,
        'category_name': row[16] as String?,
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get menu items: $e');
      rethrow;
    }
  }
  
  // ดึงข้อมูลการจองทั้งหมด
  static Future<List<Map<String, dynamic>>> getBookings({DateTime? date}) async {
    await connect();
    
    try {
      String query = '''
        SELECT b.id, b.table_id, b.customer_name, b.customer_phone, 
               b.booking_date, b.booking_time, b.number_of_people, 
               b.status, b.special_requests, b.notes, b.payment_status,
               b.total_amount, b.created_at, b.updated_at,
               t.table_number
        FROM bookings b
        LEFT JOIN tables t ON b.table_id = t.id
      ''';
      
      if (date != null) {
        query += " WHERE b.booking_date = @date";
      }
      
      query += " ORDER BY b.booking_date, b.booking_time";
      
      final results = date != null 
        ? await _connection!.execute(query, parameters: [date.toIso8601String().split('T')[0]])
        : await _connection!.execute(query);
      
      return results.map((row) => {
        'id': row[0] as int,
        'table_id': row[1] as int?,
        'customer_name': row[2] as String,
        'customer_phone': row[3] as String?,
        'booking_date': row[4] as String,
        'booking_time': row[5] as String,
        'number_of_people': row[6] as int,
        'status': row[7] as String,
        'special_requests': row[8] as String?,
        'notes': row[9] as String?,
        'payment_status': row[10] as String,
        'total_amount': row[11] as num?,
        'created_at': row[12] as DateTime,
        'updated_at': row[13] as DateTime,
        'table_number': row[14] as int?,
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get bookings: $e');
      rethrow;
    }
  }
  
  // ปิดการเชื่อมต่อ
  static Future<void> disconnect() async {
    if (_connection != null && _isConnected) {
      await _connection!.close();
      _isConnected = false;
      debugPrint('🔌 PostgreSQL disconnected');
    }
  }
  
  // ทดสอบการเชื่อมต่อ
  static Future<bool> testConnection() async {
    try {
      await connect();
      final result = await _connection!.execute('SELECT 1 as test');
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }
}
