import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_page.dart';

class AuthStateObserver extends StatefulWidget {
  final Widget child;

  /// URL ที่ capture ไว้ก่อน Supabase.initialize() จะลบ ?code= ออกจาก URL
  /// ต้องตั้งค่าใน main() ก่อน SupabaseService.initialize()
  static Uri? initialUri;

  const AuthStateObserver({super.key, required this.child});

  @override
  State<AuthStateObserver> createState() => _AuthStateObserverState();
}

class _AuthStateObserverState extends State<AuthStateObserver> {
  late final Stream<AuthState> _authStateStream;
  bool _hasCheckedUrl = false;
  bool _isNavigating = false;
  bool _isRecoveryFlowProcessed = false; // ✅ ป้องกันไม่ให้ประมวลผลซ้ำหรือเด้งไปหน้า reset ซ้ำซาก

  /// Safe logger — เฉพาะ debug mode + ไม่พิมพ์ข้อมูลอ่อนไหว
  void _safeLog(String message) {
    assert(() {
      debugPrint('[AuthObserver] $message');
      return true;
    }());
  }

  /// ตรวจสอบรูปแบบ JWT เบื้องต้น (3 ส่วนคั่นด้วยจุด)
  bool _isValidJwtFormat(String token) {
    if (token.isEmpty) return false;
    final parts = token.split('.');
    return parts.length == 3 && parts.every((p) => p.isNotEmpty);
  }

  /// ตรวจสอบรูปแบบ PKCE code (UUID format)
  bool _isValidPkceCode(String code) {
    if (code.isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(code);
  }

  @override
  void initState() {
    super.initState();
    
    // ตรวจสอบ URL parameters ตอนเริ่มต้น (ครั้งเดียว)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedUrl) {
        _hasCheckedUrl = true;
        _checkResetPasswordFromUrl();
      }
    });
    
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
    _authStateStream.listen((data) {
      final AuthState authState = data;
      _safeLog('AuthState event: ${authState.event}, session exists: ${authState.session != null}');
      
      // ตรวจหา type = recovery จาก URL ดั้งเดิม
      final uri = AuthStateObserver.initialUri ?? Uri.base;
      final type = uri.queryParameters['type'] ??
          Uri.tryParse('?${uri.fragment}')?.queryParameters['type'];

      // ✅ วิธีชัวร์ที่สุด: ถ้ามี session เข้ามาแล้ว และ URL แรกระบุว่าเป็น recovery flow
      if (authState.session != null && type == 'recovery' && !_isRecoveryFlowProcessed) {
        _safeLog('Session established for recovery flow, navigating');
        _navigateToResetPassword();
      }
      
      // Fallback: ตรวจสอบว่าเป็น password recovery event ดั้งเดิม
      if (authState.event == AuthChangeEvent.passwordRecovery && !_isRecoveryFlowProcessed) {
        _safeLog('Password recovery event detected, navigating');
        _navigateToResetPassword();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _checkResetPasswordFromUrl() async {
    final uri = AuthStateObserver.initialUri ?? Uri.base;
    _safeLog('Checking URL for recovery parameters (initialUri captured: ${AuthStateObserver.initialUri != null})');
    
    final type = uri.queryParameters['type'] ??
        Uri.tryParse('?${uri.fragment}')?.queryParameters['type'];

    // === PKCE Flow: Supabase ส่ง ?code=UUID มาแทน access_token ===
    final code = uri.queryParameters['code'] ??
        Uri.tryParse('?${uri.fragment}')?.queryParameters['code'];
    
    _safeLog('Has PKCE code: ${code != null && code.isNotEmpty}, Type: $type');
    
    if (code != null && code.isNotEmpty && _isValidPkceCode(code) && type == 'recovery') {
      _safeLog('Valid PKCE recovery code detected');
      
      // Supabase SDK อาจจะแลก session สำเร็จไปแล้วในเบื้องหลัง
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && !_isRecoveryFlowProcessed) {
        _safeLog('Session already exists from PKCE auto-exchange, navigating');
        _navigateToResetPassword();
        return;
      }
      
      // ถ้ายังไม่มี session → ลองแลกโค้ดเอง
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
        _safeLog('PKCE code exchanged manually');
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted && Supabase.instance.client.auth.currentSession != null && !_isRecoveryFlowProcessed) {
          _navigateToResetPassword();
        }
        return;
      } catch (e) {
        _safeLog('PKCE exchange failed, checking session anyway');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted && Supabase.instance.client.auth.currentSession != null && !_isRecoveryFlowProcessed) {
          _navigateToResetPassword();
        }
        return;
      }
    }

    // === Legacy Flow: access_token + type=recovery ใน URL ===
    final accessToken = uri.queryParameters['access_token'] ??
        Uri.tryParse('?${uri.fragment}')?.queryParameters['access_token'];
    
    _safeLog('Has access_token: ${accessToken != null && accessToken.isNotEmpty}');
    _safeLog('Type: $type');
    
    // ต้องมีทั้ง access_token ที่ถูกรูปแบบ JWT AND type == 'recovery'
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        type == 'recovery' &&
        _isValidJwtFormat(accessToken) &&
        !_isRecoveryFlowProcessed) {
      _safeLog('Valid recovery token detected in URL');
      _navigateToResetPassword();
    }
  }

  void _navigateToResetPassword() {
    if (mounted && !_isNavigating) {
      _isNavigating = true;
      _isRecoveryFlowProcessed = true; // ✅ ทำงานนี้สำเร็จแล้ว ป้องกันการเด้งซ้ำซ้อน
      _safeLog('Navigating to ResetPasswordPage');
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ResetPasswordPage(),
        ),
      ).then((_) {
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
