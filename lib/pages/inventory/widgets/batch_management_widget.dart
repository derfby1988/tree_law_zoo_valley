import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../theme/app_design_system.dart';

/// Widget สำหรับจัดการล็อตสินค้า
class BatchManagementWidget extends StatefulWidget {
  final String productId;
  final String productName;
  final VoidCallback? onRefresh;

  const BatchManagementWidget({
    super.key,
    required this.productId,
    required this.productName,
    this.onRefresh,
  });

  @override
  State<BatchManagementWidget> createState() => _BatchManagementWidgetState();
}

class _BatchManagementWidgetState extends State<BatchManagementWidget> {
  List<Map<String, dynamic>> _batches = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String? _error;
  String _filterBy = 'all'; // all, active, expiring, expired

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        InventoryService.getBatches(productId: widget.productId),
        InventoryService.getBatchSummary(productId: widget.productId),
      ]);

      if (!mounted) return;
      setState(() {
        _batches = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, dynamic>?;
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

  List<Map<String, dynamic>> _getFilteredBatches() {
    final now = DateTime.now();
    switch (_filterBy) {
      case 'active':
        return _batches.where((b) {
          final isExpired = b['is_expired'] == true;
          return !isExpired;
        }).toList();
      case 'expiring':
        return _batches.where((b) {
          final isExpired = b['is_expired'] == true;
          if (isExpired) return false;
          final expiryDate = b['expiry_date']?.toString();
          if (expiryDate == null) return false;
          final expiry = DateTime.parse(expiryDate);
          return expiry.isBefore(now.add(const Duration(days: 7)));
        }).toList();
      case 'expired':
        return _batches.where((b) => b['is_expired'] == true).toList();
      case 'all':
      default:
        return _batches;
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
            ElevatedButton(onPressed: _loadBatches, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final filteredBatches = _getFilteredBatches();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSummaryCard(),
            ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('ทั้งหมด'),
                  selected: _filterBy == 'all',
                  onSelected: (selected) {
                    setState(() => _filterBy = 'all');
                  },
                ),
                FilterChip(
                  label: const Text('ใช้ได้'),
                  selected: _filterBy == 'active',
                  onSelected: (selected) {
                    setState(() => _filterBy = 'active');
                  },
                ),
                FilterChip(
                  label: const Text('ใกล้หมด'),
                  selected: _filterBy == 'expiring',
                  onSelected: (selected) {
                    setState(() => _filterBy = 'expiring');
                  },
                ),
                FilterChip(
                  label: const Text('หมดอายุ'),
                  selected: _filterBy == 'expired',
                  onSelected: (selected) {
                    setState(() => _filterBy = 'expired');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Batches list
          if (filteredBatches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'ไม่มีล็อตสินค้า',
                  style: TextStyle(
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredBatches.length,
              itemBuilder: (context, index) {
                final batch = filteredBatches[index];
                return _buildBatchCard(batch);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _summary!;
    final totalBatches = (summary['total_batches'] as num?)?.toInt() ?? 0;
    final expiredBatches = (summary['expired_batches'] as num?)?.toInt() ?? 0;
    final expiringBatches = (summary['expiring_soon_batches'] as num?)?.toInt() ?? 0;
    final totalQty = (summary['total_quantity'] as num?)?.toDouble() ?? 0;
    final expiredQty = (summary['expired_quantity'] as num?)?.toDouble() ?? 0;
    final availableQty = (summary['available_quantity'] as num?)?.toDouble() ?? 0;
    final riskPct = (summary['expiry_risk_percentage'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignSystem.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปล็อตสินค้า',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('ล็อตทั้งหมด', '$totalBatches'),
              _buildSummaryItem('ใช้ได้', availableQty.toStringAsFixed(2)),
              _buildSummaryItem('หมดอายุ', expiredQty.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 12),
          if (expiringBatches > 0 || expiredBatches > 0)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'เสี่ยง: $expiringBatches ใกล้หมด, $expiredBatches หมดอายุแล้ว (${riskPct.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppDesignSystem.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    final batchNumber = batch['batch_number']?.toString() ?? 'Unknown';
    final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0;
    final expiryDate = batch['expiry_date']?.toString();
    final isExpired = batch['is_expired'] == true;
    final notes = batch['notes']?.toString();

    final now = DateTime.now();
    DateTime? expiry;
    int? daysUntilExpiry;
    Color statusColor = Colors.green;
    String statusLabel = 'ใช้ได้';

    if (expiryDate != null) {
      expiry = DateTime.parse(expiryDate);
      daysUntilExpiry = expiry.difference(now).inDays;

      if (isExpired) {
        statusColor = Colors.red;
        statusLabel = 'หมดอายุ';
      } else if (daysUntilExpiry < 0) {
        statusColor = Colors.red;
        statusLabel = 'หมดอายุ';
      } else if (daysUntilExpiry <= 7) {
        statusColor = Colors.orange;
        statusLabel = 'ใกล้หมด';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ล็อต: $batchNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'จำนวน: ${quantity.toStringAsFixed(2)} หน่วย',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            if (expiryDate != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'หมดอายุ: ${_formatDate(expiryDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (daysUntilExpiry != null && daysUntilExpiry >= 0)
                    Text(
                      'อีก $daysUntilExpiry วัน',
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                ],
              ),
            ],

            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'หมายเหตุ: $notes',
                style: TextStyle(
                  fontSize: 11,
                  color: AppDesignSystem.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year + 543}';
    } catch (e) {
      return dateString;
    }
  }
}
