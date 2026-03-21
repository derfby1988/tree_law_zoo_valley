import 'package:flutter/material.dart';
import '../../../services/procurement_service.dart';
import '../../../services/permission_service.dart';

/// Dialog สำหรับอนุมัติ PO (Sent → Confirmed)
class ApprovePODialog extends StatefulWidget {
  final Map<String, dynamic> purchaseOrder;
  final String currentUserId;
  final String userRole;

  const ApprovePODialog({
    super.key,
    required this.purchaseOrder,
    required this.currentUserId,
    required this.userRole,
  });

  @override
  State<ApprovePODialog> createState() => _ApprovePODialogState();
}

class _ApprovePODialogState extends State<ApprovePODialog> {
  bool _isLoading = false;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _approvePO() async {
    setState(() => _isLoading = true);

    final totalAmount = (widget.purchaseOrder['total_amount'] as num?)?.toDouble() ?? 0.0;
    
    final result = await ProcurementService.approvePurchaseOrder(
      widget.purchaseOrder['id'],
      widget.currentUserId,
      widget.userRole,
      totalAmount,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      // Show error but don't close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'ไม่สามารถอนุมัติ PO ได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectPO() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุเหตุผลในการปฏิเสธ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Cancel the PO with rejection reason
    final success = await ProcurementService.cancelPurchaseOrder(
      widget.purchaseOrder['id'],
      widget.currentUserId,
      'ปฏิเสธ: ${_reasonController.text.trim()}',
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ปฏิเสธ PO สำเร็จ'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถปฏิเสธ PO ได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getApprovalLimit() {
    switch (widget.userRole) {
      case 'store_manager':
        return '5,000';
      case 'manager':
        return '50,000';
      case 'admin':
        return 'ไม่จำกัด';
      default:
        return '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = widget.purchaseOrder['order_number'] ?? 'N/A';
    final supplier = widget.purchaseOrder['supplier']?['name'] ?? 'ไม่ระบุ';
    final totalAmount = (widget.purchaseOrder['total_amount'] as num?)?.toDouble() ?? 0.0;
    final lines = widget.purchaseOrder['lines'] as List<dynamic>? ?? [];

    final canApprove = PermissionService.canAccessActionSync('procurement_purchase_approve_5000') ||
        PermissionService.canAccessActionSync('procurement_purchase_approve_50000') ||
        PermissionService.canAccessActionSync('procurement_purchase_approve_unlimited');

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700]),
          const SizedBox(width: 8),
          const Text('อนุมัติใบสั่งซื้อ'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PO Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('เลขที่ PO:', orderNumber),
                  _buildInfoRow('ผู้ขาย:', supplier),
                  _buildInfoRow('จำนวนรายการ:', '${lines.length} รายการ'),
                  const Divider(),
                  _buildInfoRow(
                    'ยอดรวม:',
                    '${totalAmount.toStringAsFixed(2)} บาท',
                    valueStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Approval Limit Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'วงเงินอนุมัติของคุณ: ${_getApprovalLimit()} บาท',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items List
            if (lines.isNotEmpty) ...[
              Text(
                'รายการสินค้า:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lines.length,
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    return _buildLineItem(line);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rejection Reason
            Text(
              'หมายเหตุ (กรณีปฏิเสธ):',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'ระบุเหตุผล...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(null),
          child: const Text('ยกเลิก'),
        ),
        if (canApprove) ...[
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _rejectPO,
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
                : const Icon(Icons.close),
            label: const Text('ปฏิเสธ'),
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _approvePO,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: const Text('อนุมัติ'),
          ),
        ] else ...[
          Text(
            'คุณไม่มีสิทธิ์อนุมัติ PO นี้',
            style: TextStyle(color: Colors.red[700], fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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
              style: valueStyle ?? const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(Map<String, dynamic> line) {
    final productName = line['product_name'] ?? 'ไม่ระบุ';
    final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
    final unitPrice = (line['unit_price'] as num?)?.toDouble() ?? 0;
    final lineTotal = (line['line_total'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              productName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${quantity.toStringAsFixed(0)} x ${unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              lineTotal.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
