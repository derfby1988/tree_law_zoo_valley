// PostgreSQL service disabled - postgres package removed for mobile compatibility
// Use Supabase instead via inventory_service.dart
import 'package:flutter/foundation.dart';

class PostgreSQLService {
  static bool get isConnected => false;
  static Future<void> connect() async => throw UnimplementedError('PostgreSQL disabled');
  static Future<void> disconnect() async {}
  static Future<bool> testConnection() async => false;
  static Future<List<Map<String, dynamic>>> getTables() async => [];
  static Future<List<Map<String, dynamic>>> getMenuItems({int? categoryId}) async => [];
  static Future<List<Map<String, dynamic>>> getBookings({DateTime? date}) async => [];
}

