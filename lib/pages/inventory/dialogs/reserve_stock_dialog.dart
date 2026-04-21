import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_design_system.dart';

class ReserveStockDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final double availableQuantity;
  final VoidCallback? onSuccess;

  const ReserveStockDialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.availableQuantity,
    this.onSuccess,
  });

  @override
  State<ReserveStockDialog> createState() => _ReserveStockDialogState();
}

class _ReserveStockDialogState extends State<ReserveStockDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _orderIdController;
  late TextEditingController _notesController;

  String _action = 'reserve'; // 'reserve' or 'release'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _orderIdController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _orderIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนที่ถูกต้อง')),
      );
      return;
    }

    if (_action == 'reserve' && quantity > widget.availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('จำนวนสำรองไม่ได้เกินจำนวนพร้อมใช้ (${widget.availableQuantity})'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = PermissionService.currentUserId;
      final success = _action == 'reserve'
          ? await InventoryService.reserveStock(
              productId: widget.productId,
              quantity: quantity,
              orderId: _orderIdController.text.isNotEmpty
                  ? _orderIdController.text
                  : null,
              reservedBy: userId,
            )
          : await InventoryService.releaseReservedStock(
              productId: widget.productId,
              quantity: quantity,
              orderId: _orderIdController.text.isNotEmpty
                  ? _orderIdController.text
                  : null,
              releasedBy: userId,
            );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _action == 'reserve'
                  ? 'สำรองสินค้าสำเร็จ'
                  : 'ปล่อยสำรองสำเร็จ',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _action == 'reserve'
                  ? 'ไม่สามารถสำรองสินค้า'
                  : 'ไม่สามารถปล่อยสำรอง',
            ),
          ),
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
                        Text(
                          _action == 'reserve' ? 'สำรองสินค้า' : 'ปล่อยสำรอง',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.productName,
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
                    'การดำเนินการ',
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
                            ButtonSegment(
                              label: Text('สำรอง'),
                              value: 'reserve',
                              icon: Icon(Icons.lock),
                            ),
                            ButtonSegment(
                              label: Text('ปล่อย'),
                              value: 'release',
                              icon: Icon(Icons.lock_open),
                            ),
                          ],
                          selected: {_action},
                          onSelectionChanged: (value) {
                            setState(() => _action = value.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Available quantity info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'พร้อมใช้',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          widget.availableQuantity.toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity input
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _action == 'reserve'
                          ? 'จำนวนที่ต้องการสำรอง'
                          : 'จำนวนที่ต้องการปล่อย',
                      border: const OutlineInputBorder(),
                      suffixText: 'หน่วย',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Order ID (optional)
                  TextField(
                    controller: _orderIdController,
                    decoration: const InputDecoration(
                      labelText: 'เลขที่คำสั่ง (ถ้ามี)',
                      border: OutlineInputBorder(),
                      hintText: 'เช่น POS-001, SO-001',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes (optional)
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุ (ถ้ามี)',
                      border: OutlineInputBorder(),
                      hintText: 'เช่น สำหรับลูกค้า A, ปรับปรุงสต็อก',
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
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _action == 'reserve'
                          ? Colors.orange
                          : Colors.green,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _action == 'reserve'
                                ? 'สำรองสินค้า'
                                : 'ปล่อยสำรอง',
                          ),
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
