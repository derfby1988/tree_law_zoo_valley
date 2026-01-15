import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String _supabaseUrl = 'https://otdspdcxzdygkfahyfpg.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90ZHNwZGN4emR5Z2tmYWh5ZnBnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzNzE1MjgsImV4cCI6MjA4Mzk0NzUyOH0.z9wUxKYHHgmAEqHKRbxwV_FLWYx9330WzyH875H91r0';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Authentication methods
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static User? get currentUser => client.auth.currentUser;

  // Database methods
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await client.from('users').select();
    return response;
  }

  static Future<void> insertUser(Map<String, dynamic> userData) async {
    await client.from('users').insert(userData);
  }
}
