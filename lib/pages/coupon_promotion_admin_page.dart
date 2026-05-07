import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';
import '../services/pos_discount_service.dart';
import '../services/pos_promotion_service.dart';
import '../services/inventory_service.dart';
import '../services/user_group_service.dart';
import '../models/pos_discount_model.dart';
import '../models/pos_promotion_model.dart';
import '../models/user_group_model.dart';
import '../models/pagination_model.dart';
import '../utils/date_picker_helper.dart';
import '../utils/permission_helpers.dart';
import 'promotion_form_page.dart';
import 'promotion_product_picker_page.dart';

class CouponPromotionAdminPage extends StatefulWidget {
  const CouponPromotionAdminPage({super.key});

  @override
  State<CouponPromotionAdminPage> createState() => _CouponPromotionAdminPageState();
}

class _CouponPromotionAdminPageState extends State<CouponPromotionAdminPage> {
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  List<PosDiscount> _coupons = [];
  List<PosPromotion> _promotions = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<UserGroup> _userGroups = [];
  String? _errorMessage;
  
  // Phase 5: Expiry targeting data
  List<Map<String, dynamic>> _expiringProducts = [];
  List<Map<String, dynamic>> _expiringIngredients = [];
  String _expiryFilter = '7days'; // 3days, 7days, 14days, 30days, expired
  bool _isLoadingExpiry = false;
  
  // Phase 7: Analytics data
  List<Map<String, dynamic>> _usageData = [];
  DateTime? _analyticsStartDate;
  DateTime? _analyticsEndDate;
  String? _selectedCouponId;
  String? _selectedPromotionId;
  bool _isLoadingAnalytics = false;
  Map<String, dynamic>? _analyticsSummary;
  
