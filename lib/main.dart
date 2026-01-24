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
    );
  }

  // Header แยกตาม mode
  Widget _buildHeader() {
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
            radius: 25,
            isGuestMode: widget.isGuestMode,
          ),
        ),
        const SizedBox(width: 15),
        
        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Text(
                  widget.isGuestMode ? 'สวัสดี คุณลูกค้า' : 'สวัสดีคุณ $_userFullName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              RichText(
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
                          onTap: _login,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue[600],
                                decorationThickness: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.isGuestMode)
                      TextSpan(text: '  เพื่อติดตามคิว / สถานะการจอง / รับสิทธิพิเศษ'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Logout button for user mode only
        if (!widget.isGuestMode)
          // ✅ User Mode - แสดงปุ่ม logout
          IconButton(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
              size: 24,
            ),
          ),
      ],
    );
  }

  Widget _buildAppTitle() {
    return Column(
      children: [
        const Text(
          'ช่องทางธรรมชาติ',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'TREE LAW ZOO valley',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
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
      ],
    );
  }

  // ✅ Menu Buttons แยกตาม mode
  List<Widget> _buildMenuButtons() {
    final menuItems = [
      {'icon': Icons.restaurant, 'title': 'สั่งอาหาร', 'guestAllowed': true},
      {'icon': Icons.table_restaurant, 'title': 'จองโต๊ะ', 'guestAllowed': true},
      {'icon': Icons.bed, 'title': 'จองที่พัก', 'guestAllowed': true},
      {'icon': Icons.history, 'title': 'ติดตามคิว / ข้อมูลการจอง (โต๊ะ/ที่พัก)', 'guestAllowed': false},
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
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: isAllowed 
                      ? (widget.isGuestMode && !guestAllowed 
                          ? Colors.grey 
                          : Colors.blue[600])
                      : Colors.grey,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isAllowed 
                        ? (widget.isGuestMode && !guestAllowed 
                            ? Colors.grey 
                            : Colors.black87)
                        : Colors.grey,
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
      case 'จองที่พัก':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RoomBookingPage(isGuestMode: widget.isGuestMode),
          ),
        );
        break;
      case 'ประวัติ':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กำลังพัฒนา...')),
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
              builder: (context) => const MyHomePage(title: 'TREE LAW ZOO valley', isGuestMode: false),
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
                              builder: (context) => const MyHomePage(
                                title: 'TREE LAW ZOO valley',
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
                    'TREE LAW ZOO valley',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'หากยังไม่เคยลงทะเบียน กรุณา  ',
                              style: TextStyle(color: Colors.grey),
                            ),
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
