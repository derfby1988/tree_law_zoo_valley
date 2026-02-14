import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../services/account_chart_service.dart';
import '../../utils/permission_helpers.dart';
import 'inventory_filter_widget.dart';
import '../procurement_page.dart';

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

  void _showEditCategoryDialog(Map<String, dynamic> category) {
    final formKey = GlobalKey<FormState>();
    String? inventoryCode = category['inventory_account_code'] as String?;
    String? revenueCode = category['revenue_account_code'] as String?;
    String? costCode = category['cost_account_code'] as String?;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.folder_open, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text('แก้ไขบัญชีสำหรับ ${category['name']}'))]),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAccountDropdown(
                  label: 'บัญชีสินค้าคงเหลือ *',
                  value: inventoryCode,
                  accounts: _assetAccounts,
                  onChanged: (v) => setDialogState(() => inventoryCode = v),
                ),
                SizedBox(height: 12),
                _buildAccountDropdown(
                  label: 'บัญชีรายได้ *',
                  value: revenueCode,
                  accounts: _revenueAccounts,
                  onChanged: (v) => setDialogState(() => revenueCode = v),
                ),
                SizedBox(height: 12),
                _buildAccountDropdown(
                  label: 'บัญชีต้นทุน *',
                  value: costCode,
                  accounts: _costAccounts,
                  onChanged: (v) => setDialogState(() => costCode = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () async {
                if ([inventoryCode, revenueCode, costCode].any((c) => c == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณาเลือกบัญชีให้ครบ'), backgroundColor: Colors.red));
                  return;
                }
                final ok = await InventoryService.updateCategory(category['id'] as String, {
                  'inventory_account_code': inventoryCode,
                  'revenue_account_code': revenueCode,
                  'cost_account_code': costCode,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตประเภทสำเร็จ'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตไม่สำเร็จ'), backgroundColor: Colors.red));
                  }
                }
              },
              child: Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> accounts,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
      value: value,
      items: accounts
          .map((acc) => DropdownMenuItem(
                value: acc['code'] as String?,
                child: Text('${acc['code']} - ${acc['name_th']}'),
              ))
          .toList(),
      onChanged: accounts.isEmpty ? null : onChanged,
    );
  }

  String _formatAccountLabel(String? code) {
    if (code == null) return 'ยังไม่กำหนด';
    final account = _findAccount(code);
    return account == null ? code : '${account['code']} - ${account['name_th']}';
  }

  Map<String, dynamic>? _findAccount(String? code) {
    if (code == null) return null;
    return [..._assetAccounts, ..._revenueAccounts, ..._costAccounts].firstWhere(
      (acc) => acc['code'] == code,
      orElse: () => {},
    );
  }

  Widget _buildCategoryAccountSummary(String categoryId) {
    final Map<String, dynamic> category = _categories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {},
    );
    if (category.isEmpty) return SizedBox.shrink();

    final inventoryCode = category['inventory_account_code'] as String?;
    final revenueCode = category['revenue_account_code'] as String?;
    final costCode = category['cost_account_code'] as String?;
    final missingCount = [inventoryCode, revenueCode, costCode].where((c) => c == null).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: Colors.blueGrey[700], size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'บัญชีสำหรับ ${category['name'] ?? ''}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildAccountSummaryRow('สินค้าคงเหลือ', inventoryCode),
          SizedBox(height: 4),
          _buildAccountSummaryRow('รายได้', revenueCode),
          SizedBox(height: 4),
          _buildAccountSummaryRow('ต้นทุน', costCode),
          if (missingCount > 0) ...[
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ประเภทนี้ยังขาดการตั้งค่าบัญชี ${missingCount == 1 ? '' : 'บางรายการ'} กรุณาแก้ไขก่อนบันทึกสินค้าเพื่อหลีกเลี่ยงปัญหาการบันทึกบัญชี',
                    style: TextStyle(color: Colors.orange[800], fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountSummaryRow(String label, String? code) {
    final hasValue = code != null;
    return Row(
      children: [
        SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            _formatAccountLabel(code),
            style: TextStyle(fontSize: 12.5, color: hasValue ? Colors.black87 : Colors.red[700], fontWeight: hasValue ? FontWeight.w500 : FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
        InventoryService.getUnits(),
        InventoryService.getShelves(),
        InventoryService.getWarehouses(),
        AccountChartService.getAccounts(type: 'asset'),
        AccountChartService.getAccounts(type: 'revenue'),
        AccountChartService.getAccounts(type: 'cogs'),
      ]);
      final products = results[0];
      final categories = results[1];
      final units = results[2];
      final shelves = results[3];
      final warehouses = results[4];
      final assetAccounts = List<Map<String, dynamic>>.from(results[5]);
      final revenueAccounts = List<Map<String, dynamic>>.from(results[6]);
      final costAccounts = List<Map<String, dynamic>>.from(results[7]);
      final hasIncompleteCategoryAccounts = categories.any((cat) =>
          cat['inventory_account_code'] == null ||
          cat['revenue_account_code'] == null ||
          cat['cost_account_code'] == null);

      setState(() {
        _products = products;
        _categories = categories;
        _units = units;
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
            _buildActionButtons(),
            SizedBox(height: 16),
            _buildNoShelfCard(),
            SizedBox(height: 16),
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จัดการข้อมูลสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (PermissionService.canAccessActionSync('inventory_products_category'))
                  _buildActionButton('ประเภท', Colors.blue, Icons.folder, () => checkPermissionAndExecute(context, 'inventory_products_category', 'จัดการประเภท', () => _showCategoryDialog())),
                if (PermissionService.canAccessActionSync('inventory_products_unit'))
                  _buildActionButton('หน่วยนับ', Colors.teal, Icons.scale, () => checkPermissionAndExecute(context, 'inventory_products_unit', 'จัดการหน่วยนับ', () => _showUnitDialog())),
                if (PermissionService.canAccessActionSync('inventory_products_add'))
                  _buildActionButton('เพิ่มสินค้า', Colors.orange, Icons.add_circle, () => checkPermissionAndExecute(context, 'inventory_products_add', 'เพิ่มสินค้า', () => _showAddProductDialog())),
                if (PermissionService.canAccessActionSync('inventory_products_produce'))
                  _buildActionButton('ผลิตสินค้า', Colors.purple, Icons.factory, () => checkPermissionAndExecute(context, 'inventory_products_produce', 'ผลิตสินค้า', () => _showProduceProductDialog())),
                if (PermissionService.canAccessPageSync('procurement'))
                  _buildActionButton('สั่งซื้อสินค้า', Colors.green, Icons.shopping_cart, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProcurementPage()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  void _showCategoryDialog() {
    final newCatController = TextEditingController();
    String? newInventoryAccount;
    String? newRevenueAccount;
    String? newCostAccount;

    if (_assetAccounts.isNotEmpty) newInventoryAccount = _assetAccounts.first['code'] as String?;
    if (_revenueAccounts.isNotEmpty) newRevenueAccount = _revenueAccounts.first['code'] as String?;
    if (_costAccounts.isNotEmpty) newCostAccount = _costAccounts.first['code'] as String?;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.folder, color: Colors.blue), SizedBox(width: 8), Text('จัดการประเภท')]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._categories.map((cat) {
                  final count = _products.where((p) => p['category']?['id'] == cat['id']).length;
                  return ListTile(
                    title: Text(cat['name'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('สินค้าคงเหลือ: ${_formatAccountLabel(cat['inventory_account_code'] as String?)}'),
                        Text('รายได้: ${_formatAccountLabel(cat['revenue_account_code'] as String?)}'),
                        Text('ต้นทุน: ${_formatAccountLabel(cat['cost_account_code'] as String?)}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$count รายการ'),
                        IconButton(
                          icon: Icon(Icons.edit, size: 18),
                          onPressed: () => _showEditCategoryDialog(cat),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                Divider(),
                Align(alignment: Alignment.centerLeft, child: Text('เพิ่มประเภทใหม่', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(height: 8),
                TextField(controller: newCatController, decoration: InputDecoration(labelText: 'ชื่อประเภท *', border: OutlineInputBorder())),
                SizedBox(height: 12),
                _buildAccountDropdown(
                  label: 'บัญชีสินค้าคงเหลือ *',
                  value: newInventoryAccount,
                  accounts: _assetAccounts,
                  onChanged: (v) => setDialogState(() => newInventoryAccount = v),
                ),
                SizedBox(height: 12),
                _buildAccountDropdown(
                  label: 'บัญชีรายได้ *',
                  value: newRevenueAccount,
                  accounts: _revenueAccounts,
                  onChanged: (v) => setDialogState(() => newRevenueAccount = v),
                ),
                SizedBox(height: 12),
                _buildAccountDropdown(
                  label: 'บัญชีต้นทุน *',
                  value: newCostAccount,
                  accounts: _costAccounts,
                  onChanged: (v) => setDialogState(() => newCostAccount = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('ปิด')),
            ElevatedButton(
              onPressed: () async {
                if (newCatController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกชื่อประเภท')));
                  return;
                }
                if ([newInventoryAccount, newRevenueAccount, newCostAccount].any((element) => element == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณาเลือกบัญชีให้ครบ')));
                  return;
                }
                final ok = await InventoryService.addCategory(
                  newCatController.text.trim(),
                  inventoryAccountCode: newInventoryAccount,
                  revenueAccountCode: newRevenueAccount,
                  costAccountCode: newCostAccount,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มประเภท ${newCatController.text} สำเร็จ'), backgroundColor: Colors.green));
                  }
                }
              },
              child: Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitDialog() {
    final newUnitController = TextEditingController();
    final newAbbrController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.scale, color: Colors.teal), SizedBox(width: 8), Text('จัดการหน่วยนับ')]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._units.map((u) {
                  final count = _products.where((p) => p['unit']?['id'] == u['id']).length;
                  return ListTile(title: Text('${u['name']} (${u['abbreviation']})'), trailing: Text('$count รายการ'));
                }).toList(),
                Divider(),
                TextField(controller: newUnitController, decoration: InputDecoration(labelText: 'ชื่อหน่วย', border: OutlineInputBorder())),
                SizedBox(height: 8),
                TextField(controller: newAbbrController, decoration: InputDecoration(labelText: 'ตัวย่อ', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('ปิด')),
            ElevatedButton(
              onPressed: () async {
                if (newUnitController.text.trim().isEmpty) return;
                final ok = await InventoryService.addUnit(newUnitController.text.trim(), abbreviation: newAbbrController.text.trim().isEmpty ? null : newAbbrController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มหน่วย ${newUnitController.text} สำเร็จ'), backgroundColor: Colors.green));
                  }
                }
              },
              child: Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final qtyController = TextEditingController(text: '0');
    final minQtyController = TextEditingController(text: '0');
    String? selectedCategoryId;
    String? selectedUnitId;
    String? selectedShelfId;
    String? overrideInventoryCode;
    String? overrideRevenueCode;
    String? overrideCostCode;
    bool overrideAccounts = false;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.add_circle, color: Colors.orange), SizedBox(width: 8), Text('เพิ่มสินค้าใหม่')]),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'ชื่อสินค้า *', border: OutlineInputBorder()),
                    validator: (v) => v?.trim().isEmpty == true ? 'กรุณากรอกชื่อสินค้า' : null,
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'ประเภท *', border: OutlineInputBorder()),
                    value: selectedCategoryId,
                    items: _categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? ''))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                    validator: (v) => v == null ? 'กรุณาเลือกประเภท' : null,
                  ),
                  SizedBox(height: 8),
                  if (selectedCategoryId != null)
                    _buildCategoryAccountSummary(selectedCategoryId!),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'หน่วยนับ *', border: OutlineInputBorder()),
                    value: selectedUnitId,
                    items: _units.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['name']} (${u['abbreviation']})'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedUnitId = v),
                    validator: (v) => v == null ? 'กรุณาเลือกหน่วยนับ' : null,
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'ชั้นวาง', border: OutlineInputBorder()),
                    value: selectedShelfId,
                    items: _shelves.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text('${s['code']} (${s['warehouse']?['name'] ?? ''})' ))).toList(),
                    onChanged: (v) => setDialogState(() => selectedShelfId = v),
                  ),
                  SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: priceController, decoration: InputDecoration(labelText: 'ราคาขาย *', border: OutlineInputBorder(), prefixText: '฿'), keyboardType: TextInputType.number, validator: (v) => v?.trim().isEmpty == true ? 'กรุณากรอก' : null)),
                    SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: costController, decoration: InputDecoration(labelText: 'ต้นทุน', border: OutlineInputBorder(), prefixText: '฿'), keyboardType: TextInputType.number)),
                  ]),
                  SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: qtyController, decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                    SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: minQtyController, decoration: InputDecoration(labelText: 'จำนวนขั้นต่ำ', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  ]),
                  SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('ระบุบัญชีเอง (Override)'),
                    value: overrideAccounts,
                    onChanged: (value) => setDialogState(() {
                      overrideAccounts = value;
                      if (!overrideAccounts) {
                        overrideInventoryCode = null;
                        overrideRevenueCode = null;
                        overrideCostCode = null;
                      }
                    }),
                  ),
                  if (overrideAccounts) ...[
                    _buildAccountDropdown(
                      label: 'บัญชีสินค้าคงเหลือ *',
                      value: overrideInventoryCode,
                      accounts: _assetAccounts,
                      onChanged: (v) => setDialogState(() => overrideInventoryCode = v),
                    ),
                    SizedBox(height: 12),
                    _buildAccountDropdown(
                      label: 'บัญชีรายได้ *',
                      value: overrideRevenueCode,
                      accounts: _revenueAccounts,
                      onChanged: (v) => setDialogState(() => overrideRevenueCode = v),
                    ),
                    SizedBox(height: 12),
                    _buildAccountDropdown(
                      label: 'บัญชีต้นทุน *',
                      value: overrideCostCode,
                      accounts: _costAccounts,
                      onChanged: (v) => setDialogState(() => overrideCostCode = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState?.validate() != true) return;
                if (overrideAccounts && [overrideInventoryCode, overrideRevenueCode, overrideCostCode].any((c) => c == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณาเลือกบัญชี override ให้ครบ'), backgroundColor: Colors.red));
                  return;
                }
                setDialogState(() => isLoading = true);
                final ok = await InventoryService.addProduct(
                  name: nameController.text.trim(),
                  categoryId: selectedCategoryId!,
                  unitId: selectedUnitId!,
                  shelfId: selectedShelfId,
                  price: double.tryParse(priceController.text) ?? 0,
                  cost: double.tryParse(costController.text) ?? 0,
                  quantity: double.tryParse(qtyController.text) ?? 0,
                  minQuantity: double.tryParse(minQtyController.text) ?? 0,
                  inventoryAccountCodeOverride: overrideAccounts ? overrideInventoryCode : null,
                  revenueAccountCodeOverride: overrideAccounts ? overrideRevenueCode : null,
                  costAccountCodeOverride: overrideAccounts ? overrideCostCode : null,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มสินค้า ${nameController.text} สำเร็จ'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red));
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

  void _showEditProductDialog(Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['name'] ?? '');
    final priceController = TextEditingController(text: '${(product['price'] as num?)?.toDouble() ?? 0}');
    final qtyController = TextEditingController(text: '${(product['quantity'] as num?)?.toDouble() ?? 0}');
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
}