  // Phase 3: Enhanced product management
  PaginationState _productPagination = PaginationState();
  List<Map<String, dynamic>> _filteredProducts = [];
  String _productSearchQuery = '';
  String _selectedCategory = 'all';
  bool _showProductFilters = false;
  String _productSortBy = 'name';
  bool _productSortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        PosDiscountService.getAllDiscounts(),
        PosPromotionService.getAllPromotions(),
        // Phase 3: Use cached product loading
        InventoryService.getProducts(useCache: true),
        InventoryService.getCategories(useCache: true),
        UserGroupService.getAllGroups(),
      ]);

      setState(() {
        _coupons = results[0] as List<PosDiscount>;
        _promotions = results[1] as List<PosPromotion>;
        _allProducts = results[2] as List<Map<String, dynamic>>;
        _categories = results[3] as List<Map<String, dynamic>>;
        _userGroups = results[4] as List<UserGroup>;
        _filteredProducts = _allProducts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }
  
  // Phase 3: Enhanced product loading with pagination
  Future<void> _loadProductsPaginated({bool refresh = false}) async {
    if (refresh) {
      _productPagination.reset();
      InventoryService.clearCachePattern('getProducts');
    }
    
    setState(() {
      _productPagination.setLoading(true);
    });
    
    try {
      final result = await InventoryService.getProductsPaginated(
        page: _productPagination.currentPage,
        limit: _productPagination.limit,
        categoryId: _selectedCategory == 'all' ? null : _selectedCategory,
        searchQuery: _productSearchQuery.isNotEmpty ? _productSearchQuery : null,
        sortBy: _productSortBy,
        ascending: _productSortAscending,
        useCache: !refresh,
      );
      
      setState(() {
        if (refresh || _productPagination.currentPage == 1) {
          _filteredProducts = result.data.cast<Map<String, dynamic>>();
        } else {
          _filteredProducts.addAll(result.data.cast<Map<String, dynamic>>());
        }
        _productPagination.updateFromResult(result);
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      setState(() {
        _productPagination.setError('ไม่สามารถโหลดสินค้า: $e');
      });
    }
  }
  
  // Phase 3: Product filtering
  void _filterProducts() {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        // Category filter
        if (_selectedCategory != 'all' && product['category_id']?.toString() != _selectedCategory) {
          return false;
        }
        
        // Search filter
        if (_productSearchQuery.isNotEmpty) {
          final query = _productSearchQuery.toLowerCase();
          final name = (product['name'] ?? '').toString().toLowerCase();
          final code = (product['code'] ?? '').toString().toLowerCase();
          final sku = (product['sku'] ?? '').toString().toLowerCase();
          if (!name.contains(query) && !code.contains(query) && !sku.contains(query)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }
  
  // Phase 3: Open enhanced product picker
  Future<void> _openProductPicker() async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionProductPickerPage(
          initiallySelectedProducts: [],
        ),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      // Handle selected products for promotion creation
      debugPrint('Selected ${result.length} products for promotion');
      // TODO: Navigate to promotion form with selected products
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการคูปอง & โปรโมชั่น'),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('ลองใหม่'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => InventoryService.clearAllCache(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('ล้างแคช'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppDesignSystem.secondary,
                        AppDesignSystem.primary,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tab buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                label: 'คูปอง',
                                index: 0,
                                isSelected: _selectedTabIndex == 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTabButton(
                                label: 'โปรโมชั่น',
                                index: 1,
                                isSelected: _selectedTabIndex == 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTabButton(
                                label: 'สินค้าใกล้หมดอายุ',
                                index: 2,
                                isSelected: _selectedTabIndex == 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTabButton(
                                label: 'วัตถุดิบใกล้หมดอายุ',
                                index: 3,
                                isSelected: _selectedTabIndex == 3,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTabButton(
                                label: 'วิเคราะห์การใช้งาน',
                                index: 4,
                                isSelected: _selectedTabIndex == 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: _buildTabContent(),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedTabIndex == 0) {
            checkPermissionAndExecute(
              context,
              'coupon_promotion_add_coupon',
              'เพิ่มคูปอง',
              () => _showAddCouponDialog(),
            );
          } else {
            checkPermissionAndExecute(
              context,
              'coupon_promotion_add_promotion',
              'เพิ่มโปรโมชั่น',
              () => _showAddPromotionDialog(),
            );
          }
        },
        backgroundColor: AppDesignSystem.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
        // Phase 5: Auto-load expiry data when switching to expiry tabs
        if (index == 2 || index == 3) {
          if (_expiringProducts.isEmpty && _expiringIngredients.isEmpty) {
            _loadExpiringData();
          }
        }
        // Phase 7: Auto-load analytics data when switching to analytics tab
        if (index == 4) {
          if (_usageData.isEmpty && _analyticsSummary == null) {
            _loadAnalyticsData();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppDesignSystem.primary, width: 2)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppDesignSystem.primary : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildCouponsTab();
      case 1:
        return _buildPromotionsTab();
      case 2:
        return _buildExpiringProductsTab();
      case 3:
        return _buildExpiringIngredientsTab();
      case 4:
        return _buildAnalyticsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCouponsTab() {
    if (_coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีคูปอง',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _coupons.map((coupon) {
        final discountText = coupon.discountType == 'percentage'
            ? '${coupon.value.toStringAsFixed(0)}%'
            : '${coupon.value.toStringAsFixed(0)} บาท';

        return Column(
          children: [
            _buildCouponAdminCard(
              coupon: coupon,
              discountText: discountText,
              onEdit: () => checkPermissionAndExecute(
                context,
                'coupon_promotion_edit_coupon',
                'แก้ไขคูปอง',
                () => _showEditCouponDialog(coupon),
              ),
              onDelete: () => checkPermissionAndExecute(
                context,
                'coupon_promotion_delete_coupon',
                'ลบคูปอง',
                () => _showDeleteConfirmDialog(
                  title: 'ลบคูปอง',
                  message: 'คุณแน่ใจหรือว่าต้องการลบคูปอง "${coupon.name}"',
                  onConfirm: () => _deleteCoupon(coupon.id),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPromotionsTab() {
    if (_promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีโปรโมชั่น',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _promotions.map((promotion) {
        return Column(
          children: [
            _buildPromotionAdminCard(
              promotion: promotion,
              onEdit: () => checkPermissionAndExecute(
                context,
                'coupon_promotion_edit_promotion',
                'แก้ไขโปรโมชั่น',
                () => _showEditPromotionDialog(promotion),
              ),
              onDelete: () => checkPermissionAndExecute(
                context,
                'coupon_promotion_delete_promotion',
                'ลบโปรโมชั่น',
                () => _showDeleteConfirmDialog(
                  title: 'ลบโปรโมชั่น',
                  message: 'คุณแน่ใจหรือว่าต้องการลบโปรโมชั่น "${promotion.name}"',
                  onConfirm: () => _deletePromotion(promotion.id),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCouponAdminCard({
    required PosDiscount coupon,
    required String discountText,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase 2: Mini Usage Stats (async loaded)
            FutureBuilder<Map<String, dynamic>>(
              future: PosDiscountService.getDiscountUsageStats(coupon.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!['total_uses'] == 0) {
                  return const SizedBox.shrink();
                }
                final stats = snapshot.data!;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        label: 'ใช้แล้ว',
                        value: '${stats['total_uses']}',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      _buildStatItem(
                        label: 'ส่วนลดรวม',
                        value: '฿${(stats['total_discount_amount'] as double).toStringAsFixed(0)}',
                        icon: Icons.savings,
                        color: Colors.orange,
                      ),
                      _buildStatItem(
                        label: 'ลูกค้า',
                        value: '${stats['unique_customers']}',
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (coupon.description != null && coupon.description!.isNotEmpty)
                        Text(
                          coupon.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    discountText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: coupon.isActive ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        coupon.isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: coupon.isActive ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'หมดอายุ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coupon.endAt != null
                          ? _formatDate(coupon.endAt!)
                          : 'ไม่มีกำหนด',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('แก้ไข'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('ลบ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionAdminCard({
    required PosPromotion promotion,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promotion.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (promotion.description != null && promotion.description!.isNotEmpty)
                        Text(
                          promotion.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getPromotionTypeLabel(promotion.promotionType),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: promotion.isActive ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        promotion.isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: promotion.isActive ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'วันสิ้นสุด',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promotion.endAt != null
                          ? _formatDate(promotion.endAt!)
                          : 'ไม่มีกำหนด',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('แก้ไข'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('ลบ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCouponDialog() {
    _showCouponDialog(title: 'เพิ่มคูปองใหม่');
  }

  void _showEditCouponDialog(PosDiscount coupon) {
    _showCouponDialog(title: 'แก้ไขคูปอง', existing: coupon);
  }

  /// Validate coupon data before saving
  String? _validateCoupon({
    required String name,
    required String discountType,
    required String value,
    required String maxDiscount,
    required String scope,
    required DateTime? startAt,
    required DateTime? endAt,
  }) {
    if (name.trim().isEmpty) return 'ชื่อคูปองต้องไม่ว่าง';
    if (value.trim().isEmpty) return 'ค่าส่วนลดต้องไม่ว่าง';
    
    final val = double.tryParse(value);
    if (val == null || val <= 0) return 'ค่าส่วนลดต้องมากกว่า 0';
    
    if (discountType == 'percentage') {
      if (val > 100) return 'ส่วนลดเปอร์เซ็นต์ต้องไม่เกิน 100%';
      if (maxDiscount.isNotEmpty) {
        final max = double.tryParse(maxDiscount);
        if (max == null || max < 0) return 'ลดสูงสุดต้องเป็นตัวเลขบวก';
      }
    }
    
    if (startAt != null && endAt != null && startAt.isAfter(endAt)) {
      return 'วันเริ่มต้นต้องก่อนวันสิ้นสุด';
    }
    
    return null;
  }

  void _showCouponDialog({required String title, PosDiscount? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valueCtrl = TextEditingController(text: existing != null ? existing.value.toStringAsFixed(0) : '');
    final maxCtrl = TextEditingController(text: existing?.maxDiscount?.toStringAsFixed(0) ?? '');
    final minCtrl = TextEditingController(text: existing?.minAmount?.toStringAsFixed(0) ?? '');
    final couponCodeCtrl = TextEditingController(text: existing?.couponCode ?? '');
    final usageLimitCtrl = TextEditingController(text: existing?.usageLimit?.toString() ?? '');
    final usageLimitPerCustomerCtrl = TextEditingController(text: existing?.usageLimitPerCustomer?.toString() ?? '');
    final usageLimitPerDayCtrl = TextEditingController(text: existing?.usageLimitPerDay?.toString() ?? '');
    String discountType = existing?.discountType ?? 'fixed';
    String scope = existing?.scope ?? 'order';
    String lifecycleStatus = existing?.lifecycleStatus ?? 'active';
    List<String> selectedCategoryIds = List<String>.from(existing?.applicableCategoryIds ?? const []);
    List<String> selectedProductIds = List<String>.from(existing?.applicableProductIds ?? const []);
    List<String> applicableChannels = List<String>.from(existing?.applicableChannels ?? const []);
    bool isCategoryLoading = false;
    bool stackable = existing?.stackable ?? false;
    bool isActive = existing?.isActive ?? true;
    bool requireInStock = existing?.requireInStock ?? false;
    bool requireSufficientIngredients = existing?.requireSufficientIngredients ?? false;
    bool includePendingProcurement = existing?.includePendingProcurement ?? false;
    DateTime? startAt = existing?.startAt;
    DateTime? endAt = existing?.endAt;
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, ds) {
          Future<void> pickDate(bool isStart) async {
            final picked = await showBuddhistDatePicker(
              context: context,
              initialDate: (isStart ? startAt : endAt) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) ds(() => isStart ? startAt = picked : endAt = picked);
          }

          return AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      if (errorMsg != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                          ]),
                        ),
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อคูปอง *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: lifecycleStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'สถานะวงจรชีวิต', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('แบบร่าง')),
                        DropdownMenuItem(value: 'scheduled', child: Text('ตั้งเวลาไว้')),
                        DropdownMenuItem(value: 'active', child: Text('ใช้งานอยู่')),
                        DropdownMenuItem(value: 'paused', child: Text('หยุดชั่วคราว')),
                        DropdownMenuItem(value: 'expired', child: Text('หมดอายุ')),
                        DropdownMenuItem(value: 'archived', child: Text('เก็บถาวร')),
                      ],
                      onChanged: (v) => ds(() {
                        lifecycleStatus = v ?? 'active';
                        isActive = lifecycleStatus == 'active' || lifecycleStatus == 'scheduled';
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: couponCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'รหัสคูปอง',
                        border: OutlineInputBorder(),
                        hintText: 'ไม่กำหนด',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: discountType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ประเภทส่วนลด', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'fixed', child: Text('จำนวนเงิน (บาท)')),
                        DropdownMenuItem(value: 'percentage', child: Text('เปอร์เซ็นต์ (%)')),
                      ],
                      onChanged: (v) => ds(() => discountType = v ?? 'fixed'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueCtrl,
                      decoration: InputDecoration(
                        labelText: discountType == 'percentage' ? 'ส่วนลด (%)' : 'ส่วนลด (บาท)',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    if (discountType == 'percentage') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ลดสูงสุดไม่เกิน (บาท)',
                          border: OutlineInputBorder(),
                          hintText: 'ไม่กำหนด',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: scope,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ขอบเขต', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'order', child: Text('ทั้งบิล')),
                        DropdownMenuItem(value: 'item', child: Text('รายการสินค้า')),
                        DropdownMenuItem(value: 'category', child: Text('หมวดหมู่')),
                      ],
                      onChanged: (v) {
                        final newScope = v ?? 'order';
                        if (newScope == 'category' && scope != 'category') {
                          ds(() { scope = newScope; isCategoryLoading = true; });
                          Future.delayed(const Duration(milliseconds: 600), () {
                            ds(() => isCategoryLoading = false);
                          });
                        } else {
                          ds(() => scope = newScope);
                        }
                      },
                    ),
                    if (scope == 'category') ...[
                      const SizedBox(height: 12),
                      if (isCategoryLoading)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('กำลังโหลดหมวดหมู่...', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation(AppDesignSystem.primary),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'เลือกหมวดหมู่ *',
                            border: const OutlineInputBorder(),
                            hintText: 'แตะเพื่อเลือก',
                            suffixIcon: selectedCategoryIds.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('${selectedCategoryIds.length} รายการ', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                )
                              : null,
                          ),
                          items: _categories.isEmpty ? [] : [
                            const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                            const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ล้างการเลือก')),
                            const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                            ..._categories.map((cat) {
                              final catId = cat['id'].toString();
                              final isSelected = selectedCategoryIds.contains(catId);
                              final productCount = _allProducts.where((p) {
                                final c = p['category'];
                                return c is Map && c['id'].toString() == catId;
                              }).length;
                              return DropdownMenuItem<String>(
                                value: catId,
                                child: Row(children: [
                                  Checkbox(value: isSelected, onChanged: null),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(cat['name'] ?? 'ไม่ระบุชื่อ')),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: productCount > 0 ? AppDesignSystem.primary.withOpacity(0.15) : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$productCount',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: productCount > 0 ? AppDesignSystem.primary : Colors.grey[500],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            if (value == '__select_all__') {
                              ds(() => selectedCategoryIds = _categories.map((c) => c['id'].toString()).toList());
                            } else if (value == '__clear_all__') {
                              ds(() => selectedCategoryIds.clear());
                            } else if (value != null && value.isNotEmpty) {
                              ds(() {
                                if (selectedCategoryIds.contains(value)) {
                                  selectedCategoryIds.remove(value);
                                } else {
                                  selectedCategoryIds.add(value);
                                }
                              });
                            }
                          },
                        ),
                      if (selectedCategoryIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('หมวดหมู่ที่เลือก (${selectedCategoryIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedCategoryIds.map((catId) {
                                  final cat = _categories.firstWhere((c) => c['id'].toString() == catId, orElse: () => {});
                                  return Chip(
                                    label: Text(cat['name'] ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontSize: 10)),
                                    onDeleted: () => ds(() => selectedCategoryIds.remove(catId)),
                                    backgroundColor: AppDesignSystem.primary.withOpacity(0.2),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (scope == 'item') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'เลือกสินค้า *',
                          border: const OutlineInputBorder(),
                          hintText: 'แตะเพื่อเลือก',
                          suffixIcon: selectedProductIds.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('${selectedProductIds.length} รายการ', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                )
                              : null,
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                          const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ล้างการเลือก')),
                          const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                          ..._allProducts.map((product) {
                            final productId = product['id'].toString();
                            final isSelected = selectedProductIds.contains(productId);
                            final category = product['category'];
                            final categoryName = category is Map ? category['name']?.toString() ?? '' : '';
                            return DropdownMenuItem<String>(
                              value: productId,
                              child: Row(children: [
                                Checkbox(value: isSelected, onChanged: null),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(product['name']?.toString() ?? 'ไม่ระบุชื่อ'),
                                      if (categoryName.isNotEmpty)
                                        Text(categoryName, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                              ]),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value == '__select_all__') {
                            ds(() => selectedProductIds = _allProducts.map((p) => p['id'].toString()).toList());
                          } else if (value == '__clear_all__') {
                            ds(() => selectedProductIds.clear());
                          } else if (value != null && value.isNotEmpty) {
                            ds(() {
                              if (selectedProductIds.contains(value)) {
                                selectedProductIds.remove(value);
                              } else {
                                selectedProductIds.add(value);
                              }
                            });
                          }
                        },
                      ),
                      if (selectedProductIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('สินค้าที่เลือก (${selectedProductIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedProductIds.take(20).map((productId) {
                                  final product = _allProducts.firstWhere((p) => p['id'].toString() == productId, orElse: () => {});
                                  return Chip(
                                    label: Text(product['name']?.toString() ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontSize: 10)),
                                    onDeleted: () => ds(() => selectedProductIds.remove(productId)),
                                    backgroundColor: AppDesignSystem.primary.withOpacity(0.2),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                  );
                                }).toList(),
                              ),
                              if (selectedProductIds.length > 20)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('+ อีก ${selectedProductIds.length - 20} รายการ', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: minCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ยอดขั้นต่ำ (บาท)',
                        border: OutlineInputBorder(),
                        hintText: 'ไม่กำหนด',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: usageLimitCtrl,
                          decoration: const InputDecoration(labelText: 'จำกัดใช้ทั้งหมด', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: usageLimitPerCustomerCtrl,
                          decoration: const InputDecoration(labelText: 'ต่อคน', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usageLimitPerDayCtrl,
                      decoration: const InputDecoration(labelText: 'จำกัดใช้ต่อวัน', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Text('ช่องทางที่ใช้ได้', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    Wrap(
                      spacing: 6,
                      children: const [
                        ('pos', 'POS หน้าร้าน'),
                        ('qr_ordering', 'QR Ordering'),
                        ('delivery', 'Delivery'),
                        ('walk_in', 'Walk-in'),
                        ('table_service', 'Table service'),
                        ('group_booking', 'Group booking'),
                      ].map((channel) {
                        final selected = applicableChannels.contains(channel.$1);
                        return FilterChip(
                          label: Text(channel.$2, style: const TextStyle(fontSize: 11)),
                          selected: selected,
                          onSelected: (v) => ds(() {
                            if (v) {
                              applicableChannels.add(channel.$1);
                            } else {
                              applicableChannels.remove(channel.$1);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text('ช่วงเวลาใช้งาน', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 14),
                              label: Text(startAt != null ? _formatDate(startAt!) : 'วันเริ่มต้น', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(true),
                              style: OutlinedButton.styleFrom(foregroundColor: startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (startAt != null)
                            InkWell(onTap: () => ds(() => startAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event, size: 14),
                              label: Text(endAt != null ? _formatDate(endAt!) : 'วันสิ้นสุด', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(false),
                              style: OutlinedButton.styleFrom(foregroundColor: endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (endAt != null)
                            InkWell(onTap: () => ds(() => endAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 14),
                              label: Text(startAt != null ? '${startAt!.hour.toString().padLeft(2, '0')}:${startAt!.minute.toString().padLeft(2, '0')}' : 'เวลาเริ่มต้น', style: const TextStyle(fontSize: 11)),
                              onPressed: () async {
                                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startAt ?? DateTime.now()));
                                if (time != null && startAt != null) {
                                  ds(() => startAt = startAt!.copyWith(hour: time.hour, minute: time.minute));
                                }
                              },
                              style: OutlinedButton.styleFrom(foregroundColor: startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (startAt != null)
                            InkWell(onTap: () => ds(() => startAt = startAt!.copyWith(hour: 0, minute: 0)), child: const Icon(Icons.refresh, size: 14, color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 14),
                              label: Text(endAt != null ? '${endAt!.hour.toString().padLeft(2, '0')}:${endAt!.minute.toString().padLeft(2, '0')}' : 'เวลาสิ้นสุด', style: const TextStyle(fontSize: 11)),
                              onPressed: () async {
                                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(endAt ?? DateTime.now()));
                                if (time != null && endAt != null) {
                                  ds(() => endAt = endAt!.copyWith(hour: time.hour, minute: time.minute));
                                }
                              },
                              style: OutlinedButton.styleFrom(foregroundColor: endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (endAt != null)
                            InkWell(onTap: () => ds(() => endAt = endAt!.copyWith(hour: 23, minute: 59)), child: const Icon(Icons.refresh, size: 14, color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    CheckboxListTile(
                      title: const Text('ซ้อนส่วนลดอื่นได้', style: TextStyle(fontSize: 13)),
                      value: stackable,
                      onChanged: (v) => ds(() => stackable = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: Text('เปิดใช้งาน', style: TextStyle(fontSize: 13, color: isActive ? AppDesignSystem.primary : Colors.grey)),
                      value: isActive,
                      onChanged: (v) => ds(() => isActive = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('ต้องมีสินค้าในสต็อก', style: TextStyle(fontSize: 13)),
                      value: requireInStock,
                      onChanged: (v) => ds(() => requireInStock = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('สินค้าผลิตต้องมีวัตถุดิบเพียงพอ', style: TextStyle(fontSize: 13)),
                      value: requireSufficientIngredients,
                      onChanged: (v) => ds(() => requireSufficientIngredients = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('รวมรายการที่อยู่ในขั้นตอนจัดซื้อ', style: TextStyle(fontSize: 13)),
                      value: includePendingProcurement,
                      onChanged: (v) => ds(() => includePendingProcurement = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  final err = _validateCoupon(
                    name: nameCtrl.text,
                    discountType: discountType,
                    value: valueCtrl.text,
                    maxDiscount: maxCtrl.text,
                    scope: scope,
                    startAt: startAt,
                    endAt: endAt,
                  );
                  
                  if (err != null) {
                    ds(() => errorMsg = err);
                    return;
                  }
                  
                  if (scope == 'category' && selectedCategoryIds.isEmpty) {
                    ds(() => errorMsg = 'ต้องเลือกอย่างน้อย 1 หมวดหมู่');
                    return;
                  }

                  if (scope == 'item' && selectedProductIds.isEmpty) {
                    ds(() => errorMsg = 'ต้องเลือกอย่างน้อย 1 สินค้า');
                    return;
                  }
                  
                  ds(() => isSaving = true);
                  
                  try {
                    if (existing == null) {
                      await _addCoupon(
                        name: nameCtrl.text, description: descCtrl.text,
                        discountType: discountType, scope: scope,
                        value: double.tryParse(valueCtrl.text) ?? 0,
                        maxDiscount: maxCtrl.text.isNotEmpty ? double.tryParse(maxCtrl.text) : null,
                        minAmount: minCtrl.text.isNotEmpty ? double.tryParse(minCtrl.text) : null,
                        stackable: stackable,
                        isActive: isActive,
                        applicableCategoryIds: selectedCategoryIds,
                        applicableProductIds: selectedProductIds,
                        couponCode: couponCodeCtrl.text.trim().isEmpty ? null : couponCodeCtrl.text.trim(),
                        usageLimit: usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitCtrl.text),
                        usageLimitPerCustomer: usageLimitPerCustomerCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerCustomerCtrl.text),
                        usageLimitPerDay: usageLimitPerDayCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerDayCtrl.text),
                        lifecycleStatus: lifecycleStatus,
                        applicableChannels: applicableChannels,
                        requireInStock: requireInStock,
                        requireSufficientIngredients: requireSufficientIngredients,
                        includePendingProcurement: includePendingProcurement,
                        startAt: startAt,
                        endAt: endAt,
                      );
                    } else {
                      await _updateCoupon(
                        id: existing.id, name: nameCtrl.text, description: descCtrl.text,
                        discountType: discountType, scope: scope,
                        value: double.tryParse(valueCtrl.text) ?? 0,
                        maxDiscount: maxCtrl.text.isNotEmpty ? double.tryParse(maxCtrl.text) : null,
                        minAmount: minCtrl.text.isNotEmpty ? double.tryParse(minCtrl.text) : null,
                        stackable: stackable,
                        isActive: isActive,
                        applicableCategoryIds: selectedCategoryIds,
                        applicableProductIds: selectedProductIds,
                        couponCode: couponCodeCtrl.text.trim().isEmpty ? null : couponCodeCtrl.text.trim(),
                        usageLimit: usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitCtrl.text),
                        usageLimitPerCustomer: usageLimitPerCustomerCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerCustomerCtrl.text),
                        usageLimitPerDay: usageLimitPerDayCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerDayCtrl.text),
                        lifecycleStatus: lifecycleStatus,
                        applicableChannels: applicableChannels,
                        requireInStock: requireInStock,
                        requireSufficientIngredients: requireSufficientIngredients,
                        includePendingProcurement: includePendingProcurement,
                        startAt: startAt,
                        endAt: endAt,
                      );
                    }
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) ds(() => errorMsg = 'เกิดข้อผิดพลาด: $e');
                  } finally {
                    if (mounted) ds(() => isSaving = false);
                  }
                },
                child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(existing == null ? 'เพิ่ม' : 'บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPromotionDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PromotionFormPage(),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _showEditPromotionDialog(PosPromotion promotion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionFormPage(promotionId: promotion.id),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  Future<List<Map<String, dynamic>>> _loadPromotionItemsForDialog(String promotionId) async {
    final promotionItems = await PosPromotionService.getPromotionItems(promotionId);
    return promotionItems.map((item) {
      final product = _allProducts.firstWhere(
        (p) => p['id']?.toString() == item.productId,
        orElse: () => {},
      );
      return {
        'product_id': item.productId,
        'name': product['name']?.toString() ?? 'สินค้าเดิม',
        'quantity': item.quantityRequired,
      };
    }).toList();
  }

  void _showPromotionDialog({required String title, PosPromotion? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final searchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String promotionType = existing?.promotionType ?? 'bundle';
    String? selectedDiscountId = existing?.discountId;
    List<String> selectedUserGroupIds = List<String>.from(existing?.applicableUserGroupIds ?? const []);
    bool isActive = existing?.isActive ?? true;
    DateTime? startAt = existing?.startAt;
    DateTime? endAt = existing?.endAt;
    final List<Map<String, dynamic>> items = [];
    List<Map<String, dynamic>> searchResults = [];
    bool hasLoadedExistingItems = existing == null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, ds) {
          final showItems = promotionType == 'bundle' || promotionType == 'buy_x_get_y';

          if (!hasLoadedExistingItems && showItems) {
            hasLoadedExistingItems = true;
            final promotionId = existing!.id;
            _loadPromotionItemsForDialog(promotionId).then((loadedItems) {
              if (!mounted) return;
              ds(() {
                items
                  ..clear()
                  ..addAll(loadedItems);
              });
            });
          }

          void searchProducts(String query) {
            if (query.isEmpty) { ds(() => searchResults = []); return; }
            final q = query.toLowerCase();
            ds(() {
              searchResults = _allProducts
                  .where((p) => ((p['name'] as String?) ?? '').toLowerCase().contains(q))
                  .take(6)
                  .toList();
            });
          }

          void addItem(Map<String, dynamic> product) {
            final productId = product['id'].toString();
            final qty = int.tryParse(qtyCtrl.text) ?? 1;
            ds(() {
              final existingIndex = items.indexWhere((i) => i['product_id'].toString() == productId);
              if (existingIndex >= 0) {
                final currentQty = (items[existingIndex]['quantity'] as int?) ?? 1;
                items[existingIndex]['quantity'] = currentQty + qty;
              } else {
                items.add({'product_id': productId, 'name': product['name'], 'quantity': qty});
              }
              searchCtrl.clear();
              searchResults = [];
            });
          }

          Future<void> pickDate(bool isStart) async {
            final picked = await showBuddhistDatePicker(
              context: context,
              initialDate: (isStart ? startAt : endAt) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) ds(() => isStart ? startAt = picked : endAt = picked);
          }

          return AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อโปรโมชั่น *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: promotionType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ประเภทโปรโมชั่น', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'bundle', child: Text('ชุดสินค้า (Bundle)')),
                        DropdownMenuItem(value: 'seasonal', child: Text('ตามฤดูกาล (Seasonal)')),
                        DropdownMenuItem(value: 'buy_x_get_y', child: Text('ซื้อ X แถม Y')),
                      ],
                      onChanged: (v) {
                        final newType = v ?? 'bundle';
                        Future.microtask(() => ds(() {
                          promotionType = newType;
                          items.clear();
                          searchResults = [];
                        }));
                      },
                    ),
                    const SizedBox(height: 12),
                    // Discount linker
                    DropdownButtonFormField<String?>(
                      value: selectedDiscountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'เชื่อมส่วนลด',
                        border: const OutlineInputBorder(),
                        helperText: _coupons.isEmpty ? 'ยังไม่มีส่วนลด — สร้างที่แท็บ "คูปอง" ก่อน' : null,
                        prefixIcon: const Icon(Icons.local_offer, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('ไม่มีส่วนลด')),
                        ..._coupons.map((d) {
                          final tag = d.discountType == 'percentage'
                              ? '${d.value.toStringAsFixed(0)}%'
                              : '฿${d.value.toStringAsFixed(0)}';
                          final scopeLabel = {'order': 'ทั้งบิล', 'item': 'รายการ', 'category': 'หมวดหมู่'}[d.scope] ?? d.scope;
                          return DropdownMenuItem<String?>(
                            value: d.id,
                            child: Text('${d.name} ($tag · $scopeLabel)', overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => Future.microtask(() => ds(() => selectedDiscountId = v)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'กลุ่มผู้ใช้ที่ใช้โปรโมชันได้',
                        border: const OutlineInputBorder(),
                        hintText: 'ไม่เลือก = ใช้ได้ทุกกลุ่ม',
                        suffixIcon: selectedUserGroupIds.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text('${selectedUserGroupIds.length} กลุ่ม', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              )
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                        const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ใช้ได้ทุกกลุ่ม')),
                        const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                        ..._userGroups.map((group) {
                          final isSelected = selectedUserGroupIds.contains(group.id);
                          return DropdownMenuItem<String>(
                            value: group.id,
                            child: Row(children: [
                              Checkbox(value: isSelected, onChanged: null),
                              const SizedBox(width: 8),
                              Expanded(child: Text(group.groupName)),
                            ]),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        Future.microtask(() {
                          ds(() {
                            if (value == '__select_all__') {
                              selectedUserGroupIds = _userGroups.map((g) => g.id).toList();
                            } else if (value == '__clear_all__') {
                              selectedUserGroupIds.clear();
                            } else if (value != null && value.isNotEmpty) {
                              if (selectedUserGroupIds.contains(value)) {
                                selectedUserGroupIds.remove(value);
                              } else {
                                selectedUserGroupIds.add(value);
                              }
                            }
                          });
                        });
                      },
                    ),
                    if (selectedUserGroupIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selectedUserGroupIds.map((groupId) {
                          final group = _userGroups.firstWhere(
                            (g) => g.id == groupId,
                            orElse: () => UserGroup(id: groupId, groupName: 'กลุ่มเดิม'),
                          );
                          return Chip(
                            label: Text(group.groupName, style: const TextStyle(fontSize: 10)),
                            onDeleted: () => ds(() => selectedUserGroupIds.remove(groupId)),
                            backgroundColor: AppDesignSystem.primary.withOpacity(0.2),
                            deleteIcon: const Icon(Icons.close, size: 14),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('ช่วงเวลา', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 14),
                              label: Text(startAt != null ? _formatDate(startAt!) : 'วันเริ่มต้น', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(true),
                              style: OutlinedButton.styleFrom(foregroundColor: startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (startAt != null)
                            InkWell(onTap: () => ds(() => startAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event, size: 14),
                              label: Text(endAt != null ? _formatDate(endAt!) : 'วันสิ้นสุด', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(false),
                              style: OutlinedButton.styleFrom(foregroundColor: endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (endAt != null)
                            InkWell(onTap: () => ds(() => endAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    // Product items section for bundle / buy_x_get_y
                    if (showItems) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.inventory_2, size: 16, color: AppDesignSystem.secondary),
                            const SizedBox(width: 6),
                            Text(
                              promotionType == 'bundle' ? 'สินค้าที่ร่วมโปรโมชั่น' : 'สินค้าที่ต้องซื้อ (X)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ]),
                          Text('${items.length} รายการ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ค้นหาสินค้าจากคลัง',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.search, size: 18),
                            ),
                            onChanged: (v) => Future.microtask(() => searchProducts(v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: TextField(
                            controller: qtyCtrl,
                            decoration: const InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder(), isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ]),
                      if (searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 160),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppDesignSystem.border),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (context, i) {
                              final p = searchResults[i];
                              final catName = p['category']?['name'] as String? ?? '';
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2, size: 16, color: AppDesignSystem.secondary),
                                title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13)),
                                subtitle: catName.isNotEmpty ? Text(catName, style: const TextStyle(fontSize: 11)) : null,
                                trailing: const Icon(Icons.add_circle_outline, size: 18, color: AppDesignSystem.primary),
                                onTap: () => addItem(p),
                              );
                            },
                          ),
                        ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...items.asMap().entries.map((e) {
                          final item = e.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.selectedSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppDesignSystem.primary.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.inventory_2, size: 14, color: AppDesignSystem.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item['name'] as String, style: const TextStyle(fontSize: 13))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: Text('×${item['quantity']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => ds(() => items.removeAt(e.key)),
                                child: const Icon(Icons.close, size: 16, color: Colors.red),
                              ),
                            ]),
                          );
                        }),
                      ],
                      if (_allProducts.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('ไม่พบสินค้าในคลัง — กรุณาเพิ่มสินค้าก่อน', style: TextStyle(fontSize: 12))),
                          ]),
                        ),
                    ],
                    SwitchListTile(
                      title: Text('เปิดใช้งาน', style: TextStyle(fontSize: 13, color: isActive ? AppDesignSystem.primary : Colors.grey)),
                      value: isActive,
                      onChanged: (v) => ds(() => isActive = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
          actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
              ElevatedButton(
                onPressed: () {
                  if (existing == null) {
                    _addPromotion(
                      name: nameCtrl.text, description: descCtrl.text,
                      promotionType: promotionType, discountId: selectedDiscountId,
                      applicableUserGroupIds: selectedUserGroupIds,
                      isActive: isActive, startAt: startAt, endAt: endAt, items: items,
                    );
                  } else {
                    _updatePromotion(
                      id: existing.id, name: nameCtrl.text, description: descCtrl.text,
                      promotionType: promotionType, discountId: selectedDiscountId,
                      applicableUserGroupIds: selectedUserGroupIds,
                      isActive: isActive, startAt: startAt, endAt: endAt, items: items,
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(existing == null ? 'เพิ่ม' : 'บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'ลบ',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCoupon({
    required String name,
    required String description,
    required String discountType,
    required String scope,
    required double value,
    double? maxDiscount,
    double? minAmount,
    required bool stackable,
    required bool isActive,
    List<String> applicableCategoryIds = const [],
    List<String> applicableProductIds = const [],
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    String lifecycleStatus = 'active',
    List<String> applicableChannels = const [],
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อคูปอง')));
      return;
    }
    final result = await PosDiscountService.addDiscount(
      name: name, description: description,
      discountType: discountType, scope: scope, value: value,
      maxDiscount: maxDiscount, minAmount: minAmount,
      stackable: stackable,
      isActive: isActive,
      applicableCategoryIds: applicableCategoryIds,
      applicableProductIds: applicableProductIds,
      couponCode: couponCode,
      usageLimit: usageLimit,
      usageLimitPerCustomer: usageLimitPerCustomer,
      usageLimitPerDay: usageLimitPerDay,
      lifecycleStatus: lifecycleStatus,
      applicableChannels: applicableChannels,
      requireInStock: requireInStock,
      requireSufficientIngredients: requireSufficientIngredients,
      includePendingProcurement: includePendingProcurement,
      startAt: startAt,
      endAt: endAt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null ? 'เพิ่มคูปองสำเร็จ' : 'เพิ่มคูปองไม่สำเร็จ'),
      backgroundColor: result != null ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result != null) _loadData();
  }

  Future<void> _updateCoupon({
    required String id,
    required String name,
    required String description,
    required String discountType,
    required String scope,
    required double value,
    double? maxDiscount,
    double? minAmount,
    required bool stackable,
    required bool isActive,
    List<String> applicableCategoryIds = const [],
    List<String> applicableProductIds = const [],
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    String lifecycleStatus = 'active',
    List<String> applicableChannels = const [],
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อคูปอง')));
      return;
    }
    final result = await PosDiscountService.updateDiscount(
      id: id, name: name, description: description,
      discountType: discountType, value: value, isActive: isActive,
      scope: scope, maxDiscount: maxDiscount, minAmount: minAmount,
      stackable: stackable,
      applicableCategoryIds: applicableCategoryIds,
      applicableProductIds: applicableProductIds,
      couponCode: couponCode,
      usageLimit: usageLimit,
      usageLimitPerCustomer: usageLimitPerCustomer,
      usageLimitPerDay: usageLimitPerDay,
      lifecycleStatus: lifecycleStatus,
      applicableChannels: applicableChannels,
      requireInStock: requireInStock,
      requireSufficientIngredients: requireSufficientIngredients,
      includePendingProcurement: includePendingProcurement,
      startAt: startAt,
      endAt: endAt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null ? 'แก้ไขคูปองสำเร็จ' : 'แก้ไขคูปองไม่สำเร็จ'),
      backgroundColor: result != null ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result != null) _loadData();
  }

  Future<void> _deleteCoupon(String couponId) async {
    final result = await PosDiscountService.deleteDiscount(couponId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result ? 'ลบคูปองสำเร็จ' : 'ลบคูปองไม่สำเร็จ'),
      backgroundColor: result ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result) _loadData();
  }

  Future<void> _addPromotion({
    required String name,
    required String description,
    required String promotionType,
    String? discountId,
    List<String> applicableUserGroupIds = const [],
    required bool isActive,
    DateTime? startAt,
    DateTime? endAt,
    List<Map<String, dynamic>> items = const [],
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อโปรโมชั่น')));
      return;
    }
    final result = await PosPromotionService.addPromotion(
      name: name, description: description,
      promotionType: promotionType, discountId: discountId,
      applicableUserGroupIds: applicableUserGroupIds,
      isActive: isActive,
      startAt: startAt, endAt: endAt,
    );
    if (result != null) {
      for (final item in items) {
        await PosPromotionService.addPromotionItem(
          promotionId: result.id,
          productId: item['product_id'] as String,
          quantityRequired: (item['quantity'] as int?) ?? 1,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('เพิ่มโปรโมชั่นสำเร็จ${items.isNotEmpty ? " (${items.length} สินค้า)" : ""}'),
        backgroundColor: AppDesignSystem.primary,
      ));
      _loadData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('เพิ่มโปรโมชั่นไม่สำเร็จ'),
        backgroundColor: AppDesignSystem.danger,
      ));
    }
  }

  Future<void> _updatePromotion({
    required String id,
    required String name,
    required String description,
    required String promotionType,
    String? discountId,
    List<String> applicableUserGroupIds = const [],
    required bool isActive,
    DateTime? startAt,
    DateTime? endAt,
    List<Map<String, dynamic>> items = const [],
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อโปรโมชั่น')));
      return;
    }
    final result = await PosPromotionService.updatePromotion(
      id: id, name: name, description: description,
      promotionType: promotionType, discountId: discountId,
      applicableUserGroupIds: applicableUserGroupIds,
      isActive: isActive, startAt: startAt, endAt: endAt,
    );
    if (result != null) {
      await PosPromotionService.removePromotionItemsByPromotionId(id);
      for (final item in items) {
        await PosPromotionService.addPromotionItem(
          promotionId: id,
          productId: item['product_id'] as String,
          quantityRequired: (item['quantity'] as int?) ?? 1,
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null ? 'แก้ไขโปรโมชั่นสำเร็จ' : 'แก้ไขโปรโมชั่นไม่สำเร็จ'),
      backgroundColor: result != null ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result != null) _loadData();
  }

  Future<void> _deletePromotion(String promotionId) async {
    final result = await PosPromotionService.deletePromotion(promotionId);

    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโปรโมชั่นสำเร็จ')),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโปรโมชั่นไม่สำเร็จ')),
      );
    }
  }

  // Phase 2: Mini stat item widget for usage history
  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  String _getPromotionTypeLabel(String promotionType) {
    switch (promotionType) {
      case 'bundle':
        return 'ชุดสินค้า';
      case 'seasonal':
        return 'ตามฤดูกาล';
      case 'buy_x_get_y':
        return 'ซื้อ X แถม Y';
      default:
        return promotionType;
    }
  }

  // =============================================
  // Phase 5: Expiry Targeting Methods
  // =============================================

  Future<void> _loadExpiringData() async {
    setState(() {
      _isLoadingExpiry = true;
    });

    try {
      final daysMap = {
        '3days': 3,
        '7days': 7,
        '14days': 14,
        '30days': 30,
        'expired': 0,
      };
      final days = daysMap[_expiryFilter] ?? 7;
      final includeExpired = _expiryFilter == 'expired' || days >= 7;

      final results = await Future.wait([
        InventoryService.getExpiringProducts(
          daysThreshold: days,
          includeExpired: includeExpired,
        ),
        InventoryService.getExpiringIngredients(
          daysThreshold: days,
          includeExpired: includeExpired,
        ),
      ]);

      setState(() {
        _expiringProducts = results[0] as List<Map<String, dynamic>>;
        _expiringIngredients = results[1] as List<Map<String, dynamic>>;
        _isLoadingExpiry = false;
      });
    } catch (e) {
      debugPrint('Error loading expiry data: $e');
      setState(() {
        _isLoadingExpiry = false;
      });
    }
  }

  Widget _buildExpiryFilterChips() {
    final filters = [
      {'key': '3days', 'label': '3 วัน', 'color': Colors.red},
      {'key': '7days', 'label': '7 วัน', 'color': Colors.orange},
      {'key': '14days', 'label': '14 วัน', 'color': Colors.yellow.shade700},
      {'key': '30days', 'label': '30 วัน', 'color': Colors.blue},
      {'key': 'expired', 'label': 'หมดอายุแล้ว', 'color': Colors.red.shade900},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((filter) {
          final isSelected = _expiryFilter == filter['key'];
          return ChoiceChip(
            label: Text(filter['label'] as String),
            selected: isSelected,
            selectedColor: (filter['color'] as Color).withOpacity(0.2),
            backgroundColor: Colors.white.withOpacity(0.1),
            labelStyle: TextStyle(
              color: isSelected ? filter['color'] as Color : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _expiryFilter = filter['key'] as String;
                });
                _loadExpiringData();
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpiringProductsTab() {
    if (_isLoadingExpiry) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_expiringProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีสินค้าใกล้หมดอายุ',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ในช่วง $_expiryFilter',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildExpiryFilterChips(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _expiringProducts.length,
            itemBuilder: (context, index) {
              final product = _expiringProducts[index];
              return _buildExpiringProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringIngredientsTab() {
    if (_isLoadingExpiry) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_expiringIngredients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.kitchen_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีวัตถุดิบใกล้หมดอายุ',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ในช่วง $_expiryFilter',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildExpiryFilterChips(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _expiringIngredients.length,
            itemBuilder: (context, index) {
              final ingredient = _expiringIngredients[index];
              return _buildExpiringIngredientCard(ingredient);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringProductCard(Map<String, dynamic> product) {
    final daysUntilExpiry = product['days_until_expiry'] as int? ?? 0;
    final expiryStatus = product['expiry_status'] as String? ?? 'normal';
    final promotionReason = product['promotion_reason'] as String? ?? '';
    final promotionMetadata = product['promotion_metadata'] as Map<String, dynamic>? ?? {};
    final suggestedDiscount = promotionMetadata['suggested_discount_percent'] as int? ?? 10;

    Color statusColor;
    IconData statusIcon;
    switch (expiryStatus) {
      case 'expired':
        statusColor = Colors.red.shade900;
        statusIcon = Icons.warning_rounded;
        break;
      case 'critical':
        statusColor = Colors.red;
        statusIcon = Icons.timer_off;
        break;
      case 'warning':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.95),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['product_name'] as String? ?? 'ไม่มีชื่อ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        product['category_name'] as String? ?? 'ไม่มีหมวดหมู่',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'ส่วนลด $suggestedDiscount%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      promotionReason,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildExpiryStat(
                    label: 'เหลือ (วัน)',
                    value: daysUntilExpiry.toString(),
                    color: statusColor,
                  ),
                ),
                Expanded(
                  child: _buildExpiryStat(
                    label: 'จำนวน',
                    value: '${product['expiring_quantity'] ?? 0}',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildExpiryStat(
                    label: 'ราคาปัจจุบัน',
                    value: '${product['current_price'] ?? 0}฿',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _createPromotionFromExpiringProduct(product),
                    icon: const Icon(Icons.local_offer, size: 16),
                    label: const Text('สร้างโปรโมชั่น'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringIngredientCard(Map<String, dynamic> ingredient) {
    final daysUntilExpiry = ingredient['days_until_expiry'] as int? ?? 0;
    final expiryStatus = ingredient['expiry_status'] as String? ?? 'normal';
    final promotionReason = ingredient['promotion_reason'] as String? ?? '';
    final promotionMetadata = ingredient['promotion_metadata'] as Map<String, dynamic>? ?? {};
    final suggestedDiscount = promotionMetadata['suggested_discount_percent'] as int? ?? 10;
    final affectedRecipes = promotionMetadata['affected_recipes'] as List<dynamic>? ?? [];

    Color statusColor;
    IconData statusIcon;
    switch (expiryStatus) {
      case 'expired':
        statusColor = Colors.red.shade900;
        statusIcon = Icons.warning_rounded;
        break;
      case 'critical':
        statusColor = Colors.red;
        statusIcon = Icons.timer_off;
        break;
      case 'warning':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.95),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient['ingredient_name'] as String? ?? 'ไม่มีชื่อ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ingredient['category_name'] as String? ?? 'ไม่มีหมวดหมู่',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'ส่วนลด $suggestedDiscount%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      promotionReason,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (affectedRecipes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restaurant_menu, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'เมนูที่ใช้วัตถุดิบนี้ (${affectedRecipes.length} เมนู)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: affectedRecipes.take(5).map<Widget>((recipe) {
                        return Chip(
                          label: Text(
                            recipe['output_product_name'] as String? ?? 'ไม่มีชื่อ',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _createPromotionFromExpiringIngredient(ingredient),
                    icon: const Icon(Icons.local_offer, size: 16),
                    label: const Text('สร้างโปรโมชั่น'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _createPromotionFromExpiringProduct(Map<String, dynamic> product) async {
    final promotionMetadata = product['promotion_metadata'] as Map<String, dynamic>? ?? {};
    final suggestedDiscount = promotionMetadata['suggested_discount_percent'] as int? ?? 20;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionFormPage(
          initialName: 'โปรโมชั่นระบาย ${product['product_name']}',
          initialDescription: product['promotion_reason'] as String? ?? 'สินค้าใกล้หมดอายุ',
          initialDiscountPercent: suggestedDiscount.toDouble(),
          initialSelectedProducts: [product['product_id'] as String],
        ),
      ),
    );

    if (result == true) {
      _loadData();
      _loadExpiringData();
    }
  }

  Future<void> _createPromotionFromExpiringIngredient(Map<String, dynamic> ingredient) async {
    final promotionMetadata = ingredient['promotion_metadata'] as Map<String, dynamic>? ?? {};
    final suggestedDiscount = promotionMetadata['suggested_discount_percent'] as int? ?? 20;
    final affectedRecipes = promotionMetadata['affected_recipes'] as List<dynamic>? ?? [];

    // Get product IDs from affected recipes
    final productIds = affectedRecipes
        .map((r) => r['output_product_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionFormPage(
          initialName: 'โปรโมชั่นระบายวัตถุดิบ ${ingredient['ingredient_name']}',
          initialDescription: ingredient['promotion_reason'] as String? ?? 'วัตถุดิบใกล้หมดอายุ',
          initialDiscountPercent: suggestedDiscount.toDouble(),
          initialSelectedProducts: productIds,
        ),
      ),
    );

    if (result == true) {
      _loadData();
      _loadExpiringData();
    }
  }

  // =============================================
  // Phase 7: Analytics Tab
  // =============================================

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Date Range Filter
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'กรองข้อมูล',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Date Range Row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.7), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _analyticsStartDate != null
                                      ? '${_analyticsStartDate!.day}/${_analyticsStartDate!.month}/${_analyticsStartDate!.year + 543}'
                                      : 'วันที่เริ่มต้น',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.7), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _analyticsEndDate != null
                                    ? '${_analyticsEndDate!.day}/${_analyticsEndDate!.month}/${_analyticsEndDate!.year + 543}'
                                    : 'วันที่สิ้นสุด',
                                style: TextStyle(color: Colors.white.withOpacity(0.9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loadAnalyticsData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('ค้นหา'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Coupon/Promotion Filter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coupon Filter
                  DropdownButtonFormField<String>(
                    value: _selectedCouponId,
                    decoration: InputDecoration(
                      labelText: 'กรองตามคูปอง',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    dropdownColor: AppDesignSystem.surface,
                    style: TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: null, child: Text('ทั้งหมด', style: TextStyle(color: Colors.white))),
                      ..._coupons.map((coupon) => DropdownMenuItem(
                        value: coupon.id,
                        child: Text(coupon.name ?? '', style: TextStyle(color: Colors.white)),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCouponId = value;
                        _selectedPromotionId = null; // Clear promotion filter
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Promotion Filter
                  DropdownButtonFormField<String>(
                    value: _selectedPromotionId,
                    decoration: InputDecoration(
                      labelText: 'กรองตามโปรโมชัน',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    dropdownColor: AppDesignSystem.surface,
                    style: TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: null, child: Text('ทั้งหมด', style: TextStyle(color: Colors.white))),
                      ..._promotions.map((promotion) => DropdownMenuItem(
                        value: promotion.id,
                        child: Text(promotion.name ?? '', style: TextStyle(color: Colors.white)),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPromotionId = value;
                        _selectedCouponId = null; // Clear coupon filter
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        // Summary Cards
        if (_analyticsSummary != null) ...[
          Container(
            margin: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive layout for summary cards
                final screenWidth = constraints.maxWidth;
                final isMobile = screenWidth < 600;
                final isTablet = screenWidth < 900;
                
                if (isMobile) {
                  // Mobile: Vertical stack
                  return Column(
                    children: [
                      _buildAnalyticsCard('จำนวนครั้งที่ใช้', '${_analyticsSummary!['total_usage'] ?? 0}', Icons.receipt),
                      const SizedBox(height: 12),
                      _buildAnalyticsCard('ส่วนลดรวม', '${(_analyticsSummary!['total_discount'] ?? 0).toStringAsFixed(2)}', Icons.discount),
                      const SizedBox(height: 12),
                      _buildAnalyticsCard('ออเดอร์ที่เกี่ยวข้อง', '${_analyticsSummary!['total_orders'] ?? 0}', Icons.shopping_cart),
                    ],
                  );
                } else if (isTablet) {
                  // Tablet: 2x2 grid
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildAnalyticsCard('จำนวนครั้งที่ใช้', '${_analyticsSummary!['total_usage'] ?? 0}', Icons.receipt)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildAnalyticsCard('ส่วนลดรวม', '${(_analyticsSummary!['total_discount'] ?? 0).toStringAsFixed(2)}', Icons.discount)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildAnalyticsCard('ออเดอร์ที่เกี่ยวข้อง', '${_analyticsSummary!['total_orders'] ?? 0}', Icons.shopping_cart)),
                          const SizedBox(width: 12),
                          Expanded(child: Container()), // Empty space for balance
                        ],
                      ),
                    ],
                  );
                } else {
                  // Desktop: Horizontal row
                  return Row(
                    children: [
                      Expanded(child: _buildAnalyticsCard('จำนวนครั้งที่ใช้', '${_analyticsSummary!['total_usage'] ?? 0}', Icons.receipt)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildAnalyticsCard('ส่วนลดรวม', '${(_analyticsSummary!['total_discount'] ?? 0).toStringAsFixed(2)}', Icons.discount)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildAnalyticsCard('ออเดอร์ที่เกี่ยวข้อง', '${_analyticsSummary!['total_orders'] ?? 0}', Icons.shopping_cart)),
                    ],
                  );
                }
              },
            ),
          ),
        ],
        // Usage Data Table
        Container(
          margin: const EdgeInsets.all(16),
          height: 400, // Fixed height to prevent overflow
          child: _isLoadingAnalytics
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _usageData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'ไม่มีข้อมูลการใช้งาน',
                            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        itemCount: _usageData.length,
                        itemBuilder: (context, index) {
                          final usage = _usageData[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: usage['type'] == 'coupon' ? AppDesignSystem.primary : AppDesignSystem.secondary,
                              child: Icon(
                                usage['type'] == 'coupon' ? Icons.local_offer : Icons.card_giftcard,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              usage['name'] ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'ใช้ ${usage['usage_count']} ครั้ง | ส่วนลด ${(usage['total_discount'] ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                            trailing: Text(
                              '${'${DateTime.parse(usage['last_used']).day}/${DateTime.parse(usage['last_used']).month}/${DateTime.parse(usage['last_used']).year + 543}'}',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                            onTap: () => _showUsageDetails(usage),
                          );
                        },
                      ),
                    ),
        ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _analyticsStartDate ?? DateTime.now() : _analyticsEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _analyticsStartDate = picked;
        } else {
          _analyticsEndDate = picked;
        }
      });
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoadingAnalytics = true);
    
    try {
      // Load analytics summary
      final summary = await PosDiscountService.getAnalyticsSummary(
        startDate: _analyticsStartDate,
        endDate: _analyticsEndDate,
        discountId: _selectedCouponId,
        promotionId: _selectedPromotionId,
      );
      
      // Load detailed usage data
      final usageData = await PosDiscountService.getUsageAnalytics(
        startDate: _analyticsStartDate,
        endDate: _analyticsEndDate,
        discountId: _selectedCouponId,
        promotionId: _selectedPromotionId,
        limit: 100,
      );
      
      setState(() {
        _analyticsSummary = summary;
        _usageData = usageData;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      setState(() => _isLoadingAnalytics = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  void _showUsageDetails(Map<String, dynamic> usage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(usage['name'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ประเภท: ${usage['type'] == 'coupon' ? 'คูปอง' : 'โปรโมชั่น'}'),
            const SizedBox(height: 8),
            Text('จำนวนครั้งที่ใช้: ${usage['usage_count']}'),
            const SizedBox(height: 8),
            Text('ส่วนลดรวม: ${(usage['total_discount'] ?? 0).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('จำนวนออเดอร์: ${usage['order_count'] ?? 0}'),
            const SizedBox(height: 8),
            Text('ลูกค้าที่ใช้: ${usage['unique_customers'] ?? 0}'),
            const SizedBox(height: 8),
            Text('ใช้ครั้งล่าสุด: ${usage['last_used_at'] != null ? '${DateTime.parse(usage['last_used_at']).day}/${DateTime.parse(usage['last_used_at']).month}/${DateTime.parse(usage['last_used_at']).year + 543}' : '-'}'),
            if (usage['avg_discount_per_use'] != null) ...[
              const SizedBox(height: 8),
              Text('ส่วนลดเฉลี่ยต่อครั้ง: ${usage['avg_discount_per_use'].toStringAsFixed(2)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showOrderDetails(usage);
            },
            child: const Text('ดูรายละเอียดออเดอร์'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> usage) async {
    setState(() => _isLoadingAnalytics = true);
    
    try {
      final orderDetails = await PosDiscountService.getOrderDetailsForDiscount(
        discountId: usage['type'] == 'coupon' ? usage['id'] : null,
        promotionId: usage['type'] == 'promotion' ? usage['id'] : null,
        startDate: _analyticsStartDate,
        endDate: _analyticsEndDate,
      );
      
      setState(() => _isLoadingAnalytics = false);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'รายละเอียดออเดอร์: ${usage['name']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: orderDetails.isEmpty
                        ? const Center(child: Text('ไม่มีข้อมูลออเดอร์'))
                        : ListView.builder(
                            itemCount: orderDetails.length,
                            itemBuilder: (context, index) {
                              final order = orderDetails[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'ออเดอร์ #${order['order_number'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${(order['discount_amount'] ?? 0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'วันที่: ${order['order_date'] != null ? '${DateTime.parse(order['order_date']).day}/${DateTime.parse(order['order_date']).month}/${DateTime.parse(order['order_date']).year + 543}' : '-'}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (order['customer_name'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'ลูกค้า: ${order['customer_name']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      if (order['product_name'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'สินค้า: ${order['product_name']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      if (order['applied_by_name'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'ผู้ใช้: ${order['applied_by_name']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingAnalytics = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }
}
