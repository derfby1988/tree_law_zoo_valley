import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';
import '../services/inventory_service.dart';

class PromotionProductPickerPage extends StatefulWidget {
  final List<Map<String, dynamic>> initiallySelectedProducts;

  const PromotionProductPickerPage({
    super.key,
    this.initiallySelectedProducts = const [],
  });

  @override
  State<PromotionProductPickerPage> createState() => _PromotionProductPickerPageState();
}

class _PromotionProductPickerPageState extends State<PromotionProductPickerPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  
  // Selected products
  List<Map<String, dynamic>> _selectedProducts = [];
  
  // Data for each tab
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _expiringProducts = [];
  List<Map<String, dynamic>> _expiringIngredients = [];
  List<Map<String, dynamic>> _highMarginProducts = [];
  List<Map<String, dynamic>> _seasonalProducts = [];
  List<Map<String, dynamic>> _festivalProducts = [];
  List<Map<String, dynamic>> _recommendedProducts = [];
  
  // Loading states
  bool _isLoading = true;
  Map<String, bool> _tabLoading = {
    'all': true,
    'expiring': true,
    'ingredients': true,
    'margin': true,
    'seasonal': true,
    'festival': true,
    'recommended': true,
  };

  // Filter
  String _selectedCategory = 'all';
  String _expiringFilter = '7'; // days
  String _marginFilter = 'high'; // high, medium, low
  String _seasonFilter = 'summer'; // summer, rainy, winter

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _selectedProducts = List.from(widget.initiallySelectedProducts);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadAllProducts(),
      _loadExpiringProducts(),
      _loadExpiringIngredients(),
      _loadHighMarginProducts(),
      _loadSeasonalProducts(),
      _loadFestivalProducts(),
      _loadRecommendedProducts(),
    ]);
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadAllProducts() async {
    try {
      final products = await InventoryService.getProducts();
      // TODO: Filter by category if needed
      // if (_selectedCategory != 'all') {
      //   products = products.where((p) => p['category_id'] == _selectedCategory).toList();
      // }
      setState(() {
        _allProducts = products;
        _tabLoading['all'] = false;
      });
    } catch (e) {
      debugPrint('Error loading all products: $e');
      setState(() => _tabLoading['all'] = false);
    }
  }

  Future<void> _loadExpiringProducts() async {
    // TODO: Implement with actual API for expiring products
    // For now, simulate with placeholder data
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _expiringProducts = [];
      _tabLoading['expiring'] = false;
    });
  }

  Future<void> _loadExpiringIngredients() async {
    // TODO: Implement with actual API
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _expiringIngredients = [];
      _tabLoading['ingredients'] = false;
    });
  }

  Future<void> _loadHighMarginProducts() async {
    // TODO: Implement with actual API
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _highMarginProducts = [];
      _tabLoading['margin'] = false;
    });
  }

  Future<void> _loadSeasonalProducts() async {
    // TODO: Implement with actual API
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _seasonalProducts = [];
      _tabLoading['seasonal'] = false;
    });
  }

  Future<void> _loadFestivalProducts() async {
    // TODO: Implement with actual API
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _festivalProducts = [];
      _tabLoading['festival'] = false;
    });
  }

  Future<void> _loadRecommendedProducts() async {
    // TODO: Implement with actual API
    // This combines expiring, high margin, seasonal, etc.
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _recommendedProducts = [];
      _tabLoading['recommended'] = false;
    });
  }

  void _toggleProductSelection(Map<String, dynamic> product) {
    setState(() {
      final existingIndex = _selectedProducts.indexWhere(
        (p) => p['id'] == product['id'],
      );
      
      if (existingIndex >= 0) {
        _selectedProducts.removeAt(existingIndex);
      } else {
        _selectedProducts.add({
          ...product,
          'quantity': 1,
        });
      }
    });
  }

  void _updateQuantity(String productId, int quantity) {
    setState(() {
      final index = _selectedProducts.indexWhere((p) => p['id'] == productId);
      if (index >= 0) {
        if (quantity <= 0) {
          _selectedProducts.removeAt(index);
        } else {
          _selectedProducts[index]['quantity'] = quantity;
        }
      }
    });
  }

  void _finishSelection() {
    Navigator.pop(context, _selectedProducts);
  }

  List<Map<String, dynamic>> _getCurrentTabProducts() {
    switch (_tabController.index) {
      case 0:
        return _allProducts;
      case 1:
        return _expiringProducts;
      case 2:
        return _expiringIngredients;
      case 3:
        return _highMarginProducts;
      case 4:
        return _seasonalProducts;
      case 5:
        return _festivalProducts;
      case 6:
        return _recommendedProducts;
      default:
        return _allProducts;
    }
  }

  bool _isTabLoading() {
    final tabNames = ['all', 'expiring', 'ingredients', 'margin', 'seasonal', 'festival', 'recommended'];
    return _tabLoading[tabNames[_tabController.index]] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppDesignSystem.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'เลือกสินค้าเข้าร่วมโปรโมชัน',
          style: TextStyle(
            color: AppDesignSystem.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppDesignSystem.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppDesignSystem.primary,
          tabs: const [
            Tab(text: 'ทั้งหมด'),
            Tab(text: 'ใกล้หมดอายุ'),
            Tab(text: 'วัตถุดิบใกล้หมด'),
            Tab(text: 'กำไรสูง'),
            Tab(text: 'ตามฤดูกาล'),
            Tab(text: 'เทศกาล'),
            Tab(text: 'แนะนำ'),
          ],
          onTap: (_) => setState(() {}), // Refresh to show correct filter UI
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'เลือก ${_selectedProducts.length} รายการ',
                style: const TextStyle(
                  color: AppDesignSystem.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาสินค้า / SKU / Barcode',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 8),
                
                // Tab-specific filters
                _buildFilterBar(),
              ],
            ),
          ),
          
          // Product List
          Expanded(
            child: _isTabLoading()
                ? const Center(child: CircularProgressIndicator())
                : _buildProductList(),
          ),
          
          // Bottom Selected Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'เลือกแล้ว ${_selectedProducts.length} รายการ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (_selectedProducts.isNotEmpty)
                          Text(
                            _selectedProducts.map((p) => p['name']).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _finishSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('เสร็จ'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    // Different filters based on current tab
    switch (_tabController.index) {
      case 0: // All
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'ทุกหมวดหมู่',
                isSelected: _selectedCategory == 'all',
                onTap: () {
                  setState(() {
                    _selectedCategory = 'all';
                    _loadAllProducts();
                  });
                },
              ),
              // TODO: Add dynamic category chips
            ],
          ),
        );
        
      case 1: // Expiring
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: '3 วัน',
                isSelected: _expiringFilter == '3',
                onTap: () => setState(() => _expiringFilter = '3'),
              ),
              _buildFilterChip(
                label: '7 วัน',
                isSelected: _expiringFilter == '7',
                onTap: () => setState(() => _expiringFilter = '7'),
              ),
              _buildFilterChip(
                label: '14 วัน',
                isSelected: _expiringFilter == '14',
                onTap: () => setState(() => _expiringFilter = '14'),
              ),
              _buildFilterChip(
                label: '30 วัน',
                isSelected: _expiringFilter == '30',
                onTap: () => setState(() => _expiringFilter = '30'),
              ),
            ],
          ),
        );
        
      case 3: // High Margin
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'กำไรสูง',
                isSelected: _marginFilter == 'high',
                onTap: () => setState(() => _marginFilter = 'high'),
              ),
              _buildFilterChip(
                label: 'กำไรกลาง',
                isSelected: _marginFilter == 'medium',
                onTap: () => setState(() => _marginFilter = 'medium'),
              ),
              _buildFilterChip(
                label: 'กำไรต่ำ',
                isSelected: _marginFilter == 'low',
                onTap: () => setState(() => _marginFilter = 'low'),
              ),
            ],
          ),
        );
        
      case 4: // Seasonal
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'ฤดูร้อน',
                isSelected: _seasonFilter == 'summer',
                onTap: () => setState(() => _seasonFilter = 'summer'),
              ),
              _buildFilterChip(
                label: 'ฤดูฝน',
                isSelected: _seasonFilter == 'rainy',
                onTap: () => setState(() => _seasonFilter = 'rainy'),
              ),
              _buildFilterChip(
                label: 'ฤดูหนาว',
                isSelected: _seasonFilter == 'winter',
                onTap: () => setState(() => _seasonFilter = 'winter'),
              ),
            ],
          ),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => onTap(),
        selectedColor: AppDesignSystem.primary.withOpacity(0.2),
        checkmarkColor: AppDesignSystem.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppDesignSystem.primary : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final products = _getCurrentTabProducts();
    final searchQuery = _searchCtrl.text.toLowerCase();
    
    final filteredProducts = searchQuery.isEmpty
        ? products
        : products.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery);
          }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'ไม่พบสินค้า',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final isSelected = _selectedProducts.any((p) => p['id'] == product['id']);
        
        return _buildProductCard(product, isSelected);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isSelected) {
    final selectedIndex = _selectedProducts.indexWhere((p) => p['id'] == product['id']);
    final quantity = selectedIndex >= 0 ? (_selectedProducts[selectedIndex]['quantity'] ?? 1) : 0;
    
    // Tab-specific info
    Widget? subtitle;
    switch (_tabController.index) {
      case 1: // Expiring
        subtitle = _buildExpiringSubtitle(product);
        break;
      case 2: // Ingredients
        subtitle = _buildIngredientSubtitle(product);
        break;
      case 3: // Margin
        subtitle = _buildMarginSubtitle(product);
        break;
      case 6: // Recommended
        subtitle = _buildRecommendedSubtitle(product);
        break;
      default:
        subtitle = Text(
          'หมวด: ${product['category']?['name'] ?? 'ไม่ระบุ'} | ฿${product['price'] ?? 0} | คงเหลือ ${product['quantity'] ?? 0}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppDesignSystem.primary : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleProductSelection(product),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleProductSelection(product),
                    activeColor: AppDesignSystem.primary,
                  ),
                  Expanded(
                    child: Text(
                      product['name'] ?? 'ไม่มีชื่อ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _updateQuantity(product['id'], quantity - 1),
                            child: const Icon(Icons.remove, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$quantity',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _updateQuantity(product['id'], quantity + 1),
                            child: const Icon(Icons.add, size: 16),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 4),
                  child: subtitle,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSubtitle(Map<String, dynamic> product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'หมดอายุ: ${product['expiry_date'] ?? 'ไม่ระบุ'}',
          style: TextStyle(fontSize: 12, color: Colors.red[600]),
        ),
        Text(
          'เหลือ ${product['expiring_quantity'] ?? 0} หน่วย | คงเหลือทั้งหมด ${product['quantity'] ?? 0}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildIngredientSubtitle(Map<String, dynamic> product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วัตถุดิบใกล้หมด: ${product['expiring_ingredients'] ?? 'ไม่ระบุ'}',
          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
        ),
        Text(
          'ทำได้ประมาณ ${product['possible_servings'] ?? 0} จาน',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMarginSubtitle(Map<String, dynamic> product) {
    final margin = product['gross_margin_percent'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'กำไร: ${margin.toStringAsFixed(1)}% | ราคา: ฿${product['price'] ?? 0}',
          style: TextStyle(
            fontSize: 12,
            color: margin > 50 ? Colors.green[700] : Colors.orange[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'คงเหลือ: ${product['quantity'] ?? 0} หน่วย',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRecommendedSubtitle(Map<String, dynamic> product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppDesignSystem.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            product['reason'] ?? 'แนะนำโดยระบบ',
            style: TextStyle(
              fontSize: 11,
              color: AppDesignSystem.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Score: ${product['priority_score'] ?? 0}/100',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
