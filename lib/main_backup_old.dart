import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/otp_service.dart';
import 'register_page_clean.dart';
import 'pages/user_profile_page.dart';
import 'widgets/forgot_password_dialog.dart';
import 'pages/restaurant_menu_page.dart';
import 'pages/table_booking_page.dart';
import 'pages/room_booking_page.dart';
import 'pages/database_test_page.dart';
import 'reset_password_page.dart';
import 'auth_state_observer.dart';
import 'widgets/home_avatar.dart';

// Helper function to validate email or phone
bool isValidEmailOrPhone(String input) {
  // Email validation
  if (input.contains('@')) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
  }
  
  // Phone validation (Thai phone numbers)
  return RegExp(r'^0[689]\d{8}$').hasMatch(input);
}

String? validateEmailOrPhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'กรุณากรอก เบอร์โทรศัพท์ หรือ ชื่อเข้าใช้งาน หรือ อีเมล';
  }
  
  if (!isValidEmailOrPhone(value)) {
    return 'กรุณากรอกเบอร์โทรศัพท์ หรือ ชื่อเข้าใช้งาน หรือ อีเมล ให้ถูกต้อง';
  }
  
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TREE LAW ZOO valley',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthStateObserver(
        child: MyHomePage(
          title: 'TREE LAW ZOO valley',
          isGuestMode: true, // ✅ เริ่มต้นที่ Home Page โดยตรง
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize and check auth state after a short delay
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Wait for Supabase to be fully initialized
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Listen to auth state changes
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (mounted) { // Check if widget is still in the tree
        if (session == null) {
          // ไปหน้า login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RegisterPageClean(),
          ),
        );
        }
      }
    });
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Loading Screen
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF81D4FA),
                Color(0xFF80CBC4),
                Color(0xFF81C784),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  'กำลังเชื่อมต่อ...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check if user is logged in
    final user = SupabaseService.currentUser;
    if (user != null) {
      // User is logged in, show main app
      return const MyHomePage(
        title: 'TREE LAW ZOO valley',
        isGuestMode: false,
      );
    } else {
      // User is not logged in, show login
      return const RegisterPageClean();
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.isGuestMode = false});

  final String title;
  final bool isGuestMode;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final currentUser = Supabase.instance.client.auth.currentUser;
  String? _userFullName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser != null) {
      // ใช้ข้อมูลจาก user metadata แทนการ query จากตาราง profiles
      final userMetadata = currentUser!.userMetadata;
      final fullName = userMetadata?['full_name'] as String?;
      final username = userMetadata?['username'] as String?;
      
      if (mounted) {
        setState(() {
          _userFullName = fullName ?? username ?? currentUser?.email?.split('@')[0] ?? 'สมาชิก';
        });
      }
    }
  }
  bool get isLoggedIn => currentUser != null;

  void _login() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegisterPageClean(),
      ),
    );
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
  
    // Navigate กลับไปหน้าแรก (Guest Mode)
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(
            title: 'TREE LAW ZOO valley',
            isGuestMode: true,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      endDrawer: _buildEndDrawer(),
      body: Builder(
        builder: (context) => GestureDetector(
          onPanEnd: (details) {
            // ตรวจสอบการปัดจากขวาไปซ้าย (เปิด EndDrawer)
            if (details.velocity.pixelsPerSecond.dx > 300) {
              Scaffold.of(context).openEndDrawer();
            }
            // ตรวจสอบการปัดจากซ้ายไปขวา (เปิด Drawer)
            else if (details.velocity.pixelsPerSecond.dx < -300) {
              Scaffold.of(context).openDrawer();
            }
          },
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF81D4FA),
                  Color(0xFF80CBC4),
                  Color(0xFF81C784),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Header แยกตาม mode
                    _buildHeader(),
                    
                    const SizedBox(height: 40),
                    
                    // ✅ App Title
                    Center(
                      child: _buildAppTitle(),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // ✅ Menu Buttons แยกตาม mode
                    Expanded(
                      child: Center(
                        child: GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 1.2,
                          children: _buildMenuButtons(),
                        ),
                      ),
                    ),
                    
                    // ✅ Footer
                    Center(
                      child: _buildFooter(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // EndDrawer (ด้านขวา - เปิดโดยปัดจากขวา)
  Widget _buildEndDrawer() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF81D4FA),
            Color(0xFF80CBC4),
            Color(0xFF81C784),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header with close button
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white54, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Left side - Title
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'TREE LAW ZOO Valley',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Right side - Close Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ปิด',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Functions
                  _buildSectionHeader('🍽️ ฟังก์ชันหลัก'),
                  _buildDrawerItem(Icons.restaurant, 'สั่งอาหาร', 'สั่งอาหาร'),
                  _buildDrawerItem(Icons.table_restaurant, 'จองโต๊ะ', 'จองโต๊ะ'),
                  _buildDrawerItem(Icons.bed, 'จองที่พัก', 'จองที่พัก'),
                  _buildDrawerItem(Icons.history, 'ติดตามคิว', 'ติดตามคิว'),
                  _buildDrawerItem(Icons.storage, 'Database Test', 'Database Test'),
                  
                  const SizedBox(height: 20),
                  
                  // System Management
                  _buildSectionHeader('📊 ระบบจัดการ'),
                  _buildDrawerItem(Icons.people, 'จัดการผู้ใช้', 'จัดการผู้ใช้'),
                  _buildDrawerItem(Icons.analytics, 'รายงาน', 'รายงาน'),
                  _buildDrawerItem(Icons.settings, 'การตั้งค่า', 'การตั้งค่า'),
                  
                  const SizedBox(height: 20),
                  
                  // System Tools
                  _buildSectionHeader('🔧 ระบบ'),
                  _buildDrawerItem(Icons.sync, 'Sync Data', 'Sync Data'),
                  _buildDrawerItem(Icons.backup, 'Backup Database', 'Backup Database'),
                  _buildDrawerItem(Icons.wifi, 'Network Status', 'Network Status'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Drawer (ด้านซ้าย - สำหรับผู้ใช้)
  Widget _buildDrawer() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF81D4FA),
            Color(0xFF80CBC4),
            Color(0xFF81C784),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    HomeAvatar(
                      radius: 30,
                      isGuestMode: widget.isGuestMode,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isGuestMode ? 'Guest User' : 'User Name',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.isGuestMode ? 'guest@example.com' : 'user@example.com',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white54),
              
              // User Functions
              _buildSectionHeader('🎯 ข้อมูลส่วนตัว'),
              _buildDrawerItem(Icons.person, 'แก้ไขโปรไฟล์', 'แก้ไขโปรไฟล์'),
              _buildDrawerItem(Icons.notifications, 'การแจ้งเตือน', 'การแจ้งเตือน'),
              _buildDrawerItem(Icons.palette, 'ธีมแอป', 'ธีมแอป'),
              _buildDrawerItem(Icons.language, 'ภาษา', 'ภาษา'),
              
              const SizedBox(height: 20),
              
              // Security
              _buildSectionHeader('🔐 ความปลอดภัย'),
              _buildDrawerItem(Icons.lock, 'เปลี่ยนรหัสผ่าน', 'เปลี่ยนรหัสผ่าน'),
              _buildDrawerItem(Icons.security, '2FA Settings', '2FA Settings'),
              
              const SizedBox(height: 20),
              
              // Account Info
              _buildSectionHeader('📊 สถานะบัญชี'),
              _buildDrawerItem(Icons.history, 'ประวัติการใช้งาน', 'ประวัติการใช้งาน'),
              _buildDrawerItem(Icons.bar_chart, 'สถิติการใช้งาน', 'สถิติการใช้งาน'),
              
              const Spacer(),
              
              // Logout
              if (!widget.isGuestMode)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('ออกจากระบบ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Section Header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Drawer Item
  Widget _buildDrawerItem(IconData icon, String title, String menuTitle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            _handleMenuTap(menuTitle);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _login() async {
    // ไปหน้า login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const RegisterPageClean(),
      ),
    );
  }

  void _logout() async {
    try {
      await Supabase.client.auth.signOut();
      // กลับไปหน้า login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const RegisterPageClean(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e')),
      );
    }
  }

  // Header แยกตาม mode
  Widget _buildHeader() {
    return Row(
      children: [
        // Menu button (เปิด Drawer ด้านซ้าย)
        GestureDetector(
          onTap: () {
            Scaffold.of(context).openDrawer();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.menu,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        
        const Spacer(),
        
        // User profile avatar
        GestureDetector(
          onTap: widget.isGuestMode ? null : () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const UserProfilePage(),
              ),
            );
          },
          child: HomeAvatar(
            radius: 25,
            isGuestMode: widget.isGuestMode,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Settings button (เปิด EndDrawer ด้านขวา)
        GestureDetector(
          onTap: () {
            Scaffold.of(context).openEndDrawer();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  // App Title
  Widget _buildAppTitle() {
    return Column(
      children: [
        Text(
          'TREE LAW ZOO Valley',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ร้านอาหาร & ที่พัก',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withOpacity(0.9),
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Menu Buttons แยกตาม mode
  List<Widget> _buildMenuButtons() {
    final menuItems = [
      {'icon': Icons.restaurant, 'title': 'สั่งอาหาร', 'guestAllowed': true},
      {'icon': Icons.table_restaurant, 'title': 'จองโต๊ะ', 'guestAllowed': true},
      {'icon': Icons.bed, 'title': 'จองที่พัก', 'guestAllowed': true},
      {'icon': Icons.history, 'title': 'ติดตามคิว / ข้อมูลการจอง (โต๊ะ/ที่พัก)', 'guestAllowed': false},
      {'icon': Icons.storage, 'title': 'Database Test', 'guestAllowed': false},
    ];

    return menuItems.map((item) {
      final bool isAllowed = widget.isGuestMode ? item['guestAllowed'] as bool : true;
      
      return _buildMenuButton(
        icon: item['icon'] as IconData,
        title: item['title'] as String,
        guestAllowed: item['guestAllowed'] as bool,
        isAllowed: isAllowed,
      );
    }).toList();
  }

  // Menu Button แยกตาม mode
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required bool guestAllowed,
    required bool isAllowed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isAllowed 
            ? Colors.white.withOpacity(0.9)
            : Colors.grey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAllowed ? () => _handleMenuTap(title) : null,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isAllowed ? Colors.green[700] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isAllowed ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                if (!isAllowed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'ต้องเข้าสู่ระบบ',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
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

  void _handleMenuTap(String title) {
    switch (title) {
      case 'สั่งอาหาร':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RestaurantMenuPage(isGuestMode: widget.isGuestMode),
          ),
        );
        break;
      case 'จองโต๊ะ':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TableBookingPage(isGuestMode: widget.isGuestMode),
          ),
        );
        break;
      case 'จองที่พัก':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RoomBookingPage(isGuestMode: widget.isGuestMode),
          ),
        );
        break;
      case 'ประวัติ':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DatabaseTestPage(),
          ),
        );
        break;
      case 'Database Test':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DatabaseTestPage(),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('กำลังพัฒนาหน้า $title...')),
        );
    }
  }

  // Footer
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            width: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

class _MyHomePageState extends State<MyHomePage> {
  String? _userFullName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // โหลดข้อมูลผู้ใช้จาก Supabase หรือ localStorage
    final user = Supabase.client.auth.currentUser;
    if (user != null) {
      // ดึงข้อมูลจาก user_profiles table
      try {
        final response = await Supabase.client
            .from('user_profiles')
            .select('full_name')
            .eq('user_id', user.id)
            .single();
        
        if (response != null) {
          setState(() {
            _userFullName = response['full_name'] ?? 'ผู้ใช้';
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
        setState(() {
          _userFullName = 'ผู้ใช้';
        });
      }
    }
  }

  void _handleMenuTap(String title) {
    switch (title) {
      case 'สั่งอาหาร':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RestaurantMenuPage(isGuestMode: widget.isGuestMode),
          ),
        );
        break;
      case 'จองโต๊ะ':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TableBookingPage(isGuestMode: widget.isGuestMode),
          ),
        );
        break;
      case 'จองที่พัก':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RoomBookingPage(isGuestMode: widget.isGuestMode),
          ),
        );
        break;
      case 'ประวัติ':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DatabaseTestPage(),
          ),
        );
        break;
      case 'Database Test':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DatabaseTestPage(),
          ),
        );
        break;
      case 'ติดตามคิว':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าติดตามคิว...')),
        );
        break;
      case 'จัดการผู้ใช้':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าจัดการผู้ใช้...')),
        );
        break;
      case 'รายงาน':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้ารายงาน...')),
        );
        break;
      case 'การตั้งค่า':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าการตั้งค่า...')),
        );
        break;
      case 'Sync Data':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังทำการ Sync Data...')),
        );
        break;
      case 'Backup Database':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังทำการ Backup Database...')),
        );
        break;
      case 'Network Status':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้า Network Status...')),
        );
        break;
      case 'แก้ไขโปรไฟล์':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const UserProfilePage(),
          ),
        );
        break;
      case 'การแจ้งเตือน':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าการแจ้งเตือน...')),
        );
        break;
      case 'ธีมแอป':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าธีมแอป...')),
        );
        break;
      case 'ภาษา':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าภาษา...')),
        );
        break;
      case 'เปลี่ยนรหัสผ่าน':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าเปลี่ยนรหัสผ่าน...')),
        );
        break;
      case '2FA Settings':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้า 2FA Settings...')),
        );
        break;
      case 'ประวัติการใช้งาน':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าประวัติการใช้งาน...')),
        );
        break;
      case 'สถิติการใช้งาน':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนาหน้าสถิติการใช้งาน...')),
        );
        break;
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialIcon(Icons.phone, Colors.green),
              _buildSocialIcon(Icons.message, Colors.blue),
              _buildSocialIcon(Icons.location_on, Colors.red),
              _buildSocialIcon(Icons.info, Colors.orange),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ติดต่อ CEO : ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Text(
                'treelawzoo@gmail.com',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }
}
