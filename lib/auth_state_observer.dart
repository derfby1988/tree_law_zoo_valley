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
    
    // Polling check ทุก 3 วินาที (สำหรับ web)
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
    // Polling ทุก 3 วินาทีเป็นเวลา 30 วินาที
    for (int i = 0; i < 10; i++) {
      Future.delayed(Duration(seconds: 3 * i), () {
        if (mounted) {
          debugPrint('Polling check #$i');
          _checkResetPasswordFromUrl();
        }
      });
    }
    
    // ฟังการเปลี่ยนแปลง URL (สำหรับ web)
    if (mounted) {
      _listenToUrlChanges();
    }
  }

  void _listenToUrlChanges() {
    // ฟังการเปลี่ยนแปลง URL ผ่าน window events
    if (mounted) {
      // ใช้ timer ตรวจสอบ URL ทุก 1 วินาที
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
    
    // ตรวจสอบหลาย parameter ที่เกี่ยวข้องกับ password recovery
    final hasAccessToken = uri.queryParameters.containsKey('access_token');
    final hasRefreshToken = uri.queryParameters.containsKey('refresh_token');
    final hasType = uri.queryParameters.containsKey('type');
    final type = uri.queryParameters['type'];
    
    // ตรวจสอบใน hash fragment ด้วย (กรณี web)
    final hashUri = Uri.parse('#${uri.fragment}');
    final hasHashAccessToken = hashUri.queryParameters.containsKey('access_token');
    final hasHashType = hashUri.queryParameters.containsKey('type');
    final hashType = hashUri.queryParameters['type'];
    
    // ตรวจสอบใน full URL ด้วย (กรณีลิงก์โดยตรง)
    final fullUri = Uri.parse(uri.toString());
    final hasFullAccessToken = fullUri.queryParameters.containsKey('access_token');
    final hasFullType = fullUri.queryParameters.containsKey('type');
    final fullType = fullUri.queryParameters['type'];
    
    debugPrint('Has access_token: $hasAccessToken');
    debugPrint('Has refresh_token: $hasRefreshToken');
    debugPrint('Has type: $hasType');
    debugPrint('Type value: $type');
    debugPrint('Has hash access_token: $hasHashAccessToken');
    debugPrint('Has hash type: $hasHashType');
    debugPrint('Hash type value: $hashType');
    debugPrint('Has full access_token: $hasFullAccessToken');
    debugPrint('Has full type: $hasFullType');
    debugPrint('Full type value: $fullType');
    
    // ถ้ามี tokens หรือมี type=recovery ให้ไปหน้า reset password
    if (hasAccessToken || hasRefreshToken || (hasType && type == 'recovery') ||
        hasHashAccessToken || (hasHashType && hashType == 'recovery') ||
        hasFullAccessToken || (hasFullType && fullType == 'recovery')) {
      debugPrint('Reset password tokens detected in URL');
      _navigateToResetPassword();
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
