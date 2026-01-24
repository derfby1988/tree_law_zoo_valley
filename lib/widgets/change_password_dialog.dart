import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../utils/password_validator.dart';
import '../widgets/password_strength_indicator.dart';

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
    return PasswordValidator.getValidationMessage(value ?? '');
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
      try {
        await SupabaseService.client.auth.signInWithPassword(
          email: currentUser.email!,
          password: _currentPasswordController.text,
        );
      } catch (e) {
        // ถ้ารหัสผ่านปัจจุบันผิด ให้แสดง error ที่เหมาะสม
        if (e.toString().contains('Invalid login credentials')) {
          throw Exception('รหัสผ่านปัจจุบันไม่ถูกต้อง');
        } else {
          throw Exception('ไม่สามารถยืนยันรหัสผ่านปัจจุบันได้: ${e.toString()}');
        }
      }

      // ถ้าล็อกอินสำเร็จ ให้เปลี่ยนรหัสผ่าน
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Auto login ด้วยรหัสผ่านใหม่
      await _autoLogin(_newPasswordController.text);

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Auto login หลังเปลี่ยนรหัสผ่าน
  Future<void> _autoLogin(String newPassword) async {
    try {
      // ดู email จาก user ปัจจุบัน
      final currentUser = SupabaseService.currentUser;
      final email = currentUser?.email;
      
      if (email == null) {
        throw Exception('ไม่พบอีเมลผู้ใช้');
      }
      
      // ออกจากระบบก่อน
      await SupabaseService.client.auth.signOut();
      
      // ล็อกอินใหม่ด้วยรหัสผ่านใหม่
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: newPassword,
      );
      
      debugPrint('Auto login successful: ${response.user?.email}');
      
      if (mounted) {
        // แสดงข้อความแจ้งเตือน
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนรหัสผ่านสำเร็จ! กำลังเข้าสู่ระบบ...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // รอ 2 วินาที
        await Future.delayed(const Duration(seconds: 2));
        
        // ปิด dialog
        Navigator.of(context).pop();
        
        // ไปหน้า home โดยตรง
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MyHomePage(isGuestMode: false, title: 'TREE LAW ZOO valley'),
          ),
          (route) => false,
        );
        
        widget.onPasswordChanged();
      }
    } catch (e) {
      debugPrint('Auto login error: $e');
      if (mounted) {
        // ถ้า auto login ไม่สำเร็จ ให้ไปหน้า login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนรหัสผ่านสำเร็จ! กรุณาเข้าสู่ระบบใหม่'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        
        // ปิด dialog
        Navigator.of(context).pop();
        
        // ไปหน้า login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
          (route) => false,
        );
        
        widget.onPasswordChanged();
      }
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
            
            // Password strength indicator
            PasswordStrengthIndicator(
              password: _newPasswordController.text,
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
