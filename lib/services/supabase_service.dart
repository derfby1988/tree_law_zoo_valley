import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

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
    try {
      return await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // ถ้าเป็น email_not_confirmed ให้ลอง sign up อีกครั้งเพื่อ trigger confirmation
      if (e.toString().contains('email_not_confirmed')) {
        debugPrint('Email not confirmed, attempting to resend confirmation...');
        return await signUpWithEmail(email, password);
      }
      rethrow;
    }
  }

  // Login ด้วยเบอร์โทรศัพท์
  static Future<AuthResponse> signInWithPhone(String phone, String password) async {
    try {
      // ใช้ phone เป็น email (เพราะ Supabase ยังไม่รองรับ phone login โดยตรง)
      final email = '${phone}@treezoo.app';
      return await signInWithEmail(email, password);
    } catch (e) {
      debugPrint('Phone login error: $e');
      rethrow;
    }
  }

  static Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // สมัครด้วยเบอร์โทรศัพท์
  static Future<AuthResponse> signUpWithPhone(String phone, String password) async {
    try {
      // ใช้ phone เป็น email (เพราะ Supabase ยังไม่รองรับ phone signup โดยตรง)
      final email = '${phone}@treezoo.app';
      return await signUpWithEmail(email, password);
    } catch (e) {
      debugPrint('Phone signup error: $e');
      rethrow;
    }
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

  // OTP Methods
  static Future<bool> sendOTPToPhone(String phone) async {
    try {
      await client.auth.signInWithOtp(
        phone: phone,
      );
      debugPrint('OTP sent to $phone');
      return true;
    } catch (e) {
      debugPrint('OTP send error: $e');
      return false;
    }
  }

  static Future<AuthResponse> verifyOTPAndCreateAccount({
    required String phone,
    required String token,
    required String username,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Verify OTP โดยตรง ไม่ต้องสร้าง email
      final response = await client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      // ถ้าสำเร็จ ให้อัพเดทข้อมูลผู้ใช้
      if (response.user != null) {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'username': username,
              'phone': phone,
              'signup_method': 'phone_otp',
              'phone_only': true,
              ...?additionalData,
            },
          ),
        );
      }

      return response;
    } catch (e) {
      debugPrint('OTP verification error: $e');
      rethrow;
    }
  }

  static Future<AuthResponse> signUpWithPhoneOTP({
    required String phone,
    required String username,
    required String password,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // สร้าง email จากเบอร์โทรศัพท์
      final email = '${phone}@treezoo.app';
      
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'phone': phone,
          'signup_method': 'phone_otp',
          'phone_only': true,
          ...?additionalData,
        },
      );

      return response;
    } catch (e) {
      debugPrint('Phone OTP signup error: $e');
      rethrow;
    }
  }

  static Future<AuthResponse> signInWithPhoneOTP({
    required String phone,
    required String password,
  }) async {
    try {
      final email = '${phone}@treezoo.app';
      return await signInWithEmail(email, password);
    } catch (e) {
      debugPrint('Phone OTP login error: $e');
      rethrow;
    }
  }
}
