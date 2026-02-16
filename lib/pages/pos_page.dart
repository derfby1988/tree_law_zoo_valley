import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/inventory_service.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  // Data
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic>? _selectedProduct;
  String? _selectedCategoryId;
  bool _isLoading = true;

  // Search
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();

  // Colors from reference image
  static const _bgColor = Color(0xFFF5F6FA);
  static const _cardColor = Color(0xFFFFFFFF);
  static const _sidebarColor = Color(0xFFF8F9FD);
  static const _accentGreen = Color(0xFF2AD49B);
  static const _accentDark = Color(0xFF1B1D28);
  static const _textPrimary = Color(0xFF1B1D28);
  static const _textSecondary = Color(0xFF8B8D97);
  static const _borderColor = Color(0xFFE8E9EE);
  static const _selectedSidebar = Color(0xFFE8FFF5);
  static const _iconGradient = LinearGradient(
    colors: [Color(0xFF4992E7), Color(0xFF68CB9C)],
    begin: Alignment(-0.966, 0.259),
    end: Alignment(0.966, -0.259),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Widget _gradientIcon(IconData icon, {double size = 18}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => _iconGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        InventoryService.getProducts(),
        InventoryService.getCategories(),
      ]);
      setState(() {
        _products = results[0];
        _categories = results[1];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading POS data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Cart logic
  void _addToCart(Map<String, dynamic> product) {
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

  double get _taxRate => 0.07;
  double get _serviceRate => 0.10;
  double get _discount => 0; // TODO: implement discount logic
  double get _preTaxTotal => _subtotal - _discount;
  double get _taxAmount => _preTaxTotal * _taxRate;
  double get _serviceAmount => _preTaxTotal * _serviceRate;
  double get _netTotal => _preTaxTotal + _taxAmount + _serviceAmount;

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
      body: SafeArea(
        child: Row(
          children: [
            // Left Icon Bar (full height, over header)
            _buildLeftIconBar(),
            // Main content
            Expanded(
              child: Column(
                children: [
                  // Header
                  _buildHeader(),
                  // Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Top row: Zone 1, 2, 3
                          // Zone 3 height = Zone 1 height + gap + Zone 4 height
                          Expanded(
                            flex: 6,
                            child: _buildTopAndMiddleRow(),
                          ),
                          const SizedBox(height: 12),
                          // Zone 5: Recent Transaction / Cart
                          Expanded(
                            flex: 4,
                            child: _buildZone5(),
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
                ? const Border(left: BorderSide(color: _accentGreen, width: 3))
                : null,
          ),
          child: _gradientIcon(icon, size: 22),
        ),
      ),
    );
  }

  // =============================================
  // Header
  // =============================================
  Widget _buildHeader() {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'พนักงาน';
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year + 543}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          _gradientIcon(Icons.storefront, size: 22),
          const SizedBox(width: 8),
          Text('TREE LAW ZOO', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _textSecondary)),
          const SizedBox(width: 16),
          _headerChip(Icons.table_restaurant, 'โต๊ะ #-'),
          const SizedBox(width: 8),
          _headerChip(Icons.person, userName),
          const Spacer(),
          _headerChip(Icons.calendar_today, dateStr),
          const SizedBox(width: 8),
          _headerChip(Icons.access_time, timeStr),
          const SizedBox(width: 8),
          IconButton(
            icon: _gradientIcon(Icons.arrow_back, size: 20),
            color: _textSecondary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'กลับ',
          ),
        ],
      ),
    );
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _gradientIcon(Icons.receipt_long, size: 18),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('ราคารวมก่อนคำนวณภาษี',
                      style: TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '฿ ${_preTaxTotal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
                const SizedBox(height: 4),
                if (_discount > 0) _discountRow('ส่วนลดสมาชิก', -_discount),
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
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _gradientIcon(Icons.analytics, size: 16),
                ),
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
            _infoRow('ภาษี 7%', _taxAmount),
            _infoRow('ค่าบริการ 10%', _serviceAmount),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _gradientIcon(Icons.payment, size: 18),
                ),
                const SizedBox(width: 8),
                Text('การชำระเงิน', style: TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _paymentButton(Icons.money, 'เงินสด', Colors.green[600]!)),
            const SizedBox(height: 8),
            Expanded(child: _paymentButton(Icons.credit_card, 'เครดิต/เดบิต', Colors.blue[600]!)),
            const SizedBox(height: 8),
            Expanded(child: _paymentButton(Icons.phone_android, 'โอน/พร้อมเพย์', Colors.orange[600]!)),
            const SizedBox(height: 8),
            Expanded(child: _paymentButton(Icons.qr_code_2, 'QR Code', Colors.purple[600]!)),
          ],
        ),
      ),
    );
  }

  Widget _paymentButton(IconData icon, String label, Color color) {
    return Material(
      color: color.withOpacity(0.08),
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
          _showPaymentDialog(label);
        },
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _gradientIcon(Icons.shopping_bag, size: 18),
                ),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                        crossAxisCount: 3,
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
                          color: isSelected ? _accentGreen.withOpacity(0.1) : _bgColor,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
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
          // Header
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
              ],
            ),
          ),
          // Cart items
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _gradientIcon(Icons.shopping_cart_outlined, size: 36),
                        const SizedBox(height: 8),
                        Text('ยังไม่มีรายการ', style: TextStyle(color: _textSecondary, fontSize: 13)),
                        Text('กดเลือกสินค้าจากโซนด้านบน', style: TextStyle(color: _textSecondary.withOpacity(0.6), fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor),
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            _gradientIcon(Icons.payment),
            const SizedBox(width: 8),
            Text('ชำระเงิน - $method', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogRow('ยอดรวม', '฿${_subtotal.toStringAsFixed(2)}'),
            if (_discount > 0) _dialogRow('ส่วนลด', '-฿${_discount.toStringAsFixed(2)}'),
            _dialogRow('ภาษี 7%', '฿${_taxAmount.toStringAsFixed(2)}'),
            _dialogRow('ค่าบริการ 10%', '฿${_serviceAmount.toStringAsFixed(2)}'),
            const Divider(),
            _dialogRow('ยอดสุทธิ', '฿${_netTotal.toStringAsFixed(2)}', bold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processPayment(method);
            },
            child: const Text('ยืนยันชำระเงิน'),
          ),
        ],
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

  Future<void> _processPayment(String method) async {
    // TODO: Save order to database
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ชำระเงินสำเร็จ ($method) ยอด ฿${_netTotal.toStringAsFixed(2)}'),
        backgroundColor: _accentGreen,
      ),
    );
    setState(() {
      _cartItems.clear();
      _selectedProduct = null;
    });
  }
}
