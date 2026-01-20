import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/change_password_dialog.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEditing = false;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      debugPrint('Loading user data for ID: ${currentUser.id}');

      // ดึงข้อมูลจากตาราง users
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      debugPrint('User data response: $response');

      if (response != null) {
        setState(() {
          _userData = response;
          _usernameController.text = response['username'] ?? '';
          _fullNameController.text = response['full_name'] ?? '';
          _phoneController.text = response['phone'] ?? '';
          _emailController.text = response['email'] ?? '';
        });
        debugPrint('User data loaded successfully');
      } else {
        // ถ้าไม่มีข้อมูลใน public.users ให้ลองดึงจาก auth.users
        debugPrint('No data in public.users, trying auth.users...');
        
        final authResponse = await SupabaseService.client.auth.admin.getUserById(currentUser.id);
        if (authResponse.user?.userMetadata != null) {
          final metadata = authResponse.user!.userMetadata!;
          setState(() {
            _userData = {
              'id': currentUser.id,
              'email': currentUser.email,
              'username': metadata['username'] ?? '',
              'full_name': metadata['full_name'] ?? '',
              'phone': metadata['phone'] ?? '',
              'created_at': DateTime.now().toIso8601String(),
            };
            _usernameController.text = metadata['username'] ?? '';
            _fullNameController.text = metadata['full_name'] ?? '';
            _phoneController.text = metadata['phone'] ?? '';
            _emailController.text = currentUser.email ?? '';
          });
          debugPrint('User data loaded from auth.users metadata');
        } else {
          throw Exception('ไม่พบข้อมูลผู้ใช้ในระบบ');
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกชื่อผู้ใช้';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // อัพเดทข้อมูลในตาราง users
      await SupabaseService.client
          .from('users')
          .update({
            'username': _usernameController.text.trim(),
            'full_name': _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentUser.id);

      // อัพเดทข้อมูลใน auth.users (metadata)
      await SupabaseService.client.auth.updateUser(
        UserAttributes(
          data: {
            'username': _usernameController.text.trim(),
            'full_name': _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          },
        ),
      );

      setState(() {
        _successMessage = 'อัพเดทข้อมูลสำเร็จ';
        _isEditing = false;
      });

      // โหลดข้อมูลใหม่
      await _loadUserData();

      // ซ่อนข้อความสำเร็จหลัง 3 วินาที
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'อัพเดทข้อมูลไม่สำเร็จ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    // แสดง dialog สำหรับเปลี่ยนรหัสผ่าน
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(
        onPasswordChanged: () {
          // หลังจากเปลี่ยนรหัสผ่านสำเร็จและออกจากระบบแล้ว
          // ไม่ต้องทำอะไรเพิ่มเติม เพราะจะกลับไปหน้าล็อกอินอัตโนมัติ
        },
      ),
    );
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
                          'โปรไฟล์ของฉัน',
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
                
                // Profile content
                Expanded(
                  child: _isLoading && _userData == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              // Profile card
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
                                    // Avatar
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.blue[100],
                                      child: Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // User info display
                                    if (!_isEditing) ...[
                                      _buildInfoRow('ชื่อผู้ใช้', _userData?['username'] ?? '-'),
                                      _buildInfoRow('ชื่อ-นามสกุล', _userData?['full_name'] ?? '-'),
                                      _buildInfoRow('อีเมล', _userData?['email'] ?? '-'),
                                      _buildInfoRow('เบอร์โทรศัพท์', _userData?['phone'] ?? '-'),
                                      _buildInfoRow('วันที่สมัคร', 
                                        _userData?['created_at'] != null 
                                          ? _formatDate(_userData!['created_at'])
                                          : '-'),
                                    ] else ...[
                                      // Edit form
                                      TextField(
                                        controller: _usernameController,
                                        decoration: InputDecoration(
                                          labelText: 'ชื่อผู้ใช้ *',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          prefixIcon: const Icon(Icons.person),
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      
                                      TextField(
                                        controller: _fullNameController,
                                        decoration: InputDecoration(
                                          labelText: 'ชื่อ-นามสกุล',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          prefixIcon: const Icon(Icons.person_outline),
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      
                                      TextField(
                                        controller: _emailController,
                                        enabled: false, // Email ไม่สามารถเปลี่ยนได้
                                        decoration: InputDecoration(
                                          labelText: 'อีเมล',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          prefixIcon: const Icon(Icons.email),
                                          helperText: 'อีเมลไม่สามารถเปลี่ยนแปลงได้',
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      
                                      TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          labelText: 'เบอร์โทรศัพท์',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          prefixIcon: const Icon(Icons.phone),
                                        ),
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Messages
                                    if (_errorMessage != null)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 15),
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
                                    
                                    if (_successMessage != null)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 15),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green[200]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _successMessage!,
                                                style: TextStyle(
                                                  color: Colors.green[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    
                                    // Action buttons
                                    if (!_isEditing)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                setState(() {
                                                  _isEditing = true;
                                                  _errorMessage = null;
                                                  _successMessage = null;
                                                });
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue[600],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text(
                                                'แก้ไขข้อมูล',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: _changePassword,
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: Colors.blue[600]!),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Text(
                                                'เปลี่ยนรหัสผ่าน',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _updateProfile,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green[600],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: _isLoading
                                                  ? const CircularProgressIndicator(
                                                      color: Colors.white,
                                                    )
                                                  : const Text(
                                                      'บันทึก',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                setState(() {
                                                  _isEditing = false;
                                                  _errorMessage = null;
                                                  _successMessage = null;
                                                  _loadUserData(); // โหลดข้อมูลเดิมกลับ
                                                });
                                              },
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: Colors.grey[600]!),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Text(
                                                'ยกเลิก',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
