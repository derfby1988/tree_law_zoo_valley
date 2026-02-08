import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';
import 'inventory_filter_widget.dart';

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
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      ]);
      setState(() {
        _products = results[0];
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
        final shelf = p['shelf'];
        return shelf != null && shelf['code'] == _selectedShelf;
      }).toList();
    }
    return list;
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
    final shelfOptions = ['ทั้งหมด', ..._shelves.map((s) => s['code'] as String)];

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
              onWarehouseChanged: (value) => setState(() => _selectedWarehouse = value!),
              onShelfChanged: (value) => setState(() => _selectedShelf = value!),
              warehouseOptions: warehouseOptions,
              shelfOptions: shelfOptions,
            ),
            SizedBox(height: 16),
            _buildActionButtons(),
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

  Widget _buildProductList() {
    final filtered = _filteredProducts;
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รายการสินค้า (${filtered.length} รายการ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('ไม่พบสินค้า', style: TextStyle(color: Colors.grey[600]))),
              )
            else
              ...filtered.map((product) => _buildProductItem(product)).toList(),
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
    final shelfCode = product['shelf']?['code'] ?? '-';

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
          Expanded(child: Text(shelfCode, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center)),
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
                  return ListTile(title: Text(cat['name'] ?? ''), trailing: Text('$count รายการ'));
                }).toList(),
                Divider(),
                TextField(controller: newCatController, decoration: InputDecoration(labelText: 'เพิ่มประเภทใหม่', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('ปิด')),
            ElevatedButton(
              onPressed: () async {
                if (newCatController.text.trim().isEmpty) return;
                final ok = await InventoryService.addCategory(newCatController.text.trim());
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState?.validate() != true) return;
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
}
