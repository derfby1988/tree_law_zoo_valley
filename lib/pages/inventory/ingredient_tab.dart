import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';
import 'inventory_filter_widget.dart';

class IngredientTab extends StatefulWidget {
  const IngredientTab({super.key});

  @override
  State<IngredientTab> createState() => _IngredientTabState();
}

class _IngredientTabState extends State<IngredientTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'ทั้งหมด';
  String _selectedShelf = 'ทั้งหมด';

  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _shelves = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = true;
  String? _errorMessage;

  // No-shelf selection
  final Set<String> _selectedNoShelfIds = {};
  final ScrollController _noShelfScrollController = ScrollController();

  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 5;

  // Sorting
  String _sortBy = 'low_stock';

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
        InventoryService.getIngredients(),
        InventoryService.getCategories(),
        InventoryService.getUnits(),
        InventoryService.getShelves(),
        InventoryService.getWarehouses(),
      ]);
      setState(() {
        _ingredients = results[0];
        _categories = results[1];
        _units = results[2];
        _shelves = results[3];
        _warehouses = results[4];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _filteredIngredients {
    var list = List<Map<String, dynamic>>.from(_ingredients);
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
        return false; // ยังไม่รองรับกรองตาม shelf code (ต้อง join)
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
      case 'low_stock':
        list.sort((a, b) {
          final aQty = (a['quantity'] as num?)?.toDouble() ?? 0;
          final aMinQty = (a['min_quantity'] as num?)?.toDouble() ?? 0;
          final bQty = (b['quantity'] as num?)?.toDouble() ?? 0;
          final bMinQty = (b['min_quantity'] as num?)?.toDouble() ?? 0;
          
          // คำนวณสัดส่วนว่าเหลือเท่าไหร่ (quantity/min_quantity)
          final aRatio = aMinQty > 0 ? aQty / aMinQty : (aQty > 0 ? 999 : 0);
          final bRatio = bMinQty > 0 ? bQty / bMinQty : (bQty > 0 ? 999 : 0);
          return aRatio.compareTo(bRatio);
        });
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

  int get _totalPages => (_filteredIngredients.length / _itemsPerPage).ceil();

  List<Map<String, dynamic>> get _paginatedIngredients {
    final filtered = _filteredIngredients;
    final start = _currentPage * _itemsPerPage;
    if (start >= filtered.length) return [];
    final end = (start + _itemsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  String _getIngredientStatus(Map<String, dynamic> p) {
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
            ),
            SizedBox(height: 16),
            _buildActionButtons(),
            SizedBox(height: 16),
            _buildNoShelfCard(),
            SizedBox(height: 16),
            _buildIngredientList(),
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
            Text('จัดการวัตถุดิบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (PermissionService.canAccessActionSync('inventory_ingredients_category'))
                  _buildActionButton('ประเภท', Colors.blue, Icons.folder, () => checkPermissionAndExecute(context, 'inventory_ingredients_category', 'จัดการประเภท', () => _showCategoryDialog())),
                if (PermissionService.canAccessActionSync('inventory_ingredients_unit'))
                  _buildActionButton('หน่วยนับ', Colors.teal, Icons.scale, () => checkPermissionAndExecute(context, 'inventory_ingredients_unit', 'จัดการหน่วยนับ', () => _showUnitDialog())),
                if (PermissionService.canAccessActionSync('inventory_ingredients_add'))
                  _buildActionButton('เพิ่มวัตถุดิบ', Colors.orange, Icons.add_circle, () => checkPermissionAndExecute(context, 'inventory_ingredients_add', 'เพิ่มวัตถุดิบ', () => _showAddIngredientDialog())),
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
    final noShelfItems = _ingredients.where((p) => p['shelf_id'] == null).toList();
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
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'วัตถุดิบยังไม่มีชั้นวาง (${noShelfItems.length} รายการ)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
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
                    final status = _getIngredientStatus(item);
                    final statusColor = status == 'พร้อม' ? Colors.green : status == 'ใกล้หมด' ? Colors.orange : Colors.red;

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
                          Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  final ok = await InventoryService.updateIngredient(id, {'shelf_id': selectedShelfId});
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

  Widget _buildIngredientList() {
    final filtered = _filteredIngredients;
    final paginated = _paginatedIngredients;
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
                  child: Text('รายการวัตถุดิบ (${filtered.length} รายการ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      DropdownMenuItem(value: 'low_stock', child: Text('วัตถุดิบใกล้หมด')),
                      DropdownMenuItem(value: 'qty_desc', child: Text('จำนวนมากสุด')),
                      DropdownMenuItem(value: 'qty_asc', child: Text('จำนวนน้อยสุด')),
                      DropdownMenuItem(value: 'name_asc', child: Text('เรียงตามชื่อ')),
                      DropdownMenuItem(value: 'no_shelf', child: Text('ยังไม่จัดชั้นวาง')),
                      DropdownMenuItem(value: 'out_of_stock', child: Text('ไม่มีวัตถุดิบ')),
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
                child: Center(child: Text('ไม่พบวัตถุดิบ', style: TextStyle(color: Colors.grey[600]))),
              )
            else ...
              [
                ...paginated.map((ingredient) => _buildIngredientItem(ingredient)).toList(),
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

  Widget _buildIngredientItem(Map<String, dynamic> ingredient) {
    final status = _getIngredientStatus(ingredient);
    final statusColor = status == 'พร้อม' ? Colors.green : status == 'ใกล้หมด' ? Colors.orange : Colors.red;
    final qty = (ingredient['quantity'] as num?)?.toDouble() ?? 0;
    final cost = (ingredient['cost'] as num?)?.toDouble() ?? 0;
    final unitAbbr = ingredient['unit']?['abbreviation'] ?? '';

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
          Icon(Icons.restaurant_menu, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ingredient['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500)),
                Text('฿${cost.toStringAsFixed(0)}/$unitAbbr', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Expanded(child: Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          SizedBox(width: 8),
          IconButton(icon: Icon(Icons.edit, size: 20), onPressed: () => checkPermissionAndExecute(context, 'inventory_ingredients_edit', 'แก้ไขวัตถุดิบ', () => _showEditIngredientDialog(ingredient)), padding: EdgeInsets.zero, constraints: BoxConstraints()),
        ],
      ),
    );
  }

  // Dialogs
  void _showCategoryDialog() {
    // TODO: Implement category dialog for ingredients
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('จัดการประเภทวัตถุดิบยังไม่พร้อมใช้งาน')),
    );
  }

  void _showUnitDialog() {
    // TODO: Implement unit dialog for ingredients
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('จัดการหน่วยนับวัตถุดิบยังไม่พร้อมใช้งาน')),
    );
  }

  void _showAddIngredientDialog() {
    // TODO: Implement add ingredient dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เพิ่มวัตถุดิบยังไม่พร้อมใช้งาน')),
    );
  }

  void _showEditIngredientDialog(Map<String, dynamic> ingredient) {
    // TODO: Implement edit ingredient dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('แก้ไขวัตถุดิบยังไม่พร้อมใช้งาน')),
    );
  }
}
