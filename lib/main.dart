import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'utils/buddhist_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/otp_service.dart';
import 'config/business_settings.dart';
import 'register_page_clean.dart';
import 'pages/user_profile_page.dart';
import 'widgets/forgot_password_dialog.dart';
import 'pages/restaurant_menu_page.dart';
import 'pages/table_booking_page.dart';
import 'pages/room_booking_page.dart';
import 'pages/database_test_page.dart';
import 'pages/coupon_promotion_page.dart';
import 'widgets/glass_drawer_components.dart';
import 'reset_password_page.dart';
import 'auth_state_observer.dart';
import 'widgets/home_avatar.dart';
import 'widgets/home_left_drawer.dart';
import 'widgets/home_end_drawer.dart';
import 'widgets/drawer_clippers.dart';
import 'pages/inventory_page.dart';
import 'pages/HRM.dart';
import 'pages/user_permissions_page.dart';
import 'pages/inventory/tax_rules_admin_page.dart';
import 'pages/inventory/stock_movement_page.dart';
import 'pages/reports_page.dart';
import 'pages/table_management_page.dart';
import 'pages/pos_page.dart';
import 'services/permission_service.dart';
import 'services/user_group_service.dart';
import 'theme/app_design_system.dart';

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
      title: AppBusinessSettings.restaurantName,
      theme: AppDesignSystem.theme(),
      localizationsDelegates: const [
        BuddhistMaterialLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'), // Thai
        Locale('en', 'US'), // English
      ],
      locale: const Locale('th', 'TH'),
      home: const AuthStateObserver(
        child: MyHomePage(
          title: AppBusinessSettings.restaurantName,
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
          // User is not logged in, navigate to login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
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
                Color(0xFF4992E7),
                Color(0xFF68CB9C),
                Color(0xFF2AD49B),
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
        title: AppBusinessSettings.restaurantName,
        isGuestMode: false,
      );
    } else {
      // User is not logged in, show login
      return const LoginPage();
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final currentUser = Supabase.instance.client.auth.currentUser;
  String? _userFullName;
  int? _currentUserSortOrder;

  /// ตรวจสอบสิทธิ์ endDrawer จากระบบสิทธิ์ (toggle ได้ในหน้าจัดการสิทธิ์ผู้ใช้)
  /// ยกเว้นลำดับที่ 1 เข้าถึงได้เสมอ
  bool get _canAccessEndDrawer => _currentUserSortOrder == 1 || PermissionService.canAccessPageSync('end_drawer');

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
      
      // โหลด sort_order ของกลุ่มผู้ใช้ปัจจุบัน (ลำดับ 1 เข้าถึง endDrawer ได้เสมอ)
      final sortOrder = await UserGroupService.getCurrentUserSortOrder();
      
      if (mounted) {
        setState(() {
          _userFullName = fullName ?? username ?? currentUser?.email?.split('@')[0] ?? 'สมาชิก';
          _currentUserSortOrder = sortOrder;
        });
      }
    }
  }
  bool get isLoggedIn => currentUser != null;

  void _login() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
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
            title: AppBusinessSettings.restaurantName,
            isGuestMode: true,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('MyHomePage: Building with currentUser: ${currentUser?.email}, isGuestMode: ${widget.isGuestMode}');
    
    // ตรวจสอบการหมุนหน้าจอและกำหนดขนาด drawer
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait = screenHeight > screenWidth;
    final drawerWidth = isPortrait ? screenWidth * 0.75 : screenWidth * 0.25;
    
    print('Screen: ${screenWidth}x${screenHeight}, isPortrait: $isPortrait, drawerWidth: $drawerWidth');
    
    // สร้าง GestureDetector สำหรับ swipe gestures
    return GestureDetector(
      onPanEnd: (details) {
        print('Swipe detected: velocity.dx = ${details.velocity.pixelsPerSecond.dx}');
        
        // ตรวจสอบทิศทางการ swipe
        if (details.velocity.pixelsPerSecond.dx > 500) {
          // Swipe ขวา (dx > 0) เพื่อเปิด drawer ด้านซ้าย (ทำงานได้เสมอ)
          print('Opening left drawer with right swipe');
          _scaffoldKey.currentState?.openDrawer();
        } else if (details.velocity.pixelsPerSecond.dx < -500) {
          // Swipe ซ้าย (dx < 0) เพื่อเปิด end drawer ด้านขวา (ต้องเป็นพนักงานร้านขึ้นไป)
          if (!widget.isGuestMode && currentUser != null && _canAccessEndDrawer) {
            print('Opening right drawer with left swipe');
            _scaffoldKey.currentState?.openEndDrawer();
          } else {
            print('Right drawer requires staff or above - swipe ignored');
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        // Shared left drawer
        drawer: HomeLeftDrawer(
          isGuestMode: widget.isGuestMode,
          onHomeTap: () {
            Navigator.pop(context);
            Navigator.of(this.context).popUntil((route) => route.isFirst);
          },
          onTableBookingTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => TableBookingPage(isGuestMode: widget.isGuestMode)));
          },
        ),
        // Shared end drawer
        endDrawer: !widget.isGuestMode && currentUser != null && _canAccessEndDrawer
            ? HomeEndDrawer(drawerWidth: drawerWidth)
            : null,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppDesignSystem.secondary,
                AppDesignSystem.primary,
                Color(0xFF68CB9C),
              ],
            ),
          ),
          child: SafeArea(
            child: Builder(
              builder: (context) {
                final media = MediaQuery.of(context).size;
                final isLandscape = media.width > media.height;
                final isSmallScreen = media.width < 400;
                final needsCompactLayout = isLandscape && isSmallScreen;
                final bool compactTitle = isLandscape;
                final bool compactFooter = isLandscape;

                final double headerHeight = needsCompactLayout ? 40 : 80;
                final double sectionSpacing = needsCompactLayout
                    ? 5
                    : (isLandscape ? 10 : 20);
                final double outerPadding = needsCompactLayout ? 10 : 20;
                final bool showFooter = !needsCompactLayout;

                return Padding(
                  padding: EdgeInsets.only(
                    left: outerPadding,
                    right: outerPadding,
                    top: outerPadding,
                    bottom: needsCompactLayout ? 0 : outerPadding,
                  ),
                  child: needsCompactLayout
                    ? Column(
                        children: [
                          // ✅ Header แยกตาม mode (ไม่ scroll)
                          SizedBox(
                            height: headerHeight,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildHeader(compact: needsCompactLayout),
                              ),
                            ),
                          ),

                          SizedBox(height: sectionSpacing),

                          // ✅ App Title (ไม่ scroll)
                          Center(
                            child: _buildAppTitle(compact: compactTitle),
                          ),

                          SizedBox(height: sectionSpacing),

                          // ✅ Menu Buttons - Scroll เฉพาะส่วนนี้
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: GestureDetector(
                                  onPanEnd: (details) {
                                    // Swipe gesture สำหรับเปิด drawer
                                    if (details.velocity.pixelsPerSecond.dx > 200) {
                                      _scaffoldKey.currentState?.openDrawer();
                                    } else if (details.velocity.pixelsPerSecond.dx < -200) {
                                      if (!widget.isGuestMode && currentUser != null && _canAccessEndDrawer) {
                                        _scaffoldKey.currentState?.openEndDrawer();
                                      }
                                    }
                                  },
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // 📱 ใช้ MediaQuery แทน constraints เพื่อขนาดจริงของหน้าจอ
                                      final screenWidth = MediaQuery.of(context).size.width - (outerPadding * 2);
                                      const crossAxisCount = 2;
                                      final double spacing = screenWidth < 600 ? 12 : 18;
                                      final double aspectRatio = screenWidth < 600 ? 1.25 : 1.15;

                                      print('🔥 Responsive Grid: screenWidth=$screenWidth, columns=$crossAxisCount, spacing=$spacing');

                                      final menuItems = _buildMenuButtons();
                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: spacing,
                                        alignment: WrapAlignment.center,
                                        children: menuItems.map((item) => SizedBox(
                                          width: (screenWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount,
                                          child: AspectRatio(
                                            aspectRatio: aspectRatio,
                                            child: item,
                                          ),
                                        )).toList(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ✅ Footer (ไม่ scroll) - ชิดขอบล่างใน compact mode
                          if (showFooter)
                            _buildFooter(compact: compactFooter),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Header แยกตาม mode (ไม่ scroll)
                          SizedBox(
                            height: headerHeight,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildHeader(compact: needsCompactLayout),
                              ),
                            ),
                          ),

                          SizedBox(height: sectionSpacing),

                          // ✅ App Title (ไม่ scroll)
                          Center(
                            child: _buildAppTitle(compact: compactTitle),
                          ),

                          SizedBox(height: sectionSpacing),

                          // ✅ Menu Buttons - Scroll เฉพาะส่วนนี้
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: GestureDetector(
                                  onPanEnd: (details) {
                                    // Swipe gesture สำหรับเปิด drawer
                                    if (details.velocity.pixelsPerSecond.dx > 200) {
                                      _scaffoldKey.currentState?.openDrawer();
                                    } else if (details.velocity.pixelsPerSecond.dx < -200) {
                                      if (!widget.isGuestMode && currentUser != null && _canAccessEndDrawer) {
                                        _scaffoldKey.currentState?.openEndDrawer();
                                      }
                                    }
                                  },
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // 📱 ใช้ MediaQuery แทน constraints เพื่อขนาดจริงของหน้าจอ
                                      final screenWidth = MediaQuery.of(context).size.width - (outerPadding * 2);
                                      const crossAxisCount = 2;
                                      final double spacing = screenWidth < 600 ? 12 : 18;
                                      final double aspectRatio = screenWidth < 600 ? 1.25 : 1.15;

                                      print('🔥 Responsive Grid: screenWidth=$screenWidth, columns=$crossAxisCount, spacing=$spacing');

                                      final menuItems = _buildMenuButtons();
                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: spacing,
                                        alignment: WrapAlignment.center,
                                        children: menuItems.map((item) => SizedBox(
                                          width: (screenWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount,
                                          child: AspectRatio(
                                            aspectRatio: aspectRatio,
                                            child: item,
                                          ),
                                        )).toList(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: sectionSpacing),

                          // ✅ Footer (ไม่ scroll)
                          if (showFooter)
                            Center(
                              child: _buildFooter(compact: compactFooter),
                            ),
                        ],
                      ),
                );
              },
            ),
        ),
      ),
    ),
  );
  }

  // Header แยกตาม mode
  Widget _buildHeader({bool compact = false}) {
    return Row(
      children: [
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
            radius: compact ? 16 : 25,
            isGuestMode: widget.isGuestMode,
            borderWidth: 0.5,
          ),
        ),
        SizedBox(width: compact ? 8 : 15),
        
        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (!widget.isGuestMode) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UserProfilePage(),
                      ),
                    );
                  }
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.isGuestMode ? 'สวัสดี คุณลูกค้า' : 'สวัสดีคุณ $_userFullName',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: compact ? 12 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 0 : 4),
              if (!compact)
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        children: [
                          TextSpan(text: widget.isGuestMode ? 'กรุณา ' : 'พัก กิน ดื่ม เที่ยว เสมือน "บ้าน" ของคุณ'),
                      if (widget.isGuestMode)
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              // Navigate to login
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'เข้าสู่ระบบ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.isGuestMode)
                        TextSpan(text: ' เพื่อติดตามคิว / สถานะการจอง / รับสิทธิพิเศษ'),
                    ],
                  ),
                    ),
                ),
            ],
          ),
        ),
        
        // Menu buttons for user mode (เฉพาะพนักงานร้านขึ้นไป)
        if (!widget.isGuestMode && _canAccessEndDrawer) ...[
          // Menu button to open endDrawer
          IconButton(
            onPressed: () {
              print('Menu button pressed, opening endDrawer');
              _scaffoldKey.currentState?.openEndDrawer();
            },
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: compact ? 32 : 48,
              height: compact ? 32 : 48,
            ),
            icon: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: compact ? 20 : 24,
            ),
          ),
          // Logout button
          IconButton(
            onPressed: _logout,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: compact ? 32 : 48,
              height: compact ? 32 : 48,
            ),
            icon: Icon(
              Icons.logout,
              color: Colors.white,
              size: compact ? 20 : 24,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppTitle({bool compact = false}) {
    return Column(
      children: [
        Text(
          'ช่องทางธรรมชาติ',
          style: TextStyle(
            fontSize: compact ? 22 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: compact ? 4 : 10),
        Text(
          AppBusinessSettings.restaurantName,
          style: TextStyle(
            fontSize: compact ? 12 : 16,
            color: Colors.white70,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: compact ? 3 : 5),
        Container(
          height: compact ? 2 : 3,
          width: compact ? 70 : 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.white, Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  // ✅ Menu Buttons แยกตาม mode + permission check
  List<Widget> _buildMenuButtons() {
    final menuItems = [
      {'icon': Icons.restaurant, 'title': 'สั่งอาหาร', 'guestAllowed': true, 'pageId': 'restaurant_menu'},
      {'icon': Icons.table_restaurant, 'title': 'จองโต๊ะ', 'guestAllowed': true, 'pageId': 'table_booking'},
      {'icon': Icons.bed, 'title': 'จองที่พัก', 'guestAllowed': true, 'pageId': 'room_booking'},
      {'icon': Icons.local_offer, 'title': 'คูปอง/โปรโมชั่น', 'guestAllowed': true, 'pageId': 'coupon_promotion'},
      {'icon': Icons.history, 'title': 'ติดตามคิว / ข้อมูลการจอง (โต๊ะ/ที่พัก)', 'guestAllowed': false, 'pageId': ''},
      {'icon': Icons.storage, 'title': 'Database Test', 'guestAllowed': false, 'pageId': ''},
    ];

    return menuItems.where((item) {
      final pageId = item['pageId'] as String;
      if (pageId.isEmpty) return true;
      return PermissionService.canAccessPageSync(pageId);
    }).map((item) {
      final bool isAllowed = widget.isGuestMode ? item['guestAllowed'] as bool : true;
      
      return _buildMenuButton(
        icon: item['icon'] as IconData,
        title: item['title'] as String,
        guestAllowed: item['guestAllowed'] as bool,
        isAllowed: isAllowed,
      );
    }).toList();
  }

  // ✅ Menu Button แยกตาม mode
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
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: isAllowed ? () => _handleMenuTap(title) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isAllowed 
                      ? (widget.isGuestMode && !guestAllowed 
                          ? Colors.grey 
                          : Colors.blue[600])
                      : Colors.grey,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAllowed 
                          ? (widget.isGuestMode && !guestAllowed 
                              ? Colors.grey 
                              : Colors.black87)
                          : Colors.grey,
                    ),
                  ),
                ),
                if (widget.isGuestMode && !guestAllowed)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'สมาชิก',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w500,
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
      case 'คูปอง/โปรโมชั่น':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CouponPromotionPage(),
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
    }
  }

  Widget _buildFooter({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialIcon(Icons.phone, Colors.green, compact: compact),
              _buildSocialIcon(Icons.message, Colors.blue, compact: compact),
              _buildSocialIcon(Icons.location_on, Colors.red, compact: compact),
              _buildSocialIcon(Icons.info, Colors.orange, compact: compact),
            ],
          ),
          SizedBox(height: compact ? 8 : 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ติดต่อ CEO : ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: compact ? 12 : 14,
                ),
              ),
              Text(
                'treelawzoo@gmail.com',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 5 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: color,
        size: compact ? 16 : 20,
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key, 
    this.returnToMenu = false, 
    this.returnToBooking = false,
    this.returnToRoomBooking = false,
  });

  final bool returnToMenu;
  final bool returnToBooking;
  final bool returnToRoomBooking;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกข้อมูลให้ครบถ้วน';
      });
      return;
    }

    final input = _emailController.text.trim();
    String? validationError;
    
    // ตรวจสอบว่าเป็น email, username หรือ phone
    if (input.contains('@')) {
      // Email validation
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
        validationError = 'กรุณากรอกอีเมลให้ถูกต้อง';
      }
    } else if (RegExp(r'^0[689]\d{8}$').hasMatch(input)) {
      // Phone number (Thai format) - ถูกต้อง
      debugPrint('Login with phone: $input');
    } else {
      // Username validation
      if (input.length < 3 || input.length > 20) {
        validationError = 'ชื่อผู้ใช้ต้องมี 3-20 ตัวอักษร';
      } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(input)) {
        validationError = 'ชื่อผู้ใช้ต้องประกอบด้วยตัวอักษรภาษาอังกฤษ, ตัวเลข และ _ เท่านั้น';
      }
    }
    
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Attempting login with: $input');
      
      AuthResponse response;
      
      if (input.contains('@')) {
        // Login with Email
        response = await SupabaseService.signInWithEmail(
          input,
          _passwordController.text.trim(),
        );
      } else if (RegExp(r'^0[689]\d{8}$').hasMatch(input)) {
        // Login with Phone - ค้นหา email จาก phone mapping
        try {
          // วิธีที่ 1: ค้นหาจาก users table ที่อาจมี
          final usersResponse = await Supabase.instance.client
              .from('users')
              .select('email')
              .eq('phone', input)
              .maybeSingle();
          
          if (usersResponse != null) {
            // พบใน users table
            response = await SupabaseService.signInWithEmail(
              usersResponse['email'],
              _passwordController.text.trim(),
            );
          } else {
            // วิธีที่ 2: สร้าง mapping จาก phone ที่รู้จัก
            final phoneToEmail = {
              '0830103050': 'derfby@gmail.com',
              '0803399456': 'firmcutedra@gmail.com',
              '0999999999': 'admin@treelawzoo.local',
            };
            
            final email = phoneToEmail[input];
            if (email != null) {
              response = await SupabaseService.signInWithEmail(
                email,
                _passwordController.text.trim(),
              );
            } else {
              setState(() {
                _errorMessage = 'ไม่พบเบอร์โทรศัพท์: $input\nกรุณาใช้อีเมลแทน';
              });
              return;
            }
          }
        } catch (e) {
          debugPrint('Phone login error: $e');
          setState(() {
            _errorMessage = 'เกิดข้อผิดพลาดในการค้นหาเบอร์โทรศัพท์\nกรุณาใช้อีเมลแทน';
          });
          return;
        }
      } else {
        // Login with Username - ค้นหา email จาก user metadata
        try {
          // วิธีที่ 1: ลองค้นหาจาก users table ที่อาจมี
          final usersResponse = await Supabase.instance.client
              .from('users')
              .select('email')
              .eq('username', input)
              .maybeSingle();
          
          if (usersResponse != null) {
            // พบใน users table
            response = await SupabaseService.signInWithEmail(
              usersResponse['email'],
              _passwordController.text.trim(),
            );
          } else {
            // วิธีที่ 2: ลองค้นหาจาก user metadata ของผู้ใช้ที่ล็อกอินอยู่
            final currentUser = Supabase.instance.client.auth.currentUser;
            if (currentUser != null && currentUser.userMetadata?['username'] == input) {
              response = await SupabaseService.signInWithEmail(
                currentUser.email!,
                _passwordController.text.trim(),
              );
            } else {
              // วิธีที่ 3: สร้าง mapping จาก username ที่รู้จัก
              final usernameToEmail = {
                'derfby': 'derfby@gmail.com',
                'firm': 'firmcutedra@gmail.com',
                'admin': 'admin@treelawzoo.local',
              };
              
              final email = usernameToEmail[input];
              if (email != null) {
                response = await SupabaseService.signInWithEmail(
                  email,
                  _passwordController.text.trim(),
                );
              } else {
                setState(() {
                  _errorMessage = 'ไม่พบชื่อผู้ใช้: $input\nกรุณาใช้อีเมลแทน';
                });
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('Username login error: $e');
          setState(() {
            _errorMessage = 'เกิดข้อผิดพลาดในการค้นหาชื่อผู้ใช้\nกรุณาใช้อีเมลแทน';
          });
          return;
        }
      }

      debugPrint('Login response: ${response.user != null ? 'SUCCESS' : 'FAILED'}');
      debugPrint('Response user: ${response.user?.email}');

      if (response.user != null) {
        // โหลดสิทธิ์หลัง login สำเร็จ
        await PermissionService.loadPermissions(forceRefresh: true);
        // Login successful - navigate based on return flags
        if (widget.returnToMenu) {
          // กลับไปหน้าเมนู
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const RestaurantMenuPage(isGuestMode: false),
            ),
            (route) => false,
          );
        } else if (widget.returnToBooking) {
          // กลับไปหน้าจองโต๊ะ
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const TableBookingPage(isGuestMode: false),
            ),
            (route) => false,
          );
        } else if (widget.returnToRoomBooking) {
          // กลับไปหน้าจองที่พัก
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const RoomBookingPage(isGuestMode: false),
            ),
            (route) => false,
          );
        } else {
          // กลับไปหน้า Home (User Mode)
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MyHomePage(title: AppBusinessSettings.restaurantName, isGuestMode: false),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง กรุณาลองใหม่';
        });
      }
    } catch (e) {
      debugPrint('Login error: $e');
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
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4992E7),
              Color(0xFF68CB9C),
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
                              builder: (context) => const MyHomePage(
                                title: AppBusinessSettings.restaurantName,
                                isGuestMode: true,
                              ),
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
                            'เข้าสู่ระบบ',
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
                    AppBusinessSettings.restaurantName,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Login form
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
                        // Email field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'เบอร์โทรศัพท์ | อีเมล | ชื่อผู้ใช้',
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Error message display
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[600], size: 20),
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
                        
                        const SizedBox(height: 20),
                        
                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'รหัสผ่าน',
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
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
                                    'เข้าสู่ระบบ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Register link
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'หากยังไม่เคยลงทะเบียน กรุณา',
                              style: TextStyle(color: Colors.grey),
                              softWrap: true,
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: Text(
                                'สมัครสมาชิก',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.bold,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Forgot password link
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ForgotPasswordDialog(initialEmail: _emailController.text),
                            );
                          },
                          child: Text(
                            'ลืมรหัสผ่าน !',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontWeight: FontWeight.bold,
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
