import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../main.dart';

class ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const ChangePasswordDialog({
    super.key,
    required this.onPasswordChanged,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกรหัสผ่านปัจจุบัน';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกรหัสผ่านใหม่';
    }
    
    if (value.length < 6) {
      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณายืนยันรหัสผ่านใหม่';
    }
    
    if (value != _newPasswordController.text) {
      return 'รหัสผ่านไม่ตรงกัน';
    }
    
    return null;
  }

  Future<void> _changePassword() async {
    final currentPasswordError = _validateCurrentPassword(_currentPasswordController.text);
    if (currentPasswordError != null) {
      setState(() {
        _errorMessage = currentPasswordError;
      });
      return;
    }

    final newPasswordError = _validateNewPassword(_newPasswordController.text);
    if (newPasswordError != null) {
      setState(() {
        _errorMessage = newPasswordError;
      });
      return;
    }

    final confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
    if (confirmPasswordError != null) {
      setState(() {
        _errorMessage = confirmPasswordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ตรวจสอบรหัสผ่านปัจจุบันโดยการล็อกอินใหม่
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // ลองล็อกอินด้วยรหัสผ่านปัจจุบันเพื่อยืนยัน
      await SupabaseService.client.auth.signInWithPassword(
        email: currentUser.email!,
        password: _currentPasswordController.text,
      );

      // ถ้าล็อกอินสำเร็จ ให้เปลี่ยนรหัสผ่าน
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // แสดงข้อความแจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เปลี่ยนรหัสผ่านสำเร็จแล้ว กรุณาเข้าสู่ระบบใหม่อีกครั้ง'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // รอ 3 วินาทีก่อนออกจากระบบ
      await Future.delayed(const Duration(seconds: 3));

      // ออกจากระบบ
      await SupabaseService.client.auth.signOut();

      // ปิด dialog
      Navigator.of(context).pop();

      // ไปหน้าล็อกอินโดยตรง (ไม่พึ่ง auth state change)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
        (route) => false,
      );

      widget.onPasswordChanged();
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4FC3F7),
              Color(0xFF81C784),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'เปลี่ยนรหัสผ่าน',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance with back button
              ],
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            // Current Password
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrentPassword,
              decoration: InputDecoration(
                labelText: 'รหัสผ่านปัจจุบัน',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.white),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                  icon: Icon(
                    _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // New Password
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              decoration: InputDecoration(
                labelText: 'รหัสผ่านใหม่',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.white),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Confirm Password
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'ยืนยันรหัสผ่านใหม่',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.white),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),

            // Change Password Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      )
                    : const Text(
                        'เปลี่ยนรหัสผ่าน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
