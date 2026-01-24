import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../reset_password_page.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordDialog({super.key, this.initialEmail});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
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
      // ส่งอีเมลรีเซ็ตรหัสผ่านผ่าน Supabase
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      
      // เริ่มนับถอยหลัง
      _startCountdown();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว กรุณาตรวจสอบอีเมล\nและคลิกลิงก์เพื่อดำเนินการต่อ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // แสดง dialog แนะนำให้คลิกลิงก์
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('คำแนะนำ'),
                content: const Text(
                  '1. ตรวจสองอีเมลของคุณ\n'
                  '2. คลิกลิงก์รีเซ็ตรหัสผ่าน\n'
                  '3. ระบบจะนำคุณไปหน้าเปลี่ยนรหัสผ่านอัตโนมัติ\n\n'
                  'ถ้าไม่ไปอัตโนมัติ กรุณารอสักครู่...',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // ลองเปิดหน้า reset password ด้วยตนเอง
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ResetPasswordPage(),
                        ),
                      );
                    },
                    child: const Text('เปิดหน้าเปลี่ยนรหัสผ่าน'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ตกลง'),
                  ),
                ],
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Password reset error: $e');
      if (mounted) {
        setState(() {
          // ไม่บอกว่าอีเมลไม่มี แต่ให้ความรู้สึกเดียวกัน
          if (e.toString().contains('user_not_found') || 
              e.toString().contains('Invalid login credentials')) {
            _errorMessage = 'หากอีเมลนี้เคยลงทะเบียน ควรจะพบลิงก์ในอีเมลแล้ว';
          } else {
            _errorMessage = 'ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว กรุณาเข้ายืนยันในอีเมล';
          }
        });
        
        // เริ่มนับถอยหลังเสมอ (เพื่อความปลอดภัย)
        _startCountdown();
        
        // แสดง SnackBar เหมือนส่งสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว กรุณาตรวจสอบอีเมล\nและคลิกลิงก์เพื่อดำเนินการต่อ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ลืมรหัสผ่าน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('กรุณากรอกอีเมลของคุณเพื่อรับลิงก์รีเซ็ตรหัสผ่าน'),
        const SizedBox(height: 8),
        const Text(
          'ตัวอย่าง: user@example.com',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: widget.initialEmail != null && widget.initialEmail!.isNotEmpty 
                  ? null 
                  : 'อีเมล',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _errorMessage,
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('กำลังส่ง...'),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            Navigator.of(context).pop();
          },
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _countdown > 0) ? null : _resetPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : _countdown > 0
                  ? Text('ส่งใหม่ (${_countdown} วินาท)')
                  : const Text('ส่ง'),
        ),
      ],
    );
  }
}
