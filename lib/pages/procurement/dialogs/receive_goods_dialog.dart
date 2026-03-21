import 'package:flutter/material.dart';
import '../../../services/procurement_service.dart';

/// Dialog สำหรับรับสินค้า PO (Confirmed → Partial/Completed)
class ReceiveGoodsDialog extends StatefulWidget {
  final Map<String, dynamic> purchaseOrder;
  final String? currentUserId;

  const ReceiveGoodsDialog({
    super.key,
    required this.purchaseOrder,
    this.currentUserId,
  });

  @override
  State<ReceiveGoodsDialog> createState() => _ReceiveGoodsDialogState();
}

class _ReceiveGoodsDialogState extends State<ReceiveGoodsDialog> {
  bool _isLoading = false;
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, double> _originalQuantities = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final lines = widget.purchaseOrder['lines'] as List<dynamic>? ?? [];
    for (final line in lines) {
      final lineId = line['id'] as String?;
      final productId = line['product_id'] as String?;
      final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
      final receivedQty = (line['received_quantity'] as num?)?.toDouble() ?? 0;
      final remainingQty = quantity - receivedQty;

      if (lineId != null && productId != null) {
        _quantityControllers[lineId] = TextEditingController(
          text: remainingQty > 0 ? remainingQty.toStringAsFixed(0) : '0',
        );
        _originalQuantities[lineId] = quantity;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _receiveGoods() async {
    // Validate quantities
    final receivedItems = <Map<String, dynamic>>[];
    final lines = widget.purchaseOrder['lines'] as List<dynamic>? ?? [];

    for (final line in lines) {
      final lineId = line['id'] as String?;
      final productId = line['product_id'] as String?;
      
      if (lineId == null || productId == null) continue;

      final controller = _quantityControllers[lineId];
      if (controller == null) continue;

      final receivedQty = double.tryParse(controller.text) ?? 0;
      if (receivedQty <= 0) continue;

      final originalQty = _originalQuantities[lineId] ?? 0;
      final alreadyReceived = (line['received_quantity'] as num?)?.toDouble() ?? 0;

      // Validate: cannot receive more than ordered
      if (alreadyReceived + receivedQty > originalQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถรับเกินจำนวนที่สั่งซื้อได้'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      receivedItems.add({
        'line_id': lineId,
        'product_id': productId,
        'received_quantity': alreadyReceived + receivedQty,
      });
    }

    if (receivedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุจำนวนสินค้าที่รับอย่างน้อย 1 รายการ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await ProcurementService.receivePurchaseOrder(
      widget.purchaseOrder['id'],
      receivedItems,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รับสินค้าสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถรับสินค้าได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = widget.purchaseOrder['order_number'] ?? 'N/A';
    final supplier = widget.purchaseOrder['supplier']?['name'] ?? 'ไม่ระบุ';
    final lines = widget.purchaseOrder['lines'] as List<dynamic>? ?? [];

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.inventory_2, color: Colors.orange[700]),
          const SizedBox(width: 8),
          const Text('รับสินค้า'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PO Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('เลขที่ PO:', orderNumber),
                  _buildInfoRow('ผู้ขาย:', supplier),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items to receive
            Text(
              'รายการสินค้า (ระบุจำนวนที่รับ):',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'กรอก 0 หากไม่ได้รับสินค้ารายการนั้น',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // Items List
            ...lines.map((line) => _buildReceiveItem(line)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _receiveGoods,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_isLoading ? 'กำลังบันทึก...' : 'บันทึกการรับ'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveItem(Map<String, dynamic> line) {
    final lineId = line['id'] as String?;
    final productName = line['product_name'] ?? 'ไม่ระบุ';
    final orderQty = (line['quantity'] as num?)?.toDouble() ?? 0;
    final receivedQty = (line['received_quantity'] as num?)?.toDouble() ?? 0;
    final remainingQty = orderQty - receivedQty;

    if (lineId == null || remainingQty <= 0) {
      return const SizedBox.shrink(); // Skip fully received items
    }

    final controller = _quantityControllers[lineId];
    if (controller == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            productName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'สั่ง: ${orderQty.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'รับแล้ว: ${receivedQty.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'เหลือ: ${remainingQty.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: remainingQty > 0 ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'จำนวนที่รับ',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixText: '/${remainingQty.toStringAsFixed(0)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
