import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

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
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกรหัสผ่าน';
    }
    
    if (value.length < 6) {
      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    }
    
    return null;
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
    
    // ตรวจสอบการยืนยันรหัสผ่าน
    final confirmError = _validateConfirmPassword(confirmPassword);
    if (confirmError != null) {
      setState(() {
        _errorMessage = confirmError;
      });
      return;
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
        // อัปเดตรหัสผ่านใหม่ (วิธีที่ถูกต้องสำหรับ password recovery)
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            password: newPassword,
          ),
        );
      } else {
        // ถ้าไม่มี session ให้ใช้วิธีอื่น
        throw Exception('ไม่พบ session กรุณาคลิกลิงก์ในอีเมลอีกครั้ง');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปลี่ยนรหัสผ่านสำเร็จ! กรุณาเข้าสู่ระบบใหม่'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // กลับไปหน้า login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginPage(),
          ),
          (route) => false,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                        const SizedBox(height: 20),
                        
                        // Confirm password field
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
