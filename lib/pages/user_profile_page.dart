import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/avatar_picker.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  
  // Avatar related
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// ตรวจสอบว่าควรแสดง default icon หรือไม่
  bool _shouldShowDefaultIcon() {
    return _avatarUrl == null && _avatarBytes == null;
  }

  /// ดูรูปภาพ Avatar ที่เหมาะสม (พร้อม caching)
  ImageProvider? _getAvatarImage() {
    // 1. ถ้ามีรูปที่เลือกใหม่ (preview)
    if (_avatarBytes != null) {
      return MemoryImage(_avatarBytes!);
    }
    
    // 2. ถ้ามี URL จาก Supabase - ใช้ NetworkImage แทน CachedNetworkImage เพื่อ force refresh
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // ตรวจสอบว่าเป็น URL ที่ถูกต้อง
      if (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) {
        // ใช้ Supabase Image Transformation ลดขนาดรูป
        final optimizedUrl = _getOptimizedAvatarUrl(_avatarUrl!);
        debugPrint('ProfilePage: Loading avatar from optimized URL: $optimizedUrl');
        return NetworkImage(optimizedUrl);
      }
      
      // ถ้าไม่ใช่ URL ที่ถูกต้อง ให้ลองสร้าง Supabase URL
      if (!_avatarUrl!.startsWith('http')) {
        final supabaseUrl = 'https://otdspdcxzdygkfahyfpg.supabase.co/storage/v1/object/public/avatars/$_avatarUrl';
        final optimizedUrl = _getOptimizedAvatarUrl(supabaseUrl);
        debugPrint('ProfilePage: Loading avatar from optimized Supabase URL: $optimizedUrl');
        return NetworkImage(optimizedUrl);
      }
    }
    
    // 3. ไม่มีรูป
    return null;
  }

  /// ตรวจสอบว่าควรใช้ CachedNetworkImage หรือไม่
  bool _shouldUseCachedNetworkImage() {
    return _avatarUrl != null && 
           _avatarUrl!.isNotEmpty && 
           (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) &&
           _avatarBytes == null;
  }

  /// ดู URL สำหรับ CachedNetworkImage
  String? _getCachedImageUrl() {
    if (!_shouldUseCachedNetworkImage()) return null;
    
    if (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) {
      return _getOptimizedAvatarUrl(_avatarUrl!);
    }
    
    if (!_avatarUrl!.startsWith('http')) {
      final supabaseUrl = 'https://otdspdcxzdygkfahyfpg.supabase.co/storage/v1/object/public/avatars/$_avatarUrl';
      return _getOptimizedAvatarUrl(supabaseUrl);
    }
    
    return null;
  }

  /// สร้าง URL รูปที่ถูก optimize สำหรับแสดงในโปรไฟล์
  String _getOptimizedAvatarUrl(String originalUrl) {
    try {
      // แก้ไข path ที่ซ้ำกัน: avatars/avatars/ → avatars/
      String fixedUrl = originalUrl;
      if (originalUrl.contains('/avatars/avatars/')) {
        fixedUrl = originalUrl.replaceFirst('/avatars/avatars/', '/avatars/');
        debugPrint('ProfilePage: Fixed avatar URL: $fixedUrl');
      }
      
      // ใช้ Supabase Image Transformation API
      // ขนาด 100x100 px, quality 70%, format jpeg (เร็ววกว่า webp)
      final uri = Uri.parse(fixedUrl);
      
      // เพิ่ม query parameters สำหรับ optimization
      final optimizedUrl = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'width': '100',
          'height': '100',
          'quality': '70',
          'format': 'jpeg', // ใช้ jpeg แทน webp เพื่อความเร็ว
        },
      );
      
      return optimizedUrl.toString();
    } catch (e) {
      debugPrint('ProfilePage: Error optimizing avatar URL: $e');
      return originalUrl; // ถ้า error ใช้ URL เดิม
    }
  }

  /// โหลดข้อมูลผู้ใช้
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

      // 1. ลองโหลดจาก auth.users metadata ก่อน (มี avatar_url ล่าสุด)
      try {
        // ใช้ currentUser.userMetadata แทน admin API
        final metadata = currentUser.userMetadata ?? {};
        debugPrint('Found auth metadata: $metadata');
        
        // ถ้ามี avatar_url ใน metadata ให้ใช้เลย
        if (metadata['avatar_url'] != null && metadata['avatar_url'] != 'pending') {
          setState(() {
            _userData = {
              'id': currentUser.id,
              'email': currentUser.email,
              'username': metadata['username'] ?? '',
              'full_name': metadata['full_name'] ?? '',
              'phone': metadata['phone'] ?? '',
              'avatar_url': metadata['avatar_url'],
              'created_at': currentUser.createdAt ?? DateTime.now().toIso8601String(),
            };
            _usernameController.text = metadata['username'] ?? '';
            _fullNameController.text = metadata['full_name'] ?? '';
            _phoneController.text = metadata['phone'] ?? '';
            _emailController.text = currentUser.email ?? '';
            _avatarUrl = metadata['avatar_url'];
            debugPrint('Avatar URL from auth metadata: ${metadata['avatar_url']}');
          });
          debugPrint('User data loaded from auth.users metadata');
          return; // ใช้ข้อมูลจาก auth แล้ว
        }
      } catch (e) {
        debugPrint('Error loading auth metadata: $e');
      }

      // 2. ถ้าไม่มีใน auth หรือ avatar_url เป็น pending ให้ลองจาก public.users
      debugPrint('Trying to load from public.users...');
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
          _avatarUrl = response['avatar_url'];
          debugPrint('Avatar URL from database: ${response['avatar_url']}');
        });
        debugPrint('User data loaded successfully');
      } else {
        // 3. ถ้าไม่มีในทั้งสองที่ให้ใช้ข้อมูลพื้นฐานจาก auth
        debugPrint('No data in public.users, using basic auth info...');
        setState(() {
          _userData = {
            'id': currentUser.id,
            'email': currentUser.email,
            'username': '',
            'full_name': '',
            'phone': '',
            'avatar_url': null,
            'created_at': currentUser.createdAt ?? DateTime.now().toIso8601String(),
          };
          _usernameController.text = '';
          _fullNameController.text = '';
          _phoneController.text = '';
          _emailController.text = currentUser.email ?? '';
          _avatarUrl = null;
        });
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

      // อัปโหลดรูปภาพใหม่ (ถ้ามี)
      String? newAvatarUrl = _avatarUrl;
      if (_avatarBytes != null && _avatarFileName != null) {
        setState(() {
          _errorMessage = 'กำลังอัปโหลดรูปภาพ...';
        });

        try {
          final avatarUrl = await Supabase.instance.client.storage
              .from('avatars')
              .uploadBinary(
                'avatars/${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.${_avatarFileName!.split('.').last}',
                _avatarBytes!,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          
          newAvatarUrl = Supabase.instance.client.storage
              .from('avatars')
              .getPublicUrl(avatarUrl);
        } catch (e) {
          throw Exception('อัปโหลดรูปภาพไม่สำเร็จ: ${e.toString()}');
        }
      }

      // อัพเดทข้อมูลในตาราง users
      await SupabaseService.client
          .from('users')
          .update({
            'username': _usernameController.text.trim(),
            'full_name': _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            'avatar_url': newAvatarUrl,
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
            'avatar_url': newAvatarUrl,
          },
        ),
      );

      setState(() {
        _successMessage = 'อัพเดทข้อมูลสำเร็จ';
        _isEditing = false;
        _avatarUrl = newAvatarUrl;
        _avatarBytes = null;
        _avatarFileName = null;
      });

      // โหลดข้อมูลใหม่ทันทีเพื่ออัปเดตรูป
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
                          'โปรไฟล์คุณลูกค้า',
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
                                    GestureDetector(
                                      onTap: _isEditing ? _pickAvatar : null,
                                      child: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 50,
                                            backgroundColor: Colors.blue[100],
                                            backgroundImage: _getAvatarImage(),
                                            child: _shouldShowDefaultIcon()
                                                ? Icon(
                                                    Icons.person,
                                                    size: 50,
                                                    color: Colors.blue[600],
                                                  )
                                                : null,
                                          ),
                                          if (_isEditing)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[600],
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_isEditing)
                                      const SizedBox(height: 8),
                                    if (_isEditing)
                                      const Text(
                                        'แตะเพื่อเปลี่ยนรูปโปรไฟล์',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    
                                    // User info display
                                    if (!_isEditing) ...[
                                      _buildInfoRow('ชื่อผู้ใช้', _userData?['username'] ?? '-'),
                                      _buildInfoRow('ชื่อ-นามสกุล', _userData?['full_name'] ?? '-'),
                                      
                                      _buildInfoRow('เบอร์โทรศัพท์', _userData?['phone'] ?? '-'),
                                      _buildInfoRow('อีเมล', _userData?['email'] ?? '-'),
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
      final thaiYear = date.year + 543; // แปลงปี ค.ศ. เป็น พ.ศ.
      
      // ชื่อเดือนภาษาไทย
      const thaiMonths = [
        'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
      ];
      
      final monthName = thaiMonths[date.month - 1];
      return '${date.day} $monthName $thaiYear';
    } catch (e) {
      return dateString;
    }
  }

  /// เลือกรูปภาพสำหรับ Avatar
  Future<void> _pickAvatar() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'เลือกรูปภาพ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Web: แสดงแค่ File Picker
                // Mobile: แสดงทั้ง Camera และ Gallery
                if (kIsWeb) ...[
                  // Web - File Picker เท่านั้น
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        // ใช้ ImagePicker สำหรับ Web
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 85,
                        );
                        
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          Navigator.of(context).pop({
                            'bytes': bytes,
                            'fileName': image.name,
                          });
                        }
                      } catch (e) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('เลือกรูปภาพไม่สำเร็จ: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.file_upload),
                    label: const Text('เลือกไฟล์รูปภาพ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'รองรับไฟล์: JPG, PNG, GIF, WebP (สูงสุด 50MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  // Mobile - Camera และ Gallery
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                              maxHeight: 800,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              Navigator.of(context).pop({
                                'bytes': bytes,
                                'fileName': image.name,
                              });
                            }
                          } catch (e) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('เลือกรูปภาพไม่สำเร็จ: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('แกลเลอรี่'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.camera,
                              maxWidth: 800,
                              maxHeight: 800,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              Navigator.of(context).pop({
                                'bytes': bytes,
                                'fileName': image.name,
                              });
                            }
                          } catch (e) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ถ่ายรูปไม่สำเร็จ: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('กล้อง'),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ยกเลิก'),
                ),
              ],
            ),
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _avatarBytes = result['bytes'];
          _avatarFileName = result['fileName'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เลือกรูปภาพไม่สำเร็จ: ${e.toString()}';
      });
    }
  }
}
