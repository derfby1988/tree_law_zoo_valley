import 'package:flutter/material.dart';
import '../../../services/procurement_service.dart';
import '../../../services/inventory_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_design_system.dart';
import '../../../utils/thai_date_utils.dart';

class ReceiveGoodsEnhancedDialog extends StatefulWidget {
  final String poLineId;
  final Map<String, dynamic> poLineData;
  final VoidCallback? onSuccess;

  const ReceiveGoodsEnhancedDialog({
    super.key,
    required this.poLineId,
    required this.poLineData,
    this.onSuccess,
  });

  @override
  State<ReceiveGoodsEnhancedDialog> createState() => _ReceiveGoodsEnhancedDialogState();
}

class _ReceiveGoodsEnhancedDialogState extends State<ReceiveGoodsEnhancedDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _batchController;
  late TextEditingController _notesController;
  
  String? _selectedWarehouseId;
  String? _selectedShelfId;
  String _qcStatus = 'pending';
  DateTime? _expiryDate;
  
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _shelves = [];
  
  bool _isLoading = false;
  bool _isLoadingWarehouses = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: ((widget.poLineData['quantity'] as num?) ?? 0).toString(),
    );
    _batchController = TextEditingController();
    _notesController = TextEditingController();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _batchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _isLoadingWarehouses = true);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโหลดคลัง: $e')),
      );
    } finally {
      setState(() => _isLoadingWarehouses = false);
    }
  }

  Future<void> _loadShelves() async {
    if (_selectedWarehouseId == null) return;
    
    try {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโหลดชั้นวาง: $e')),
      );
    }
  }

  Future<void> _submitReceive() async {
    if (_selectedWarehouseId == null || _selectedShelfId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกคลังและชั้นวาง')),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนที่ถูกต้อง')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = PermissionService.currentUserId;
      final success = await ProcurementService.recordPartialReceive(
        poLineId: widget.poLineId,
        receivedQuantity: quantity,
        warehouseId: _selectedWarehouseId!,
        shelfId: _selectedShelfId!,
        batchNumber: _batchController.text.isNotEmpty ? _batchController.text : null,
        expiryDate: _expiryDate,
        qcStatus: _qcStatus,
        qcNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
        receivedBy: userId,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกการรับสินค้าสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกการรับสินค้า')),
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
    final poNumber = widget.poLineData['po']?['order_number'] ?? '-';
    final productName = widget.poLineData['product']?['name'] ?? 'Unknown';
    final orderedQuantity = widget.poLineData['quantity'] ?? 0;
    final receivedQuantity = widget.poLineData['received_quantity'] ?? 0;
    final remainingQuantity = (orderedQuantity as num) - (receivedQuantity as num);

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
                        Text(
                          'รับสินค้า',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PO: $poNumber | $productName',
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
                  // Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'สั่งซื้อ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                            Text(
                              '$orderedQuantity',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'รับแล้ว',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                            Text(
                              '$receivedQuantity',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'เหลือ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                            Text(
                              '$remainingQuantity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: remainingQuantity > 0 ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนที่รับ',
                      border: OutlineInputBorder(),
                      suffixText: 'หน่วย',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Warehouse
                  if (_isLoadingWarehouses)
                    const Center(child: CircularProgressIndicator())
                  else
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

                  // Shelf
                  DropdownButtonFormField<String>(
                    value: _selectedShelfId,
                    decoration: const InputDecoration(
                      labelText: 'ชั้นวาง',
                      border: OutlineInputBorder(),
                    ),
                    items: _shelves.map((s) => DropdownMenuItem(
                      value: s['id']?.toString(),
                      child: Text(s['name']?.toString() ?? 'Unknown'),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => _selectedShelfId = value);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Batch Number
                  TextField(
                    controller: _batchController,
                    decoration: const InputDecoration(
                      labelText: 'เลขล็อต/แบตช์ (ถ้ามี)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Expiry Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _expiryDate == null
                          ? 'วันหมดอายุ (ถ้ามี)'
                          : 'วันหมดอายุ: ${ThaiDateUtils.formatBuddhistDate(_expiryDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await ThaiDateUtils.showThaiDatePicker(
                        context: context,
                        initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 1825)),
                      );
                      if (date != null) {
                        setState(() => _expiryDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // QC Status
                  Text(
                    'สถานะ QC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(label: Text('รอตรวจ'), value: 'pending'),
                            ButtonSegment(label: Text('ผ่าน'), value: 'pass'),
                            ButtonSegment(label: Text('ไม่ผ่าน'), value: 'fail'),
                          ],
                          selected: {_qcStatus},
                          onSelectionChanged: (value) {
                            setState(() => _qcStatus = value.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // QC Notes
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุ QC',
                      border: OutlineInputBorder(),
                      hintText: 'เช่น สภาพสินค้า, ปัญหาที่พบ, ฯลฯ',
                    ),
                  ),
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
                    onPressed: _isLoading ? null : _submitReceive,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('บันทึกการรับสินค้า'),
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
