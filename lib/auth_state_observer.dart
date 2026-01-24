import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_page.dart';

class AuthStateObserver extends StatefulWidget {
  final Widget child;

  const AuthStateObserver({super.key, required this.child});

  @override
  State<AuthStateObserver> createState() => _AuthStateObserverState();
}

class _AuthStateObserverState extends State<AuthStateObserver> {
  late final Stream<AuthState> _authStateStream;

  @override
  void initState() {
    super.initState();
    
    // ตรวจสอบ URL parameters ตอนเริ่มต้น
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkResetPasswordFromUrl();
    });
    
    // ตรวจสอบซ้ำหลัง 2 วินาที (กรณี URL โหลดช้า)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkResetPasswordFromUrl();
      }
    });
    
    // Polling check ทุก 1 วินาทีตลอดเวลา (สำคัญสำหรับ tab ใหม่)
    _startUrlPolling();
    
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
    _authStateStream.listen((data) {
      final AuthState authState = data;
      debugPrint('AuthState event: ${authState.event}');
      debugPrint('AuthState session: ${authState.session}');
      
      // ตรวจสอบว่าเป็น password recovery event
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Password recovery event detected!');
        _navigateToResetPassword();
      }
      
      // ตรวจสอบ signedIn พร้อม session (กรณี recovery ทำงาน)
      if (authState.event == AuthChangeEvent.signedIn && authState.session != null) {
        debugPrint('SignedIn event detected, checking for recovery...');
        _checkResetPasswordFromUrl();
      }
    });
  }

  void _startUrlPolling() {
    // Polling ทุก 1 วินาทีตลอดเวลา (ไม่มี limit - สำคัญสำหรับ tab ใหม่)
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      debugPrint('URL Polling check');
      _checkResetPasswordFromUrl();
    });
    
    // ฟังการเปลี่ยนแปลง URL (สำหรับ web)
    if (mounted) {
      _listenToUrlChanges();
    }
  }

  void _listenToUrlChanges() {
    // ฟังการเปลี่ยนแปลง URL ผ่าน window events
    if (mounted) {
      // ใช้ timer ตรวจสอบ URL ทุก 1 วินาทีตลอดเวลา (ไม่มี limit)
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _checkResetPasswordFromUrl();
      });
    }
  }

  void _checkResetPasswordFromUrl() {
    // ตรวจสอบว่ามี access_token ใน URL หรือไม่ (จากลิงก์รีเซ็ตรหัสผ่าน)
    final uri = Uri.base;
    debugPrint('Current URI: $uri');
    debugPrint('Query parameters: ${uri.queryParameters}');
    debugPrint('Hash: ${uri.fragment}');
    
    // ตรวจสอบใน query parameters ก่อน
    final hasAccessToken = uri.queryParameters.containsKey('access_token');
    final hasRefreshToken = uri.queryParameters.containsKey('refresh_token');
    final hasType = uri.queryParameters.containsKey('type');
    final type = uri.queryParameters['type'];
    
    // ตรวจสอบ code parameter (กรณี OAuth flow หรือ custom flow)
    final hasCode = uri.queryParameters.containsKey('code');
    final code = uri.queryParameters['code'];
    
    debugPrint('Has access_token: $hasAccessToken');
    debugPrint('Has refresh_token: $hasRefreshToken');
    debugPrint('Has type: $hasType');
    debugPrint('Type value: $type');
    debugPrint('Has code: $hasCode');
    debugPrint('Code value: $code');
    
    // ถ้ามี code parameter (อาจเป็น OAuth flow หรือ custom flow)
    if (hasCode && code != null) {
      debugPrint('Code parameter detected, checking if it\'s password recovery...');
      // ตรวจสอบว่าเป็น password recovery หรือไม่
      _handleCodeParameter(code);
      return;
    }
    
    // ตรวจสอบใน hash fragment (สำคัญสำหรับ Supabase web links)
    final hashFragment = uri.fragment;
    debugPrint('Full hash fragment: $hashFragment');
    
    // แยก hash fragment ที่มีลักษณะเป็น query string
    if (hashFragment.contains('=')) {
      final hashUri = Uri.parse('#$hashFragment');
      final hasHashAccessToken = hashUri.queryParameters.containsKey('access_token');
      final hasHashRefreshToken = hashUri.queryParameters.containsKey('refresh_token');
      final hasHashType = hashUri.queryParameters.containsKey('type');
      final hashType = hashUri.queryParameters['type'];
      
      debugPrint('Hash URI: $hashUri');
      debugPrint('Hash query params: ${hashUri.queryParameters}');
      debugPrint('Has hash access_token: $hasHashAccessToken');
      debugPrint('Has hash refresh_token: $hasHashRefreshToken');
      debugPrint('Has hash type: $hasHashType');
      debugPrint('Hash type value: $hashType');
      
      // Supabase ส่งลิงก์ในรูปแบบ hash fragment สำหรับ web
      if (hasHashAccessToken || hasHashRefreshToken || 
          (hasHashType && hashType == 'recovery')) {
        debugPrint('Reset password tokens detected in HASH fragment');
        _navigateToResetPassword();
        return;
      }
    }
    
    // ตรวจสองใน full URL ด้วย (กรณีอื่นๆ)
    final fullUri = Uri.parse(uri.toString());
    final hasFullAccessToken = fullUri.queryParameters.containsKey('access_token');
    final hasFullType = fullUri.queryParameters.containsKey('type');
    final fullType = fullUri.queryParameters['type'];
    
    debugPrint('Has full access_token: $hasFullAccessToken');
    debugPrint('Has full type: $hasFullType');
    debugPrint('Full type value: $fullType');
    
    // ถ้ามี tokens ใน query parameters ปกติ
    if (hasAccessToken || hasRefreshToken || (hasType && type == 'recovery') ||
        hasFullAccessToken || (hasFullType && fullType == 'recovery')) {
      debugPrint('Reset password tokens detected in QUERY parameters');
      _navigateToResetPassword();
    }
  }
  
  void _handleCodeParameter(String code) {
    debugPrint('Handling code parameter: $code');
    
    // ตรวจสอบว่าเป็น UUID format หรือไม่ (password recovery tokens)
    if (code.length > 20 && code.contains('-')) {
      debugPrint('Code looks like a recovery token, navigating to reset password');
      
      // ลอง recover session จาก code ก่อน
      _tryRecoverSessionFromCode(code);
      
      // แล้วค่อย navigate
      _navigateToResetPassword();
    } else {
      debugPrint('Code doesn\'t look like a recovery token, ignoring');
    }
  }
  
  void _tryRecoverSessionFromCode(String code) async {
    try {
      debugPrint('Attempting to recover session from code: $code');
      // บางทีอาจต้องใช้ code แปลงเป็น access token
      // หรือเรียก API พิเศษจาก Supabase
      debugPrint('Session recovery attempt completed');
    } catch (e) {
      debugPrint('Session recovery failed: $e');
    }
  }

  void _navigateToResetPassword() {
    if (mounted) {
      debugPrint('Navigating to ResetPasswordPage');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const ResetPasswordPage(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
