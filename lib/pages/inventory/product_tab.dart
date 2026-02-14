import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../services/account_chart_service.dart';
import '../../utils/permission_helpers.dart';
import 'inventory_filter_widget.dart';
import 'product_action_buttons_card.dart';
import '../procurement_page.dart';
import 'category_management_page.dart';
import 'add_product_page.dart';

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
      return Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red),
        SizedBox(height: 8),
        Text(_errorMessage!, style: TextStyle(color: Colors.red)),
        SizedBox(height: 12),
        ElevatedButton(onPressed: _loadData, child: Text('ลองใหม่')),
      ])));
    }

    final warehouseOptions = ['ทั้งหมด', ..._warehouses.map((w) => w['name'] as String)];
    final shelfOptions = ['ทั้งหมด', 'ยังไม่มีชั้นวาง', ..._shelves.map((s) => s['code'] as String)];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            SizedBox(height: 16),
            if (_accountErrorMessage != null)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(_accountErrorMessage!, style: TextStyle(color: Colors.red)),
              ),
            ProductActionButtonsCard(
              onShowCategoryDialog: _showCategoryDialog,
              onShowUnitDialog: _showUnitDialog,
              onShowAddProductDialog: _showAddProductDialog,
              onShowProduceProductDialog: _showProduceProductDialog,
              onNavigateToProcurement: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcurementPage())),
            ),
            SizedBox(height: 16),
            _buildNoShelfCard(),
            SizedBox(height: 16),
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  
  Widget _buildNoShelfCard() {
    final noShelfItems = _products.where((p) => p['shelf_id'] == null).toList();
    if (noShelfItems.isEmpty) return SizedBox.shrink();

    final allSelected = noShelfItems.isNotEmpty && noShelfItems.every((p) => _selectedNoShelfIds.contains(p['id']));

    return Card(
      elevation: 2,
      color: Colors.orange[50],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'สินค้ายังไม่มีชั้นวาง (${noShelfItems.length} รายการ)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
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
                    child: Text('เลือกทั้งหมด', style: TextStyle(fontSize: 13)),
                  ),
                ),
                Spacer(),
                if (_selectedNoShelfIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _showAssignShelfDialog(),
                    icon: Icon(Icons.shelves, size: 16),
                    label: Text('จัดเข้าชั้นวาง (${_selectedNoShelfIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: TextStyle(fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
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
                    final statusColor = status == 'พร้อม' ? Colors.green : status == 'ใกล้หมด' ? Colors.orange : Colors.red;
                    final unitAbbr = item['unit']?['abbreviation'] ?? '';

                    return Container(
                      margin: EdgeInsets.only(bottom: 4),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange[200]!),
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
                          SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(item['name'] ?? '', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(width: 4),
                          Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} $unitAbbr', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
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
          title: Row(children: [
            Icon(Icons.shelves, color: Colors.blue),
            SizedBox(width: 8),
            Text('จัดเข้าชั้นวาง'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เลือก ${_selectedNoShelfIds.length} รายการ', style: TextStyle(color: Colors.grey[600])),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
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
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: isLoading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('บันทึก'),
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
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Sort dropdown
            Row(
              children: [
                Expanded(
                  child: Text('รายการสินค้า (${filtered.length} รายการ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 36,
                  child: DropdownButton<String>(
                    value: _sortBy,
                    underline: SizedBox(),
                    icon: Icon(Icons.sort, size: 18),
                    style: TextStyle(fontSize: 13, color: Colors.black87),
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
            SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('ไม่พบสินค้า', style: TextStyle(color: Colors.grey[600]))),
              )
            else ...
              [
                ...paginated.map((product) => _buildProductItem(product)).toList(),
                // Pagination controls
                if (totalPages > 1)
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // First page
                        IconButton(
                          icon: Icon(Icons.first_page, size: 22),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                          tooltip: 'หน้าแรก',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        // Previous page
                        IconButton(
                          icon: Icon(Icons.chevron_left, size: 22),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                          tooltip: 'ก่อนหน้า',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('${_currentPage + 1} / $totalPages', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        // Next page
                        IconButton(
                          icon: Icon(Icons.chevron_right, size: 22),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                          tooltip: 'ถัดไป',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        // Last page
                        IconButton(
                          icon: Icon(Icons.last_page, size: 22),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                          tooltip: 'หน้าสุดท้าย',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
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
    final statusColor = status == 'พร้อม' ? Colors.green : status == 'ใกล้หมด' ? Colors.orange : Colors.red;
    final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final unitAbbr = product['unit']?['abbreviation'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('฿${price.toStringAsFixed(0)}/$unitAbbr', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Expanded(child: Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          SizedBox(width: 8),
          IconButton(icon: Icon(Icons.edit, size: 20), onPressed: () => checkPermissionAndExecute(context, 'inventory_products_edit', 'แก้ไขสินค้า', () => _showEditProductDialog(product)), padding: EdgeInsets.zero, constraints: BoxConstraints()),
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
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('แก้ไขสินค้า')]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: 'ชื่อสินค้า', border: OutlineInputBorder())),
                SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: qtyController, decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  SizedBox(width: 12),
                  Expanded(child: TextField(controller: priceController, decoration: InputDecoration(labelText: 'ราคา', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('แก้ไขสินค้าสำเร็จ'), backgroundColor: Colors.green));
                  }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProduceProductDialog() {
    // TODO: Implement produce product dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ผลิตสินค้ายังไม่พร้อมใช้งาน')),
    );
  }

  void _showUnitDialog() {
    // TODO: Implement unit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('จัดการหน่วยนับยังไม่พร้อมใช้งาน')),
    );
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
}
