import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../reset_password_page.dart';
import 'glass_dialog.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordDialog({super.key, this.initialEmail});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController(); // ✅ เพิ่ม Controller สำหรับ OTP 6 หลัก
  bool _isLoading = false;
  bool _otpSent = false; // ✅ ควบคุมการแสดงผลสลับระหว่างเฟสขอ OTP และเฟสยืนยัน OTP
  String? _errorMessage;
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // เริ่มนับถอยหลัง 120 วินาที
  void _startCountdown() {
    setState(() {
      _countdown = 120;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }
  
  // ฟังก์ชันตรวจสอบรูปแบบอีเมล
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกอีเมล';
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'กรุณากรอกอีเมลให้ถูกต้อง';
    }
    
    return null;
  }

  // ฟังก์ชันส่งอีเมลคำขอรีเซ็ตรหัสผ่าน (OTP)
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    // ตรวจสอบรูปแบบอีเมล
    final validationError = _validateEmail(email);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ ส่งพารามิเตอร์เพื่อบอกปลายทางให้ถูกต้อง (กรณีผู้ใช้กดลิงก์)
      final String? redirectTo = kIsWeb ? '${Uri.base.origin}/?type=recovery' : null;
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
      
      _startCountdown();
      
      if (mounted) {
        setState(() {
          _otpSent = true; // ✅ สลับไปยังเฟสการกรอก OTP 6 หลัก
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งรหัส OTP 6 หลักไปยังอีเมลของคุณเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Password reset error: $e');
      if (mounted) {
        // แนะนำความปลอดภัย: เสมือนส่งสำเร็จเพื่อป้องกัน Email Enumeration
        setState(() {
          _otpSent = true; 
        });
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งรหัส OTP 6 หลักไปยังอีเมลของคุณเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ ฟังก์ชันยืนยันรหัส OTP 6 หลัก
  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'กรุณากรอกรหัส OTP 6 หลักให้ครบถ้วน';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ เรียกใช้ API verifyOTP เพื่อสร้าง session และยืนยันตัวตนขากู้คืน
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );

      if (mounted) {
        // ปิด ForgotPasswordDialog
        Navigator.of(context).pop();
        
        // นำทางผู้ใช้ไปยังหน้าจอตั้งรหัสผ่านใหม่ (ResetPasswordPage) ทันที
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ResetPasswordPage(),
          ),
        );
      }
    } catch (e) {
      debugPrint('OTP Verification error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'รหัส OTP ไม่ถูกต้อง หรืออาจจะหมดอายุแล้ว';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: _otpSent ? 'ยืนยันรหัส OTP' : 'ลืมรหัสผ่าน',
      actions: [
        Row(
          children: [
            Expanded(
              child: GlassDialogButton(
                text: 'ยกเลิก',
                onPressed: _isLoading ? null : () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassDialogButton(
                text: _otpSent 
                    ? 'ยืนยัน OTP' 
                    : (_countdown > 0 ? 'ส่งใหม่ ($_countdown วินาที)' : 'ส่ง'),
                onPressed: _isLoading
                    ? null
                    : (_otpSent
                        ? _verifyOtp
                        : (_countdown > 0 ? null : _resetPassword)),
                isPrimary: true,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Content Text
          Text(
            _otpSent
                ? 'กรุณากรอกรหัส OTP 6 หลักที่ได้รับในอีเมลของคุณ\nเพื่อความปลอดภัยในการยืนยันตัวตนข้ามอุปกรณ์'
                : 'กรุณากรอกอีเมลของคุณเพื่อรับลิงก์และรหัส OTP สำหรับรีเซ็ตรหัสผ่าน',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _otpSent ? 'ส่งรหัสไปที่: ${_emailController.text}' : 'ตัวอย่าง: user@example.com',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          
          // Field selection depending on phase
          if (!_otpSent)
            GlassTextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              hintText: widget.initialEmail != null && widget.initialEmail!.isNotEmpty 
                  ? null 
                  : 'อีเมล',
              errorText: _errorMessage,
            )
          else
            GlassTextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
              hintText: 'รหัส OTP 6 หลัก',
              errorText: _errorMessage,
            ),
          
          // Loading indicator
          if (_isLoading) ...[
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'กำลังประมวลผล...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
