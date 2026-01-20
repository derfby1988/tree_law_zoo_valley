import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'main.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _phoneErrorText;
  String? _usernameErrorText;
  bool _isCheckingUsername = false;
  bool _isCheckingPhone = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // โหลดข้อมูลจาก user metadata
        final userMetadata = user.userMetadata;
        final fullName = userMetadata?['full_name'] as String?;
        final username = userMetadata?['username'] as String?;
        final phone = userMetadata?['phone'] as String?;

        if (mounted) {
          setState(() {
            _fullNameController.text = fullName ?? '';
            _usernameController.text = username ?? '';
            _phoneController.text = phone ?? '';
            _emailController.text = user.email ?? '';
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // ฟังก์ชันตรวจสอบว่า username ซ้ำหรือไม่ (ยกเว้นตัวเอง)
  Future<bool> _checkUsernameExists(String username, {String? excludeUserId}) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;
      
      // วิธีที่ 1: ตรวจสอบจาก users table (ถ้ามี)
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('username, user_id')
            .eq('username', username)
            .maybeSingle();
        
        if (response != null) {
          // ถ้าพบ username ซ้ำ แต่เป็นของตัวเอง ให้ผ่าน
          return response['user_id'] != currentUser.id;
        }
      } catch (e) {
        debugPrint('Users table not found, using auth metadata: $e');
      }
      
      // วิธีที่ 2: ตรวจสอบจาก Supabase Auth user metadata
      // ดึงข้อมูลผู้ใช้ทั้งหมด (ต้องใช้ service role แต่ชั่วคราวใช้วิธีอื่น)
      
      // วิธีที่ 3: ตรวจสอบจาก user metadata ของผู้ใช้ปัจจุบัน
      final currentUsername = currentUser.userMetadata?['username'] as String?;
      
      // ถ้าเป็น username ของตัวเอง ให้ผ่าน
      if (username.toLowerCase() == currentUsername?.toLowerCase()) {
        return false;
      }
      
      // วิธีที่ 4: ตรวจสอบจาก hardcoded mapping (ชั่วคราว)
      final existingUsers = {
        'derfby': 'derfby@gmail.com',
        'firm': 'firmcutedra@gmail.com',
        'admin': 'admin@treelawzoo.local',
      };
      
      return existingUsers.containsKey(username.toLowerCase());
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false;
    }
  }

  // ฟังก์ชันตรวจสอบว่า phone ซ้ำหรือไม่ (ยกเว้นตัวเอง)
  Future<bool> _checkPhoneExists(String phone) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;
      
      // วิธีที่ 1: ตรวจสอบจาก users table (ถ้ามี)
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('phone, user_id')
            .eq('phone', phone)
            .maybeSingle();
        
        if (response != null) {
          // ถ้าพบ phone ซ้ำ แต่เป็นของตัวเอง ให้ผ่าน
          return response['user_id'] != currentUser.id;
        }
      } catch (e) {
        debugPrint('Users table not found, using auth metadata: $e');
      }
      
      // วิธีที่ 2: ตรวจสอบจาก Supabase Auth user metadata
      // ดึงข้อมูลผู้ใช้ทั้งหมด (ต้องใช้ service role แต่ชั่วคราวใช้วิธีอื่น)
      
      // วิธีที่ 3: ตรวจสอบจาก user metadata ของผู้ใช้ปัจจุบัน
      final currentPhone = currentUser.userMetadata?['phone'] as String?;
      
      // ถ้าเป็น phone ของตัวเอง ให้ผ่าน
      if (phone == currentPhone) {
        return false;
      }
      
      // วิธีที่ 4: ตรวจสอบจาก hardcoded mapping (ชั่วคราว)
      final existingPhones = {
        '0830103050': 'derfby@gmail.com',
        '0803399456': 'firmcutedra@gmail.com',
        '0999999999': 'admin@treelawzoo.local',
      };
      
      return existingPhones.containsKey(phone);
    } catch (e) {
      debugPrint('Error checking phone: $e');
      return false;
    }
  }

  // ฟังก์ชันตรวจสอบเบอร์โทรศัพท์
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // phone เป็น optional ใน profile
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

  Future<void> _saveProfile() async {
    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'ไม่พบข้อมูลผู้ใช้';
          _isSaving = false;
        });
        return;
      }

      // ตรวจสอบ username ซ้ำ
      final username = _usernameController.text.trim();
      if (username.isNotEmpty) {
        final usernameExists = await _checkUsernameExists(username);
        if (usernameExists) {
          setState(() {
            _errorMessage = 'ชื่อผู้ใช้ "$username" มีผู้ใช้แล้ว กรุณาเลือกชื่ออื่น';
            _isSaving = false;
          });
          return;
        }
      }

      // ตรวจสอบ phone ซ้ำ
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty) {
        final phoneError = _validatePhone(phone);
        if (phoneError != null) {
          setState(() {
            _errorMessage = phoneError;
            _isSaving = false;
          });
          return;
        }

        final phoneExists = await _checkPhoneExists(phone);
        if (phoneExists) {
          setState(() {
            _errorMessage = 'เบอร์โทรศัพท์ "$phone" มีผู้ใช้แล้ว กรุณาใช้เบอร์อื่น';
            _isSaving = false;
          });
          return;
        }
      }

      // อัปเดตข้อมูลใน Supabase
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'username': username.isNotEmpty ? username : null,
            'phone': phone.isNotEmpty ? phone : null,
            'full_name': _fullNameController.text.trim().isNotEmpty 
                ? _fullNameController.text.trim() 
                : null,
          },
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกข้อมูลสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
          _isSaving = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                            'โปรไฟล์ผู้ใช้',
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
                  
                  // Profile form
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
                        // Email field (readonly)
                        TextField(
                          controller: _emailController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'อีเมล',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.email),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                        ),
                        const SizedBox(height: 15),
                        
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
                            labelText: 'ชื่อเข้าใช้งาน',
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
                        
                        // Full Name field
                        TextField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อ-นามสกุล',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person_outline),
                            hintText: 'ชื่อ และนามสกุล',
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Phone field
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
                            labelText: 'เบอร์โทรศัพท์',
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
                        
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'บันทึกข้อมูล',
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
