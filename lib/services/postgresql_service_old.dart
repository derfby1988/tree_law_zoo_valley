// PostgreSQL service (old) disabled - postgres package removed for mobile compatibility
import 'package:flutter/foundation.dart';

class PostgreSQLServiceOld {
  static bool get isConnected => false;
  static Future<void> connect() async => throw UnimplementedError('PostgreSQL disabled');
  static Future<void> disconnect() async {}
  static Future<bool> testConnection() async => false;
}
