import 'package:flutter/material.dart';
import '../../../services/procurement_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_design_system.dart';

class ProcurementIntegrationPanel extends StatefulWidget {
  final String productId;
  final String productName;

  const ProcurementIntegrationPanel({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProcurementIntegrationPanel> createState() => _ProcurementIntegrationPanelState();
}

class _ProcurementIntegrationPanelState extends State<ProcurementIntegrationPanel> {
  List<Map<String, dynamic>> _purchaseOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPurchaseOrders();
  }

  Future<void> _loadPurchaseOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allOrders = await ProcurementService.getPurchaseOrdersWithLines();
      final filteredOrders = allOrders.where((order) {
        final lines = order['lines'] as List? ?? [];
        return lines.any((line) => line['product_id'] == widget.productId);
      }).toList();

      if (!mounted) return;
      setState(() {
        _purchaseOrders = filteredOrders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลด PO: $e';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'partial_received':
        return Colors.amber;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'ร่าง';
      case 'sent':
        return 'ส่งแล้ว';
      case 'confirmed':
        return 'อนุมัติแล้ว';
      case 'partial_received':
        return 'รับบางส่วน';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.canAccessTabSync('procurement_purchase')) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
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
                Text(
                  'ประวัติการสั่งซื้อ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadPurchaseOrders,
                  tooltip: 'รีเฟรช',
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppDesignSystem.danger, fontSize: 12),
                ),
              )
            else if (_purchaseOrders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingMd),
                  child: Text(
                    'ไม่มีการสั่งซื้อสินค้านี้',
                    style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _purchaseOrders.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final po = _purchaseOrders[index];
                  final status = po['status']?.toString() ?? 'unknown';
                  final orderNumber = po['order_number']?.toString() ?? '-';
                  final orderDate = DateTime.tryParse(po['order_date']?.toString() ?? '');
                  final totalAmount = (po['total_amount'] as num?)?.toDouble() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PO: $orderNumber',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    orderDate != null
                                        ? '${orderDate.day}/${orderDate.month}/${orderDate.year + 543}'
                                        : '-',
                                    style: TextStyle(
                                      color: AppDesignSystem.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusLabel(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'รวม: ฿${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppDesignSystem.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
