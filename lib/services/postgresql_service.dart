import 'package:postgres/postgres.dart';
import 'package:flutter/foundation.dart';

class PostgreSQLService {
  static PostgreSQLConnection? _connection;
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
      _connection = PostgreSQLConnection(
        _host,
        _port,
        _database,
        username: _username,
      );
      
      await _connection!.open();
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
      final results = await _connection!.query('''
        SELECT id, table_number, status, capacity, location, description, 
               last_updated, updated_by, created_at
        FROM tables 
        ORDER BY table_number
      ''');
      
      return results.map((row) => {
        'id': row[0],
        'table_number': row[1],
        'status': row[2],
        'capacity': row[3],
        'location': row[4],
        'description': row[5],
        'last_updated': row[6],
        'updated_by': row[7],
        'created_at': row[8],
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get tables: $e');
      rethrow;
    }
  }
  
  // อัปเดตสถานะโต๊ะ
  static Future<bool> updateTableStatus(int tableId, String status, {String? updatedBy}) async {
    await connect();
    
    try {
      await _connection!.execute('''
        UPDATE tables 
        SET status = @status, last_updated = NOW(), updated_by = @updatedBy
        WHERE id = @id
      ''', substitutionValues: {
        'id': tableId,
        'status': status,
        'updatedBy': updatedBy ?? 'mobile_app',
      });
      
      debugPrint('✅ Table $tableId status updated to $status');
      return true;
      
    } catch (e) {
      debugPrint('❌ Failed to update table status: $e');
      return false;
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
      
      final results = await _connection!.query(
        query,
        substitutionValues: date != null ? {'date': date.toIso8601String().split('T')[0]} : null,
      );
      
      return results.map((row) => {
        'id': row[0],
        'table_id': row[1],
        'customer_name': row[2],
        'customer_phone': row[3],
        'booking_date': row[4],
        'booking_time': row[5],
        'number_of_people': row[6],
        'status': row[7],
        'special_requests': row[8],
        'notes': row[9],
        'payment_status': row[10],
        'total_amount': row[11],
        'created_at': row[12],
        'updated_at': row[13],
        'table_number': row[14],
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get bookings: $e');
      rethrow;
    }
  }
  
  // สร้างการจองใหม่
  static Future<int> createBooking(Map<String, dynamic> booking) async {
    await connect();
    
    try {
      final result = await _connection!.query('''
        INSERT INTO bookings (table_id, customer_name, customer_phone, 
                              booking_date, booking_time, number_of_people, 
                              special_requests, notes, created_by)
        VALUES (@tableId, @customerName, @customerPhone, @bookingDate, 
                @bookingTime, @numberOfPeople, @specialRequests, @notes, @createdBy)
        RETURNING id
      ''', substitutionValues: {
        'tableId': booking['table_id'],
        'customerName': booking['customer_name'],
        'customerPhone': booking['customer_phone'],
        'bookingDate': booking['booking_date'],
        'bookingTime': booking['booking_time'],
        'numberOfPeople': booking['number_of_people'],
        'specialRequests': booking['special_requests'],
        'notes': booking['notes'],
        'createdBy': booking['created_by'] ?? 'mobile_app',
      });
      
      final bookingId = result.first[0];
      debugPrint('✅ Booking created with ID: $bookingId');
      return bookingId;
      
    } catch (e) {
      debugPrint('❌ Failed to create booking: $e');
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
      
      final results = await _connection!.query(
        query,
        substitutionValues: categoryId != null ? {'categoryId': categoryId} : null,
      );
      
      return results.map((row) => {
        'id': row[0],
        'category_id': row[1],
        'name_th': row[2],
        'name_en': row[3],
        'description_th': row[4],
        'description_en': row[5],
        'price': row[6],
        'original_price': row[7],
        'image_url': row[8],
        'thumbnail_url': row[9],
        'preparation_time': row[10],
        'is_available': row[11],
        'is_featured': row[12],
        'sort_order': row[13],
        'created_at': row[14],
        'updated_at': row[15],
        'category_name': row[16],
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get menu items: $e');
      rethrow;
    }
  }
  
  // ดึงข้อมูลหมวดหมู่
  static Future<List<Map<String, dynamic>>> getCategories() async {
    await connect();
    
    try {
      final results = await _connection!.query('''
        SELECT id, name_th, name_en, description, icon_url, 
               sort_order, is_active, created_at, updated_at
        FROM categories 
        WHERE is_active = true
        ORDER BY sort_order, name_th
      ''');
      
      return results.map((row) => {
        'id': row[0],
        'name_th': row[1],
        'name_en': row[2],
        'description': row[3],
        'icon_url': row[4],
        'sort_order': row[5],
        'is_active': row[6],
        'created_at': row[7],
        'updated_at': row[8],
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get categories: $e');
      rethrow;
    }
  }
  
  // ดึงข้อมูลโปรโมชั่นที่ใช้งานได้
  static Future<List<Map<String, dynamic>>> getActivePromotions() async {
    await connect();
    
    try {
      final results = await _connection!.query('''
        SELECT id, title, description, promo_code, discount_type, 
               discount_value, min_order_amount, max_discount_amount,
               start_date, end_date, usage_limit, usage_count,
               is_active, image_url, created_at, updated_at
        FROM promotions 
        WHERE is_active = true 
        AND (start_date <= CURRENT_DATE OR start_date IS NULL)
        AND (end_date >= CURRENT_DATE OR end_date IS NULL)
        ORDER BY created_at DESC
      ''');
      
      return results.map((row) => {
        'id': row[0],
        'title': row[1],
        'description': row[2],
        'promo_code': row[3],
        'discount_type': row[4],
        'discount_value': row[5],
        'min_order_amount': row[6],
        'max_discount_amount': row[7],
        'start_date': row[8],
        'end_date': row[9],
        'usage_limit': row[10],
        'usage_count': row[11],
        'is_active': row[12],
        'image_url': row[13],
        'created_at': row[14],
        'updated_at': row[15],
      }).toList();
      
    } catch (e) {
      debugPrint('❌ Failed to get promotions: $e');
      rethrow;
    }
  }
  
  // ดึงข้อมูลการตั้งค่า
  static Future<Map<String, dynamic>> getSettings({bool publicOnly = true}) async {
    await connect();
    
    try {
      String query = 'SELECT key, value, data_type FROM settings';
      
      if (publicOnly) {
        query += ' WHERE is_public = true';
      }
      
      final results = await _connection!.query(query);
      
      final settings = <String, dynamic>{};
      for (final row in results) {
        final key = row[0] as String;
        final value = row[1] as String;
        final dataType = row[2] as String;
        
        switch (dataType) {
          case 'number':
            settings[key] = double.tryParse(value) ?? int.tryParse(value) ?? value;
            break;
          case 'boolean':
            settings[key] = value.toLowerCase() == 'true';
            break;
          case 'json':
            // จำเป็นต้อง import dart:convert
            settings[key] = value; // สำหรับตอนนี้ให้เป็น string ก่อน
            break;
          default:
            settings[key] = value;
        }
      }
      
      return settings;
      
    } catch (e) {
      debugPrint('❌ Failed to get settings: $e');
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
      final result = await _connection!.query('SELECT 1 as test');
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }
}
