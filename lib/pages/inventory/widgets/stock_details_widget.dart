import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../theme/app_design_system.dart';

/// Widget แสดงรายละเอียดสต็อก (total, reserved, available)
class StockDetailsWidget extends StatefulWidget {
  final String productId;
  final String productName;
  final bool showLogs;

  const StockDetailsWidget({
    super.key,
    required this.productId,
    required this.productName,
    this.showLogs = false,
  });

  @override
  State<StockDetailsWidget> createState() => _StockDetailsWidgetState();
}

class _StockDetailsWidgetState extends State<StockDetailsWidget> {
  Map<String, dynamic>? _stockDetails;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final details = await InventoryService.getStockDetails(widget.productId);
      List<Map<String, dynamic>> logs = [];
      
      if (widget.showLogs) {
        logs = await InventoryService.getReserveLogs(
          productId: widget.productId,
        );
      }

      if (!mounted) return;
      setState(() {
        _stockDetails = details;
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_stockDetails == null) {
      return const Center(child: Text('ไม่พบข้อมูลสต็อก'));
    }

    final total = (_stockDetails!['total_quantity'] as num?)?.toDouble() ?? 0;
    final reserved = (_stockDetails!['reserved_quantity'] as num?)?.toDouble() ?? 0;
    final available = (_stockDetails!['available_quantity'] as num?)?.toDouble() ?? 0;
    final reservedPct = (_stockDetails!['reserved_percentage'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Stock Summary Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สรุปสต็อก: ${widget.productName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // Three-column layout
                Row(
                  children: [
                    // Total Quantity
                    Expanded(
                      child: _buildStockCard(
                        title: 'รวมทั้งสิ้น',
                        value: total.toStringAsFixed(2),
                        color: Colors.blue,
                        icon: Icons.inventory_2,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Reserved Quantity
                    Expanded(
                      child: _buildStockCard(
                        title: 'สำรองไว้',
                        value: reserved.toStringAsFixed(2),
                        color: Colors.orange,
                        icon: Icons.lock,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Available Quantity
                    Expanded(
                      child: _buildStockCard(
                        title: 'พร้อมใช้',
                        value: available.toStringAsFixed(2),
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'สัดส่วนสำรอง',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${reservedPct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: reservedPct / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          reservedPct > 80
                              ? Colors.red
                              : reservedPct > 50
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Reserve Logs (if enabled)
          if (widget.showLogs && _logs.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ประวัติสำรอง/ปล่อย',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final action = log['action']?.toString() ?? 'unknown';
                      final quantity = (log['quantity'] as num?)?.toDouble() ?? 0;
                      final orderId = log['order_id']?.toString();
                      final createdAt = log['created_at']?.toString();

                      final isReserve = action == 'reserve';
                      final color = isReserve ? Colors.orange : Colors.green;
                      final icon = isReserve ? Icons.lock : Icons.lock_open;
                      final actionLabel = isReserve ? 'สำรอง' : 'ปล่อย';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$actionLabel: $quantity หน่วย',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (orderId != null)
                                      Text(
                                        'Order: $orderId',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppDesignSystem.textSecondary,
                                        ),
                                      ),
                                    if (createdAt != null)
                                      Text(
                                        _formatDate(createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppDesignSystem.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year + 543} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
