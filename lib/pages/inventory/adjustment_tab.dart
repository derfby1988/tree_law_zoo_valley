import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import 'inventory_filter_widget.dart';

class AdjustmentTab extends StatefulWidget {
  const AdjustmentTab({super.key});

  @override
  State<AdjustmentTab> createState() => _AdjustmentTabState();
}

class _AdjustmentTabState extends State<AdjustmentTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'ทั้งหมด';
  String _selectedShelf = 'ทั้งหมด';

  List<Map<String, dynamic>> _adjustments = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _shelves = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ฟอร์มปรับปรุง
  String? _selectedProductId;
  final _newQtyController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
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
        InventoryService.getAdjustments(limit: 20),
        InventoryService.getProducts(),
        InventoryService.getWarehouses(),
        InventoryService.getShelves(),
      ]);
      setState(() {
        _adjustments = results[0];
        _products = results[1];
        _warehouses = results[2];
        _shelves = results[3];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  Map<String, dynamic>? get _selectedProduct {
    if (_selectedProductId == null) return null;
    return _products.where((p) => p['id'] == _selectedProductId).firstOrNull;
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
            _buildActionButtons(),
            SizedBox(height: 16),
            _buildWarehouseList(),
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
            Text('ดำเนินการคลังสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (PermissionService.canAccessActionSync('inventory_adjustment_shelf'))
                  _buildActionButton('ชั้นวาง', Colors.teal, Icons.shelves, () => _showShelfDialog()),
                if (PermissionService.canAccessActionSync('inventory_adjustment_purchase'))
                  _buildActionButton('ซื้อสินค้า', Colors.green, Icons.shopping_cart, () => _showQuickAdjustDialog('purchase', 'ซื้อสินค้า', Colors.green)),
                if (PermissionService.canAccessActionSync('inventory_adjustment_withdraw'))
                  _buildActionButton('เบิกใช้', Colors.cyan, Icons.outbox, () => _showQuickAdjustDialog('withdraw', 'เบิกใช้สินค้า', Colors.cyan)),
                if (PermissionService.canAccessActionSync('inventory_adjustment_damage'))
                  _buildActionButton('ตัดสินค้าเสีย', Colors.red, Icons.delete_forever, () => _showQuickAdjustDialog('damage', 'ตัดสินค้าเสีย', Colors.red)),
                if (PermissionService.canAccessActionSync('inventory_adjustment_count'))
                  _buildActionButton('ตรวจนับสต๊อก', Colors.orange, Icons.inventory_2, () => _showQuickAdjustDialog('count', 'ตรวจนับสต๊อก', Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('รายการคลัง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (PermissionService.canAccessActionSync('inventory_adjustment_warehouse_add'))
                  ElevatedButton.icon(
                    onPressed: () => _showWarehouseDialog(),
                    icon: Icon(Icons.add, size: 18),
                    label: Text('เพิ่มคลัง'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            if (_warehouses.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('ไม่มีคลัง', style: TextStyle(color: Colors.grey[600]))),
              )
            else
              Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('ชื่อคลัง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('ที่อยู่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        SizedBox(width: 40, child: Text('จัดการ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
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
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  color: Colors.grey[100],
                                  child: Text(name, style: TextStyle(fontWeight: FontWeight.w500)),
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
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(name)),
          Expanded(flex: 2, child: Text(location, style: TextStyle(color: Colors.grey[600]))),
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditWarehouseDialog(id, name, location);
                } else if (value == 'delete') {
                  _showDeleteWarehouseDialog(id, name);
                }
              },
              itemBuilder: (context) => [
                if (PermissionService.canAccessActionSync('inventory_adjustment_warehouse_edit'))
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text('แก้ไข')),
                      ],
                    ),
                  ),
                if (PermissionService.canAccessActionSync('inventory_adjustment_warehouse_delete'))
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('ลบ')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWarehouseOrder() async {
    // TODO: Implement order saving via InventoryService
    // For now, just save locally
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

  Widget _buildAdjustmentForm() {
    final product = _selectedProduct;
    final currentQty = (product?['quantity'] as num?)?.toDouble() ?? 0;
    final unitAbbr = product?['unit']?['abbreviation'] ?? '';
    final shelfCode = product?['shelf']?['code'] ?? '-';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ฟอร์มปรับปรุงคลังสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              value: _selectedProductId,
              items: _products.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] ?? ''))).toList(),
              onChanged: (value) => setState(() { _selectedProductId = value; _newQtyController.clear(); }),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(decoration: InputDecoration(labelText: 'ชั้นวาง', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), initialValue: shelfCode, enabled: false)),
                SizedBox(width: 12),
                Expanded(child: TextFormField(decoration: InputDecoration(labelText: 'ปัจจุบัน ($unitAbbr)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), controller: TextEditingController(text: '${currentQty.toStringAsFixed(currentQty == currentQty.roundToDouble() ? 0 : 1)}'), enabled: false)),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _newQtyController, decoration: InputDecoration(labelText: 'ปรับเป็น', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), keyboardType: TextInputType.number)),
                SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _reasonController, decoration: InputDecoration(labelText: 'เหตุผล', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
              ],
            ),
            SizedBox(height: 12),
            TextFormField(decoration: InputDecoration(labelText: 'วันที่', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), initialValue: dateStr, enabled: false),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() { _selectedProductId = null; _newQtyController.clear(); _reasonController.clear(); }),
                  icon: Icon(Icons.refresh),
                  label: Text('รีเซ็ต'),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _selectedProductId == null ? null : () async {
                    final newQty = double.tryParse(_newQtyController.text);
                    if (newQty == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกจำนวนที่ถูกต้อง'), backgroundColor: Colors.red));
                      return;
                    }
                    final ok = await InventoryService.addAdjustment(
                      productId: _selectedProductId!,
                      type: 'adjust',
                      quantityBefore: currentQty,
                      quantityAfter: newQty,
                      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
                    );
                    if (mounted) {
                      if (ok) {
                        _loadData();
                        setState(() { _selectedProductId = null; _newQtyController.clear(); _reasonController.clear(); });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ปรับปรุงสำเร็จ'), backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  icon: Icon(Icons.save),
                  label: Text('บันทึก'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAdjustments() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ประวัติการปรับปรุงล่าสุด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            if (_adjustments.isEmpty)
              Padding(padding: EdgeInsets.all(16), child: Center(child: Text('ไม่มีประวัติ', style: TextStyle(color: Colors.grey[600]))))
            else
              ..._adjustments.map((adj) {
                final productName = adj['product']?['name'] ?? '-';
                final qtyBefore = (adj['quantity_before'] as num?)?.toDouble() ?? 0;
                final qtyAfter = (adj['quantity_after'] as num?)?.toDouble() ?? 0;
                final change = (adj['quantity_change'] as num?)?.toDouble() ?? 0;
                final type = adj['type'] ?? '';
                final userName = adj['user_name'] ?? '-';
                final createdAt = DateTime.tryParse(adj['created_at']?.toString() ?? '');
                final timeStr = createdAt != null ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}' : '';
                final isPositive = change >= 0;
                final color = isPositive ? Colors.green : Colors.red;
                final typeLabel = _getTypeLabel(type);

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$productName ${qtyBefore.toStringAsFixed(0)}→${qtyAfter.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text('$typeLabel ${adj['reason'] ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      )),
                      Flexible(child: Text(userName, style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 8),
                      Flexible(child: Text(timeStr, style: TextStyle(color: Colors.grey[500], fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'purchase': return 'ซื้อ';
      case 'return': return 'ส่งคืน';
      case 'count': return 'ตรวจนับ';
      case 'transfer': return 'โอนคลัง';
      case 'withdraw': return 'เบิกใช้';
      case 'damage': return 'สินค้าเสีย';
      case 'produce': return 'ผลิต';
      case 'adjust': return 'ปรับปรุง';
      default: return type;
    }
  }

  // Dialogs
  void _showWarehouseDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    bool isLoading = false;

    // Thai character regex
    final thaiRegex = RegExp(r'^[\u0E00-\u0E7F0-9\s]+$');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.warehouse, color: Colors.indigo), SizedBox(width: 8), Expanded(child: Text('กำหนดคลัง'))]),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return 'กรุณากรอกชื่อคลัง';
                      if (!thaiRegex.hasMatch(v!.trim())) return 'กรุณาใช้ภาษาไทยเท่านั้น';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'ที่ตั้ง',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
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
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกชื่อคลัง'), backgroundColor: Colors.red));
                  return;
                }
                // Check Thai characters
                if (!thaiRegex.hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อคลังต้องเป็นภาษาไทยเท่านั้น'), backgroundColor: Colors.red));
                  return;
                }
                // Check duplicate name
                final isDuplicate = _warehouses.any((w) => (w['name'] as String?)?.trim() == name);
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อคลังนี้มีอยู่แล้ว'), backgroundColor: Colors.red));
                  return;
                }
                setDialogState(() => isLoading = true);
                final ok = await InventoryService.addWarehouse(
                  name: name,
                  location: locationController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มคลังสำเร็จ'), backgroundColor: Colors.green));
                  }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditWarehouseDialog(String? id, String currentName, String currentLocation) {
    if (id == null) return;
    final nameController = TextEditingController(text: currentName);
    final locationController = TextEditingController(text: currentLocation);
    bool isLoading = false;

    // Thai character regex
    final thaiRegex = RegExp(r'^[\u0E00-\u0E7F0-9\s]+$');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text('แก้ไขคลัง'))]),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'ที่ตั้ง',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
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
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกชื่อคลัง'), backgroundColor: Colors.red));
                  return;
                }
                // Check Thai characters
                if (!thaiRegex.hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อคลังต้องเป็นภาษาไทยเท่านั้น'), backgroundColor: Colors.red));
                  return;
                }
                // Check duplicate name (excluding current)
                final isDuplicate = _warehouses.any((w) => 
                  (w['name'] as String?)?.trim() == name && 
                  w['id'] != id
                );
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อคลังนี้มีอยู่แล้ว'), backgroundColor: Colors.red));
                  return;
                }
                setDialogState(() => isLoading = true);
                final ok = await InventoryService.updateWarehouse(
                  id: id,
                  name: name,
                  location: locationController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('แก้ไขคลังสำเร็จ'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red));
                  }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteWarehouseDialog(String? id, String name) {
    if (id == null) return;
    
    // Check if warehouse has shelves
    final warehouseShelves = _shelves.where((s) => s['warehouse_id'] == id).toList();
    final shelfCount = warehouseShelves.length;
    
    if (shelfCount > 0) {
      // Show warning that warehouse has shelves
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('ไม่สามารถลบได้'))]),
          content: Text('คลัง "$name" มีชั้นวางอยู่ $shelfCount รายการ\n\nกรุณาลบชั้นวางทั้งหมดในคลังก่อนลบคลัง'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: Text('เข้าใจแล้ว'),
            ),
          ],
        ),
      );
      return;
    }
    
    // No shelves, show delete confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Expanded(child: Text('ลบคลัง'))]),
        content: Text('คุณต้องการลบคลัง "$name" ใช่หรือไม่?\n\nหมายเหตุ: การลบคลังไม่สามารถเรียกคืนได้'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await InventoryService.deleteWarehouse(id);
              if (context.mounted) {
                Navigator.pop(context);
                if (ok) {
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบคลังสำเร็จ'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถลบคลังได้'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('ลบ'),
          ),
        ],
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
          title: Row(children: [Icon(Icons.shelves, color: Colors.teal), SizedBox(width: 8), Expanded(child: Text('กำหนดชั้นวาง'))]),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'เลือกคลัง *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                margin: EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(shelfName, overflow: TextOverflow.ellipsis),
                                    ),
                                    if (hasProducts)
                                      Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Text(' ($productCount สินค้า)', 
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    // Move shelf button - available for all shelves
                                    IconButton(
                                      icon: Icon(Icons.move_up, color: Colors.blue, size: 20),
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
                                        icon: Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          // Check if shelf has products first
                                          final productCount = _products.where((p) => p['shelf_id'] == shelfId).length;
                                          if (productCount > 0) {
                                            // Show warning that shelf has products
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('ไม่สามารถลบได้'))]),
                                                content: Text('ชั้นวาง "$shelfName" มีสินค้าจัดอยู่ $productCount รายการ\n\nกรุณาย้ายสินค้าออกจากชั้นวางก่อนลบ'),
                                                actions: [
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                                    child: Text('เข้าใจแล้ว'),
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
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  child: Text('ลบ'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && shelfId != null) {
                                            final ok = await InventoryService.deleteShelf(shelfId);
                                            if (context.mounted) {
                                              if (ok) {
                                                await _loadData();
                                                setDialogState(() {});
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบชั้นวางสำเร็จ'), backgroundColor: Colors.green));
                                                // Check if no more shelves in this warehouse and close dialog
                                                final remainingShelves = _shelves.where((s) => s['warehouse_id'] == selectedWarehouseId).toList();
                                                if (remainingShelves.isEmpty) {
                                                  Navigator.pop(context);
                                                }
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถลบชั้นวางได้'), backgroundColor: Colors.red));
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณาเลือกคลัง'), backgroundColor: Colors.red));
                  return;
                }
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกชื่อชั้นวาง'), backgroundColor: Colors.red));
                  return;
                }
                // Check Thai characters for shelf name
                if (!thaiRegex.hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อชั้นวางต้องเป็นภาษาไทยเท่านั้น'), backgroundColor: Colors.red));
                  return;
                }
                // Check duplicate shelf name in same warehouse
                final isDuplicate = _shelves.any((s) => 
                  (s['code'] as String?)?.trim() == name &&
                  (s['warehouse_id'] as String?) == selectedWarehouseId
                );
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อชั้นวางนี้มีอยู่แล้วในคลังนี้'), backgroundColor: Colors.red));
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มชั้นวางสำเร็จ'), backgroundColor: Colors.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก กรุณาลองใหม่'), backgroundColor: Colors.red));
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
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
            title: Row(children: [Icon(Icons.move_up, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text('ย้ายชั้นวาง'))]),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      child: Text('ไม่มีคลังอื่นที่สามารถย้ายไปได้', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อชั้นวาง (เปลี่ยนได้ถ้าต้องการ)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกชื่อชั้นวาง'), backgroundColor: Colors.red));
                        return;
                      }
                      // Check Thai characters
                      if (!thaiRegex.hasMatch(newName)) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อชั้นวางต้องเป็นภาษาไทยเท่านั้น'), backgroundColor: Colors.red));
                        return;
                      }
                      // Check duplicate shelf name in destination warehouse
                      final isDuplicate = _shelves.any((s) =>
                        (s['code'] as String?)?.trim() == newName &&
                        (s['warehouse_id'] as String?) == selectedDestinationWarehouseId
                      );
                      if (isDuplicate) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ชื่อชั้นวางนี้มีอยู่แล้วในคลังปลายทาง กรุณาเปลี่ยนชื่อ'), backgroundColor: Colors.red));
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
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ย้ายชั้นวางสำเร็จ'), backgroundColor: Colors.green));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถย้ายชั้นวางได้'), backgroundColor: Colors.red));
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setMoveDialogState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('ย้าย'),
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
            title: Row(children: [Icon(Icons.edit, color: color), SizedBox(width: 8), Expanded(child: Text(title))]),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
                items: _products.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] ?? ''))).toList(),
                onChanged: (v) => setDialogState(() => selectedProductId = v),
              ),
              if (product != null) ...[
                SizedBox(height: 8),
                Text('คงเหลือ: ${currentQty.toStringAsFixed(0)} ${product['unit']?['abbreviation'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
              ],
              SizedBox(height: 12),
              TextField(controller: qtyController, decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              SizedBox(height: 12),
              TextField(controller: reasonController, decoration: InputDecoration(labelText: 'เหตุผล/หมายเหตุ', border: OutlineInputBorder())),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (selectedProductId == null) return;
                  final qty = double.tryParse(qtyController.text);
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกจำนวนที่ถูกต้อง'), backgroundColor: Colors.red));
                    return;
                  }
                  setDialogState(() => isLoading = true);
                  double newQty;
                  if (type == 'purchase') {
                    newQty = currentQty + qty;
                  } else {
                    newQty = currentQty - qty;
                    if (newQty < 0) newQty = 0;
                  }
                  final ok = await InventoryService.addAdjustment(
                    productId: selectedProductId!,
                    type: type,
                    quantityBefore: currentQty,
                    quantityAfter: newQty,
                    reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (ok) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title สำเร็จ'), backgroundColor: Colors.green)); }
                    else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red)); }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }
}
