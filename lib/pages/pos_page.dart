import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/business_settings.dart';
import '../services/inventory_service.dart';
import '../services/pos_held_order_service.dart';
import '../models/pos_held_order_model.dart';
import '../services/pos_payment_split_service.dart';
import '../services/pos_discount_service.dart';
import '../services/pos_shift_service.dart';
import '../services/table_management_service.dart';
import '../services/supabase_service.dart';
import '../models/pos_shift_model.dart';
import '../utils/permission_helpers.dart';
import '../theme/app_design_system.dart';
import '../widgets/pos_customer_picker_widget.dart';
import '../widgets/pos_discount_panel_widget.dart';
import '../widgets/pos_loyalty_display_widget.dart';
import '../widgets/pos_receipt_preview_widget.dart';
import '../widgets/pos_order_history_widget.dart';
import '../widgets/pos_shift_widget.dart';

import '../widgets/pos_printer_settings_widget.dart';
import '../services/pos_printer_service.dart';

enum _PosWorkspaceMode {
  pos,
  orderHistory,
  printerSettings,
}

class PosPage extends StatefulWidget {
  const PosPage({
    super.key,
    this.initialOrderType = 'walk_in',
    this.initialTableId,
    this.initialTableNumber,
    this.initialZoneName,
    this.initialTableSessionId,
    this.initialCustomerUserId,
    this.initialCustomerName,
    this.initialCustomerPhone,
  });

  final String initialOrderType;
  final String? initialTableId;
  final String? initialTableNumber;
  final String? initialZoneName;
  final String? initialTableSessionId;
  final String? initialCustomerUserId;
  final String? initialCustomerName;
  final String? initialCustomerPhone;

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  // Data
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _salesStaffUsers = [];
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedResponsibleStaff;
  String _orderType = 'walk_in';
  String? _selectedTableId;
  String? _selectedTableSessionId;
  String? _selectedTableNumber;
  String? _selectedZoneId;
  String? _selectedZoneName;
  double _zoneServiceCharge = 0; // ค่าบริการจากโซนที่ลูกค้านั่ง
  String? _selectedCustomerUserId;
  String? _selectedCustomerName;
  String? _selectedCustomerPhone;
  String? _selectedCategoryId;
  bool _isLoading = true;
  bool _isProcessing = false;
  final FocusNode _searchFocus = FocusNode();

  // Tax/service cache per category
  final Map<String, Map<String, dynamic>> _taxRuleCache = {};

  // Phase 2: Customer & Loyalty
  Map<String, dynamic>? _selectedCustomer;
  
  // Phase 2: Discounts
  final List<Map<String, dynamic>> _appliedDiscounts = [];
  double _totalDiscountAmount = 0;
  
  // Phase 2: Loyalty
  double _redeemedPoints = 0;

  // Phase 2C: Held Orders
  int _heldOrderCount = 0;

  // Phase 2D: Split Payment
  final List<Map<String, dynamic>> _paymentSplits = [];
  bool _useSplitPayment = false;

  // Phase 2B: Shift Management
  PosShift? _currentShift;

  // Phase 2E: Refund / Void workspace
  _PosWorkspaceMode _workspaceMode = _PosWorkspaceMode.pos;

  // Search
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final ScrollController _zone3ScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _zone5ScrollController = ScrollController();

  Color get _bgColor => AppDesignSystem.background;
  Color get _cardColor => AppDesignSystem.surface;
  Color get _sidebarColor => AppDesignSystem.surfaceAlt;
  Color get _accentGreen => AppDesignSystem.primary;
  Color get _textPrimary => AppDesignSystem.textPrimary;
  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _borderColor => AppDesignSystem.border;
  Color get _selectedSidebar => AppDesignSystem.selectedSurface;
  LinearGradient get _iconGradient => AppDesignSystem.accentGradient;

  @override
  void initState() {
    super.initState();
    _orderType = widget.initialOrderType;
    _selectedTableId = widget.initialTableId;
    _selectedTableSessionId = widget.initialTableSessionId;
    _selectedTableNumber = widget.initialTableNumber;
    _selectedZoneName = widget.initialZoneName;
    _selectedCustomerUserId = widget.initialCustomerUserId;
    _selectedCustomerName = widget.initialCustomerName;
    _selectedCustomerPhone = widget.initialCustomerPhone;
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
    PosPrinterService.initOnPosOpen();
    // โหลดโซนล่าสุดของพนักงาน (ถ้าไม่มีโซนเริ่มต้น)
    _loadLastPosZone();
  }

