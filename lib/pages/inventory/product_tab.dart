import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/inventory_service.dart';
import '../../services/account_chart_service.dart';
import '../../utils/permission_helpers.dart';
import '../../theme/app_design_system.dart';
import 'inventory_filter_widget.dart';
import 'product_action_buttons_card.dart';
import 'widgets/procurement_integration_panel.dart';
import '../procurement/purchase_tab.dart';
import '../procurement/tracking_tab.dart';
import '../procurement/receive_tab.dart';
import 'category_management_page.dart';
import 'add_product_page.dart';
import 'unit_management_page.dart';

class ProductTab extends StatefulWidget {
  const ProductTab({super.key});

  @override
  State<ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'ทั้งหมด';
  String _selectedShelf = 'ทั้งหมด';

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _shelves = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _assetAccounts = [];
  List<Map<String, dynamic>> _revenueAccounts = [];
  List<Map<String, dynamic>> _costAccounts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _accountErrorMessage;

  // No-shelf selection
  final Set<String> _selectedNoShelfIds = {};
  final ScrollController _noShelfScrollController = ScrollController();

  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 5;

  // Sorting
  String _sortBy = 'qty_desc';

  Color get _surface => AppDesignSystem.surface;
  Color get _surfaceAlt => AppDesignSystem.background;
  Color get _textPrimary => AppDesignSystem.textPrimary;
  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _borderColor => AppDesignSystem.border;
  Color get _primaryColor => AppDesignSystem.primary;
  Color get _secondaryColor => AppDesignSystem.secondary;
  Color get _warningColor => AppDesignSystem.warning;
  Color get _successColor => AppDesignSystem.success;
  Color get _dangerColor => AppDesignSystem.danger;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() { _currentPage = 0; }));
  }


  @override
  void dispose() {
    _searchController.dispose();
    _noShelfScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        InventoryService.getProducts(),
        InventoryService.getCategories(),
        InventoryService.getUnitsSortedByInventoryUsage(),
        InventoryService.getRecipesSortedByUsage(),
        InventoryService.getShelves(),
        InventoryService.getWarehouses(),
        AccountChartService.getAccounts(type: 'asset'),
        AccountChartService.getAccounts(type: 'revenue'),
        AccountChartService.getAccounts(type: 'cogs'),
      ]);
      final products = results[0];
      final categories = results[1];
      final units = results[2];
      final recipes = results[3];
      final shelves = results[4];
      final warehouses = results[5];
      final assetAccounts = List<Map<String, dynamic>>.from(results[6]);
      final revenueAccounts = List<Map<String, dynamic>>.from(results[7]);
      final costAccounts = List<Map<String, dynamic>>.from(results[8]);
      // Debug: แสดงข้อมูล account ของแต่ละ category
      for (final cat in categories) {
        debugPrint('📋 Category "${cat['name']}": inv=${cat['inventory_account_code']}, rev=${cat['revenue_account_code']}, cost=${cat['cost_account_code']}');
      }
      final incompleteCats = categories.where((cat) =>
          cat['inventory_account_code'] == null ||
          cat['revenue_account_code'] == null ||
          cat['cost_account_code'] == null).toList();
      debugPrint('📋 Incomplete categories: ${incompleteCats.length}/${categories.length} → ${incompleteCats.map((c) => c['name']).toList()}');
      final hasIncompleteCategoryAccounts = incompleteCats.isNotEmpty;

      setState(() {
        _products = products;
        _categories = categories;
        _units = units;
        _recipes = recipes;
        _shelves = shelves;
        _warehouses = warehouses;
        _assetAccounts = assetAccounts;
        _revenueAccounts = revenueAccounts;
        _costAccounts = costAccounts;
        _isLoading = false;
        _accountErrorMessage = hasIncompleteCategoryAccounts
            ? 'มีบางประเภทสินค้าที่ยังไม่ได้กำหนดบัญชีครบถ้วน กรุณาอัปเดตก่อนเพิ่มสินค้าใหม่'
            : null;
      });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var list = List<Map<String, dynamic>>.from(_products);
    final search = _searchController.text.toLowerCase();
    if (search.isNotEmpty) {
      list = list.where((p) => (p['name'] as String).toLowerCase().contains(search)).toList();
    }
    if (_selectedWarehouse != 'ทั้งหมด') {
      list = list.where((p) {
        final shelf = p['shelf'];
        if (shelf == null) return false;
        final wh = shelf['warehouse'];
        return wh != null && wh['name'] == _selectedWarehouse;
      }).toList();
    }
    if (_selectedShelf != 'ทั้งหมด') {
      list = list.where((p) {
        if (_selectedShelf == 'ยังไม่มีชั้นวาง') {
          return p['shelf_id'] == null;
        }
        final shelf = p['shelf'];
        return shelf != null && shelf['code'] == _selectedShelf;
      }).toList();
    }
    // Sorting
    switch (_sortBy) {
      case 'qty_desc':
        list.sort((a, b) => ((b['quantity'] as num?)?.toDouble() ?? 0).compareTo((a['quantity'] as num?)?.toDouble() ?? 0));
        break;
      case 'qty_asc':
        list.sort((a, b) => ((a['quantity'] as num?)?.toDouble() ?? 0).compareTo((b['quantity'] as num?)?.toDouble() ?? 0));
        break;
      case 'out_of_stock':
        list = list.where((p) => ((p['quantity'] as num?)?.toDouble() ?? 0) <= 0).toList();
        break;
      case 'name_asc':
        list.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
        break;
      case 'no_shelf':
        list = list.where((p) => p['shelf'] == null || p['shelf_id'] == null).toList();
        break;
    }
    return list;
  }

  int get _totalPages => (_filteredProducts.length / _itemsPerPage).ceil();

  List<Map<String, dynamic>> get _paginatedProducts {
    final filtered = _filteredProducts;
    final start = _currentPage * _itemsPerPage;
    if (start >= filtered.length) return [];
    final end = (start + _itemsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  String _getProductStatus(Map<String, dynamic> p) {
    final qty = (p['quantity'] as num?)?.toDouble() ?? 0;
    final minQty = (p['min_quantity'] as num?)?.toDouble() ?? 0;
    if (qty <= 0) return 'หมด';
    if (qty <= minQty) return 'ใกล้หมด';
    return 'พร้อม';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: _dangerColor),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: _dangerColor)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }
    if (_accountErrorMessage != null) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: _dangerColor),
        const SizedBox(height: 8),
        Text(_accountErrorMessage!, style: TextStyle(color: _dangerColor)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
      ])));
    }

    final warehouseOptions = ['ทั้งหมด', ..._warehouses.map((w) => w['name'] as String)];
    final shelfOptions = ['ทั้งหมด', 'ยังไม่มีชั้นวาง', ..._shelves.map((s) => s['code'] as String)];

    return _buildProductContent(warehouseOptions, shelfOptions);
  }

  Widget _buildLoadingShimmer() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter card shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Card(
                elevation: 0,
                color: _surface,
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                  child: Column(
                    children: [
                      Container(height: 48, color: Colors.white),
                      const SizedBox(height: AppDesignSystem.spacingMd),
                      Row(
                        children: [
                          Expanded(child: Container(height: 48, color: Colors.white)),
                          const SizedBox(width: AppDesignSystem.spacingMd),
                          Expanded(child: Container(height: 48, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingLg),
            // Product list shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Card(
                elevation: 0,
                color: _surface,
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                  child: Column(
                    children: List.generate(
                      5,
                      (index) => Padding(
                        padding: EdgeInsets.only(bottom: index < 4 ? AppDesignSystem.spacingMd : 0),
                        child: Row(
                          children: [
                            Container(width: 80, height: 80, color: Colors.white),
                            const SizedBox(width: AppDesignSystem.spacingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(height: 16, color: Colors.white),
                                  const SizedBox(height: 8),
                                  Container(height: 14, width: 120, color: Colors.white),
                                  const SizedBox(height: 8),
                                  Container(height: 12, width: 80, color: Colors.white),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductContent(List<String> warehouseOptions, List<String> shelfOptions) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_accountErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
                  child: Text(_accountErrorMessage!, style: TextStyle(color: _dangerColor)),
                ),
              ProductActionButtonsCard(
                onShowCategoryDialog: _showCategoryDialog,
                onShowUnitDialog: _showUnitDialog,
                onShowAddProductDialog: _showAddProductDialog,
                onShowProduceProductDialog: _showProduceProductDialog,
                onNavigateToProcurementPurchase: () => _openProcurementTab('procurement_purchase'),
                onNavigateToProcurementTracking: () => _openProcurementTab('procurement_tracking'),
                onNavigateToProcurementReceive: () => _openProcurementTab('procurement_receive'),
                onNavigateToProcurementApprove: () => _openProcurementTab('procurement_purchase'),
              ),
              const SizedBox(height: AppDesignSystem.spacingLg),
              InventoryFilterWidget(
                searchController: _searchController,
                selectedWarehouse: _selectedWarehouse,
                selectedShelf: _selectedShelf,
                onWarehouseChanged: (value) => setState(() { _selectedWarehouse = value!; _currentPage = 0; }),
                onShelfChanged: (value) => setState(() { _selectedShelf = value!; _currentPage = 0; }),
                warehouseOptions: warehouseOptions,
                shelfOptions: shelfOptions,
                showNoShelfOption: true,
              ),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildNoShelfCard(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildProductList(),
            ],
          ),
        ),
      ),
    );
  }

  
  Widget _buildNoShelfCard() {
    final noShelfItems = _products.where((p) => p['shelf_id'] == null).toList();
    if (noShelfItems.isEmpty) return SizedBox.shrink();

    final allSelected = noShelfItems.isNotEmpty && noShelfItems.every((p) => _selectedNoShelfIds.contains(p['id']));

    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _warningColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'สินค้ายังไม่มีชั้นวาง (${noShelfItems.length} รายการ)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingSm),
            // Select all + Assign button
            Row(
              children: [
                SizedBox(
                  height: 32,
                  child: CheckboxMenuButton(
                    value: allSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedNoShelfIds.addAll(noShelfItems.map((p) => p['id'] as String));
                        } else {
                          _selectedNoShelfIds.clear();
                        }
                      });
                    },
                    child: Text('เลือกทั้งหมด', style: TextStyle(fontSize: 13, color: _textPrimary)),
                  ),
                ),
                const Spacer(),
                if (_selectedNoShelfIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _showAssignShelfDialog(),
                    icon: Icon(Icons.shelves, size: 16),
                    label: Text('จัดเข้าชั้นวาง (${_selectedNoShelfIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingSm),
                      textStyle: const TextStyle(fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingSm),
            // Scrollable list
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: noShelfItems.length > 5 ? 280 : double.infinity),
              child: Scrollbar(
                controller: _noShelfScrollController,
                thumbVisibility: noShelfItems.length > 5,
                child: ListView.builder(
                  controller: _noShelfScrollController,
                  shrinkWrap: true,
                  physics: noShelfItems.length > 5 ? AlwaysScrollableScrollPhysics() : NeverScrollableScrollPhysics(),
                  itemCount: noShelfItems.length,
                  itemBuilder: (context, index) {
                    final item = noShelfItems[index];
                    final id = item['id'] as String;
                    final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                    final status = _getProductStatus(item);
                    final statusColor = status == 'พร้อม' ? _successColor : status == 'ใกล้หมด' ? _warningColor : _dangerColor;
                    final unitAbbr = item['unit']?['abbreviation'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28, height: 28,
                            child: Checkbox(
                              value: _selectedNoShelfIds.contains(id),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedNoShelfIds.add(id);
                                  } else {
                                    _selectedNoShelfIds.remove(id);
                                  }
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(item['name'] ?? '', style: TextStyle(fontSize: 13, color: _textPrimary), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} $unitAbbr', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                          const SizedBox(width: 8),
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignShelfDialog() {
    String? selectedShelfId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.shelves, color: _secondaryColor), const SizedBox(width: 8), const Text('จัดเข้าชั้นวาง')]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เลือก ${_selectedNoShelfIds.length} รายการ', style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'เลือกชั้นวาง *',
                  border: OutlineInputBorder(),
                ),
                value: selectedShelfId,
                items: _shelves.map((s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text('${s['code']} (${s['warehouse']?['name'] ?? ''})'),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedShelfId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: isLoading || selectedShelfId == null ? null : () async {
                setDialogState(() => isLoading = true);
                int success = 0;
                for (final id in _selectedNoShelfIds) {
                  final ok = await InventoryService.updateProductShelf(
                    productId: id,
                    shelfId: selectedShelfId!,
                  );
                  if (ok) success++;
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() => _selectedNoShelfIds.clear());
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('จัดเข้าชั้นวางสำเร็จ $success รายการ'),
                      backgroundColor: _successColor,
                    ),
                  );
                }
              },
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final filtered = _filteredProducts;
    final paginated = _paginatedProducts;
    final totalPages = _totalPages;
    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Sort dropdown
            Row(
              children: [
                Expanded(
                  child: Text('รายการสินค้า (${filtered.length} รายการ)', style: Theme.of(context).textTheme.titleMedium),
                ),
                SizedBox(
                  height: 36,
                  child: DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    icon: Icon(Icons.sort, size: 18),
                    style: TextStyle(fontSize: 13, color: _textPrimary),
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: 'qty_desc', child: Text('จำนวนมากสุด')),
                      DropdownMenuItem(value: 'qty_asc', child: Text('จำนวนน้อยสุด')),
                      
                      DropdownMenuItem(value: 'name_asc', child: Text('เรียงตามชื่อ')),
                      DropdownMenuItem(value: 'no_shelf', child: Text('ยังไม่จัดชั้นวาง')),
                      DropdownMenuItem(value: 'out_of_stock', child: Text('ไม่มีสินค้า')),
                    ],
                    onChanged: (v) => setState(() { _sortBy = v!; _currentPage = 0; }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
                child: Center(child: Text('ไม่พบสินค้า', style: TextStyle(color: _textSecondary))),
              )
            else ...
              [
                ...paginated.map((product) => _buildProductItem(product)).toList(),
                // Pagination controls
                if (totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDesignSystem.spacingMd),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // First page
                        IconButton(
                          icon: Icon(Icons.first_page, size: 22),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                          tooltip: 'หน้าแรก',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        // Previous page
                        IconButton(
                          icon: Icon(Icons.chevron_left, size: 22),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                          tooltip: 'ก่อนหน้า',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd),
                          child: Text('${_currentPage + 1} / $totalPages', style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                        ),
                        // Next page
                        IconButton(
                          icon: Icon(Icons.chevron_right, size: 22),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                          tooltip: 'ถัดไป',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        // Last page
                        IconButton(
                          icon: Icon(Icons.last_page, size: 22),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                          tooltip: 'หน้าสุดท้าย',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ],
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    final status = _getProductStatus(product);
    final statusColor = status == 'พร้อม' ? _successColor : status == 'ใกล้หมด' ? _warningColor : _dangerColor;
    final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final unitAbbr = product['unit']?['abbreviation'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
      padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2, color: _textSecondary),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500, color: _textPrimary)),
                Text('฿${price.toStringAsFixed(0)}/$unitAbbr', style: TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Expanded(child: Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)}', style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary), textAlign: TextAlign.center)),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          IconButton(icon: Icon(Icons.edit, size: 20, color: _secondaryColor), onPressed: () => checkPermissionAndExecute(context, 'inventory_products_edit', 'แก้ไขสินค้า', () => _showEditProductDialog(product)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }

  // Dialogs

  void _showCategoryDialog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryManagementPage(
          initialCategories: _categories,
          initialProducts: _products,
          assetAccounts: _assetAccounts,
          revenueAccounts: _revenueAccounts,
          costAccounts: _costAccounts,
        ),
      ),
    );
    // Refresh data when returning from management page
    await _loadData();
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['name']);
    final qtyController = TextEditingController(text: (product['quantity'] as num?)?.toString() ?? '0');
    final priceController = TextEditingController(text: (product['price'] as num?)?.toString() ?? '0');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: _secondaryColor),
                      const SizedBox(width: 8),
                      const Text('แก้ไขสินค้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'ชื่อสินค้า', border: OutlineInputBorder())),
                      const SizedBox(height: AppDesignSystem.spacingMd),
                      Row(children: [
                        Expanded(child: TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        const SizedBox(width: AppDesignSystem.spacingMd),
                        Expanded(child: TextField(controller: priceController, decoration: const InputDecoration(labelText: 'ราคา', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      ]),
                      const SizedBox(height: AppDesignSystem.spacingLg),
                      ProcurementIntegrationPanel(
                        productId: product['id']?.toString() ?? '',
                        productName: product['name']?.toString() ?? 'Unknown',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: const Text('ยกเลิก')),
                      const SizedBox(width: AppDesignSystem.spacingSm),
                      ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          setDialogState(() => isLoading = true);
                          final ok = await InventoryService.updateProduct(product['id'], {
                            'name': nameController.text.trim(),
                            'quantity': double.tryParse(qtyController.text) ?? 0,
                            'price': double.tryParse(priceController.text) ?? 0,
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (ok) {
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('แก้ไขสินค้าสำเร็จ'), backgroundColor: _successColor));
                            }
                          }
                        },
                        child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('บันทึก'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Helper methods for recipes =====
  List<Map<String, dynamic>> _getIngredients(Map<String, dynamic> recipe) {
    final raw = recipe['ingredients'];
    if (raw == null || raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw);
  }

  String _getIngName(Map<String, dynamic> ing) => ing['product']?['name'] ?? '-';
  double _getIngQty(Map<String, dynamic> ing) => (ing['quantity'] as num?)?.toDouble() ?? 0;
  String _getIngUnit(Map<String, dynamic> ing) => ing['product']?['unit']?['abbreviation'] ?? '';
  double _getIngStock(Map<String, dynamic> ing) => (ing['product']?['quantity'] as num?)?.toDouble() ?? 0;
  String _getIngProductId(Map<String, dynamic> ing) => ing['product']?['id'] ?? '';

  double _getYield(Map<String, dynamic> recipe) => (recipe['yield_quantity'] as num?)?.toDouble() ?? 1;
  String _getYieldUnit(Map<String, dynamic> recipe) => recipe['yield_unit'] ?? 'ชิ้น';

  bool _canProduceRecipe(Map<String, dynamic> recipe) {
    final ings = _getIngredients(recipe);
    if (ings.isEmpty) return false;
    return ings.every((ing) => _getIngStock(ing) >= _getIngQty(ing));
  }

  int _getMaxBatch(Map<String, dynamic> recipe) {
    final ings = _getIngredients(recipe);
    if (ings.isEmpty) return 0;
    int maxBatch = 999999;
    for (final ing in ings) {
      final qty = _getIngQty(ing);
      final stock = _getIngStock(ing);
      if (qty <= 0) continue;
      final batch = (stock / qty).floor();
      if (batch < maxBatch) maxBatch = batch;
    }
    return maxBatch == 999999 ? 0 : maxBatch;
  }

  void _showProduceProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ผลิตสินค้า'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.menu_book, color: _primaryColor),
              title: const Text('ผลิตจากสูตร'),
              subtitle: const Text('เลือกสูตรอาหารและผลิตตามสูตร'),
              onTap: () {
                Navigator.pop(context);
                _showProduceFromRecipeDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.build, color: _secondaryColor),
              title: const Text('ผลิตแบบ Manual'),
              subtitle: const Text('กำหนดวัตถุดิบเอง'),
              onTap: () {
                Navigator.pop(context);
                _showProduceManualDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  void _showProduceFromRecipeDialog() {
    // ดึง recipes ทั้งหมด (ไม่ filter ที่ผลิตได้)
    if (_recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีสูตรอาหาร'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedRecipeId;  // ✅ ว่างไว้ก่อน (null)
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController(text: '1');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedRecipe = selectedRecipeId != null
              ? _recipes.firstWhere(
                  (r) => r['id'] == selectedRecipeId,
                  orElse: () => _recipes.first,
                )
              : null;
          
          final maxBatch = selectedRecipe != null ? _getMaxBatch(selectedRecipe) : 0;
          final ingredients = selectedRecipe != null ? _getIngredients(selectedRecipe) : [];
          final batchQty = int.tryParse(qtyController.text) ?? 1;
          
          // 🔍 Debug
          if (selectedRecipe != null) {
            debugPrint('📋 Selected Recipe: ${selectedRecipe['name']}');
            debugPrint('🥘 Ingredients count: ${ingredients.length}');
            debugPrint('🥘 Ingredients: $ingredients');
          }

          // ✅ ตรวจสอบวัตถุดิบไม่พอ (หลังจากเลือกสูตร)
          final insufficientIngredients = selectedRecipe != null
              ? ingredients.where((ing) {
                  final stock = _getIngStock(ing);
                  final needed = _getIngQty(ing) * batchQty;
                  return stock < needed;
                }).toList()
              : [];

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),  // ✅ ซ่อนแป้นพิมพ์
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.play_arrow, color: _successColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedRecipe != null
                          ? 'ผลิตจากสูตร: ${selectedRecipe['name']}'
                          : 'ผลิตจากสูตร',
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown: เลือกสูตร (default ว่าง)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'เลือกสูตร *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.menu_book),
                        ),
                        value: selectedRecipeId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('-- เลือกสูตร --'),
                          ),
                          ..._recipes.map((r) => DropdownMenuItem<String>(
                            value: r['id'] as String?,
                            child: Text(r['name'] ?? ''),
                          )).toList(),
                        ],
                        onChanged: (value) => setDialogState(() => selectedRecipeId = value),
                        validator: (v) => v == null ? 'กรุณาเลือกสูตร' : null,
                      ),
                      const SizedBox(height: 16),

                      // Info: สูงสุดที่ผลิตได้ (แสดงเฉพาะเมื่อเลือกสูตร)
                      if (selectedRecipe != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[800], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ผลิตได้สูงสุด $maxBatch ชุด (ได้ ${(maxBatch * _getYield(selectedRecipe)).toStringAsFixed(0)} ${_getYieldUnit(selectedRecipe)})',
                                  style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (selectedRecipe != null) const SizedBox(height: 16),

                      // Input: จำนวนชุด (แสดงเฉพาะเมื่อเลือกสูตร)
                      if (selectedRecipe != null)
                        TextFormField(
                          controller: qtyController,
                          decoration: const InputDecoration(
                            labelText: 'จำนวนชุดที่ต้องการผลิต *',
                            border: OutlineInputBorder(),
                            suffixText: 'ชุด',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'กรุณากรอกจำนวน';
                            final n = int.tryParse(value);
                            if (n == null || n <= 0) return 'กรุณากรอกจำนวนที่ถูกต้อง';
                            if (n > maxBatch) return 'วัตถุดิบไม่เพียงพอ (สูงสุด $maxBatch ชุด)';
                            return null;
                          },
                        ),
                      if (selectedRecipe != null) const SizedBox(height: 16),

                      // ⚠️ Warning: วัตถุดิบไม่พอ (แสดงเฉพาะเมื่อเลือกสูตร)
                      if (selectedRecipe != null && insufficientIngredients.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.red[800], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'วัตถุดิบไม่พอ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...insufficientIngredients.map((ing) {
                                final stock = _getIngStock(ing);
                                final needed = _getIngQty(ing) * batchQty;
                                final short = needed - stock;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• ${_getIngName(ing)}: ต้องการ ${needed.toStringAsFixed(2)} แต่มี ${stock.toStringAsFixed(2)} (ขาด ${short.toStringAsFixed(2)} ${_getIngUnit(ing)})',
                                    style: TextStyle(fontSize: 12, color: Colors.red[700]),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.add_shopping_cart),
                                      label: const Text('เติมสต็อก'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('ตรวจนับสต็อก'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else if (selectedRecipe != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: _successColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'วัตถุดิบพอสำหรับผลิต',
                                  style: TextStyle(fontSize: 13, color: _successColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (selectedRecipe != null) const SizedBox(height: 16),

                      // Preview: วัตถุดิบที่จะใช้ (แสดงเสมอเมื่อเลือกสูตร)
                      if (selectedRecipe != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'วัตถุดิบที่จะถูกตัด:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
                            ),
                            const SizedBox(height: 8),
                            ...ingredients.map((ing) {
                              final qty = _getIngQty(ing);
                              final totalUse = qty * batchQty;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(_getIngName(ing))),
                                    Text(
                                      '-${totalUse.toStringAsFixed(2)} ${_getIngUnit(ing)}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const Divider(),

                            // Output: สินค้าที่จะได้
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'สินค้าที่จะได้:',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
                                  ),
                                ),
                                Text(
                                  '+${(batchQty * _getYield(selectedRecipe)).toStringAsFixed(0)} ${_getYieldUnit(selectedRecipe)}',
                                  style: TextStyle(
                                    color: _successColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton.icon(
                  onPressed: (isLoading || insufficientIngredients.isNotEmpty || selectedRecipe == null)
                      ? null
                      : () async {
                    if (formKey.currentState?.validate() != true) return;
                    setDialogState(() => isLoading = true);

                    final batchQty = int.tryParse(qtyController.text) ?? 1;
                    final ingData = ingredients.map((ing) => {
                      'product_id': _getIngProductId(ing),
                      'quantity': _getIngQty(ing),
                      'current_stock': _getIngStock(ing),
                    }).toList();

                    final result = await InventoryService.produceFromRecipe(
                      recipeId: selectedRecipeId!,
                      batchQuantity: batchQty,
                      ingredients: ingData,
                      yieldQuantity: (batchQty * _getYield(selectedRecipe!)).toDouble(),
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (result['success'] == true) {
                        await _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ผลิต ${selectedRecipe!['name']} $batchQty ชุด สำเร็จ'),
                            backgroundColor: _successColor,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'เกิดข้อผิดพลาด'),
                            backgroundColor: _dangerColor,
                          ),
                        );
                      }
                    }
                  },
                  icon: isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.play_arrow),
                  label: const Text('ยืนยันผลิต'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _successColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProduceManualDialog() {
    // TODO: Implement manual produce dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ผลิตแบบ Manual - ยังไม่พร้อมใช้งาน')),
    );
  }

  void _showUnitDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UnitManagementPage()),
    ).then((_) async {
      await _loadData();
    });
  }

  void _showAddProductDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductPage(
          categories: _categories,
          units: _units,
          recipes: _recipes,
          shelves: _shelves,
          warehouses: _warehouses,
        ),
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  void _openProcurementTab(String tabId) {
    Widget page;
    switch (tabId) {
      case 'procurement_tracking':
        page = const TrackingTab();
        break;
      case 'procurement_receive':
        page = const ReceiveTab();
        break;
      case 'procurement_purchase':
      default:
        page = const PurchaseTab();
        break;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
