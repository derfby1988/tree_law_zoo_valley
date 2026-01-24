import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'utils/password_validator.dart';
import 'widgets/password_strength_indicator.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _showNewPassword = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recoverSessionFromUrl();
  }

  // ฟังก์ชันกู้คืน session จาก URL
  void _recoverSessionFromUrl() async {
    try {
      final uri = Uri.base;
      debugPrint('ResetPasswordPage - Current URI: $uri');
      
      // ตรวจสอบว่ามี tokens ใน URL หรือไม่
      if (uri.queryParameters.containsKey('access_token')) {
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        
        debugPrint('Found access token in URL');
        debugPrint('Access token: $accessToken');
        debugPrint('Refresh token: $refreshToken');
        
        // กู้คืน session จาก tokens
        if (accessToken != null) {
          await Supabase.instance.client.auth.recoverSession(accessToken);
          debugPrint('Session recovered successfully');
        }
      }
    } catch (e) {
      debugPrint('Error recovering session: $e');
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ฟังก์ชันตรวจสอบรหัสผ่าน
  String? _validatePassword(String? value) {
    return PasswordValidator.getValidationMessage(value ?? '', isReset: true);
  }

  // ฟังก์ชันตรวจสอบการยืนยันรหัสผ่าน
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณายืนยันรหัสผ่าน';
    }
    
    if (value != _newPasswordController.text) {
      return 'รหัสผ่านไม่ตรงกัน';
    }
    
    return null;
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    
    // ตรวจสอบรหัสผ่าน
    final passwordError = _validatePassword(newPassword);
    if (passwordError != null) {
      setState(() {
        _errorMessage = passwordError;
      });
      return;
    }
    
    // ตรวจสอบการยืนยันรหัสผ่าน (เฉพาะเมื่อไม่ได้เปิดดูรหัสผ่าน)
    if (!_showNewPassword) {
      final confirmError = _validateConfirmPassword(confirmPassword);
      if (confirmError != null) {
        setState(() {
          _errorMessage = confirmError;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ตรวจสอบว่ามี session จากการคลิกลิงก์ในอีเมลหรือไม่
      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('Current session: $session');
      
      if (session != null) {
        // อัปเดตรหัสผ่านใหม่
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            password: newPassword,
          ),
        );
        
        // Auto login ด้วยรหัสผ่านใหม่
        await _autoLogin(newPassword);
        
      } else {
        // ถ้าไม่มี session ให้ใช้วิธีอื่น
        throw Exception('ไม่พบ session กรุณาคลิกลิงก์ในอีเมลอีกครั้ง');
      }
      
    } catch (e) {
      debugPrint('Reset password error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
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
  
  /// Auto login หลังเปลี่ยนรหัสผ่าน
  Future<void> _autoLogin(String newPassword) async {
    try {
      // ดู email จาก session ปัจจุบัน
      final session = Supabase.instance.client.auth.currentSession;
      final email = session?.user?.email;
      
      if (email == null) {
        throw Exception('ไม่พบอีเมลผู้ใช้');
      }
      
      // ออกจากระบบก่อน
      await Supabase.instance.client.auth.signOut();
      
      // ล็อกอินใหม่ด้วยรหัสผ่านใหม่
      final response = await Supabase.instance.client.auth.signInWithPassword(
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
        
        // รอ 2 วินาทีแล้วไปหน้า home
        await Future.delayed(const Duration(seconds: 2));
        
        // ไปหน้า home โดยตรง
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MyHomePage(isGuestMode: false, title: 'TREE LAW ZOO valley'),
          ),
          (route) => false,
        );
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
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4FC3F7), // ฟ้า
              Color(0xFF81C784), // เขียว
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'เปลี่ยนรหัสผ่าน',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TREE LAW ZOO valley',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Reset password form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'กรุณากรอกรหัสผ่านใหม่ของคุณ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        
                        // New password field
                        TextField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่านใหม่ *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                  _showNewPassword = !_obscureNewPassword;
                                });
                              },
                              icon: Icon(
                                _obscureNewPassword 
                                    ? Icons.visibility 
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        
                        // Password strength indicator
                        PasswordStrengthIndicator(
                          password: _newPasswordController.text,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Confirm password field
                        if (!_showNewPassword) ...[
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'ยืนยันรหัสผ่านใหม่ *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: _isLoading ? null : () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword 
                                      ? Icons.visibility 
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Show confirmation message when password is visible
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'เห็นรหัสผ่านแล้ว ไม่ต้องยืนยันอีก',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        
                        // Error message
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Reset password button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'เปลี่ยนรหัสผ่าน',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