  /// โหลดโซน POS ล่าสุดของพนักงาน
  Future<void> _loadLastPosZone() async {
    // ถ้ามีโซนเริ่มต้นจาก widget ให้ใช้ค่านั้น ไม่ต้องโหลดจาก DB
    if (widget.initialZoneName != null && widget.initialZoneName!.isNotEmpty) {
      return;
    }
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final lastZoneData = await SupabaseService.getLastPosZone(currentUser.id);
      if (lastZoneData != null && lastZoneData['zone'] != null) {
        final zone = lastZoneData['zone'] as Map<String, dynamic>;
        setState(() {
          _selectedZoneId = lastZoneData['zone_id']?.toString();
          _selectedZoneName = zone['name']?.toString();
          _zoneServiceCharge = (zone['service_charge'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error loading last POS zone: $e');
    }
  }

  Widget _gradientIcon(IconData icon, {double size = 18}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => _iconGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  Widget _gradientText(String label, {double fontSize = 13, FontWeight weight = FontWeight.w600}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => _iconGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, fontWeight: weight, color: Colors.white),
      ),
    );
  }

  void _focusSearchField() {
    if (!_searchFocus.hasFocus) {
      FocusScope.of(context).requestFocus(_searchFocus);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    _searchFocus.dispose();
    _zone3ScrollController.dispose();
    _headerScrollController.dispose();
    _zone5ScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        InventoryService.getProducts(),
        InventoryService.getCategories(),
        _loadResponsibleStaffUsers(),
      ]);
      final staffUsers = List<Map<String, dynamic>>.from(results[2]);
      final selectedStaff = _pickDefaultResponsibleStaff(staffUsers);
      final heldCount = await PosHeldOrderService.getHeldOrderCount();
      final currentShift = await PosShiftService.getCurrentOpenShift();
      setState(() {
        _products = results[0];
        _categories = results[1];
        _salesStaffUsers = staffUsers;
        _selectedResponsibleStaff = selectedStaff;
        _heldOrderCount = heldCount;
        _currentShift = currentShift;
        _isLoading = false;
      });
      // โหลดค่าบริการจากโซน (ถ้ามีโต๊ะที่เลือก)
      await _loadZoneServiceCharge();
    } catch (e) {
      debugPrint('Error loading POS data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// โหลดค่าบริการจากโซนของโต๊ะที่เลือก
  Future<void> _loadZoneServiceCharge() async {
    if (_selectedTableId == null) {
      setState(() => _zoneServiceCharge = 0);
      return;
    }
    try {
      final tableData = await TableManagementService.getTableWithZone(_selectedTableId!);
      if (tableData != null && tableData['zone'] != null) {
        final zoneData = tableData['zone'] as Map<String, dynamic>;
        final serviceCharge = (zoneData['service_charge'] ?? 0).toDouble();
        setState(() {
          _zoneServiceCharge = serviceCharge;
          _selectedZoneName = zoneData['name']?.toString();
        });
      } else {
        setState(() => _zoneServiceCharge = 0);
      }
    } catch (e) {
      debugPrint('Error loading zone service charge: $e');
      setState(() => _zoneServiceCharge = 0);
    }
  }

  Future<List<Map<String, dynamic>>> _loadResponsibleStaffUsers() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    Map<String, dynamic>? currentUserRecord;
    if (currentUser != null) {
      currentUserRecord = {
        'id': currentUser.id,
        'full_name': currentUser.userMetadata?['full_name'] ?? currentUser.email?.split('@').first ?? 'พนักงาน',
        'email': currentUser.email,
        'username': currentUser.userMetadata?['username'],
        'is_active': true,
        'is_sales_staff': true,
      };
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, full_name, email, username, avatar_url, is_active, is_sales_staff')
          .eq('is_active', true)
          .order('full_name');

      final staffUsers = List<Map<String, dynamic>>.from(response);
      final salesStaff = staffUsers.where((u) => u['is_sales_staff'] == true).toList();
      final usableUsers = salesStaff.isNotEmpty ? salesStaff : staffUsers;
      final currentUserRow = currentUserRecord;
      if (currentUserRow != null &&
          usableUsers.where((u) => u['id']?.toString() == currentUserRow['id']?.toString()).isEmpty) {
        return [currentUserRow, ...usableUsers];
      }
      if (usableUsers.isNotEmpty) return usableUsers;

      return currentUserRow != null ? [currentUserRow] : [];
    } catch (e) {
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('id, full_name, email, username, avatar_url, is_active')
            .eq('is_active', true)
            .order('full_name');
        final users = List<Map<String, dynamic>>.from(response);
        final currentUserRow = currentUserRecord;
        if (currentUserRow != null &&
            users.where((u) => u['id']?.toString() == currentUserRow['id']?.toString()).isEmpty) {
          return [currentUserRow, ...users];
        }
        if (users.isNotEmpty) return users;

        return currentUserRow != null ? [currentUserRow] : [];
      } catch (inner) {
        debugPrint('Error loading sales staff users: $inner');
        return currentUserRecord != null ? [currentUserRecord] : [];
      }
    }
  }

  Map<String, dynamic>? _pickDefaultResponsibleStaff(List<Map<String, dynamic>> staffUsers) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      for (final staff in staffUsers) {
        if (staff['id']?.toString() == currentUserId) {
          return staff;
        }
      }
    }
    return staffUsers.isNotEmpty ? staffUsers.first : null;
  }

  String _abbreviateStaffName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return rawName;

    final parts = name.split(RegExp(r'\s+')).where((part) => part.trim().isNotEmpty).toList();
    if (parts.length < 2) return name;

    final firstName = parts.first;
    final lastNameInitial = parts.last.characters.first;
    return '$firstName $lastNameInitial.';
  }

  String _displayNameFromUser(Map<String, dynamic>? user) {
    if (user == null) return 'ไม่ระบุ';
    final email = user['email']?.toString();
    final username = user['username']?.toString();
    final fullName = user['full_name']?.toString();
    return fullName != null
        ? _abbreviateStaffName(fullName)
        : username ??
            (email != null && email.contains('@') ? email.split('@').first : null) ??
            'ไม่ระบุ';
  }

  String _displayFullNameFromUser(Map<String, dynamic>? user) {
    if (user == null) return 'ไม่ระบุ';
    final fullName = user['full_name']?.toString();
    final email = user['email']?.toString();
    final username = user['username']?.toString();
    return fullName ??
        username ??
        (email != null && email.contains('@') ? email.split('@').first : null) ??
        'ไม่ระบุ';
  }

  String _displayNameFromAuthUser(User? user) {
    if (user == null) return 'พนักงาน';
    final metadataName = user.userMetadata?['full_name']?.toString();
    final metadataUsername = user.userMetadata?['username']?.toString();
    final email = user.email;
    return metadataName != null
        ? _abbreviateStaffName(metadataName)
        : metadataUsername ??
            (email != null && email.contains('@') ? email.split('@').first : null) ??
            'พนักงาน';
  }

  Widget _buildResponsibleStaffSelector() {
    final selected = _selectedResponsibleStaff;
    final hasSelection = selected != null;

    return PopupMenuButton<String>(
      tooltip: 'เลือกพนักงานผู้รับผิดชอบ',
      enabled: _salesStaffUsers.isNotEmpty,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (userId) {
        final selectedUser = _salesStaffUsers.firstWhere(
          (user) => user['id']?.toString() == userId,
          orElse: () => <String, dynamic>{},
        );
        setState(() {
          _selectedResponsibleStaff = selectedUser.isEmpty ? null : selectedUser;
        });
      },
      itemBuilder: (context) => _salesStaffUsers
          .map(
            (user) => PopupMenuItem<String>(
              value: user['id']?.toString() ?? '',
              child: Row(
                children: [
                  Icon(
                    Icons.badge,
                    size: 18,
                    color: (user['id']?.toString() == selected?['id']?.toString())
                        ? _accentGreen
                        : _textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayFullNameFromUser(user),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasSelection ? _bgColor : Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasSelection ? _borderColor : Colors.orange.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gradientIcon(Icons.badge, size: 14),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                hasSelection ? _displayNameFromUser(selected) : 'เลือกพนักงานรับผิดชอบ',
                style: TextStyle(
                  fontSize: 11,
                  color: hasSelection ? _textSecondary : Colors.orange[800],
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: hasSelection ? _textSecondary : Colors.orange[800],
            ),
          ],
        ),
      ),
    );
  }

  // Cart logic
  Future<void> _addToCart(Map<String, dynamic> product) async {
    // Resolve tax rule if not cached
    final catId = (product['category'] is Map) ? product['category']['id'] as String? : null;
    if (catId != null && !_taxRuleCache.containsKey(catId)) {
      final rule = await InventoryService.resolveTaxRuleForCategory(
        categoryId: catId,
        itemType: 'product',
      );
      _taxRuleCache[catId] = rule;
    }
    // Apply tax rule to product
    if (catId != null && _taxRuleCache.containsKey(catId)) {
      final rule = _taxRuleCache[catId]!;
      product['is_tax_exempt'] = rule['is_tax_exempt'] ?? false;
      product['tax_rate'] = rule['tax_rate'] ?? AppBusinessSettings.defaultTaxRate;
    }

    setState(() {
      final existingIndex = _cartItems.indexWhere(
        (item) => item['product']['id'] == product['id'],
      );
      if (existingIndex >= 0) {
        _cartItems[existingIndex]['qty'] += 1;
      } else {
        _cartItems.add({
          'product': product,
          'qty': 1,
          'note': '',
        });
      }
      _selectedProduct = product;
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateQty(int index, int delta) {
    setState(() {
      _cartItems[index]['qty'] += delta;
      if (_cartItems[index]['qty'] <= 0) {
        _cartItems.removeAt(index);
      }
    });
  }

  double get _subtotal {
    double total = 0;
    for (final item in _cartItems) {
      final price = (item['product']['price'] ?? 0).toDouble();
      total += price * (item['qty'] as int);
    }
    return total;
  }

  /// ส่วนลดจากระบบสมาชิก (ยังไม่ implement)
  double get _discount => 0;
  
  /// ยอดรวมหลังหักส่วนลดทั้งหมด (รวมส่วนลดจากระบบ + ส่วนลดเพิ่มเติม)
  double get _preTaxTotal => _subtotal - _discount - _totalDiscountAmount;

  /// คำนวณภาษีจาก tax rule จริงต่อสินค้า
  double get _taxAmount {
    double tax = 0;
    for (final item in _cartItems) {
      final product = item['product'] as Map<String, dynamic>;
      final qty = item['qty'] as int;
      final price = (product['price'] ?? 0).toDouble();
      final isTaxExempt = product['is_tax_exempt'] == true;
      final taxRate = (product['tax_rate'] ?? AppBusinessSettings.defaultTaxRate).toDouble();
      if (!isTaxExempt) {
        tax += price * qty * (taxRate / 100);
      }
    }
    return tax;
  }

  /// อัตราภาษีเฉลี่ยถ่วงน้ำหนัก (สำหรับแสดงผล)
  double get _avgTaxRate {
    if (_subtotal == 0) return AppBusinessSettings.defaultTaxRate;
    return (_taxAmount / _preTaxTotal) * 100;
  }

  double get _serviceAmount => _preTaxTotal * _serviceRate;
  double get _netTotal => _preTaxTotal + _taxAmount + _serviceAmount;

  /// ดึงอัตราค่าบริการจากโซนที่ลูกค้านั่ง (ถ้ามี) หรือใช้ default
  double get _serviceRate {
    // ถ้าเป็น dine-in และมีค่าบริการจากโซน ให้ใช้ค่านั้น
    if (_orderType == 'dine_in' && _zoneServiceCharge > 0) {
      return _zoneServiceCharge / 100; // แปลงจาก % เป็นทศนิยม
    }
    // ถ้าไม่มี ใช้ default 0%
    return 0.0;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var list = _products;
    if (_selectedCategoryId != null) {
      list = list.where((p) {
        final cat = p['category'];
        if (cat is Map) return cat['id'] == _selectedCategoryId;
        return false;
      }).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((p) =>
        (p['name'] ?? '').toString().toLowerCase().contains(query),
      ).toList();
    }
    return list;
  }

  // Category icons
  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('เครื่องดื่ม') || lower.contains('น้ำ')) return Icons.local_cafe;
    if (lower.contains('อาหาร') || lower.contains('ข้าว')) return Icons.restaurant;
    if (lower.contains('ของหวาน') || lower.contains('เบเกอรี่')) return Icons.cake;
    if (lower.contains('ผัก') || lower.contains('ผลไม้')) return Icons.eco;
    if (lower.contains('เนื้อ') || lower.contains('ทะเล')) return Icons.set_meal;
    if (lower.contains('สมุนไพร')) return Icons.grass;
    if (lower.contains('ไข่')) return Icons.egg;
    if (lower.contains('ทำความสะอาด')) return Icons.cleaning_services;
    if (lower.contains('แปรรูป') || lower.contains('แห้ง')) return Icons.inventory_2;
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Row(
            children: [
              // Left Icon Bar (full height, over header)
              _buildLeftIconBar(),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    if (_workspaceMode == _PosWorkspaceMode.pos) _buildHeader(),
                    Expanded(
                      child: _buildWorkspaceContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================
  // Left Icon Bar
  // =============================================
  Widget _buildLeftIconBar() {
    // Get unique categories that have products
    final usedCatIds = _products
        .map((p) => (p['category'] is Map) ? p['category']['id'] : null)
        .where((id) => id != null)
        .toSet();
    final displayCategories = _categories
        .where((c) => usedCatIds.contains(c['id']))
        .toList();

    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: _sidebarColor,
        border: Border(right: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildSidebarIcon(
            icon: Icons.point_of_sale,
            label: 'POS',
            isSelected: _workspaceMode == _PosWorkspaceMode.pos,
            onTap: () => _switchWorkspace(_PosWorkspaceMode.pos),
          ),
          _buildSidebarIcon(
            icon: Icons.receipt_long,
            label: 'ประวัติ',
            isSelected: _workspaceMode == _PosWorkspaceMode.orderHistory,
            onTap: () => _switchWorkspace(_PosWorkspaceMode.orderHistory),
          ),
          _buildSidebarIcon(
            icon: Icons.print,
            label: 'พิมพ์',
            isSelected: _workspaceMode == _PosWorkspaceMode.printerSettings,
            onTap: () => _switchWorkspace(_PosWorkspaceMode.printerSettings),
          ),
          const Divider(height: 1, indent: 8, endIndent: 8),
          // All categories button
          _buildSidebarIcon(
            icon: Icons.grid_view,
            label: 'ทั้งหมด',
            isSelected: _selectedCategoryId == null,
            onTap: () => setState(() => _selectedCategoryId = null),
          ),
          const Divider(height: 1, indent: 8, endIndent: 8),
          // Category icons
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: displayCategories.length,
              itemBuilder: (context, index) {
                final cat = displayCategories[index];
                return _buildSidebarIcon(
                  icon: _getCategoryIcon(cat['name'] ?? ''),
                  label: cat['name'] ?? '',
                  isSelected: _selectedCategoryId == cat['id'],
                  onTap: () => setState(() => _selectedCategoryId = cat['id']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarIcon({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? _selectedSidebar : Colors.transparent,
            border: isSelected
                ? Border(left: BorderSide(color: _accentGreen, width: 3))
                : null,
          ),
          child: _gradientIcon(icon, size: 22),
        ),
      ),
    );
  }

  void _switchWorkspace(_PosWorkspaceMode mode) {
    if (_workspaceMode == mode) return;
    setState(() {
      _workspaceMode = mode;
    });
  }

  Widget _buildWorkspaceContent() {
    switch (_workspaceMode) {
      case _PosWorkspaceMode.pos:
        return _buildPosWorkspace();
      case _PosWorkspaceMode.orderHistory:
        return PosOrderHistoryWidget(
          onBackToPos: () => _switchWorkspace(_PosWorkspaceMode.pos),
        );
      case _PosWorkspaceMode.printerSettings:
        return const PosPrinterSettingsWidget();
    }
  }

  Widget _buildPosWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the 5 zones fixed in place; only Zone 5 scrolls internally.
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: _buildTopAndMiddleRow(),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 4,
                child: _buildZone5(),
              ),
            ],
          ),
        );
      },
    );
  }

  // =============================================
  // Header
  // =============================================
  Widget _buildHeader() {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = _displayNameFromAuthUser(user);
    final now = DateTime.now();
    final dateStr = _formatThaiShortDate(now);
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} น.';
    final tableLabel = _selectedTableNumber?.trim().isNotEmpty == true ? _selectedTableNumber!.trim() : '-';
    final orderTypeLabel = _orderType == 'dine_in' ? 'Dine-in' : 'Walk-in';
    final customerLabel = _selectedCustomerName?.trim().isNotEmpty == true ? _selectedCustomerName!.trim() : null;
    final customerPhoneLabel = _selectedCustomerPhone?.trim().isNotEmpty == true ? _selectedCustomerPhone!.trim() : null;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: _gradientIcon(Icons.arrow_back, size: 20),
            color: _textSecondary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'กลับ',
          ),
          const SizedBox(width: 8),
          _gradientIcon(Icons.storefront, size: 22),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              AppBusinessSettings.brandShortName,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Scrollbar(
              controller: _headerScrollController,
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _headerScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // โซน/ร้าน (แสดงก่อน)
                    if (_selectedZoneName != null) ...[
                      InkWell(
                        onTap: _showTablePickerDialog,
                        borderRadius: BorderRadius.circular(6),
                        child: _headerChip(Icons.store, _selectedZoneName!),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // โต๊ะ
                    InkWell(
                      onTap: _showTablePickerDialog,
                      borderRadius: BorderRadius.circular(6),
                      child: _headerChip(Icons.table_restaurant, _orderType == 'dine_in' ? 'โต๊ะ $tableLabel' : 'โต๊ะ -'),
                    ),
                    const SizedBox(width: 8),
                    // ประเภทออเดอร์
                    _headerChip(Icons.receipt_long, orderTypeLabel),
                    if (customerLabel != null) ...[
                      const SizedBox(width: 8),
                      _headerChip(Icons.person_pin, customerLabel),
                    ],
                    if (customerPhoneLabel != null) ...[
                      const SizedBox(width: 8),
                      _headerChip(Icons.phone, customerPhoneLabel),
                    ],
                    const SizedBox(width: 8),
                    _headerChip(Icons.person, userName),
                    const SizedBox(width: 8),
                    _buildResponsibleStaffSelector(),
                    const SizedBox(width: 8),
                    _buildShiftChip(),
                    const SizedBox(width: 8),
                    _headerChip(Icons.calendar_today, dateStr),
                    const SizedBox(width: 8),
                    _headerChip(Icons.access_time, timeStr),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatThaiShortDate(DateTime date) {
    const weekDays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
    const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    final thaiYear = (date.year + 543).toString().substring(2);
    return '${weekDays[date.weekday - 1]}${date.day}${months[date.month - 1]}$thaiYear';
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gradientIcon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
        ],
      ),
    );
  }

  // =============================================
  // Shift Chip (Header) — delegated to PosShiftChip widget
  // =============================================
  Widget _buildShiftChip() {
    return PosShiftChip(
      currentShift: _currentShift,
      onOpenShift: _showOpenShiftDialog,
      onCloseShift: _showCloseShiftDialog,
    );
  }

  // =============================================
  // Shift Dialogs — delegated to PosShiftDialogs
  // =============================================
  void _showOpenShiftDialog() async {
    final shift = await PosShiftDialogs.showOpenShiftDialog(context);
    if (shift != null && mounted) {
      setState(() => _currentShift = shift);
    }
  }

  void _showCloseShiftDialog() async {
    if (_currentShift == null) return;
    final closed = await PosShiftDialogs.showCloseShiftDialog(context, _currentShift!);
    if (closed != null && mounted) {
      setState(() => _currentShift = null);
    }
  }

  // =============================================
  // Table Picker Dialog
  // =============================================
  Future<void> _showTablePickerDialog() async {
    final zonesWithTables = await TableManagementService.getZonesWithTables();
    if (!mounted) return;

    // เริ่มจากโซนล่าสุดที่เลือกไว้ (ถ้ามี)
    String? selectedZoneId = _selectedZoneId;
    String? savingTableId; // เก็บ tableId ที่กำลังบันทึก

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Step 1: เลือกโซน
          if (selectedZoneId == null) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.store, color: Colors.green),
                  SizedBox(width: 8),
                  Text('เลือกโซน/ร้าน'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: zonesWithTables.isEmpty
                    ? const Center(child: Text('ไม่มีร้าน/โซนที่เปิดใช้งาน'))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: zonesWithTables.length,
                        itemBuilder: (context, index) {
                          final zone = zonesWithTables[index];
                          final tables = zone['tables'] as List<dynamic>? ?? [];
                          final availableCount = tables.where((t) => t['status'] == 'available').length;

                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedZoneId = zone['id']?.toString();
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _bgColor,
                                border: Border.all(color: _borderColor, width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.store, size: 18, color: _accentGreen),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          zone['name'] ?? 'ไม่มีชื่อ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.table_restaurant, size: 14, color: _textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$availableCount โต๊ะว่าง',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      if ((zone['service_charge'] ?? 0) > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '+${zone['service_charge']}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _orderType = 'walk_in';
                      _selectedTableId = null;
                      _selectedTableNumber = null;
                      _selectedZoneId = null;
                      _selectedZoneName = null;
                      _zoneServiceCharge = 0;
                    });
                  },
                  child: const Text('ไม่ใช้โต๊ะ (Walk-in)'),
                ),
              ],
            );
          }

          // Step 2: เลือกโต๊ะในโซน
          final selectedZone = zonesWithTables.firstWhere(
            (z) => z['id']?.toString() == selectedZoneId,
            orElse: () => {},
          );
          final tables = selectedZone['tables'] as List<dynamic>? ?? [];
          final availableTables = tables.where((t) => t['status'] == 'available').toList();

          return AlertDialog(
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setDialogState(() {
                      selectedZoneId = null;
                    });
                  },
                ),
                const SizedBox(width: 4),
                Icon(Icons.table_restaurant, color: _accentGreen),
                const SizedBox(width: 8),
                Text('โต๊ะ ${selectedZone['name'] ?? ''}'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: availableTables.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_restaurant_outlined, size: 48, color: _textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            'ไม่มีโต๊ะว่างในโซนนี้',
                            style: TextStyle(color: _textSecondary),
                          ),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: availableTables.map((table) {
                        final tableId = table['id']?.toString() ?? '';
                        final tableName = table['name']?.toString() ?? 'โต๊ะ';
                        final capacity = (table['capacity'] ?? 0) as int;
                        final isSelected = _selectedTableId == tableId;

                        final isSavingThisTable = savingTableId == tableId;

                        return InkWell(
                          onTap: () async {
                            setDialogState(() {
                              savingTableId = tableId; // แสดง loading
                            });
                            
                            // บันทึกโซนล่าสุดของพนักงานก่อน
                            final currentUser = Supabase.instance.client.auth.currentUser;
                            if (currentUser != null && selectedZoneId != null) {
                              await SupabaseService.saveLastPosZone(currentUser.id, selectedZoneId!);
                            }
                            
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            
                            setState(() {
                              _orderType = 'dine_in';
                              _selectedTableId = tableId;
                              _selectedTableNumber = tableName;
                              _selectedZoneId = selectedZoneId;
                              _selectedZoneName = selectedZone['name']?.toString();
                            });
                            _loadZoneServiceCharge();
                          },
                          child: Container(
                            width: 90,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? _accentGreen.withValues(alpha: 0.15) : _bgColor,
                              border: Border.all(
                                color: isSelected ? _accentGreen : _borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSavingThisTable)
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _accentGreen,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.table_restaurant,
                                    color: isSelected ? _accentGreen : _textSecondary,
                                    size: 28,
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  tableName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? _accentGreen : _textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (capacity > 0 && !isSavingThisTable)
                                  Text(
                                    '$capacity ที่นั่ง',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _textSecondary,
                                    ),
                                  )
                                else if (isSavingThisTable)
                                  Text(
                                    'กำลังบันทึก...',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _accentGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          );
        },
      ),
    );
  }

  // =============================================
  // Top + Middle Row (Zone 1, 2, 3, 4)
  // =============================================
  Widget _buildTopAndMiddleRow() {
    // Layout structure:
    // Left side (flex 7):
    //   - Top row: Zone1 and Zone2 side-by-side
    //   - Bottom row: Zone4 spans full left width (Zone1+Zone2 combined)
    // Right side (flex 3):
    //   - Zone3 tall, matches the combined height of top+bottom on the left
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left composite column
        Expanded(
          flex: 7,
          child: Column(
            children: [
              // Top row: Zone1 + Zone2
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Expanded(flex: 1, child: _buildZone1()),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: _buildZone2()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Bottom: Zone4 spans width of Zone1+Zone2
              Expanded(flex: 5, child: _buildZone4()),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right column: Zone3 full height
        Expanded(
          flex: 3,
          child: _buildZone3(),
        ),
      ],
    );
  }

  // =============================================
  // Zone 1: Total Balance (pre-tax + discount list)
  // =============================================
  Widget _buildZone1() {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Zone 1 Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _gradientIcon(Icons.receipt_long, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('ราคารวมก่อนคำนวณภาษี',
                          style: TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '฿ ${_preTaxTotal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
                const SizedBox(height: 2),
                if (_discount > 0) _discountRow('ส่วนลดสมาชิก', -_discount),
                if (_totalDiscountAmount > 0) _discountRow('ส่วนลดเพิ่มเติม', -_totalDiscountAmount),
                _infoRow('ยอดรวม', _subtotal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _discountRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.red[400])),
          Text('${amount.toStringAsFixed(2)} ฿', style: TextStyle(fontSize: 11, color: Colors.red[400])),
        ],
      ),
    );
  }

  Widget _infoRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: _textSecondary)),
          Text('${amount.toStringAsFixed(2)} ฿', style: TextStyle(fontSize: 10, color: _textPrimary)),
        ],
      ),
    );
  }

  // =============================================
  // Zone 2: Total Spending / Net Total
  // =============================================
  Widget _buildZone2() {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                _gradientIcon(Icons.analytics, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('ยอดสุทธิ',
                      style: TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '฿ ${_netTotal.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            const SizedBox(height: 4),
            _infoRow('ภาษี ${_avgTaxRate.toStringAsFixed(1)}%', _taxAmount),
            _infoRow('ค่าบริการ ${(_serviceRate * 100).toStringAsFixed(0)}%', _serviceAmount),
          ],
        ),
      ),
    );
  }

  // =============================================
  // Zone 3: Payment Methods (full height = Zone2 + Zone4)
  // =============================================
  Widget _buildZone3() {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase 2: Customer Picker (compact)
            PosCustomerPickerWidget(
              onCustomerSelected: (customer) {
                setState(() => _selectedCustomer = customer);
              },
              initialCustomer: _selectedCustomer,
            ),
            const SizedBox(height: 6),
            // Phase 2: Loyalty Display (compact)
            if (_selectedCustomer != null)
              PosLoyaltyDisplayWidget(
                customerId: _selectedCustomer?['id'],
                orderAmount: _subtotal,
                onPointsRedeemed: (points) {
                  setState(() => _redeemedPoints = points);
                },
              ),
            if (_selectedCustomer != null) const SizedBox(height: 6),
            // Phase 2: Discount Panel
            PosDiscountPanelWidget(
              onDiscountApplied: (discount, amount, {couponCode}) {
                setState(() {
                  _appliedDiscounts.add({
                    'discount_id': discount.id,
                    'discount_amount': amount,
                    'coupon_code': couponCode,
                    'pos_discounts': {
                      'name': discount.name,
                      'discount_type': discount.discountType,
                      'value': discount.value,
                    },
                  });
                  _totalDiscountAmount += amount;
                });
              },
              onDiscountRemoved: (discountId) {
                setState(() {
                  final index = _appliedDiscounts.indexWhere((d) => d['discount_id'] == discountId);
                  if (index >= 0) {
                    _totalDiscountAmount -= (_appliedDiscounts[index]['discount_amount'] ?? 0).toDouble();
                    _appliedDiscounts.removeAt(index);
                  }
                });
              },
              orderAmount: _subtotal,
              appliedDiscounts: _appliedDiscounts,
              customerId: _selectedCustomer?['id']?.toString(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _gradientIcon(Icons.payment, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'การชำระเงิน',
                    style: TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_useSplitPayment || _paymentSplits.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'แยกจ่าย ${_paymentSplits.length}',
                      style: TextStyle(fontSize: 10, color: _accentGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    controller: _zone3ScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _zone3ScrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_paymentSplits.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('รายการแยกจ่าย', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _textPrimary)),
                                    const SizedBox(height: 6),
                                    ..._paymentSplits.asMap().entries.map((entry) {
                                      final split = entry.value;
                                      final amount = (split['amount'] ?? 0).toDouble();
                                      final methodLabel = _getPaymentMethodLabel(split['payment_method'] as String);
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '$methodLabel ฿${amount.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 11, color: _textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // Edit button
                                            InkWell(
                                              onTap: () => _showEditSplitDialog(context, entry.key, () => setState(() {})),
                                              child: Icon(Icons.edit, size: 16, color: _accentGreen.withValues(alpha: 0.7)),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _paymentSplits.removeAt(entry.key);
                                                  if (_paymentSplits.isEmpty) {
                                                    _useSplitPayment = false;
                                                  }
                                                });
                                              },
                                              child: Icon(Icons.close, size: 16, color: Colors.red.shade300),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('รวมจ่ายแล้ว', style: TextStyle(fontSize: 11, color: _textSecondary)),
                                        Text('฿${_calculateTotalSplitAmount().toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _accentGreen)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(height: 56, child: _paymentButton(AppBusinessSettings.paymentMethods[0])),
                            const SizedBox(height: 8),
                            SizedBox(height: 56, child: _paymentButton(AppBusinessSettings.paymentMethods[1])),
                            const SizedBox(height: 8),
                            SizedBox(height: 56, child: _paymentButton(AppBusinessSettings.paymentMethods[2])),
                            const SizedBox(height: 8),
                            SizedBox(height: 56, child: _paymentButton(AppBusinessSettings.paymentMethods[3])),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _useSplitPayment = true);
                                  _showAddPaymentMethodDialog(context);
                                },
                                icon: const Icon(Icons.playlist_add, size: 18),
                                label: const Text('เพิ่มวิธีจ่าย'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _accentGreen,
                                  side: BorderSide(color: _accentGreen.withValues(alpha: 0.35)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentButton(BusinessPaymentMethod method) {
    return Material(
      color: method.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_cartItems.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ยังไม่มีสินค้าในตะกร้า'), backgroundColor: Colors.orange),
            );
            return;
          }
          _showPaymentDialog(method.label);
        },
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _gradientIcon(method.icon, size: 22),
                const SizedBox(width: 8),
                _gradientText(method.label, fontSize: 13, weight: FontWeight.w600),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================
  // Zone 4: Sales Overview / Current Product
  // =============================================
  Widget _buildZone4() {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _gradientIcon(Icons.shopping_bag, size: 18),
                const SizedBox(width: 8),
                Text('สินค้า', style: TextStyle(fontSize: 11.5, color: _textSecondary, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_filteredProducts.length} รายการ', style: TextStyle(fontSize: 10.5, color: _textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            // Search bar
            SizedBox(
              height: 34,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onTap: () {
                  _focusSearchField();
                  setState(() {});
                },
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ค้นหาสินค้า...',
                  hintStyle: TextStyle(fontSize: 12, color: _textSecondary),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _gradientIcon(Icons.search, size: 18),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: _gradientIcon(Icons.qr_code_scanner, size: 18),
                        onPressed: () {},
                        tooltip: 'สแกนบาร์โค้ด',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBusinessSettings.defaultPosProductRadius), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Product grid
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(child: Text('ไม่พบสินค้า', style: TextStyle(color: _textSecondary, fontSize: 13)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: AppBusinessSettings.defaultPosProductGridCount,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final price = (product['price'] ?? 0).toDouble();
                        final name = product['name'] ?? '';
                        final isSelected = _selectedProduct != null && _selectedProduct!['id'] == product['id'];

                        return Material(
                          color: isSelected ? _accentGreen.withValues(alpha: 0.1) : _bgColor,
                          borderRadius: BorderRadius.circular(AppBusinessSettings.defaultPosProductRadius),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppBusinessSettings.defaultPosProductRadius),
                            onTap: () => _addToCart(product),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? _accentGreen : _textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '฿${price.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _accentGreen),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  // Zone 5: Recent Transaction / Cart Items
  // =============================================
  Widget _buildZone5() {
    return _glassCard(
      child: Column(
        children: [
          // Header (not expanded, takes only needed space)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
            ),
            child: Row(
              children: [
                _gradientIcon(Icons.receipt, size: 18),
                const SizedBox(width: 8),
                Text('รายการสินค้าในการสั่งซื้อ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                const Spacer(),
                Text('${_cartItems.length} รายการ', style: TextStyle(fontSize: 11, color: _textSecondary)),
                const SizedBox(width: 8),
                // ปุ่มพักบิล
                InkWell(
                  onTap: _holdCurrentOrder,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_circle_outline, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text('พักบิล', style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // ปุ่มเรียกบิลที่พัก
                InkWell(
                  onTap: _showHeldOrdersDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _accentGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_outline, size: 14, color: _accentGreen),
                        const SizedBox(width: 4),
                        Text('เรียกบิล', style: TextStyle(fontSize: 10, color: _accentGreen, fontWeight: FontWeight.w600)),
                        if (_heldOrderCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _accentGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$_heldOrderCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cart items (expanded to fill remaining space)
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _gradientIcon(Icons.shopping_cart_outlined, size: 36),
                        const SizedBox(height: 8),
                        Text('ยังไม่มีรายการ', style: TextStyle(color: _textSecondary, fontSize: 13)),
                        Text('กดเลือกสินค้าจากโซนด้านบน', style: TextStyle(color: _textSecondary.withValues(alpha: 0.6), fontSize: 11)),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _zone5ScrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _zone5ScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      itemCount: _cartItems.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: _borderColor),
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        final product = item['product'] as Map<String, dynamic>;
                        final qty = item['qty'] as int;
                        final price = (product['price'] ?? 0).toDouble();
                        final total = price * qty;
                        final name = product['name'] ?? '';
                        final unit = product['unit'];
                        final unitName = (unit is Map) ? (unit['abbreviation'] ?? unit['name'] ?? '') : '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              // Product name
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (unitName.isNotEmpty)
                                      Text(unitName, style: TextStyle(fontSize: 10, color: _textSecondary)),
                                  ],
                                ),
                              ),
                              // Price per unit
                              SizedBox(
                                width: 60,
                                child: Text('฿${price.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: _textSecondary), textAlign: TextAlign.center),
                              ),
                              // Qty controls
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _qtyButton(Icons.remove, () => _updateQty(index, -1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('$qty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
                                  ),
                                  _qtyButton(Icons.add, () => _updateQty(index, 1)),
                                ],
                              ),
                              // Total
                              SizedBox(
                                width: 70,
                                child: Text('฿${total.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _accentGreen), textAlign: TextAlign.right),
                              ),
                              // Remove
                              IconButton(
                                icon: _gradientIcon(Icons.close, size: 16),
                                onPressed: () => _removeFromCart(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _borderColor),
        ),
        child: Icon(icon, size: 14, color: _textPrimary),
      ),
    );
  }

  // =============================================
  // Glass Card
  // =============================================
  Widget _glassCard({required Widget child}) {
    return Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(AppBusinessSettings.defaultPosCardRadius),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBusinessSettings.defaultPosCardRadius),
        child: child,
      ),
    );
  }

  // =============================================
  // Payment Dialog
  // =============================================
  void _showPaymentDialog(String method) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                _gradientIcon(Icons.payment),
                const SizedBox(width: 8),
                Text(_useSplitPayment ? 'แยกจ่าย' : 'ชำระเงิน - $method', style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary
                    _dialogRow('ยอดรวม', '฿${_subtotal.toStringAsFixed(2)}'),
                    _dialogRow('พนักงานรับผิดชอบ', _displayNameFromUser(_selectedResponsibleStaff)),
                    if (_discount > 0) _dialogRow('ส่วนลดสมาชิก', '-฿${_discount.toStringAsFixed(2)}'),
                    if (_totalDiscountAmount > 0) _dialogRow('ส่วนลดเพิ่มเติม', '-฿${_totalDiscountAmount.toStringAsFixed(2)}'),
                    _dialogRow('ภาษี ${_avgTaxRate.toStringAsFixed(1)}%', '฿${_taxAmount.toStringAsFixed(2)}'),
                    _dialogRow('ค่าบริการ ${(_serviceRate * 100).toStringAsFixed(0)}%', '฿${_serviceAmount.toStringAsFixed(2)}'),
                    const Divider(),
                    _dialogRow('ยอดสุทธิ', '฿${_netTotal.toStringAsFixed(2)}', bold: true),
                    const SizedBox(height: 16),

                    // Split Payment Toggle
                    Row(
                      children: [
                        Checkbox(
                          value: _useSplitPayment,
                          onChanged: (val) {
                            setDialogState(() {
                              _useSplitPayment = val ?? false;
                              if (!_useSplitPayment) {
                                _paymentSplits.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text('แยกจ่ายหลายวิธี', style: TextStyle(fontSize: 13, color: _textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Split Payment UI
                    if (_useSplitPayment) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentGreen.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _accentGreen.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('วิธีการจ่าย', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                            const SizedBox(height: 8),
                            if (_paymentSplits.isEmpty)
                              Text('ยังไม่มีวิธีจ่าย — เพิ่มได้จากปุ่มบนหน้า POS', style: TextStyle(fontSize: 11, color: _textSecondary))
                            else
                              Column(
                                children: List.generate(_paymentSplits.length, (idx) {
                                  final split = _paymentSplits[idx];
                                  final methodKey = split['payment_method'] as String;
                                  final methodLabel = _getPaymentMethodLabel(methodKey);
                                  final amount = (split['amount'] ?? 0).toDouble();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text('$methodLabel: ฿${amount.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 11, color: _textPrimary)),
                                        ),
                                        // Edit button
                                        InkWell(
                                          onTap: () {
                                            _showEditSplitDialog(context, idx, () => setDialogState(() {}));
                                          },
                                          child: Icon(Icons.edit, size: 16, color: _accentGreen.withValues(alpha: 0.7)),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            setDialogState(() => _paymentSplits.removeAt(idx));
                                          },
                                          child: Icon(Icons.close, size: 16, color: Colors.red.shade300),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            const SizedBox(height: 8),
                            // Total paid
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('รวมจ่ายแล้ว:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary)),
                                Text('฿${_calculateTotalSplitAmount().toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _accentGreen)),
                              ],
                            ),
                            if ((_netTotal - _calculateTotalSplitAmount()).abs() > 0.01) ...[
                              const SizedBox(height: 6),
                              Text('ยังเหลือ: ฿${(_netTotal - _calculateTotalSplitAmount()).toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ยกเลิก', style: TextStyle(color: _textSecondary)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.receipt),
                label: const Text('ตัวอย่าง'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showReceiptPreview(_useSplitPayment ? 'แยกจ่าย' : method);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBusinessSettings.defaultPosProductRadius)),
                ),
                onPressed: () {
                  if (_useSplitPayment) {
                    // Validate split payment
                    if (!PosPaymentSplitService.validateSplits(_paymentSplits, _netTotal)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ยอดจ่ายไม่ตรงกับยอดสุทธิ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    checkPermissionAndExecute(
                      context,
                      'pos_main_sell',
                      'ขายสินค้า',
                      () => _processPayment('split'),
                    );
                  } else {
                    Navigator.pop(ctx);
                    checkPermissionAndExecute(
                      context,
                      'pos_main_sell',
                      'ขายสินค้า',
                      () => _processPayment(method),
                    );
                  }
                },
                child: const Text('ยืนยันชำระเงิน'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: _textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: _textPrimary)),
        ],
      ),
    );
  }

  void _showReceiptPreview(String paymentMethod) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = _displayNameFromAuthUser(user);

    // แปลงข้อมูลสินค้าให้ตรงกับรูปแบบที่ใบเสร็จคาดหวัง
    final cartItemsForPrint = _cartItems.map((item) => {
      'product_name': item['product']['name'] ?? 'สินค้า',
      'quantity': item['qty'] ?? 1,
      'unit_price': (item['product']['price'] ?? 0).toDouble(),
    }).toList();

    showDialog(
      context: context,
      builder: (context) => PosReceiptPreviewWidget(
        orderNumber: 'POS-${DateTime.now().toString().replaceAll(RegExp(r'[^\d]'), '').substring(0, 14)}',
        orderType: _orderType,
        tableNumber: _selectedTableNumber,
        customerName: _selectedCustomer?['display_name'] ?? _selectedCustomerName,
        cashierName: userName,
        items: cartItemsForPrint,
        subtotal: _subtotal,
        discountAmount: _discount + _totalDiscountAmount,
        taxAmount: _taxAmount,
        serviceAmount: _serviceAmount,
        netTotal: _netTotal,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
      ),
    );
  }

  // =============================================
  // Phase 2D: Split Payment Helpers
  // =============================================

  double _calculateTotalSplitAmount() {
    double total = 0;
    for (final split in _paymentSplits) {
      total += (split['amount'] ?? 0).toDouble();
    }
    return total;
  }

  String _getPaymentMethodLabel(String key) {
    switch (key) {
      case 'cash':
        return 'เงินสด';
      case 'credit_debit':
        return 'เครดิต/เดบิต';
      case 'transfer':
        return 'โอน/พร้อมเพย์';
      case 'qr_code':
        return 'QR Code';
      default:
        return key;
    }
  }

  void _showAddPaymentMethodDialog(BuildContext ctx) {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    String selectedMethod = 'cash';

    showDialog(
      context: ctx,
      builder: (addCtx) {
        return StatefulBuilder(
          builder: (addCtx, setAddState) {
            return AlertDialog(
              title: const Text('เพิ่มวิธีจ่าย', style: TextStyle(fontSize: 15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('วิธีการจ่าย', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedMethod,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: 'cash', child: Text(_getPaymentMethodLabel('cash'))),
                      DropdownMenuItem(value: 'credit_debit', child: Text(_getPaymentMethodLabel('credit_debit'))),
                      DropdownMenuItem(value: 'transfer', child: Text(_getPaymentMethodLabel('transfer'))),
                      DropdownMenuItem(value: 'qr_code', child: Text(_getPaymentMethodLabel('qr_code'))),
                    ],
                    onChanged: (val) {
                      setAddState(() => selectedMethod = val ?? 'cash');
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('จำนวนเงิน', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('เลขอ้างอิง (ถ้ามี)', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      hintText: 'เลขบัตร / สลิปโอน',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(addCtx),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _accentGreen),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(addCtx).showSnackBar(
                        const SnackBar(content: Text('กรุณาใส่จำนวนเงิน'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    setState(() {
                      _paymentSplits.add({
                        'payment_method': selectedMethod,
                        'amount': amount,
                        'reference_number': refController.text.isNotEmpty ? refController.text : null,
                      });
                    });
                    Navigator.pop(addCtx);
                  },
                  child: const Text('เพิ่ม', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSplitDialog(BuildContext ctx, int index, VoidCallback setStateCallback) {
    final split = _paymentSplits[index];
    final amountController = TextEditingController(text: (split['amount'] ?? 0).toString());
    final refController = TextEditingController(text: split['reference_number']?.toString() ?? '');
    String selectedMethod = split['payment_method'] as String;

    showDialog(
      context: ctx,
      builder: (editCtx) {
        return StatefulBuilder(
          builder: (editCtx, setEditState) {
            return AlertDialog(
              title: const Text('แก้ไขรายการจ่าย', style: TextStyle(fontSize: 15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('วิธีการจ่าย', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedMethod,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: 'cash', child: Text(_getPaymentMethodLabel('cash'))),
                      DropdownMenuItem(value: 'credit_debit', child: Text(_getPaymentMethodLabel('credit_debit'))),
                      DropdownMenuItem(value: 'transfer', child: Text(_getPaymentMethodLabel('transfer'))),
                      DropdownMenuItem(value: 'qr_code', child: Text(_getPaymentMethodLabel('qr_code'))),
                    ],
                    onChanged: (val) {
                      setEditState(() => selectedMethod = val ?? 'cash');
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('จำนวนเงิน', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('เลขอ้างอิง (ถ้ามี)', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      hintText: 'เลขบัตร / สลิปโอน',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(editCtx),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _accentGreen),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(editCtx).showSnackBar(
                        const SnackBar(content: Text('กรุณาใส่จำนวนเงิน'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    setState(() {
                      _paymentSplits[index] = {
                        'payment_method': selectedMethod,
                        'amount': amount,
                        'reference_number': refController.text.isNotEmpty ? refController.text : null,
                      };
                    });
                    setStateCallback();
                    Navigator.pop(editCtx);
                  },
                  child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =============================================
  // Phase 2C: Hold/Resume Orders
  // =============================================

  Future<void> _holdCurrentOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีรายการในตะกร้าที่จะพักบิล'), backgroundColor: Colors.orange),
      );
      return;
    }

    // ถ้ามีโน้ต ให้ใส่ได้
    String? note;
    final noteResult = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.pause_circle, color: _accentGreen),
              const SizedBox(width: 8),
              const Text('พักบิล', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_cartItems.length} รายการ  ยอด ฿${_subtotal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: _textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'หมายเหตุ (ไม่บังคับ)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: _accentGreen),
              child: const Text('พักบิล', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (noteResult == null) return; // user cancelled
    note = noteResult.isNotEmpty ? noteResult : null;

    final result = await PosHeldOrderService.holdOrder(
      cartItems: _cartItems,
      subtotal: _subtotal,
      appliedDiscounts: _appliedDiscounts.isNotEmpty ? _appliedDiscounts : null,
      orderType: _orderType,
      tableId: _selectedTableId,
      tableNumber: _selectedTableNumber,
      customerId: _selectedCustomer?['id']?.toString(),
      customerName: _selectedCustomer?['display_name']?.toString() ?? _selectedCustomerName,
      note: note,
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('พักบิลสำเร็จ — ${result.displayLabel}'),
          backgroundColor: _accentGreen,
        ),
      );
      setState(() {
        _cartItems.clear();
        _selectedProduct = null;
        _appliedDiscounts.clear();
        _totalDiscountAmount = 0;
        _redeemedPoints = 0;
        _selectedCustomer = null;
        _heldOrderCount++;
      });
    }
  }

  void _resumeHeldOrder(PosHeldOrder heldOrder) {
    // ถ้าตะกร้ายังมีของ ถามก่อน
    if (_cartItems.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ยืนยัน', style: TextStyle(fontSize: 16)),
          content: const Text('ตะกร้าปัจจุบันมีรายการอยู่ จะแทนที่ด้วยบิลที่พักหรือไม่?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doResumeHeldOrder(heldOrder);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('แทนที่', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _doResumeHeldOrder(heldOrder);
    }
  }

  Future<void> _doResumeHeldOrder(PosHeldOrder heldOrder) async {
    final resumed = await PosHeldOrderService.resumeOrder(heldOrder.id);
    if (resumed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเรียกบิลกลับได้'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // แปลง cart_data กลับเป็น _cartItems format
    // ต้อง lookup product จาก _products ที่โหลดไว้
    final restoredCart = <Map<String, dynamic>>[];
    for (final item in heldOrder.cartData) {
      final productId = item['product_id'] as String?;
      if (productId == null) continue;

      // หา product จาก loaded products
      Map<String, dynamic>? product;
      try {
        product = _products.firstWhere((p) => p['id'] == productId);
      } catch (_) {
        // ถ้าไม่เจอ ให้สร้าง product map จาก snapshot
        product = {
          'id': productId,
          'name': item['product_name'] ?? 'สินค้า',
          'price': item['price'] ?? 0,
          'unit': item['unit'],
          'image_url': item['image_url'],
          'category_id': item['category_id'],
          'tax_rate': item['tax_rate'],
          'is_tax_exempt': item['is_tax_exempt'],
        };
      }

      restoredCart.add({
        'product': product,
        'qty': item['qty'] ?? 1,
        'note': item['note'],
      });
    }

    // Restore discounts if any
    final restoredDiscounts = <Map<String, dynamic>>[];
    if (heldOrder.discountData != null) {
      restoredDiscounts.addAll(heldOrder.discountData!);
    }
    double restoredDiscountAmount = 0;
    for (final d in restoredDiscounts) {
      restoredDiscountAmount += (d['discount_amount'] ?? 0).toDouble();
    }

    setState(() {
      _cartItems.clear();
      _cartItems.addAll(restoredCart);
      _appliedDiscounts.clear();
      _appliedDiscounts.addAll(restoredDiscounts);
      _totalDiscountAmount = restoredDiscountAmount;
      _heldOrderCount = (_heldOrderCount - 1).clamp(0, 9999);

      // Restore table/customer context
      if (heldOrder.orderType == 'dine_in') {
        _orderType = 'dine_in';
        _selectedTableId = heldOrder.tableId;
        _selectedTableNumber = heldOrder.tableNumber;
      }
      if (heldOrder.customerName != null) {
        _selectedCustomerName = heldOrder.customerName;
      }
    });

    // โหลดค่าบริการจากโซนของโต๊ะที่ restore
    await _loadZoneServiceCharge();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เรียกบิลกลับสำเร็จ — ${heldOrder.displayLabel} (${restoredCart.length} รายการ)'),
          backgroundColor: _accentGreen,
        ),
      );
    }
  }

  Future<void> _showHeldOrdersDialog() async {
    final heldOrders = await PosHeldOrderService.getHeldOrders();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.pause_circle_outline, color: _accentGreen),
                  const SizedBox(width: 8),
                  Text('บิลที่พัก (${heldOrders.length})', style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: heldOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: _textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text('ไม่มีบิลที่พักอยู่', style: TextStyle(color: _textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: heldOrders.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final order = heldOrders[index];
                          final heldAgo = DateTime.now().difference(order.heldAt);
                          final agoStr = heldAgo.inMinutes < 60
                              ? '${heldAgo.inMinutes} นาทีที่แล้ว'
                              : '${heldAgo.inHours} ชม.ที่แล้ว';

                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _accentGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  order.tableNumber != null ? Icons.table_restaurant : Icons.receipt_long,
                                  color: _accentGreen,
                                  size: 20,
                                ),
                              ),
                            ),
                            title: Text(
                              order.displayLabel,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${order.lineCount} รายการ (${order.itemCount} ชิ้น)  ฿${order.subtotal.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 11, color: _textSecondary),
                                ),
                                Row(
                                  children: [
                                    Text(agoStr, style: TextStyle(fontSize: 10, color: _textSecondary.withValues(alpha: 0.7))),
                                    if (order.note != null && order.note!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          order.note!,
                                          style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // เรียกกลับ
                                IconButton(
                                  icon: Icon(Icons.play_circle, color: _accentGreen, size: 28),
                                  tooltip: 'เรียกบิลกลับ',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _resumeHeldOrder(order);
                                  },
                                ),
                                // ยกเลิก
                                IconButton(
                                  icon: Icon(Icons.cancel_outlined, color: Colors.red.shade300, size: 24),
                                  tooltip: 'ยกเลิกบิล',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (c) => AlertDialog(
                                        title: const Text('ยืนยันยกเลิก', style: TextStyle(fontSize: 15)),
                                        content: Text('ยกเลิกบิล "${order.displayLabel}" ?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไม่')),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(c, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await PosHeldOrderService.cancelHeldOrder(order.id);
                                      setDialogState(() {
                                        heldOrders.removeAt(index);
                                      });
                                      if (mounted) {
                                        setState(() => _heldOrderCount = (_heldOrderCount - 1).clamp(0, 9999));
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processPayment(String method) async {
    if (_isProcessing) return;
    if (_selectedResponsibleStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกพนักงานผู้รับผิดชอบก่อนชำระเงิน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_orderType == 'dine_in' && (_selectedTableNumber == null || _selectedTableNumber!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกโต๊ะก่อนทำรายการ dine-in'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Phase 2B: บังคับเปิดกะก่อนชำระเงิน
    if (_currentShift == null || !_currentShift!.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเปิดกะก่อนชำระเงิน'),
          backgroundColor: Colors.orange,
        ),
      );
      _showOpenShiftDialog();
      return;
    }

    setState(() => _isProcessing = true);

    final user = Supabase.instance.client.auth.currentUser;
    final userName = _displayNameFromAuthUser(user);
    final responsibleUserId = _selectedResponsibleStaff?['id']?.toString() ?? '';
    final responsibleUserName = _displayNameFromUser(_selectedResponsibleStaff);

    final result = await InventoryService.createPosOrder(
      cartItems: _cartItems,
      subtotal: _subtotal,
      discountAmount: _discount,
      discountNote: _discount > 0 ? 'ส่วนลด' : null,
      taxRate: _avgTaxRate,
      taxAmount: _taxAmount,
      serviceRate: _serviceRate * 100,
      serviceAmount: _serviceAmount,
      netTotal: _netTotal,
      paymentMethod: method,
      responsibleUserId: responsibleUserId,
      responsibleUserName: responsibleUserName,
      cashierUserId: user?.id,
      cashierUserName: userName,
      orderType: _orderType,
      tableNumber: _orderType == 'dine_in' ? _selectedTableNumber : null,
      tableId: _orderType == 'dine_in' ? _selectedTableId : null,
      tableSessionId: _orderType == 'dine_in' ? _selectedTableSessionId : null,
      customerUserId: _selectedCustomerUserId,
      customerName: _selectedCustomerName,
      userName: userName,
      appliedDiscounts: _appliedDiscounts,
      totalDiscountAmount: _totalDiscountAmount,
      customerId: _selectedCustomer?['id']?.toString(),
      loyaltyPointsRedeemed: _redeemedPoints,
      shiftId: _currentShift?.id,
    );

    setState(() => _isProcessing = false);

    if (result != null) {
      final orderId = result['id'] as String;
      final orderNumber = result['order_number'] ?? '';

      // Phase 2D: Save split payments if used
      if (_useSplitPayment && _paymentSplits.isNotEmpty) {
        await PosPaymentSplitService.savePaymentSplits(
          orderId: orderId,
          splits: _paymentSplits,
        );
      }

      // Phase 2: Record discount usage
      for (final discountData in _appliedDiscounts) {
        final discountId = discountData['discount_id']?.toString();
        final discountAmount = (discountData['discount_amount'] ?? 0).toDouble();
        final couponCode = discountData['coupon_code']?.toString();
        final discountInfo = discountData['pos_discounts'] as Map<String, dynamic>?;

        if (discountId != null && discountId.isNotEmpty) {
          await PosDiscountService.recordDiscountUsage(
            orderId: orderId,
            discountId: discountId,
            discountAmount: discountAmount,
            appliedBy: userName,
            customerId: _selectedCustomer?['id']?.toString(),
            couponCode: couponCode,
            discountName: discountInfo?['name']?.toString() ?? '',
            discountType: discountInfo?['discount_type']?.toString() ?? 'fixed',
            discountValue: (discountInfo?['value'] ?? 0).toDouble(),
          );
        }
      }

      // Phase 2F: Auto-print receipt
      final cartItemsForPrint = _cartItems.map((item) => {
        'product_name': item['product']['name'],
        'quantity': item['qty'],
        'unit_price': item['product']['price'],
      }).toList();
      
      final printSuccess = await PosPrinterService.autoPrintReceipt(
        orderId: orderId,
        orderNumber: orderNumber,
        orderType: _orderType,
        tableNumber: _orderType == 'dine_in' ? _selectedTableNumber : null,
        customerName: _selectedCustomerName,
        cashierName: userName,
        items: cartItemsForPrint,
        subtotal: _subtotal,
        discountAmount: _discount + _totalDiscountAmount,
        taxAmount: _taxAmount,
        serviceAmount: _serviceAmount,
        netTotal: _netTotal,
        paymentMethod: _useSplitPayment ? 'split' : method,
        createdAt: DateTime.now(),
      );

      if (mounted && printSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('พิมพ์ใบเสร็จสำเร็จ $orderNumber'),
            backgroundColor: _accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (mounted) {
        final paymentLabel = _useSplitPayment ? 'แยกจ่าย' : method;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ชำระเงินสำเร็จ ($paymentLabel) $orderNumber ยอด ฿${_netTotal.toStringAsFixed(2)}'),
            backgroundColor: _accentGreen,
          ),
        );
      }
      setState(() {
        _cartItems.clear();
        _selectedProduct = null;
        _appliedDiscounts.clear();
        _totalDiscountAmount = 0;
        _redeemedPoints = 0;
        _selectedCustomer = null;
        _paymentSplits.clear();
        _useSplitPayment = false;
      });
      // Reload products to refresh stock
      _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึกออเดอร์'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
