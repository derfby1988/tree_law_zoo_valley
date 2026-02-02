import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_group_model.dart';
import '../services/supabase_service.dart';
import '../services/user_group_service.dart';
import '../services/group_form_config_service.dart';
import '../models/group_form_config_model.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/glass_dialog.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
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
  UserGroup? _userGroup;
  bool _isGroupLoading = false;
  bool _isFormLoading = false;
  
  // Avatar related
  bool _isAvatarLoading = false;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// ตรวจสอบว่ากำลังโหลดรูปจาก Supabase หรือไม่
  bool _shouldShowAvatarLoading() {
    return _isAvatarLoading;
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

  /// ตรวจสอบว่ามีรูป avatar หรือไม่
  bool _hasAvatar() {
    return _avatarUrl != null || _avatarBytes != null;
  }

  /// ตรวจสอบว่าควรแสดง default icon หรือไม่
  bool _shouldShowDefaultIcon() {
    return _avatarUrl == null && _avatarBytes == null;
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
        // เริ่ม loading สำหรับ avatar
        setState(() {
          _isAvatarLoading = true;
        });
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
              'user_group_id': metadata['user_group_id'],
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
          await _loadUserGroup();
          return; // ใช้ข้อมูลจาก auth แล้ว
        }
      } catch (e) {
        debugPrint('Error loading auth metadata: $e');
      } finally {
        // หยุด loading สำหรับ avatar
        setState(() {
          _isAvatarLoading = false;
        });
      }

      // 2. ถ้าไม่มีใน auth หรือ avatar_url เป็น pending ให้ลองจาก public.users
      debugPrint('Trying to load from public.users...');
      
      // เริ่ม loading สำหรับ avatar (กรณีโหลดจาก public.users)
      setState(() {
        _isAvatarLoading = true;
      });
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
            'user_group_id': null,
            'created_at': currentUser.createdAt ?? DateTime.now().toIso8601String(),
          };
          _usernameController.text = '';
          _fullNameController.text = '';
          _phoneController.text = '';
          _emailController.text = currentUser.email ?? '';
          _avatarUrl = null;
        });
      }
      
      // โหลดข้อมูลกลุ่มผู้ใช้จาก database
      await _loadUserGroup();
      
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isAvatarLoading = false; // หยุด avatar loading ในทุกกรณี
      });
    }
  }

  Future<void> _loadUserGroup() async {
    try {
      debugPrint('🔍 Loading user group...');
      final groupId = await UserGroupService.getCurrentUserGroupId();
      debugPrint('📊 Got group ID: $groupId');
      
      if (groupId != null) {
        final group = await UserGroupService.getGroupById(groupId);
        debugPrint('📋 Got group data: ${group?.displayName}');
        
        if (mounted) {
          setState(() {
            _userGroup = group;
          });
          debugPrint('✅ Updated UI with group: ${group?.displayName}');
        }
      } else {
        debugPrint('❌ No group ID found');
      }
    } catch (e) {
      debugPrint('❌ Error loading user group: $e');
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
                                          // Avatar หรือ Progress
                                          if (_shouldShowAvatarLoading())
                                            // Progress indicator ระหว่างโหลดจาก Supabase
                                            Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                shape: BoxShape.circle,
                                              ),
                                              child: Stack(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 50,
                                                    backgroundColor: Colors.blue[100],
                                                    child: _shouldShowDefaultIcon()
                                                        ? Icon(
                                                            Icons.person,
                                                            size: 50,
                                                            color: Colors.blue[600],
                                                          )
                                                        : null,
                                                  ),
                                                  Positioned.fill(
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 3,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (_shouldUseCachedNetworkImage())
                                            // ใช้ CachedNetworkImage สำหรับโหลดจาก Supabase Storage
                                            Container(
                                              width: 100,
                                              height: 100,
                                              child: Stack(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 50,
                                                    backgroundColor: Colors.blue[100],
                                                  ),
                                                  ClipOval(
                                                    child: CachedNetworkImage(
                                                      imageUrl: _getCachedImageUrl()!,
                                                      width: 100,
                                                      height: 100,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Container(
                                                        width: 100,
                                                        height: 100,
                                                        child: Stack(
                                                          children: [
                                                            CircleAvatar(
                                                              radius: 50,
                                                              backgroundColor: Colors.blue[100],
                                                              child: Icon(
                                                                Icons.person,
                                                                size: 50,
                                                                color: Colors.blue[600],
                                                              ),
                                                            ),
                                                            Positioned.fill(
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 3,
                                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) => CircleAvatar(
                                                        radius: 50,
                                                        backgroundColor: Colors.blue[100],
                                                        child: Icon(
                                                          Icons.person,
                                                          size: 50,
                                                          color: Colors.blue[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            // Avatar ปกติ (MemoryImage หรือ default)
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
                                      const Divider(height: 24),
                                      // User Group Section
                                      _buildUserGroupSection(),
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
      // เริ่ม loading state
      setState(() {
        _isAvatarLoading = true;
      });
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => GlassDialog(
          title: 'เลือกรูปภาพ',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Web: แสดงแค่ File Picker
              // Mobile: แสดงทั้ง Camera และ Gallery
              if (kIsWeb) ...[
                // Web - File Picker เท่านั้น
                GlassDialogButton(
                  text: 'เลือกไฟล์รูปภาพ',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_upload, size: 18),
                      SizedBox(width: 8),
                      Text('เลือกไฟล์รูปภาพ'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'รองรับไฟล์: JPG, PNG, GIF, WebP (สูงสุด 50MB)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Mobile - Camera และ Gallery
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GlassDialogButton(
                      text: 'แกลเลอรี่',
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library, size: 18),
                          SizedBox(width: 8),
                          Text('แกลเลอรี่'),
                        ],
                      ),
                    ),
                    GlassDialogButton(
                      text: 'กล้อง',
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, size: 18),
                          SizedBox(width: 8),
                          Text('กล้อง'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
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
    } finally {
      // หยุด loading state
      setState(() {
        _isAvatarLoading = false;
      });
    }
  }

  /// สร้าง UI ส่วนแสดงกลุ่มผู้ใช้
  Widget _buildUserGroupSection() {
    final group = _userGroup;
    final groupLabel = group?.displayName ?? 'ลูกค้า';
    final groupDesc = group?.displayDescription ?? '';
    final groupColor = group?.colorValue ?? const Color(0xFF4CAF50);
    final groupIcon = group?.iconData ?? Icons.person;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ประเภทผู้ใช้',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: groupColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: groupColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: groupColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  groupIcon,
                  color: groupColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: groupColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      groupDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Get screen width for responsive button sizing
        LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
            final buttonWidth = isLandscape ? MediaQuery.of(context).size.width * 0.5 : double.infinity;
            
            return Center(
              child: SizedBox(
                width: buttonWidth,
                child: OutlinedButton.icon(
                  onPressed: _isGroupLoading ? null : _showGroupSelectionDialog,
                  icon: _isGroupLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue[600],
                          ),
                        )
                      : Icon(Icons.swap_horiz, size: 18, color: Colors.blue[600]),
                  label: Text(
                    'เปลี่ยนประเภทผู้ใช้',
                    style: TextStyle(color: Colors.blue[600]),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue[600]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// แสดง Dialog เลือกกลุ่มผู้ใช้
  Future<void> _showGroupSelectionDialog() async {
    final availableGroups = await UserGroupService.getAvailableGroups();
    
    if (!mounted) return;

    final selectedGroup = await showDialog<UserGroup>(
      context: context,
      builder: (context) => GlassDialog(
        title: 'เลือกประเภทผู้ใช้',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight * 0.7;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'เลือกประเภทผู้ใช้ที่ตรงกับบทบาทของคุณ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ...availableGroups.map((group) {
                            final isSelected = _userGroup?.id == group.id;
                            final color = group.colorValue;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassDialogButton(
                                text: group.displayName,
                                onPressed: () => Navigator.of(context).pop(group),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        group.iconData,
                                        color: color,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.displayName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            group.displayDescription,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, color: Colors.green[300]),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassDialogButton(
                    text: 'ยกเลิก',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (selectedGroup != null && selectedGroup.id != _userGroup?.id) {
      final canProceed = await _ensureGroupRequirements(selectedGroup);
      if (!canProceed) return;
      await _updateUserGroup(selectedGroup.id);
    }
  }

  Future<bool> _ensureGroupRequirements(UserGroup selectedGroup) async {
    if (_isFormLoading) return false;

    setState(() {
      _isFormLoading = true;
    });

    try {
      final config = await GroupFormConfigService.getFormConfigByGroupId(selectedGroup.id);
      if (config == null || config.fields.isEmpty) {
        return !selectedGroup.requiresProfileCompletion;
      }

      if (!config.isRequired) return true;

      final completed = await _showProfileCompletionDialog(config, selectedGroup);
      return completed;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ตรวจสอบข้อมูลไม่สำเร็จ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isFormLoading = false;
        });
      }
    }
  }

  Future<bool> _showProfileCompletionDialog(
    GroupFormConfig config,
    UserGroup group,
  ) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return false;

    final existingData = await GroupFormConfigService.getUserFormData(
      userId: currentUser.id,
      groupId: group.id,
    );

    final controllers = <String, TextEditingController>{};
    final dropdownValues = <String, String?>{};
    Uint8List? avatarBytes;
    String? avatarFileName;
    Map<String, dynamic>? pendingFormData;

    for (final field in config.fields) {
      final initialValue = _getInitialFieldValue(field, existingData);
      if (field.type == FormFieldType.dropdown) {
        dropdownValues[field.key] = initialValue;
      } else if (field.type != FormFieldType.image) {
        controllers[field.key] = TextEditingController(text: initialValue);
      }
    }

    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GlassDialog(
        title: config.dialogTitle,
        child: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (config.dialogDescription != null && config.dialogDescription!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      config.dialogDescription!,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ...config.fields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildFormField(
                      field: field,
                      controller: controllers[field.key],
                      dropdownValue: dropdownValues[field.key],
                      onDropdownChanged: (value) {
                        setDialogState(() {
                          dropdownValues[field.key] = value;
                        });
                      },
                      avatarUrl: _avatarUrl,
                      onAvatarSelected: (bytes, fileName) {
                        setDialogState(() {
                          avatarBytes = bytes;
                          avatarFileName = fileName;
                        });
                      },
                    ),
                  );
                }).toList(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassDialogButton(
                        text: 'ยกเลิก',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassDialogButton(
                        text: 'บันทึก',
                        isPrimary: true,
                        onPressed: () async {
                          final validationError = _validateFormFields(
                            config: config,
                            controllers: controllers,
                            dropdownValues: dropdownValues,
                            hasAvatar: _hasAvatar() || avatarBytes != null,
                          );
                          if (validationError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(validationError),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final formData = <String, dynamic>{};
                          for (final field in config.fields) {
                            if (field.type == FormFieldType.image) {
                              formData[field.key] = _avatarUrl;
                            } else if (field.type == FormFieldType.dropdown) {
                              formData[field.key] = dropdownValues[field.key];
                            } else {
                              formData[field.key] = controllers[field.key]?.text.trim();
                            }
                          }

                          pendingFormData = formData;
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      if (avatarBytes != null && avatarFileName != null) {
        final uploaded = await _uploadAvatarOnly(
          bytes: avatarBytes!,
          fileName: avatarFileName!,
        );
        if (!uploaded) {
          for (final controller in controllers.values) {
            controller.dispose();
          }
          return false;
        }
      }

      final formData = <String, dynamic>{};
      for (final field in config.fields) {
        if (field.type == FormFieldType.image) {
          formData[field.key] = _avatarUrl;
        } else if (field.type == FormFieldType.dropdown) {
          formData[field.key] = dropdownValues[field.key];
        } else {
          formData[field.key] = controllers[field.key]?.text.trim();
        }
      }

      final saved = await GroupFormConfigService.saveUserFormData(
        userId: currentUser.id,
        groupId: group.id,
        formData: formData,
        isCompleted: true,
      );

      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกข้อมูลไม่สำเร็จ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    for (final controller in controllers.values) {
      controller.dispose();
    }

    return result == true;
  }

  String? _getInitialFieldValue(
    FormFieldConfig field,
    Map<String, dynamic>? existingData,
  ) {
    final key = field.key;
    if (key == 'full_name') return _fullNameController.text;
    if (key == 'phone') return _phoneController.text;
    if (key == 'email') return _emailController.text;
    return existingData?[key]?.toString();
  }

  String? _validateFormFields({
    required GroupFormConfig config,
    required Map<String, TextEditingController> controllers,
    required Map<String, String?> dropdownValues,
    required bool hasAvatar,
  }) {
    for (final field in config.fields) {
      if (!field.required) continue;
      if (field.type == FormFieldType.image) {
        if (!hasAvatar) return 'กรุณาอัปโหลดรูปโปรไฟล์';
        continue;
      }
      if (field.type == FormFieldType.dropdown) {
        if (dropdownValues[field.key] == null || dropdownValues[field.key]!.isEmpty) {
          return 'กรุณาเลือก ${field.label}';
        }
        continue;
      }
      final value = controllers[field.key]?.text.trim() ?? '';
      if (value.isEmpty) return 'กรุณากรอก ${field.label}';
    }
    return null;
  }

  Widget _buildFormField({
    required FormFieldConfig field,
    TextEditingController? controller,
    String? dropdownValue,
    required ValueChanged<String?> onDropdownChanged,
    required String? avatarUrl,
    required void Function(Uint8List?, String?) onAvatarSelected,
  }) {
    final label = field.required ? '${field.label} *' : field.label;

    if (field.type == FormFieldType.image) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          AvatarPicker(
            currentAvatarUrl: avatarUrl,
            onImageSelected: onAvatarSelected,
            radius: 40,
          ),
        ],
      );
    }

    if (field.type == FormFieldType.dropdown) {
      final options = (field.config?['options'] as List<dynamic>?)?.cast<String>() ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: dropdownValue,
            items: options
                .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                .toList(),
            onChanged: onDropdownChanged,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    }

    final keyboardType = switch (field.type) {
      FormFieldType.phone => TextInputType.phone,
      FormFieldType.email => TextInputType.emailAddress,
      FormFieldType.number => TextInputType.number,
      FormFieldType.textarea => TextInputType.multiline,
      _ => TextInputType.text,
    };

    final maxLines = field.type == FormFieldType.textarea ? 3 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Future<bool> _uploadAvatarOnly({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return false;

      final path = 'avatars/${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.${fileName.split('.').last}';
      final avatarUrl = await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(avatarUrl);

      await SupabaseService.client.from('users').update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', currentUser.id);

      await SupabaseService.client.auth.updateUser(
        UserAttributes(
          data: {
            'avatar_url': publicUrl,
          },
        ),
      );

      setState(() {
        _avatarUrl = publicUrl;
        _avatarBytes = null;
        _avatarFileName = null;
      });

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปโหลดรูปภาพไม่สำเร็จ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// อัปเดตกลุ่มผู้ใช้
  Future<void> _updateUserGroup(String groupId) async {
    setState(() {
      _isGroupLoading = true;
    });

    try {
      final success = await UserGroupService.updateUserGroup(groupId);
      
      if (success) {
        final newGroup = await UserGroupService.getGroupById(groupId);
        setState(() {
          _userGroup = newGroup;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เปลี่ยนประเภทผู้ใช้เป็น "${newGroup?.displayName ?? groupId}" สำเร็จ'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('ไม่สามารถอัปเดตประเภทผู้ใช้ได้');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isGroupLoading = false;
      });
    }
  }
}
