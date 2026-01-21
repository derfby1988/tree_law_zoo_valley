import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../reset_password_page.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
          _errorMessage = 'เกิดข้อผิดพลาด: ไม่พบอีเมลนี้ในระบบ กรุณาลองใหม่';
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
    return AlertDialog(
      title: const Text('ลืมรหัสผ่าน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('กรุณากรอกอีเมลของคุณเพื่อรับลิงก์รีเซ็ตรหัสผ่าน'),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'อีเมล',
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
          onPressed: _isLoading ? null : _resetPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('ส่ง'),
        ),
      ],
    );
  }
}
