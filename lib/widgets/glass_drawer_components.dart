import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../pages/user_profile_page.dart';
import '../pages/database_test_page.dart';
import '../main.dart';

// Glass Drawer Components
class GlassDrawer extends StatefulWidget {
  final Widget child;
  final double width;
  final double borderRadius;
  final double blurSigma;
  final double opacity;
  final EdgeInsetsGeometry? padding;

  const GlassDrawer({
    super.key,
    required this.child,
    this.width = 300,
    this.borderRadius = 20,
    this.blurSigma = 15,
    this.opacity = 0.1,
    this.padding,
  });

  @override
  State<GlassDrawer> createState() => _GlassDrawerState();
}

class _GlassDrawerState extends State<GlassDrawer> {
  double _rotation = 0.0;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotation += details.delta.dx * 0.5; // ปรับความโค้มตามการ swipe
    });
  }

  void _resetRotation() {
    setState(() {
      _rotation = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      child: Transform.rotate(
        angle: _rotation * 3.14159 / 180, // แปลงจากองศาเป็นเรียน
        child: Container(
          width: widget.width, // ใช้ widget.width แทน width
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF6A11CB), // ม่วงเข้ม
                Color(0xFF2575FC), // น้ำเงินเข้ม
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.borderRadius), // ใช้ widget.borderRadius
              bottomLeft: Radius.circular(widget.borderRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma), // ใช้ widget.blurSigma
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(widget.opacity), // ใช้ widget.opacity
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.borderRadius),
                  bottomLeft: Radius.circular(widget.borderRadius),
                ),
              ),
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.all(24.0), // ใช้ widget.padding
                child: widget.child, // ใช้ widget.child
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const GlassDrawerItem({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Colors.white,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

class GlassDrawerHeader extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final Widget? avatar;
  final VoidCallback? onProfileTap;
  final VoidCallback? onResetRotation;

  const GlassDrawerHeader({
    super.key,
    this.userName,
    this.userEmail,
    this.avatar,
    this.onProfileTap,
    this.onResetRotation,
  });

  @override
  Widget build(BuildContext context) {
    print('GlassDrawerHeader: Building header with userName: $userName, userEmail: $userEmail');
    
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: avatar ?? 
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6A11CB),
                        Color(0xFF2575FC),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // User Info
          if (userName != null) ...[
            Text(
              userName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          if (userEmail != null) ...[
            Text(
              userEmail!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],

          // Reset rotation button
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onResetRotation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'รีเซ็ต',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassDrawerDivider extends StatelessWidget {
  final double height;
  final Color? color;

  const GlassDrawerDivider({
    super.key,
    this.height = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color ?? Colors.white.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// Dashboard Drawer Content Widget
class DashboardDrawerContent extends StatefulWidget {
  const DashboardDrawerContent({super.key});

  @override
  State<DashboardDrawerContent> createState() => _DashboardDrawerContentState();
}

class _DashboardDrawerContentState extends State<DashboardDrawerContent> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  void _resetRotation() {
    // ส่งการเรียกค่า _resetRotation ไปยยังหลัง
    if (mounted) {
      // หากว่ามีการอ้างอิงกจาก drawer เพื่อรีเซ็ต
      final scaffoldState = context.findAncestorStateOfType<ScaffoldState>();
      if (scaffoldState != null) {
        // หากว่ามีการอ้าออิงกจาก drawer
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    print('DashboardDrawerContent: initState called');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      print('DashboardDrawer: Current user: ${user?.email}');
      
      if (user != null) {
        // ใช้วิธีการดึงข้อมูลผู้ใช้จาก Supabase โดยตรง
        final response = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        
        print('DashboardDrawer: User data response: $response');
        
        if (mounted) {
          setState(() {
            _currentUser = user;
            _userData = response;
            _isLoading = false;
          });
        }
      } else {
        print('DashboardDrawer: No user found');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('DashboardDrawer: Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MyHomePage(
              title: 'TREE LAW ZOO valley', 
              isGuestMode: false
            )
          ),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ออกจากระบบไม่สำเร็จ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calculate drawer width based on orientation and platform
  double _getDrawerWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;
    final platform = Theme.of(context).platform;
    
    // Web or landscape mode on mobile
    if (platform == TargetPlatform.macOS || 
        platform == TargetPlatform.windows || 
        platform == TargetPlatform.linux ||
        orientation == Orientation.landscape) {
      return screenWidth * 0.2; // 20% for landscape/web
    } else {
      return screenWidth * 0.75; // 75% for portrait mobile
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DashboardDrawer: Building drawer, isLoading: $_isLoading, currentUser: ${_currentUser?.email}');
    
    // แสดง drawer แม้ว่าจะมีข้อมูลหรือไม่
    return GlassDrawer(
      width: _getDrawerWidth(context),
      child: Column(
        children: [
          // Header
          GlassDrawerHeader(
            userName: 'Test User', // ใช้ค่าคงที่เพื่อทดสอบ
            userEmail: 'test@example.com', // ใช้ค่าคงที่เพื่อทดสอบ
            avatar: null,
            onProfileTap: () {
              Navigator.pop(context);
            },
            onResetRotation: _resetRotation, // เพิ่มฟังก์ชันรีเซ็ต
          ),
          
          const GlassDrawerDivider(),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                GlassDrawerItem(
                  icon: Icons.point_of_sale,
                  title: 'ขาย/POS',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                GlassDrawerItem(
                  icon: Icons.table_restaurant,
                  title: 'เปิดโต๊ะ',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                GlassDrawerItem(
                  icon: Icons.inventory,
                  title: 'คลังสินค้า',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                                GlassDrawerItem(
                  icon: Icons.inventory,
                  title: 'คูปอง/โปรโมชั่น',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                GlassDrawerItem(
                  icon: Icons.people,
                  title: 'ลูกค้า',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                GlassDrawerItem(
                  icon: Icons.handshake,
                  title: 'เจ้าหนี้/Partner',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const GlassDrawerDivider(),
                                GlassDrawerItem(
                  icon: Icons.person,
                  title: 'โฮมสตย์',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const GlassDrawerDivider(),
                                const GlassDrawerDivider(),
                                GlassDrawerItem(
                  icon: Icons.person,
                  title: 'ที่จอดรถ',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const GlassDrawerDivider(),
                GlassDrawerItem(
                  icon: Icons.person,
                  title: 'ข้อมูลส่วนตัว',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const GlassDrawerDivider(),
                GlassDrawerItem(
                  icon: Icons.settings,
                  title: 'ตั้งค่า',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                GlassDrawerItem(
                  icon: Icons.logout,
                  title: 'ออกจากระบบ',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}