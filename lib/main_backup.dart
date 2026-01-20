import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/otp_service.dart';
import 'widgets/forgot_password_dialog.dart';
import 'pages/restaurant_menu_page.dart';
import 'pages/table_booking_page.dart';
import 'pages/room_booking_page.dart';
import 'register_page_clean.dart';

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
    return 'กรุณากรอกอีเมลหรือเบอร์โทรศัพท์';
  }
  
  if (!isValidEmailOrPhone(value)) {
    return 'กรุณากรอกอีเมลหรือเบอร์โทรศัพท์ให้ถูกต้อง';
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
      home: const MyHomePage(
        title: 'TREE LAW ZOO valley',
        isGuestMode: true, // ✅ เริ่มต้นที่ Home Page โดยตรง
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                SizedBox(height: 20),
                Text('กำลังโหลดแอปพลิเคชัน...', 
                     style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ ตรวจสอบ user และส่งไปหน้าที่ถูกต้อง
    final currentUser = SupabaseService.currentUser;
    
    if (currentUser != null) {
      // User Mode - Login แล้ว
      return const MyHomePage(
        title: 'TREE LAW ZOO valley',
        isGuestMode: false, // ✅ User Mode
      );
    } else {
      // Guest Mode - ยังไม่ login
      return const MyHomePage(
        title: 'TREE LAW ZOO valley',
        isGuestMode: true, // ✅ Guest Mode
      );
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.isGuestMode = false});

  final String title;
  final bool isGuestMode; // ✅ เพิ่ม parameter

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  User? get currentUser => SupabaseService.currentUser;
  bool get isLoggedIn => currentUser != null;

  // ✅ Actions แยกตาม mode
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 20), // ✅ ลด spacing จาก 30 เป็น 20
                  
                  // App title
                  _buildAppTitle(),
                  
                  const SizedBox(height: 30), // ✅ ลด spacing จาก 40 เป็น 30
                  
                  // Menu Buttons
                  ..._buildMenuButtons(),
                  
                  const SizedBox(height: 40),
                  
                  // Footer
                  _buildFooter(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Header แยกตาม mode
  Widget _buildHeader() {
    return Row(
      children: [
        // User avatar or guest icon
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white.withOpacity(0.9),
          child: Icon(
            widget.isGuestMode ? Icons.person_outline : Icons.person,
            size: 30,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 15),
        
        // User info or guest message
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isGuestMode ? 'ผู้เยี่ยม' : (currentUser?.email ?? 'ผู้ใช้'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                widget.isGuestMode ? 'กรุณาเข้าสู่ระบบ' : 'ยินดีต้อนรับ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        
        // Login or Logout button
        if (widget.isGuestMode)
          // ✅ Guest Mode - แสดงปุ่มเข้าสู่ระบบ
          ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'เข้าสู่ระบบ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
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
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
      {'icon': Icons.fastfood, 'title': 'ติดตามคิว', 'guestAllowed': false},
      {'icon': Icons.book_online, 'title': 'ข้อมูลการจองโต๊ะ', 'guestAllowed': false},
      {'icon': Icons.hotel, 'title': 'จองที่พัก', 'guestAllowed': true},
      {'icon': Icons.card_membership, 'title': 'สมัคร Gold Member', 'guestAllowed': false},
    ];

    List<Widget> buttons = [];
    for (var item in menuItems) {
      buttons.add(_buildMenuButton(
        icon: item['icon'] as IconData,
        title: item['title'] as String,
        guestAllowed: item['guestAllowed'] as bool,
        onTap: () => _handleMenuTap(
          title: item['title'] as String,
          guestAllowed: item['guestAllowed'] as bool,
        ),
      ));
      buttons.add(const SizedBox(height: 15));
    }
    return buttons;
  }

  // ✅ Menu Button แยกตาม mode
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required bool guestAllowed,
    required VoidCallback onTap,
  }) {
    final isGuestMode = widget.isGuestMode;
    final isDisabled = isGuestMode && !guestAllowed;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDisabled 
            ? Colors.grey.withOpacity(0.3) // ✅ ปุ่ม disabled
            : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDisabled
                  ? Colors.grey.withOpacity(0.2) // ✅ Guest disabled
                  : guestAllowed && isGuestMode
                    ? Colors.green.withOpacity(0.2) // ✅ Guest allowed
                    : Colors.blue.withOpacity(0.2), // ✅ User mode
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isDisabled
                  ? Colors.grey[400] // ✅ Disabled icon
                  : guestAllowed && isGuestMode
                    ? Colors.green[600] // ✅ Guest allowed icon
                    : Colors.blue[700], // ✅ User mode icon
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                    ? Colors.grey[400] // ✅ Disabled text
                    : Colors.black87,
                ),
              ),
            ),
            if (guestAllowed && isGuestMode) ...[
              // ✅ Badge สำหรับ Guest ที่ใช้ได้
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ดูได้',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.arrow_forward_ios,
              color: isDisabled
                ? Colors.grey[300] // ✅ Disabled arrow
                : Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // Address section
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ที่อยู่ / นำทาง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Social media icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialIcon(Icons.facebook, Colors.blue[700]!),
              _buildSocialIcon(Icons.tiktok, Colors.black),
              _buildSocialIcon(Icons.camera_alt, Colors.pink[600]!),
              _buildSocialIcon(Icons.message, Colors.green[600]!),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Partnership and Admin
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to partnership page
                },
                child: const Text(
                  'ร่วมงานกับเรา',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to admin page
                },
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleMenuTap({required String title, required bool guestAllowed}) {
    if (widget.isGuestMode && guestAllowed) {
      // ✅ Guest สามารถเข้าดูได้
      _navigateToGuestFeature(title);
    } else if (widget.isGuestMode && !guestAllowed) {
      // ❌ Guest ไม่สามารถเข้าใช้ได้
      _showLoginRequired(title);
    } else {
      // ✅ User ใช้งานได้ปกติ
      _navigateToUserFeature(title);
    }
  }

  void _navigateToGuestFeature(String feature) {
    // ✅ Guest Mode - ดูเมนู/เลือกโต๊ะ/จองที่พักได้
    switch (feature) {
      case 'สั่งอาหาร':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RestaurantMenuPage(
              isGuestMode: true,
            ),
          ),
        );
        break;
      case 'จองโต๊ะ':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TableBookingPage(
              isGuestMode: true,
            ),
          ),
        );
        break;
      case 'จองที่พัก':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RoomBookingPage(
              isGuestMode: true,
            ),
          ),
        );
        break;
    }
  }

  void _navigateToUserFeature(String feature) {
    // ✅ User Mode - ใช้งานได้เต็มที่
    switch (feature) {
      case 'สั่งอาหาร':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RestaurantMenuPage(
              isGuestMode: false,
            ),
          ),
        );
        break;
      case 'จองโต๊ะ':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TableBookingPage(
              isGuestMode: false,
            ),
          ),
        );
        break;
      case 'จองที่พัก':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RoomBookingPage(
              isGuestMode: false,
            ),
          ),
        );
        break;
      // ... features อื่นๆ
    }
  }

  void _showLoginRequired(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ต้องการเข้าสู่ระบบ'),
        content: Text('ฟีเจอร์ "$feature" ต้องการเข้าสู่ระบบก่อนใช้งาน'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // ปิด dialog
              _login(); // ไปหน้า login
            },
            child: const Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 24,
        color: color,
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key, 
    this.returnToMenu = false, 
    this.returnToBooking = false,
    this.returnToRoomBooking = false, // ✅ เพิ่ม parameter ใหม่
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

    // Validate email format only for login
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
      setState(() {
        _errorMessage = 'กรุณากรอกอีเมลให้ถูกต้อง';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Attempting login with email: ${_emailController.text.trim()}');
      
      final response = await SupabaseService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

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
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const MyHomePage(title: 'TREE LAW ZOO valley'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.home,
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
                    const SizedBox(width: 48), // Balance the home button
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
                
                const Spacer(),
                
                // Form
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
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
                      
                      // Email field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'เบอร์โทรศัพท์ หรือ อีเมล',
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
                          prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
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
                                  strokeWidth: 3,
                                )
                              : const Text(
                                  'ตกลง',
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
                
                const Spacer(),
                
                // Register link
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'สมัครสมาชิก',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                
                // Forgot password link
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      ForgotPasswordDialog.show(context);
                    },
                    child: const Text(
                      'ลืมรหัสผ่าน',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

      _otpMessage = null;
    });

    try {
      final success = await OTPService.sendOTP(_phoneController.text);
      
      if (success) {
        setState(() {
          _otpSent = true;
          _otpCountdown = 120;
          _otpMessage = 'ส่ง OTP แล้ว กรุณาตรวจสอบ SMS';
        });
        
        _startCountdown();
      } else {
        setState(() {
          _errorMessage = 'ส่ง OTP ไม่สำเร็จ กรุณาลองใหม่';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSendingOTP = false;
      });
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _otpCountdown > 0) {
        setState(() {
          _otpCountdown--;
        });
        _startCountdown();
      }
    });
  }

  Future<void> _register() async {
    if (_phoneController.text.isEmpty ||
        _passwordController.text.isEmpty || 
        _confirmPasswordController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกข้อมูลให้ครบถ้วน';
      });
      return;
    }

    // Validate email format only if email is provided
    if (_emailController.text.isNotEmpty && 
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
      setState(() {
        _errorMessage = 'กรุณากรอกอีเมลให้ถูกต้อง';
      });
      return;
    }

    // Validate phone format (Thai phone numbers)
    if (!RegExp(r'^0[689]\d{8}$').hasMatch(_phoneController.text)) {
      setState(() {
        _errorMessage = 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง (เช่น 0812345678)';
      });
      return;
    }

    // Check if OTP is verified
    if (!_otpSent || _otpController.text.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณายืนยัน OTP ก่อนสมัครสมาชิก';
      });
      return;
    }

    // Verify OTP
    if (!OTPService.verifyOTP(_otpController.text)) {
      setState(() {
        _errorMessage = 'OTP ไม่ถูกต้องหรือหมดอายุ';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'รหัสผ่านไม่ตรงกัน';
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // สร้าง email ที่ถูกต้องเสมอ
      final email = _emailController.text.trim().isEmpty 
          ? 'user${DateTime.now().millisecondsSinceEpoch % 100000}@gmail.com'
          : _emailController.text.trim();
      
      debugPrint('Attempting to register with email: $email');
      
      final response = await SupabaseService.signUpWithEmail(
        email,
        _passwordController.text.trim(),
        data: {
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          'full_name': _usernameController.text.trim(), // ใช้ username เป็น full_name ชั่วคราว
        },
      );

      debugPrint('Registration response: ${response.user != null ? 'SUCCESS' : 'FAILED'}');
      debugPrint('Response user: ${response.user?.email}');
      debugPrint('Response session: ${response.session?.accessToken}');

      if (response.user != null) {
        // Registration successful - navigate to login
        setState(() {
          _errorMessage = null;
        });
        
        // แสดง success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบ'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'สมัครสมาชิกล้มเหลว: ไม่สามารถสร้างผู้ใช้ได้ กรุณาลองใหม่';
        });
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
                        // Email field
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'อีเมล (ไม่บังคับ)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Username field
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อผู้ใช้',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Phone field
                        TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'เบอร์โทรศัพท์',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 15),
                        
                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน',
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
                            labelText: 'ยืนยันรหัสผ่าน',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // OTP section
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpController,
                                decoration: InputDecoration(
                                  labelText: 'OTP',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: const Icon(Icons.message),
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _isSendingOTP ? null : _sendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSendingOTP
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _otpCountdown > 0 ? '($_otpCountdown)' : 'ส่ง OTP',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
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
                        
                        // OTP message
                        if (_otpMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _otpMessage!,
                                    style: TextStyle(
                                      color: Colors.green[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 30),
                        
                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isLoading || !_otpSent || _otpController.text.isEmpty) ? null : _register,
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
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (!_otpSent || _otpController.text.isEmpty) ...[
                                        Icon(Icons.lock, size: 18, color: Colors.white),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        _otpSent && _otpController.text.isNotEmpty 
                                            ? 'สมัครสมาชิก'
                                            : 'กรุณายืนยัน OTP ก่อน',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
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
