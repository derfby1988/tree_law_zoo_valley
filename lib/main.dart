import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/otp_service.dart';
import 'widgets/forgot_password_dialog.dart';

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
      home: const MyHomePage(title: 'TREE LAW ZOO valley'),
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
      // Show loading screen while initializing
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF81D4FA), // Light Blue
                Color(0xFF80CBC4), // Teal
                Color(0xFF81C784), // Light Green
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'กำลังโหลดแอปพลิเคชัน...',
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

    // Always show home page first, login is optional
    return const MyHomePage(title: 'TREE LAW ZOO valley');
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  User? get currentUser => SupabaseService.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<void> _logout() async {
    await SupabaseService.signOut();
    setState(() {}); // Refresh UI
  }

  Future<void> _login() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
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
              Color(0xFF81D4FA), // Light Blue
              Color(0xFF80CBC4), // Teal
              Color(0xFF81C784), // Light Green
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header with user info and login/logout
                  Row(
                    children: [
                      // User avatar or guest icon
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        child: Icon(
                          isLoggedIn ? Icons.person : Icons.person_outline,
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
                              isLoggedIn ? (currentUser?.email ?? 'ผู้ใช้') : 'ผู้เยี่ยม',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              isLoggedIn ? 'ยินดีต้อนรับ' : 'กรุณาเข้าสู่ระบบ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Login or Logout button
                      IconButton(
                        onPressed: isLoggedIn ? _logout : _login,
                        icon: Icon(
                          isLoggedIn ? Icons.logout : Icons.login,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // App title
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
                  
                  const SizedBox(height: 40),
                  
                  // Menu buttons
                  _buildMenuButton(
                    icon: Icons.restaurant,
                    title: 'สั่งอาหาร',
                    onTap: () {
                      // TODO: Navigate to restaurant page
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _buildMenuButton(
                    icon: Icons.table_restaurant,
                    title: 'จองโต๊ะ',
                    onTap: () {
                      // TODO: Navigate to table booking page
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _buildMenuButton(
                    icon: Icons.fastfood,
                    title: 'ติดตามคิว',
                    onTap: () {
                      // TODO: Navigate to order tracking page
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _buildMenuButton(
                    icon: Icons.book_online,
                    title: 'ข้อมูลการจองโต๊ะ',
                    onTap: () {
                      // TODO: Navigate to booking info page
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _buildMenuButton(
                    icon: Icons.hotel,
                    title: 'จองที่พัก',
                    onTap: () {
                      // TODO: Navigate to room booking page
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _buildMenuButton(
                    icon: Icons.card_membership,
                    title: 'สมัคร Gold Member',
                    onTap: () {
                      // TODO: Navigate to membership page
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Footer section
                  Container(
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
                            Icon(
                              Icons.location_on, color: Colors.blue),
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
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
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
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
          ],
        ),
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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

    // Validate email or phone format
    final validationError = validateEmailOrPhone(_emailController.text);
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
      final response = await SupabaseService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Login successful - navigate to home page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MyHomePage(title: 'TREE LAW ZOO valley'),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'เข้าสู่ระบบล้มเหลว กรุณาลองใหม่';
        });
      }
    } catch (e) {
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSendingOTP = false;
  bool _otpSent = false;
  int _otpCountdown = 0;
  String? _errorMessage;
  String? _otpMessage;

  Future<void> _sendOTP() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกเบอร์โทรศัพท์ก่อน';
      });
      return;
    }

    if (!RegExp(r'^0[689]\d{8}$').hasMatch(_phoneController.text)) {
      setState(() {
        _errorMessage = 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';
      });
      return;
    }

    setState(() {
      _isSendingOTP = true;
      _errorMessage = null;
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
      if (_otpCountdown > 0) {
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
      final response = await SupabaseService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Registration successful - navigate to login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'สมัครสมาชิกล้มเหลว กรุณาลองใหม่';
        });
      }
    } catch (e) {
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
                      
                      // Username field
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'ชื่อผู้ใช้',
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
                      
                      // Email field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'อีเมล',
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                          suffixText: 'ไม่บังคับ',
                          suffixStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Password field
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)',
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
                      
                      // Confirm password field
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'ยืนยันรหัสผ่าน',
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
                      
                      // Phone field (required)
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'เบอร์โทรศัพท์* (08xxxxxxxx)',
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[600]),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_otpCountdown > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '$_otpCountdown',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              TextButton(
                                onPressed: (_otpCountdown > 0 || _isSendingOTP) ? null : _sendOTP,
                                child: _isSendingOTP
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.blue,
                                        ),
                                      )
                                    : Text(
                                        _otpCountdown > 0 ? 'ส่งใหม่' : 'ส่ง OTP',
                                        style: TextStyle(
                                          color: _otpCountdown > 0 ? Colors.grey : Colors.orange,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // OTP field (shown after phone is entered)
                      if (_otpSent) ...[
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            hintText: 'รหัส OTP 6 หลัก',
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.verified_outlined, color: Colors.grey[600]),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_otpMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _otpMessage!,
                                    style: TextStyle(
                                      color: Colors.green[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
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
                
                const Spacer(),
                
                // Back to login link
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'กลับไปหน้าเข้าสู่ระบบ',
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
