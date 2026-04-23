import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_design_system.dart';

class BulkActionsDialog extends StatefulWidget {
  final List<String> selectedProductIds;
  final List<Map<String, dynamic>> products;
  final VoidCallback? onSuccess;

  const BulkActionsDialog({
    super.key,
    required this.selectedProductIds,
    required this.products,
    this.onSuccess,
  });

  @override
  State<BulkActionsDialog> createState() => _BulkActionsDialogState();
}

class _BulkActionsDialogState extends State<BulkActionsDialog> {
  String _selectedAction = 'adjustment'; // adjustment, price, location, approve, reject
  
  // Adjustment fields
  late TextEditingController _adjustmentQtyController;
  late TextEditingController _adjustmentReasonController;
  
  // Price fields
  late TextEditingController _priceController;
  
  // Location fields
  String? _selectedWarehouseId;
  String? _selectedShelfId;
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _shelves = [];
  
  // Approval fields
  late TextEditingController _approvalNoteController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _adjustmentQtyController = TextEditingController();
    _adjustmentReasonController = TextEditingController();
    _priceController = TextEditingController();
    _approvalNoteController = TextEditingController();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _adjustmentQtyController.dispose();
    _adjustmentReasonController.dispose();
    _priceController.dispose();
    _approvalNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    try {
      final warehouses = await InventoryService.getWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        if (warehouses.isNotEmpty) {
          _selectedWarehouseId = warehouses.first['id']?.toString();
          _loadShelves();
        }
      });
    } catch (e) {
      debugPrint('Error loading warehouses: $e');
    }
  }

  Future<void> _loadShelves() async {
    if (_selectedWarehouseId == null) return;
    try {
      // ✅ รีเซ็ต _shelves ก่อนโหลด
      setState(() {
        _shelves = [];
        _selectedShelfId = null;
      });
      
      final shelves = await InventoryService.getShelves(
        warehouseId: _selectedWarehouseId!,
      );
      if (!mounted) return;
      setState(() {
        _shelves = shelves;
        if (shelves.isNotEmpty) {
          _selectedShelfId = shelves.first['id']?.toString();
        }
      });
    } catch (e) {
      debugPrint('Error loading shelves: $e');
    }
  }

  Future<void> _executeAction() async {
    setState(() => _isLoading = true);

    try {
      final userId = PermissionService.currentUserId;
      bool success = false;

      switch (_selectedAction) {
        case 'adjustment':
          final qty = double.tryParse(_adjustmentQtyController.text);
          if (qty == null || qty == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('กรุณากรอกจำนวน')),
            );
            return;
          }

          final adjustments = widget.selectedProductIds.map((id) => {
            'product_id': id,
            'quantity': qty,
            'reason': _adjustmentReasonController.text.isNotEmpty
                ? _adjustmentReasonController.text
                : 'Bulk adjustment',
          }).toList();

          success = await InventoryService.bulkAdjustment(
            adjustments: adjustments,
            adjustedBy: userId,
          );
          break;

        case 'price':
          final price = double.tryParse(_priceController.text);
          if (price == null || price < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('กรุณากรอกราคาที่ถูกต้อง')),
            );
            return;
          }

          final updates = widget.selectedProductIds.map((id) => {
            'product_id': id,
            'new_price': price,
          }).toList();

          success = await InventoryService.bulkUpdatePrice(
            updates: updates,
            updatedBy: userId,
          );
          break;

        case 'location':
          if (_selectedWarehouseId == null || _selectedShelfId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('กรุณาเลือกคลังและชั้นวาง')),
            );
            return;
          }

          success = await InventoryService.bulkUpdateLocation(
            productIds: widget.selectedProductIds,
            newWarehouseId: _selectedWarehouseId!,
            newShelfId: _selectedShelfId!,
            updatedBy: userId,
          );
          break;

        case 'approve':
          success = await InventoryService.bulkApproveAdjustments(
            adjustmentIds: widget.selectedProductIds,
            approvedBy: userId,
            approvalNote: _approvalNoteController.text.isNotEmpty
                ? _approvalNoteController.text
                : null,
          );
          break;

        case 'reject':
          success = await InventoryService.bulkRejectAdjustments(
            adjustmentIds: widget.selectedProductIds,
            rejectedBy: userId,
            rejectionReason: _approvalNoteController.text.isNotEmpty
                ? _approvalNoteController.text
                : null,
          );
          break;
      }

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดำเนินการสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถดำเนินการ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ดำเนินการเป็นกลุ่ม',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'เลือก: ${widget.selectedProductIds.length} รายการ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action selector
                  Text(
                    'เลือกการดำเนินการ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        label: Text('ปรับปรุง'),
                        value: 'adjustment',
                        icon: Icon(Icons.edit),
                      ),
                      ButtonSegment(
                        label: Text('ราคา'),
                        value: 'price',
                        icon: Icon(Icons.attach_money),
                      ),
                      ButtonSegment(
                        label: Text('ตำแหน่ง'),
                        value: 'location',
                        icon: Icon(Icons.location_on),
                      ),
                    ],
                    selected: {_selectedAction},
                    onSelectionChanged: (value) {
                      setState(() => _selectedAction = value.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Action-specific fields
                  if (_selectedAction == 'adjustment') ...[
                    TextField(
                      controller: _adjustmentQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'จำนวนที่ปรับปรุง',
                        border: OutlineInputBorder(),
                        suffixText: 'หน่วย',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _adjustmentReasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'เหตุผล',
                        border: OutlineInputBorder(),
                        hintText: 'เช่น ปรับปรุงสต็อก, ตรวจนับ',
                      ),
                    ),
                  ] else if (_selectedAction == 'price') ...[
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ราคาใหม่',
                        border: OutlineInputBorder(),
                        prefixText: '฿ ',
                      ),
                    ),
                  ] else if (_selectedAction == 'location') ...[
                    DropdownButtonFormField<String>(
                      value: _selectedWarehouseId,
                      decoration: const InputDecoration(
                        labelText: 'คลัง',
                        border: OutlineInputBorder(),
                      ),
                      items: _warehouses.map((w) => DropdownMenuItem(
                        value: w['id']?.toString(),
                        child: Text(w['name']?.toString() ?? 'Unknown'),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedWarehouseId = value;
                          _selectedShelfId = null;
                        });
                        _loadShelves();
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedShelfId,
                      decoration: const InputDecoration(
                        labelText: 'ชั้นวาง',
                        border: OutlineInputBorder(),
                      ),
                      items: _shelves
                          .where((s) => _selectedWarehouseId == null || s['warehouse_id'] == _selectedWarehouseId)
                          .map((s) => DropdownMenuItem(
                            value: s['id']?.toString(),
                            child: Text('${s['code'] ?? '-'} - ${s['name']?.toString() ?? 'Unknown'}'),
                          )).toList(),
                      onChanged: (value) {
                        setState(() => _selectedShelfId = value);
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _executeAction,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ดำเนินการ'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
