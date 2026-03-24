import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';
import '../../theme/app_design_system.dart';

class AdjustmentTab extends StatefulWidget {
  const AdjustmentTab({super.key});

  @override
  State<AdjustmentTab> createState() => _AdjustmentTabState();
}

class _AdjustmentTabState extends State<AdjustmentTab> {
  final TextEditingController _searchController = TextEditingController();

  // State for shelf listing with pagination
  String? _selectedWarehouseForShelfFilter;
  final Map<String, int> _shelfProductPages = {}; // shelfId -> current page
  static const int _productsPerPage = 10;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _shelves = [];
  bool _isLoading = true;
  String? _errorMessage;
  Color get _surface => AppDesignSystem.surface;
  Color get _surfaceAlt => AppDesignSystem.background;
  Color get _textPrimary => AppDesignSystem.textPrimary;
  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _borderColor => AppDesignSystem.border;
  Color get _primaryColor => AppDesignSystem.primary;
  Color get _secondaryColor => AppDesignSystem.secondary;
  Color get _successColor => AppDesignSystem.success;
  Color get _warningColor => AppDesignSystem.warning;
  Color get _dangerColor => AppDesignSystem.danger;
  Color get _onPrimaryColor => Theme.of(context).colorScheme.onPrimary;

  // ฟอร์มปรับปรุง
  final _newQtyController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _showPurchaseReceiveDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์นี้กำลังพัฒนา')),
    );
  }

  Widget _buildActionButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newQtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        InventoryService.getProducts(),
        InventoryService.getWarehouses(),
        InventoryService.getShelves(),
      ]);
      setState(() {
        _products = results[0];
        _warehouses = results[1];
        _shelves = results[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: _dangerColor),
        SizedBox(height: 8),
        Text(_errorMessage!, style: TextStyle(color: _dangerColor)),
        SizedBox(height: 12),
        ElevatedButton(onPressed: _loadData, child: Text('ลองใหม่')),
      ])));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActionButtons(),
            SizedBox(height: 16),
            _buildWarehouseList(),
            SizedBox(height: 16),
            _buildShelfList(), // New shelf listing section
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
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
            Text('ดำเนินการคลังสินค้า', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDesignSystem.spacingMd),
            Wrap(
              spacing: AppDesignSystem.spacingSm,
              runSpacing: AppDesignSystem.spacingSm,
              children: [
                if (PermissionService.canAccessActionSync('inventory_adjustment_shelf'))
                  _buildActionButton('ชั้นวาง', _secondaryColor, Icons.shelves, () => checkPermissionAndExecute(context, 'inventory_adjustment_shelf', 'จัดการชั้นวาง', () => _showShelfDialog())),
                if (PermissionService.canAccessActionSync('inventory_adjustment_purchase'))
                  _buildActionButton('รับเข้า', _successColor, Icons.add_shopping_cart, () => checkPermissionAndExecute(context, 'inventory_adjustment_purchase', 'รับเข้าสินค้า', () => _showPurchaseReceiveDialog())),
                if (PermissionService.canAccessActionSync('inventory_adjustment_withdraw'))
                  _buildActionButton('เบิกใช้', _primaryColor, Icons.outbox, () => checkPermissionAndExecute(context, 'inventory_adjustment_withdraw', 'เบิกใช้สินค้า', () => _showQuickAdjustDialog('withdraw', 'เบิกใช้สินค้า', _primaryColor))),
                if (PermissionService.canAccessActionSync('inventory_adjustment_damage'))
                  _buildActionButton('ตัดสินค้าเสีย', _dangerColor, Icons.delete_forever, () => checkPermissionAndExecute(context, 'inventory_adjustment_damage', 'ตัดสินค้าเสีย', () => _showQuickAdjustDialog('damage', 'ตัดสินค้าเสีย', _dangerColor))),
                if (PermissionService.canAccessActionSync('inventory_adjustment_count'))
                  _buildActionButton('ตรวจนับสต๊อก', _warningColor, Icons.inventory_2, () => checkPermissionAndExecute(context, 'inventory_adjustment_count', 'ตรวจนับสต๊อก', () => _showQuickAdjustDialog('count', 'ตรวจนับสต๊อก', _warningColor))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseList() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('รายการคลัง', style: Theme.of(context).textTheme.titleMedium),
                if (PermissionService.canAccessActionSync('inventory_adjustment_warehouse_add'))
                  ElevatedButton.icon(
                    onPressed: () => checkPermissionAndExecute(context, 'inventory_adjustment_warehouse_add', 'เพิ่มคลัง', () => _showWarehouseDialog()),
                    icon: Icon(Icons.add, size: 18),
                    label: Text('เพิ่มคลัง'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _secondaryColor,
                      foregroundColor: _onPrimaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingLg, vertical: AppDesignSystem.spacingSm),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (_warehouses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
                child: Center(child: Text('ไม่มีคลัง', style: TextStyle(color: _textSecondary))),
              )
            else
              Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm, horizontal: AppDesignSystem.spacingMd),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppDesignSystem.radiusSm),
                        topRight: Radius.circular(AppDesignSystem.radiusSm),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('ชื่อคลัง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary))),
                        Expanded(flex: 3, child: Text('ที่อยู่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary))),
                      ],
                    ),
                  ),
                  // Reorderable List with Scrollbar if > 5 items
                  Container(
                    constraints: _warehouses.length > 5 ? BoxConstraints(maxHeight: 5 * 48) : null, // Approx 5 rows height
                    child: Scrollbar(
                      thumbVisibility: _warehouses.length > 5,
                      child: SingleChildScrollView(
                        physics: _warehouses.length > 5 ? AlwaysScrollableScrollPhysics() : NeverScrollableScrollPhysics(),
                        child: Column(
                          children: List.generate(_warehouses.length, (index) {
                            final warehouse = _warehouses[index];
                            final name = warehouse['name'] ?? '';
                            final location = warehouse['location'] ?? '';
                            final id = warehouse['id'] as String?;

                            return LongPressDraggable<Map<String, dynamic>>(
                              data: warehouse,
                              onDragStarted: () {},
                              onDragEnd: (_) {},
                              feedback: Material(
                                elevation: 4,
                                child: Container(
                                  width: MediaQuery.of(context).size.width - 64,
                                  padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingMd, horizontal: AppDesignSystem.spacingMd),
                                  color: _surfaceAlt,
                                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: _buildWarehouseRow(name, location, id),
                              ),
                              child: DragTarget<Map<String, dynamic>>(
                                onAccept: (draggedWarehouse) async {
                                  final oldIndex = _warehouses.indexWhere((w) => w['id'] == draggedWarehouse['id']);
                                  final newIndex = index;
                                  if (oldIndex != newIndex && oldIndex != -1) {
                                    setState(() {
                                      final item = _warehouses.removeAt(oldIndex);
                                      _warehouses.insert(newIndex, item);
                                    });
                                    // Save new order
                                    await _saveWarehouseOrder();
                                  }
                                },
                                builder: (context, candidateData, rejectedData) {
                                  return _buildWarehouseRow(name, location, id);
                                },
                              ),
                            );
                          }),
                        ),
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

  Widget _buildWarehouseRow(String name, String location, String? id) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingMd, horizontal: AppDesignSystem.spacingMd),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: TextStyle(color: _textPrimary))),
          Expanded(flex: 3, child: Text(location, style: TextStyle(color: _textSecondary))),
        ],
      ),
    );
  }

  Future<void> _saveWarehouseOrder() async {
    // TODO: Implement order saving via InventoryService
    // For now, just save locally
  }

  // ========== SHELF LISTING SECTION ==========
  Widget _buildShelfList() {
    // Don't show anything until user selects a warehouse
    if (_selectedWarehouseForShelfFilter == null) {
      return Card(
        elevation: 0,
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          side: const BorderSide(color: AppDesignSystem.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รายการชั้นวางสินค้า',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDesignSystem.spacingLg),
              // Warehouse Filter Dropdown
              Container(
                width: double.infinity,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'เลือกคลัง',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                  ),
                  value: _selectedWarehouseForShelfFilter,
                  hint: Text('กรุณาเลือกคลัง'),
                  items: _getSortedWarehousesByShelfCount().map((w) {
                    final id = w['id'] as String?;
                    final name = w['name'] as String? ?? 'ไม่มีชื่อ';
                    final shelfCount = _shelves.where((s) => s['warehouse_id'] == id).length;
                    if (id == null) return null;
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        '$name ($shelfCount)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).where((item) => item != null).cast<DropdownMenuItem<String?>>().toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedWarehouseForShelfFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.arrow_upward, size: 32, color: _textSecondary.withValues(alpha: 0.55)),
                    const SizedBox(height: 8),
                    Text(
                      'เลือกคลังด้านบนเพื่อดูชั้นวาง',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Filter shelves based on selected warehouse
    final filteredShelves = _shelves.where((shelf) {
      return shelf['warehouse_id'] == _selectedWarehouseForShelfFilter;
    }).toList();

    // Only show shelves with products > 0, sorted by product count (most to least)
    final shelvesWithProducts = filteredShelves.where((shelf) {
      final shelfId = shelf['id'] as String?;
      final productCount = _products.where((p) => p['shelf_id'] == shelfId).length;
      return productCount > 0;
    }).toList()
      ..sort((a, b) {
        final countA = _products.where((p) => p['shelf_id'] == a['id']).length;
        final countB = _products.where((p) => p['shelf_id'] == b['id']).length;
        return countB.compareTo(countA); // มากไปน้อย
      });

    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with dropdown filter
            Row(
              children: [
                Expanded(
                  child: Text(
                    'รายการชั้นวางสินค้า',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Warehouse Filter Dropdown - already selected but can change
                Container(
                  width: 140,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'คลัง',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    value: _selectedWarehouseForShelfFilter,
                    items: _getSortedWarehousesByShelfCount().map((w) {
                      final id = w['id'] as String?;
                      final name = w['name'] as String? ?? 'ไม่มีชื่อ';
                      final shelfCount = _shelves.where((s) => s['warehouse_id'] == id).length;
                      if (id == null) return null;
                      return DropdownMenuItem(
                        value: id,
                        child: Container(
                          width: 120,
                          child: Text(
                            '$name ($shelfCount)',
                            textAlign: TextAlign.right,
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    }).where((item) => item != null).cast<DropdownMenuItem<String?>>().toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedWarehouseForShelfFilter = value;
                        _shelfProductPages.clear(); // Reset pagination when changing warehouse
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Shelf Cards
            if (shelvesWithProducts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: _textSecondary.withValues(alpha: 0.55)),
                      const SizedBox(height: 12),
                      Text(
                        'ไม่มีชั้นวางที่มีสินค้า',
                        style: TextStyle(color: _textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: shelvesWithProducts.length,
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final shelf = shelvesWithProducts[index];
                  return _buildShelfCard(shelf);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfCard(Map<String, dynamic> shelf) {
    final shelfId = shelf['id'] as String?;
    final shelfName = shelf['code'] ?? shelf['name'] ?? 'ไม่มีชื่อ';
    final warehouseId = shelf['warehouse_id'] as String?;
    final warehouseName = _warehouses.firstWhere(
      (w) => w['id'] == warehouseId,
      orElse: () => {'name': 'ไม่ระบุคลัง'},
    )['name'];
    final isActive = shelf['is_active'] ?? true;

    // Get products in this shelf, sorted by quantity (low to high)
    final shelfProducts = _products
        .where((p) => p['shelf_id'] == shelfId)
        .toList()
      ..sort((a, b) {
        final qtyA = (a['quantity'] as num?)?.toDouble() ?? 0;
        final qtyB = (b['quantity'] as num?)?.toDouble() ?? 0;
        return qtyA.compareTo(qtyB); // น้อยไปหามาก
      });
    final totalProducts = shelfProducts.length;

    // Pagination
    final currentPage = _shelfProductPages[shelfId] ?? 0;
    final totalPages = (totalProducts / _productsPerPage).ceil();
    final startIndex = currentPage * _productsPerPage;
    final endIndex = (startIndex + _productsPerPage).clamp(0, totalProducts);
    final paginatedProducts = shelfProducts.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: isActive ? _surface : _surfaceAlt,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        border: Border.all(
          color: isActive ? _secondaryColor.withValues(alpha: 0.3) : _borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shelf Header
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
            decoration: BoxDecoration(
              color: isActive ? _secondaryColor.withValues(alpha: 0.1) : _surfaceAlt,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppDesignSystem.radiusMd),
                topRight: Radius.circular(AppDesignSystem.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shelves,
                  color: isActive ? _secondaryColor : _textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shelfName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isActive ? _textPrimary : _textSecondary,
                          decoration: isActive ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        warehouseName,
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingSm, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? _successColor : _textSecondary,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                  ),
                  child: Text(
                    isActive ? 'ใช้งาน' : 'ไม่ใช้งาน',
                    style: TextStyle(color: _onPrimaryColor, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                // Product Count Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingSm, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                    border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2, size: 12, color: _primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '$totalProducts',
                        style: TextStyle(color: _primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Product List
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm, horizontal: AppDesignSystem.spacingSm),
                  decoration: BoxDecoration(
                    color: _surfaceAlt,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('สินค้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary))),
                      Expanded(flex: 1, child: Text('คงเหลือ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('หน่วย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary), textAlign: TextAlign.center)),
                      const SizedBox(width: 32), // Space for action menu button
                    ],
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingSm),
                // Products
                ...paginatedProducts.map((product) {
                  final productName = product['name'] ?? '-';
                  final quantity = (product['quantity'] as num?)?.toDouble() ?? 0;
                  final unit = product['unit']?['abbreviation'] ?? '-';
                  final isLowStock = quantity <= 5; // threshold for low stock warning

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm, horizontal: AppDesignSystem.spacingSm),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _borderColor)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            productName,
                            style: TextStyle(fontSize: 13, color: _textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isLowStock ? _warningColor : _textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            unit,
                            style: TextStyle(fontSize: 12, color: _textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Action menu button - only show if user has any move permission
                        Builder(
                          builder: (context) {
                            final canMoveShelf = PermissionService.canAccessActionSync('inventory_adjustment_product_move_shelf');
                            final canMoveWarehouse = PermissionService.canAccessActionSync('inventory_adjustment_product_move_warehouse');
                            
                            if (!canMoveShelf && !canMoveWarehouse) {
                              return SizedBox(width: 32); // Placeholder when no permissions
                            }
                            
                            return PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: _textSecondary, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onSelected: (value) {
                                if (value == 'move_shelf') {
                                  checkPermissionAndExecute(
                                    context,
                                    'inventory_adjustment_product_move_shelf',
                                    'ย้ายชั้นวาง',
                                    () => _showMoveProductShelfDialog(product),
                                  );
                                } else if (value == 'move_warehouse') {
                                  checkPermissionAndExecute(
                                    context,
                                    'inventory_adjustment_product_move_warehouse',
                                    'โอนไปคลังอื่น',
                                    () => _showMoveProductWarehouseDialog(product),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                if (canMoveShelf)
                                  PopupMenuItem(
                                    value: 'move_shelf',
                                    child: Row(
                                      children: [
                                        Icon(Icons.move_up, color: _primaryColor, size: 18),
                                        const SizedBox(width: 8),
                                        Text('ย้ายชั้นวาง'),
                                      ],
                                    ),
                                  ),
                                if (canMoveWarehouse)
                                  PopupMenuItem(
                                    value: 'move_warehouse',
                                    child: Row(
                                      children: [
                                        Icon(Icons.warehouse, color: _warningColor, size: 18),
                                        const SizedBox(width: 8),
                                        Text('โอนไปคลังอื่น'),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
                // Pagination Controls
                if (totalPages > 1) ...[
                  const SizedBox(height: AppDesignSystem.spacingMd),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // First page button
                      IconButton(
                        icon: Icon(Icons.first_page, size: 20),
                        onPressed: currentPage > 0
                            ? () {
                                setState(() {
                                  _shelfProductPages[shelfId!] = 0;
                                });
                              }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'หน้าแรก',
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_left, size: 20),
                        onPressed: currentPage > 0
                            ? () {
                                setState(() {
                                  _shelfProductPages[shelfId!] = currentPage - 1;
                                });
                              }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingSm),
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                        ),
                        child: Text(
                          '${currentPage + 1} / $totalPages',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, size: 20),
                        onPressed: currentPage < totalPages - 1
                            ? () {
                                setState(() {
                                  _shelfProductPages[shelfId!] = currentPage + 1;
                                });
                              }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      // Last page button
                      IconButton(
                        icon: Icon(Icons.last_page, size: 20),
                        onPressed: currentPage < totalPages - 1
                            ? () {
                                setState(() {
                                  _shelfProductPages[shelfId!] = totalPages - 1;
                                });
                              }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'หน้าสุดท้าย',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== END SHELF LISTING SECTION ==========

  List<Map<String, dynamic>> _getSortedWarehousesByShelfCount() {
    return List<Map<String, dynamic>>.from(_warehouses)
      ..sort((a, b) {
        final shelfCountA = _shelves.where((s) => s['warehouse_id'] == a['id']).length;
        final shelfCountB = _shelves.where((s) => s['warehouse_id'] == b['id']).length;
        return shelfCountB.compareTo(shelfCountA); // มากไปน้อย
      });
  }

  // Dialog ย้ายสินค้าไปชั้นวางอื่น
  void _showMoveProductShelfDialog(Map<String, dynamic> product) {
    final currentShelfId = product['shelf_id'] as String?;
    String? selectedTargetShelfId;
    bool isLoading = false;

    // Get current shelf info and warehouse_id from _shelves list
    final currentShelf = _shelves.firstWhere(
      (s) => s['id'] == currentShelfId,
      orElse: () => {'code': 'ไม่ระบุ', 'name': 'ไม่ระบุ', 'warehouse_id': null},
    );
    final currentShelfName = currentShelf['code'] ?? currentShelf['name'] ?? 'ไม่ระบุ';
    final currentWarehouseId = currentShelf['warehouse_id'] as String?;

    // Filter shelves in same warehouse, exclude current shelf
    final availableShelves = _shelves.where((s) {
      final sId = s['id'] as String?;
      final sWarehouseId = s['warehouse_id'] as String?;
      return sWarehouseId == currentWarehouseId && sId != currentShelfId;
    }).toList();

    if (availableShelves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('ไม่มีชั้นวางอื่นในคลังนี้ที่จะย้ายได้'), backgroundColor: _warningColor),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [
            Icon(Icons.move_up, color: _primaryColor),
            const SizedBox(width: 8),
            const Expanded(child: Text('ย้ายชั้นวาง')),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สินค้า: ${product['name'] ?? '-'}', style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 4),
                Text('ชั้นวางปัจจุบัน: $currentShelfName', style: TextStyle(color: _textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'ชั้นวางปลายทาง *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  value: selectedTargetShelfId,
                  hint: Text('เลือกชั้นวาง'),
                  items: availableShelves.map((s) {
                    final id = s['id'] as String?;
                    final name = s['code'] ?? s['name'] ?? 'ไม่มีชื่อ';
                    if (id == null) return null;
                    return DropdownMenuItem(value: id, child: Text(name));
                  }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
                  onChanged: (value) => setDialogState(() => selectedTargetShelfId = value),
                  validator: (v) => v == null ? 'กรุณาเลือกชั้นวาง' : null,
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: isLoading || selectedTargetShelfId == null
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      final ok = await InventoryService.updateProductShelf(
                        productId: product['id'] as String,
                        shelfId: selectedTargetShelfId!,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (ok) {
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('ย้ายชั้นวางสำเร็จ'), backgroundColor: _successColor),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('เกิดข้อผิดพลาด'), backgroundColor: _dangerColor),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: _onPrimaryColor),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_onPrimaryColor),
                      ),
                    )
                  : const Text('ย้าย'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog ย้ายสินค้าไปคลังอื่น
  void _showMoveProductWarehouseDialog(Map<String, dynamic> product) {
    final currentWarehouseId = product['warehouse']?['id'] as String?;
    String? selectedTargetWarehouseId;
    String? selectedTargetShelfId;
    bool isLoading = false;

    final currentWarehouse = _warehouses.firstWhere(
      (w) => w['id'] == currentWarehouseId,
      orElse: () => {'name': 'ไม่ระบุคลัง'},
    );
    final currentWarehouseName = currentWarehouse['name'] ?? 'ไม่ระบุ';

    final availableWarehouses = _warehouses.where((w) => w['id'] != currentWarehouseId).toList();

    if (availableWarehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('ไม่มีคลังอื่นที่จะโอนได้'), backgroundColor: _warningColor),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final targetShelves = selectedTargetWarehouseId != null
              ? _shelves.where((s) => s['warehouse_id'] == selectedTargetWarehouseId).toList()
              : <Map<String, dynamic>>[];

          return AlertDialog(
            title: Row(children: [Icon(Icons.warehouse, color: _primaryColor), const SizedBox(width: 8), const Expanded(child: Text('โอนไปคลังอื่น'))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สินค้า: ${product['name'] ?? '-'}', style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                  const SizedBox(height: AppDesignSystem.spacingSm),
                  Text('คลังปัจจุบัน: $currentWarehouseName', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  const SizedBox(height: AppDesignSystem.spacingMd),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'คลังปลายทาง *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                    ),
                    value: selectedTargetWarehouseId,
                    hint: const Text('เลือกคลัง'),
                    items: availableWarehouses.map((w) {
                      final id = w['id'] as String?;
                      final name = w['name'] as String? ?? 'ไม่มีชื่อ';
                      if (id == null) return null;
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
                    onChanged: (value) => setDialogState(() {
                      selectedTargetWarehouseId = value;
                      selectedTargetShelfId = null;
                    }),
                    validator: (v) => v == null ? 'กรุณาเลือกคลัง' : null,
                  ),
                  const SizedBox(height: AppDesignSystem.spacingSm),
                  if (selectedTargetWarehouseId != null)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'ชั้นวางปลายทาง *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                      ),
                      value: selectedTargetShelfId,
                      hint: const Text('เลือกชั้นวาง'),
                      items: targetShelves.isEmpty
                          ? [DropdownMenuItem(value: '', child: Text('ไม่มีชั้นวาง', style: TextStyle(color: _textSecondary)))]
                          : targetShelves.map((s) {
                              final id = s['id'] as String?;
                              final name = s['code'] ?? s['name'] ?? 'ไม่มีชื่อ';
                              if (id == null) return null;
                              return DropdownMenuItem(value: id, child: Text(name));
                            }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
                      onChanged: targetShelves.isEmpty ? null : (value) => setDialogState(() => selectedTargetShelfId = value),
                      validator: (v) => v == null || v.isEmpty ? 'กรุณาเลือกชั้นวาง' : null,
                    ),
                  if (selectedTargetWarehouseId != null && targetShelves.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDesignSystem.spacingSm),
                      child: Text(
                        'คลังนี้ไม่มีชั้นวาง กรุณาเพิ่มชั้นวางก่อน',
                        style: TextStyle(color: _warningColor, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: isLoading || selectedTargetWarehouseId == null || selectedTargetShelfId == null || targetShelves.isEmpty
                    ? null
                    : () async {
                        setDialogState(() => isLoading = true);
                        final ok = await InventoryService.updateProductShelf(
                          productId: product['id'] as String,
                          shelfId: selectedTargetShelfId!,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (ok) {
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('โอนคลังสำเร็จ'), backgroundColor: _successColor),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('เกิดข้อผิดพลาด'), backgroundColor: _dangerColor),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: _onPrimaryColor),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_onPrimaryColor),
                        ),
                      )
                    : const Text('ย้าย'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWarehouseDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    bool isLoading = false;

    final thaiRegex = RegExp(r'^[\u0E00-\u0E7F0-9\s]+$');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(children: [Icon(Icons.warehouse, color: _secondaryColor), const SizedBox(width: 8), const Expanded(child: Text('กำหนดคลัง'))]),
            content: SingleChildScrollView(
              child: Form(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อคลัง *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingMd),
                    TextFormField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'ที่ตั้ง',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('กรุณากรอกชื่อคลัง'), backgroundColor: _dangerColor),
                          );
                          return;
                        }
                        if (!thaiRegex.hasMatch(name)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('ชื่อคลังต้องเป็นภาษาไทยเท่านั้น'), backgroundColor: _dangerColor),
                          );
                          return;
                        }
                        final isDuplicate = _warehouses.any((w) => (w['name'] as String?)?.trim() == name);
                        if (isDuplicate) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('ชื่อคลังนี้มีอยู่แล้ว'), backgroundColor: _dangerColor),
                          );
                          return;
                        }
                        setDialogState(() => isLoading = true);
                        final ok = await InventoryService.addWarehouse(
                          name: name,
                          location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (ok) {
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('เพิ่มคลังสำเร็จ'), backgroundColor: _successColor),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('เกิดข้อผิดพลาด'), backgroundColor: _dangerColor),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: _onPrimaryColor),
                child: isLoading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _onPrimaryColor))
                    : const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShelfDialog() {
    final nameController = TextEditingController();
    String? selectedWarehouseId;
    bool isLoading = false;

    // Thai character regex
    final thaiRegex = RegExp(r'^[\u0E00-\u0E7F0-9\s]+$');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Get shelves for selected warehouse
          final warehouseShelves = selectedWarehouseId != null 
            ? _shelves.where((s) => s['warehouse_id'] == selectedWarehouseId).toList()
            : <Map<String, dynamic>>[];

          return AlertDialog(
          title: Row(children: [Icon(Icons.shelves, color: _secondaryColor), SizedBox(width: 8), Expanded(child: Text('กำหนดชั้นวาง'))]),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'เลือกคลัง *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                    ),
                    value: selectedWarehouseId,
                    items: _warehouses.map((w) {
                      final id = w['id'] as String?;
                      final name = w['name'] as String? ?? 'ไม่มีชื่อ';
                      if (id == null) return null;
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
                    onChanged: _warehouses.isEmpty 
                      ? null
                      : (v) {
                          if (v != null && v.isNotEmpty) {
                            setDialogState(() => selectedWarehouseId = v);
                          }
                        },
                    validator: (v) => v == null || v.isEmpty ? 'กรุณาเลือกคลัง' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อชั้นวาง *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                    ),
                  ),
                  // Show existing shelves if any
                  if (warehouseShelves.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Divider(),
                    Text('ชั้นวางที่มีอยู่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 8),
                    Container(
                      constraints: warehouseShelves.length > 5 ? BoxConstraints(maxHeight: 5 * 48) : null,
                      child: Scrollbar(
                        thumbVisibility: warehouseShelves.length > 5,
                        child: SingleChildScrollView(
                          physics: warehouseShelves.length > 5 ? AlwaysScrollableScrollPhysics() : NeverScrollableScrollPhysics(),
                          child: Column(
                            children: warehouseShelves.map((shelf) {
                              final shelfName = shelf['name'] ?? shelf['code'] ?? '';
                              final shelfId = shelf['id'] as String?;
                              // Check if shelf has products
                              final productCount = _products.where((p) => p['shelf_id'] == shelfId).length;
                              final hasProducts = productCount > 0;

                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm, horizontal: AppDesignSystem.spacingMd),
                                decoration: BoxDecoration(
                                  color: _surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                                ),
                                margin: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(shelfName, overflow: TextOverflow.ellipsis),
                                    ),
                                    if (hasProducts)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(' ($productCount สินค้า)', 
                                          style: TextStyle(color: _textSecondary, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    // Move shelf button - available for all shelves
                                    IconButton(
                                      icon: Icon(Icons.move_up, color: _primaryColor, size: 20),
                                      onPressed: () => _showMoveShelfDialog(
                                        shelfId: shelfId,
                                        shelfName: shelfName,
                                        currentWarehouseId: selectedWarehouseId,
                                        onMoved: () async {
                                          await _loadData();
                                          setDialogState(() {});
                                        },
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                      tooltip: 'ย้ายชั้นวาง',
                                    ),
                                    if (!hasProducts)
                                      IconButton(
                                        icon: Icon(Icons.delete, color: _dangerColor, size: 20),
                                        onPressed: () async {
                                          // Check if shelf has products first
                                          final productCount = _products.where((p) => p['shelf_id'] == shelfId).length;
                                          if (productCount > 0) {
                                            // Show warning that shelf has products
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Row(children: [Icon(Icons.warning, color: _warningColor), const SizedBox(width: 8), const Expanded(child: Text('ไม่สามารถลบได้'))]),
                                                content: Text('ชั้นวาง "$shelfName" มีสินค้าจัดอยู่ $productCount รายการ\n\nกรุณาย้ายสินค้าออกจากชั้นวางก่อนลบ'),
                                                actions: [
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    style: ElevatedButton.styleFrom(backgroundColor: _warningColor, foregroundColor: _onPrimaryColor),
                                                    child: const Text('เข้าใจแล้ว'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            return;
                                          }

                                          // No products, show delete confirmation
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('ลบชั้นวาง'),
                                              content: Text('ต้องการลบชั้นวาง "$shelfName" ใช่หรือไม่?'),
                                              actions: [
                                                OutlinedButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text('ยกเลิก'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: _dangerColor, foregroundColor: _onPrimaryColor),
                                                  child: const Text('ลบ'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && shelfId != null) {
                                            await InventoryService.deleteShelf(shelfId);
                                            if (context.mounted) {
                                              await _loadData();
                                              setDialogState(() {});
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบชั้นวางสำเร็จ'), backgroundColor: _successColor));
                                              // Check if no more shelves in this warehouse and close dialog
                                              final remainingShelves = _shelves.where((s) => s['warehouse_id'] == selectedWarehouseId).toList();
                                              if (remainingShelves.isEmpty) {
                                                Navigator.pop(context);
                                              }
                                            }
                                          }
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (selectedWarehouseId == null || selectedWarehouseId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('กรุณาเลือกคลัง'), backgroundColor: _dangerColor));
                  return;
                }
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('กรุณากรอกชื่อชั้นวาง'), backgroundColor: _dangerColor));
                  return;
                }
                // Check Thai characters for shelf name
                if (!thaiRegex.hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('ชื่อชั้นวางต้องเป็นภาษาไทยเท่านั้น'), backgroundColor: _dangerColor));
                  return;
                }
                // Check duplicate shelf name in same warehouse
                final isDuplicate = _shelves.any((s) => 
                  (s['code'] as String?)?.trim() == name &&
                  (s['warehouse_id'] as String?) == selectedWarehouseId
                );
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('ชื่อชั้นวางนี้มีอยู่แล้วในคลังนี้'), backgroundColor: _dangerColor));
                  return;
                }
                setDialogState(() => isLoading = true);
                try {
                  final ok = await InventoryService.addShelf(
                    warehouseId: selectedWarehouseId!,
                    code: name,
                    capacity: 0,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (ok) {
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มชั้นวางสำเร็จ'), backgroundColor: _successColor));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก กรุณาลองใหม่'), backgroundColor: _dangerColor));
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: _dangerColor));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryColor,
                foregroundColor: _onPrimaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_onPrimaryColor),
                      ),
                    )
                  : const Text('บันทึก'),
            ),
          ],
          );
        },
      ),
    );
  }

  void _showMoveShelfDialog({
    required String? shelfId,
    required String shelfName,
    required String? currentWarehouseId,
    required VoidCallback onMoved,
  }) {
    if (shelfId == null || currentWarehouseId == null) return;

    final nameController = TextEditingController(text: shelfName);
    String? selectedDestinationWarehouseId;
    bool isLoading = false;

    // Thai character regex
    final thaiRegex = RegExp(r'^[\u0E00-\u0E7F0-9\s]+$');

    // Get other warehouses (exclude current)
    final otherWarehouses = _warehouses.where((w) => w['id'] != currentWarehouseId).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setMoveDialogState) {
          return AlertDialog(
            title: Row(children: [Icon(Icons.move_up, color: _primaryColor), const SizedBox(width: 8), const Expanded(child: Text('ย้ายชั้นวาง'))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ชั้นวาง: $shelfName', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'เลือกคลังปลายทาง *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                    ),
                    value: selectedDestinationWarehouseId,
                    items: otherWarehouses.map((w) {
                      final id = w['id'] as String?;
                      final name = w['name'] as String? ?? 'ไม่มีชื่อ';
                      if (id == null) return null;
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
                    onChanged: otherWarehouses.isEmpty
                      ? null
                      : (v) {
                          if (v != null && v.isNotEmpty) {
                            setMoveDialogState(() => selectedDestinationWarehouseId = v);
                          }
                        },
                    validator: (v) => v == null || v.isEmpty ? 'กรุณาเลือกคลังปลายทาง' : null,
                  ),
                  if (otherWarehouses.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'ไม่มีคลังอื่นที่สามารถย้ายไปได้',
                        style: TextStyle(color: _warningColor, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อชั้นวาง (เปลี่ยนได้ถ้าต้องการ)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingMd),
                      helperText: 'หากชื่อซ้ำในคลังปลายทาง ต้องเปลี่ยนชื่อ',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: isLoading || otherWarehouses.isEmpty || selectedDestinationWarehouseId == null
                  ? null
                  : () async {
                      final newName = nameController.text.trim();
                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('กรุณากรอกชื่อชั้นวาง'), backgroundColor: _dangerColor));
                        return;
                      }
                      // Check Thai characters
                      if (!thaiRegex.hasMatch(newName)) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('ชื่อชั้นวางต้องเป็นภาษาไทยเท่านั้น'), backgroundColor: _dangerColor));
                        return;
                      }
                      // Check duplicate shelf name in destination warehouse
                      final isDuplicate = _shelves.any((s) =>
                        (s['code'] as String?)?.trim() == newName &&
                        (s['warehouse_id'] as String?) == selectedDestinationWarehouseId
                      );
                      if (isDuplicate) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('ชื่อชั้นวางนี้มีอยู่แล้วในคลังปลายทาง กรุณาเปลี่ยนชื่อ'), backgroundColor: _dangerColor));
                        return;
                      }

                      setMoveDialogState(() => isLoading = true);
                      try {
                        final ok = await InventoryService.updateShelf(
                          id: shelfId,
                          warehouseId: selectedDestinationWarehouseId!,
                          code: newName,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (ok) {
                            onMoved();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ย้ายชั้นวางสำเร็จ'), backgroundColor: _successColor));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถย้ายชั้นวางได้'), backgroundColor: _dangerColor));
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setMoveDialogState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: _dangerColor));
                        }
                      }
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: _onPrimaryColor,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_onPrimaryColor),
                        ),
                      )
                    : const Text('ย้าย'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickAdjustDialog(String type, String title, Color color) {
    String? selectedProductId;
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final product = selectedProductId != null ? _products.where((p) => p['id'] == selectedProductId).firstOrNull : null;
          final currentQty = (product?['quantity'] as num?)?.toDouble() ?? 0;

          return AlertDialog(
            title: Row(children: [Icon(Icons.edit, color: color), const SizedBox(width: 8), Expanded(child: Text(title))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
                    items: _products.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] ?? ''))).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedProductId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (product != null) ...[
                    Text('จำนวนปัจจุบัน: ${currentQty.toStringAsFixed(0)}'),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'เหตุผล', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedProductId == null || qtyController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')));
                    return;
                  }
                  setDialogState(() => isLoading = true);
                  try {
                    final newQty = double.tryParse(qtyController.text) ?? 0;
                    final ok = await InventoryService.addAdjustment(
                      productId: selectedProductId!,
                      type: type,
                      quantityBefore: currentQty,
                      quantityAfter: newQty,
                      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (ok) {
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title สำเร็จ'), backgroundColor: _successColor));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('เกิดข้อผิดพลาด'), backgroundColor: _dangerColor));
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setDialogState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: _dangerColor));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: _onPrimaryColor),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_onPrimaryColor),
                        ),
                      )
                    : const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }
}
