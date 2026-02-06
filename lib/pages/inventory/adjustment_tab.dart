import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
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
            _buildAdjustmentForm(),
            SizedBox(height: 16),
            _buildRecentAdjustments(),
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
                _buildActionButton('กำหนดคลัง', Colors.indigo, Icons.warehouse, () => _showWarehouseDialog()),
                _buildActionButton('ชั้นวาง', Colors.teal, Icons.shelves, () => _showShelfDialog()),
                _buildActionButton('ซื้อสินค้า', Colors.green, Icons.shopping_cart, () => _showQuickAdjustDialog('purchase', 'ซื้อสินค้า', Colors.green)),
                _buildActionButton('เบิกใช้', Colors.cyan, Icons.outbox, () => _showQuickAdjustDialog('withdraw', 'เบิกใช้สินค้า', Colors.cyan)),
                _buildActionButton('ตัดสินค้าเสีย', Colors.red, Icons.delete_forever, () => _showQuickAdjustDialog('damage', 'ตัดสินค้าเสีย', Colors.red)),
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
                      Text(userName, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      SizedBox(width: 8),
                      Text(timeStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
    final managerController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.warehouse, color: Colors.indigo), SizedBox(width: 8), Text('กำหนดคลัง')]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_warehouses.isNotEmpty) ...[
              ..._warehouses.map((w) => ListTile(title: Text(w['name'] ?? ''), subtitle: Text(w['location'] ?? ''))).toList(),
              Divider(),
            ],
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'ชื่อคลัง', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(controller: locationController, decoration: InputDecoration(labelText: 'ที่ตั้ง', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(controller: managerController, decoration: InputDecoration(labelText: 'ผู้รับผิดชอบ', border: OutlineInputBorder())),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameController.text.trim().isEmpty) return;
                setDialogState(() => isLoading = true);
                final ok = await InventoryService.addWarehouse(name: nameController.text.trim(), location: locationController.text.trim(), manager: managerController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มคลังสำเร็จ'), backgroundColor: Colors.green)); }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShelfDialog() {
    final codeController = TextEditingController();
    final capacityController = TextEditingController();
    String? selectedWarehouseId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.shelves, color: Colors.teal), SizedBox(width: 8), Text('จัดการชั้นวาง')]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกคลัง', border: OutlineInputBorder()),
              items: _warehouses.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] ?? ''))).toList(),
              onChanged: (v) => setDialogState(() => selectedWarehouseId = v),
            ),
            SizedBox(height: 12),
            TextField(controller: codeController, decoration: InputDecoration(labelText: 'รหัสชั้น', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(controller: capacityController, decoration: InputDecoration(labelText: 'ความจุ', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (selectedWarehouseId == null || codeController.text.trim().isEmpty) return;
                setDialogState(() => isLoading = true);
                final ok = await InventoryService.addShelf(warehouseId: selectedWarehouseId!, code: codeController.text.trim(), capacity: int.tryParse(capacityController.text) ?? 0);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มชั้นวางสำเร็จ'), backgroundColor: Colors.green)); }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
            ),
          ],
        ),
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
            title: Row(children: [Icon(Icons.edit, color: color), SizedBox(width: 8), Text(title)]),
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
