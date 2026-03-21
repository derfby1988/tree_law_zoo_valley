import 'package:flutter/material.dart';
import '../../../services/procurement_service.dart';

/// Dialog สำหรับส่ง PO (Draft → Sent)
class SendPODialog extends StatefulWidget {
  final Map<String, dynamic> purchaseOrder;
  final String? currentUserId;

  const SendPODialog({
    super.key,
    required this.purchaseOrder,
    this.currentUserId,
  });

  @override
  State<SendPODialog> createState() => _SendPODialogState();
}

class _SendPODialogState extends State<SendPODialog> {
  bool _isLoading = false;

  Future<void> _sendPO() async {
    setState(() => _isLoading = true);
    
    final success = await ProcurementService.sendPurchaseOrder(
      widget.purchaseOrder['id'],
      sentBy: widget.currentUserId,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่ง PO สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถส่ง PO ได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = widget.purchaseOrder['order_number'] ?? 'N/A';
    final supplier = widget.purchaseOrder['supplier']?['name'] ?? 'ไม่ระบุ';
    final totalAmount =
        (widget.purchaseOrder['total_amount'] as num?)?.toDouble() ?? 0.0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.send, color: Colors.blue[700]),
          const SizedBox(width: 8),
          const Text('ส่งใบสั่งซื้อ'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คุณต้องการส่ง PO นี้หรือไม่?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _buildInfoRow('เลขที่ PO:', orderNumber),
          _buildInfoRow('ผู้ขาย:', supplier),
          _buildInfoRow('ยอดรวม:', '${totalAmount.toStringAsFixed(2)} บาท'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'หลังจากส่งแล้ว PO จะเข้าสู่สถานะ "รออนุมัติ" และไม่สามารถแก้ไขได้',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _sendPO,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_isLoading ? 'กำลังส่ง...' : 'ส่ง PO'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
