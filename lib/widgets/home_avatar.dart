import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../services/user_group_service.dart';
import '../models/user_group_model.dart';
import 'dart:async';

/// Widget สำหรับแสดง Avatar ในหน้า Home พร้อม optimization และ auto refresh
class HomeAvatar extends StatefulWidget {
  final double radius;
  final VoidCallback? onTap;
  final bool isGuestMode;
  final double borderWidth;

  const HomeAvatar({
    super.key,
    this.radius = 25,
    this.onTap,
    required this.isGuestMode,
    this.borderWidth = 0.0,
  });

  @override
  State<HomeAvatar> createState() => _HomeAvatarState();
}

class _HomeAvatarState extends State<HomeAvatar> {
  String? _avatarUrl;
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSubscription;
  Color? _groupColor;

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// ฟังการเปลี่ยนแปลงของ Auth state
  void _listenToAuthChanges() {
    if (widget.isGuestMode) return;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent? event = data.event;
      
      debugPrint('HomeAvatar: Auth event: $event');
      
      // ถ้ามีการอัปเดท user metadata หรือ signed in ให้รีเฟรชรูป
      if (event == AuthChangeEvent.userUpdated || event == AuthChangeEvent.signedIn) {
        debugPrint('HomeAvatar: Auth state changed, refreshing avatar');
        _loadUserAvatar();
      }
      
      // เพิ่ม: ถ้ามีการเปลี่ยนแปลงใดๆ ให้รีเฟรชด้วย (เผื่อไว้)
      else if (event != null) {
        debugPrint('HomeAvatar: Any auth change, checking avatar');
        _loadUserAvatar();
      }
    });
  }

  /// โหลด avatar URL จาก user metadata และสีกลุ่มจากตาราง user_groups
  Future<void> _loadUserAvatar() async {
    if (widget.isGuestMode) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser?.userMetadata != null) {
        final metadata = currentUser!.userMetadata!;
        final avatarUrl = metadata['avatar_url'] as String?;
        
        debugPrint('HomeAvatar: Checking avatar URL: $avatarUrl');
        
        if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'pending') {
          setState(() {
            _avatarUrl = avatarUrl;
          });
          debugPrint('HomeAvatar: Set avatar URL: $avatarUrl');
        } else {
          setState(() {
            _avatarUrl = null;
          });
          debugPrint('HomeAvatar: Cleared avatar URL');
        }
        
        // โหลดสีกลุ่มจากตาราง user_groups ผ่าน UserGroupService
        try {
          final userGroup = await UserGroupService.getCurrentUserGroup();
          if (userGroup != null && userGroup.color != null) {
            setState(() {
              _groupColor = userGroup.colorValue;
            });
            debugPrint('HomeAvatar: Set group color from user_groups: ${userGroup.color}');
          } else {
            setState(() {
              _groupColor = null;
            });
            debugPrint('HomeAvatar: No group color found in user_groups');
          }
        } catch (e) {
          debugPrint('HomeAvatar: Error loading group color: $e');
          setState(() {
            _groupColor = null;
          });
        }
      }
    } catch (e) {
      debugPrint('HomeAvatar: Error loading avatar: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// สร้าง URL รูปที่ถูก optimize สำหรับแสดงในหน้า home
  String _getOptimizedAvatarUrl(String originalUrl) {
    try {
      // แก้ไข path ที่ซ้ำกัน: avatars/avatars/ → avatars/
      String fixedUrl = originalUrl;
      if (originalUrl.contains('/avatars/avatars/')) {
        fixedUrl = originalUrl.replaceFirst('/avatars/avatars/', '/avatars/');
        debugPrint('Fixed avatar URL: $fixedUrl');
      }
      
      return fixedUrl;
    } catch (e) {
      debugPrint('Error fixing avatar URL: $e');
      return originalUrl;
    }
  }

  /// ตรวจสอบว่าควรใช้ CachedNetworkImage หรือไม่
  bool _shouldUseCachedNetworkImage() {
    return _avatarUrl != null && 
           _avatarUrl!.isNotEmpty && 
           (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) &&
           !widget.isGuestMode;
  }

  @override
  Widget build(BuildContext context) {
    final hasBorder = widget.borderWidth > 0 && _groupColor != null;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: (widget.radius + (hasBorder ? widget.borderWidth : 0)) * 2,
        height: (widget.radius + (hasBorder ? widget.borderWidth : 0)) * 2,
        decoration: hasBorder ? BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _groupColor!,
            width: widget.borderWidth,
          ),
        ) : null,
        child: CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.white.withOpacity(0.9),
          child: widget.isGuestMode
              ? Icon(Icons.person_outline, color: Colors.grey[600], size: widget.radius)
              : _buildAvatarContent(),
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    // ถ้ากำลังโหลดให้แสดง progress
    if (_isLoading) {
      return Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: Colors.white.withOpacity(0.9),
            child: Icon(
              Icons.person,
              color: Colors.blue[600],
              size: widget.radius,
            ),
          ),
          Positioned.fill(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
          ),
        ],
      );
    }

    // ถ้ามี avatar URL ให้ใช้ CachedNetworkImage
    if (_shouldUseCachedNetworkImage()) {
      final imageUrl = _getOptimizedAvatarUrl(_avatarUrl!);
      debugPrint('HomeAvatar: Loading image from: $imageUrl');
      
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: widget.radius * 2,
            height: widget.radius * 2,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: widget.radius,
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: Icon(
                    Icons.person,
                    color: Colors.blue[600],
                    size: widget.radius,
                  ),
                ),
                Positioned.fill(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                  ),
                ),
              ],
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: widget.radius,
            backgroundColor: Colors.white.withOpacity(0.9),
            child: Icon(
              Icons.person,
              color: Colors.blue[600],
              size: widget.radius,
            ),
          ),
        ),
      );
    }

    // ถ้าไม่มี avatar ให้แสดง default icon
    return Icon(
      Icons.person,
      color: Colors.blue[600],
      size: widget.radius,
    );
  }
}
