import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/user_group_service.dart';
import 'services/image_upload_service.dart';
import 'widgets/avatar_picker.dart';
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
  String? _phoneErrorText;
  String? _usernameErrorText;
  String? _emailErrorText;
  bool _isCheckingUsername = false;
  bool _isCheckingPhone = false;
  bool _isCheckingEmail = false;
  Uint8List? _avatarBytes; // เก็บ bytes ของรูป
  String? _avatarFileName; // เก็บชื่อไฟล์
  String? _avatarUrl; // เก็บ URL หลังอัปโหลด

  // ฟังก์ชันตรวจสอบว่า username ซ้ำหรือไม่
  Future<bool> _checkUsernameExists(String username) async {
    try {
      // วิธีที่ 1: ตรวจสอบจาก users table (ถ้ามี)
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('username')
            .eq('username', username)
            .maybeSingle();
        
        if (response != null) {
          return true; // พบ username ซ้ำ
        }
      } catch (e) {
        debugPrint('Users table not found, checking auth users: $e');
      }
      
      // วิธีที่ 2: ตรวจสอบจาก auth.users metadata
      try {
        final response = await Supabase.instance.client
            .rpc('check_username_exists', params: {'username_to_check': username});
        
        if (response != null && response == true) {
          return true;
        }
      } catch (e) {
        debugPrint('RPC function not found, skipping username check: $e');
      }
      
      // วิธีที่ 3: ตรวจสอบจาก hardcoded mapping (เฉพาะ admin เท่านั้น)
      final adminUsers = {
        'admin': 'admin@treelawzoo.local',
      };
      
      return adminUsers.containsKey(username.toLowerCase());
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false; // ถ้า error ให้ผ่านไปก่อน
    }
  }

  // ฟังก์ชันตรวจสอบว่า phone ซ้ำหรือไม่
  Future<bool> _checkPhoneExists(String phone) async {
    try {
      // วิธีที่ 1: ตรวจสอบจาก users table (ถ้ามี)
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('phone')
            .eq('phone', phone)
            .maybeSingle();
        
        if (response != null) {
          return true; // พบ phone ซ้ำ
        }
      } catch (e) {
        debugPrint('Users table not found, checking auth users: $e');
      }
      
      // วิธีที่ 2: ตรวจสอบจาก auth.users metadata
      try {
        final response = await Supabase.instance.client
            .rpc('check_phone_exists', params: {'phone_to_check': phone});
        
        if (response != null && response == true) {
          return true;
        }
      } catch (e) {
        debugPrint('RPC function not found, skipping phone check: $e');
      }
      
      // วิธีที่ 3: ตรวจสอบจาก hardcoded mapping (เฉพาะ admin เท่านั้น)
      final adminPhones = {
        '0999999999': 'admin@treelawzoo.local',
      };
      
      return adminPhones.containsKey(phone);
    } catch (e) {
      debugPrint('Error checking phone: $e');
      return false; // ถ้า error ให้ผ่านไปก่อน
    }
  }

  // ฟังก์ชันตรวจสอบว่า email ซ้ำหรือไม่
  Future<bool> _checkEmailExists(String email) async {
    try {
      debugPrint('Checking email: $email');
      
      // วิธีที่ 1: ตรวจสอบจาก users table (ถ้ามี)
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('email')
            .eq('email', email)
            .maybeSingle();

        debugPrint('Email check response from users table: $response');
        if (response != null) {
          debugPrint('Email found in users table');
          return true;
        }
      } catch (e) {
        debugPrint('Error checking email from users table: $e');
      }
      
      // วิธีที่ 2: ตรวจสอบจาก auth.users
      try {
        // ใช้ RPC หรือ admin API ถ้าจำเป็น
        final response = await Supabase.instance.client.rpc('check_email_exists', params: {
          'email_to_check': email,
        });
        
        debugPrint('Email RPC check response: $response');
        if (response != null && response == true) {
          debugPrint('Email found via RPC');
          return true;
        }
      } catch (e) {
        debugPrint('Error checking email from auth: $e');
      }
      
      // วิธีที่ 3: ตรวจสอบจาก hardcoded mapping (เฉพาะ admin เท่านั้น)
      final adminEmails = {
        'admin@treelawzoo.local': 'admin',
      };
      
      final emailLower = email.toLowerCase();
      final existsInMapping = adminEmails.containsKey(emailLower);
      debugPrint('Email exists in mapping: $existsInMapping for email: $emailLower');
      
      return existsInMapping;
    } catch (e) {
      debugPrint('Error checking email: $e');
      return false; // ถ้า error ให้ผ่านไปก่อน
    }
  }

  Future<void> _register() async {
    setState(() {
      _errorMessage = null;
      _phoneErrorText = null;
      _isLoading = true;
    });

    // ตรวจสอบเบอร์โทรศัพท์ก่อน
    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      setState(() {
        _phoneErrorText = phoneError;
        _isLoading = false;
      });
      return;
    }

    // ตรวจสอบอีเมล (บังคับ)
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailErrorText = 'กรุณากรอกอีเมล';
        _isLoading = false;
      });
      return;
    }
    
    // ตรวจสอบรูปแบบอีเมล
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _emailErrorText = 'กรุณากรอกอีเมลให้ถูกต้อง';
        _isLoading = false;
      });
      return;
    }

    // ล้าง error messages ก่อนตรวจสอบ
    setState(() {
      _errorMessage = null;
      _phoneErrorText = null;
      _usernameErrorText = null;
      _emailErrorText = null;
    });

    // ตรวจสอบ username ซ้ำ
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      final usernameExists = await _checkUsernameExists(username);
      if (usernameExists) {
        setState(() {
          _errorMessage = 'ชื่อผู้ใช้ "$username" มีผู้ใช้แล้ว กรุณาเลือกชื่ออื่น';
          _isLoading = false;
        });
        return;
      }
    }

    // ตรวจสอบ phone ซ้ำ
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final phoneExists = await _checkPhoneExists(phone);
      if (phoneExists) {
        setState(() {
          _errorMessage = 'เบอร์โทรศัพท์ "$phone" มีผู้ใช้แล้ว กรุณาใช้เบอร์อื่น';
          _isLoading = false;
        });
        return;
      }
    }

    // ดึง default group จาก database
    final defaultGroup = await UserGroupService.getDefaultGroup();
    final defaultGroupId = defaultGroup?.id;
    
    if (defaultGroupId == null) {
      debugPrint('Warning: No default group found in database');
    } else {
      debugPrint('Using default group: ${defaultGroup!.groupName} (ID: $defaultGroupId)');
    }

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
            'avatar_url': 'pending',
            'user_group_id': defaultGroupId,
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
            'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
            'full_name': _fullNameController.text.trim().isNotEmpty ? _fullNameController.text.trim() : null,
            'avatar_url': 'pending',
            'user_group_id': defaultGroupId,
          },
        );
      }

      // อัปโหลดรูปภาพหลังสมัครสมาชิกสำเร็จ
      if (_avatarBytes != null && _avatarFileName != null && response.user != null) {
        try {
          // แสดง loading สำหรับการอัปโหลดรูป
          setState(() {
            _errorMessage = 'กำลังอัปโหลดรูปภาพ...';
          });

          _avatarUrl = await ImageUploadService.uploadImageToSupabase(
            _avatarBytes!,
            _avatarFileName!,
            response.user!.id,
          );
          
          // อัปเดต user metadata ด้วย avatar URL จริง
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {
              'avatar_url': _avatarUrl,
            }),
          );
          
          // แสดง success message
          setState(() {
            _errorMessage = null;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัปโหลดรูปภาพสำเร็จแล้ว'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          debugPrint('Error uploading avatar: $e');
          // ไม่ throw error แค่ log ไว้ เพราะสมัครสมาชิกสำเร็จแล้ว
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('อัปโหลดรูปภาพไม่สำเร็จ: ${e.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      debugPrint('Registration response: ${response.user != null ? 'SUCCESS' : 'FAILED'}');

      if (response.user != null) {
        setState(() {
          _errorMessage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ! กำลังเข้าสู่ระบบ...'),
            backgroundColor: Colors.green,
          ),
        );
        
        // ไปที่หน้า User Mode โดยตรง
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MyHomePage(
              title: 'TREE LAW ZOO valley',
              isGuestMode: false,
            ),
          ),
          (route) => false,
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

  // ฟังก์ชันตรวจสอบเบอร์โทรศัพท์
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกเบอร์โทรศัพท์';
    }
    
    // ตรวจสอบว่ามี 10 หลัก
    if (value.length != 10) {
      return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
    }
    
    // ตรวจสอบว่าขึ้นต้นด้วย 06, 08, 09
    if (!RegExp(r'^0[689]\d{8}$').hasMatch(value)) {
      return 'เบอร์โทรศัพท์ต้องขึ้นต้นด้วย 06, 08, หรือ 09';
    }
    
    return null;
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
                        // Avatar Picker
                        Center(
                          child: AvatarPicker(
                            onImageSelected: (bytes, fileName) {
                              setState(() {
                                _avatarBytes = bytes;
                                _avatarFileName = fileName;
                                _avatarUrl = null; // รีเซ็ต URL เมื่อเลือกรูปใหม่
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Username field
                        TextField(
                          controller: _usernameController,
                          onChanged: (value) async {
                            // Real-time username validation
                            final username = value.trim();
                            if (username.length >= 3) {
                              setState(() {
                                _isCheckingUsername = true;
                                _usernameErrorText = null;
                              });
              
                              final exists = await _checkUsernameExists(username);
                              if (mounted) {
                                setState(() {
                                  _isCheckingUsername = false;
                                  if (exists) {
                                    _usernameErrorText = 'ชื่อผู้ใช้นี้มีผู้ใช้แล้ว';
                                  }
                                });
                              }
                            } else {
                              setState(() {
                                _usernameErrorText = null;
                                _isCheckingUsername = false;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'ชื่อเข้าใช้งาน *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person),
                            suffixIcon: _isCheckingUsername 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : null,
                            errorText: _usernameErrorText,
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Full Name field (optional)
                        TextField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อ-นามสกุล (ไม่ต้องมีคำนำหน้า)',
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
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (value) async {
                            // Auto-format phone number
                            if (value.isNotEmpty && !value.startsWith('0')) {
                              _phoneController.text = '0' + value;
                              _phoneController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _phoneController.text.length),
                              );
                            }
                            
                            // ตรวจสอบรูปแบบเบอร์โทรศัพท์
                            final phoneFormatError = _validatePhone(_phoneController.text);
                            
                            // Real-time phone validation
                            if (phoneFormatError == null && _phoneController.text.length == 10) {
                              setState(() {
                                _isCheckingPhone = true;
                                _phoneErrorText = null;
                              });
              
                              final exists = await _checkPhoneExists(_phoneController.text);
                              if (mounted) {
                                setState(() {
                                  _isCheckingPhone = false;
                                  if (exists) {
                                    _phoneErrorText = 'เบอร์โทรศัพท์นี้มีผู้ใช้แล้ว';
                                  }
                                });
                              }
                            } else {
                              setState(() {
                                _phoneErrorText = phoneFormatError;
                                _isCheckingPhone = false;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'เบอร์โทรศัพท์ *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.phone),
                            hintText: '08xxxxxxxx',
                            counterText: '',
                            suffixIcon: _isCheckingPhone 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : null,
                            errorText: _phoneErrorText,
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Email field (required)
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) async {
                            // ล้าง error text เมื่อกรอกข้อมูลใหม่
                            if (_emailErrorText != null) {
                              setState(() {
                                _emailErrorText = null;
                              });
                            }
                            
                            // Real-time email validation
                            final email = value.trim();
                            debugPrint('Email changed: $email');
                            debugPrint('Email format valid: ${RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)}');
                            
                            if (email.isNotEmpty && RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                              debugPrint('Starting email validation...');
                              setState(() {
                                _isCheckingEmail = true;
                                _emailErrorText = null;
                              });
                              
                              // เพิ่ม delay เล็กน้อยเพื่อให้เห็น loading indicator
                              await Future.delayed(const Duration(milliseconds: 500));
                              
                              final emailExists = await _checkEmailExists(email);
                              debugPrint('Email exists result: $emailExists');
                              
                              if (mounted) {
                                setState(() {
                                  _isCheckingEmail = false;
                                  if (emailExists) {
                                    debugPrint('Setting email error: อีเมลนี้มีผู้ใช้แล้ว');
                                    _emailErrorText = 'อีเมลนี้มีผู้ใช้แล้ว กรุณาใช้อีเมลอื่น';
                                  } else {
                                    debugPrint('Email is available');
                                  }
                                });
                              }
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'อีเมล *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.email),
                            hintText: 'example@email.com',
                            errorText: _emailErrorText,
                            suffixIcon: _isCheckingEmail 
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                    ),
                                  )
                                : null,
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

