import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import '../main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _register() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      AuthResponse response;

      // ตรวจสอบว่าใช้ email หรือ phone
      if (_emailController.text.isNotEmpty) {
        // วิธีที่ 1: Email + Password
        debugPrint('Using email registration method');
        
        final emailError = validateEmail(_emailController.text);
        if (emailError != null) {
          setState(() {
            _errorMessage = emailError;
            _isLoading = false;
          });
          return;
        }

        final passwordError = validatePassword(_passwordController.text);
        if (passwordError != null) {
          setState(() {
            _errorMessage = passwordError;
            _isLoading = false;
          });
          return;
        }

        final confirmError = validateConfirmPassword(
          _confirmPasswordController.text, 
          _passwordController.text
        );
        if (confirmError != null) {
          setState(() {
            _errorMessage = confirmError;
            _isLoading = false;
          });
          return;
        }

        final usernameError = validateUsername(_usernameController.text);
        if (usernameError != null) {
          setState(() {
            _errorMessage = usernameError;
            _isLoading = false;
          });
          return;
        }

        response = await SupabaseService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          data: {
            'username': _usernameController.text.trim(),
            'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
            'full_name': _fullNameController.text.trim().isNotEmpty ? _fullNameController.text.trim() : null,
          },
        );
      } else {
        // วิธีที่ 2: Phone + Password
        debugPrint('Using phone registration method');
        
        final phoneError = validatePhone(_phoneController.text);
        if (phoneError != null) {
          setState(() {
            _errorMessage = phoneError;
            _isLoading = false;
          });
          return;
        }

        final passwordError = validatePassword(_passwordController.text);
        if (passwordError != null) {
          setState(() {
            _errorMessage = passwordError;
            _isLoading = false;
          });
          return;
        }

        final confirmError = validateConfirmPassword(
          _confirmPasswordController.text, 
          _passwordController.text
        );
        if (confirmError != null) {
          setState(() {
            _errorMessage = confirmError;
            _isLoading = false;
          });
          return;
        }

        final usernameError = validateUsername(_usernameController.text);
        if (usernameError != null) {
          setState(() {
            _errorMessage = usernameError;
            _isLoading = false;
          });
          return;
        }

        response = await SupabaseService.signUpWithPhone(
          _phoneController.text.trim(),
          _passwordController.text.trim(),
          data: {
            'username': _usernameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'full_name': _fullNameController.text.trim().isNotEmpty ? _fullNameController.text.trim() : null,
          },
        );
      }

      debugPrint('Registration response: ${response.user != null ? 'SUCCESS' : 'FAILED'}');

      if (response.user != null) {
        setState(() {
          _errorMessage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบ'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginPage(
              returnToMenu: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Registration error: $e');
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
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
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
                            'สมัครสมาชิก',
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
                  
                  // Registration form
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
                        // Username field
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อเข้าใช้งาน *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Full Name field (optional)
                        TextField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อ-นามสกุล (ถ้ามี)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person_outline),
                            hintText: 'ชื่อ และนามสกุล',
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Phone field (required)
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'เบอร์โทรศัพท์ *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.phone),
                            hintText: '08xxxxxxxx',
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Email field (optional)
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'อีเมล (จำเป็น)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.email),
                            hintText: 'example@email.com',
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Confirm password field
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'ยืนยันรหัสผ่าน *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
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
                        
                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  )
                                : const Text(
                                    'สมัครสมาชิก',
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

// Validation functions
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'กรุณากรอกอีเมล';
  }
  
  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
    return 'กรุณากรอกอีเมลให้ถูกต้อง';
  }
  
  return null;
}

String? validatePhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'กรุณากรอกเบอร์โทรศัพท์';
  }
  
  if (!RegExp(r'^0[689]\d{8}$').hasMatch(value)) {
    return 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง (เช่น 0812345678)';
  }
  
  return null;
}

String? validateUsername(String? value) {
  if (value == null || value.isEmpty) {
    return 'กรุณากรอกชื่อผู้ใช้';
  }
  
  if (value.length < 3) {
    return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
  }
  
  if (value.length > 20) {
    return 'ชื่อผู้ใช้ต้องไม่เกิน 20 ตัวอักษร';
  }
  
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    return 'ชื่อผู้ใช้สามารถใช้ได้เฉพาะตัวอักษรภาษาอังกฤษ, ตัวเลข และ _';
  }
  
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'กรุณากรอกรหัสผ่าน';
  }
  
  if (value.length < 6) {
    return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
  }
  
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'กรุณายืนยันรหัสผ่าน';
  }
  
  if (value != password) {
    return 'รหัสผ่านไม่ตรงกัน';
  }
  
  return null;
}

