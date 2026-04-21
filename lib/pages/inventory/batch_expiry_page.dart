import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../theme/app_design_system.dart';

class BatchExpiryPage extends StatefulWidget {
  const BatchExpiryPage({super.key});

  @override
  State<BatchExpiryPage> createState() => _BatchExpiryPageState();
}

class _BatchExpiryPageState extends State<BatchExpiryPage> {
  List<Map<String, dynamic>> _expiringBatches = [];
  List<Map<String, dynamic>> _expiredBatches = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTab = 'expiring'; // 'expiring', 'expired'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        InventoryService.getExpiringBatches(daysUntilExpiry: 7),
        InventoryService.getExpiredBatches(),
      ]);

      if (!mounted) return;
      setState(() {
        _expiringBatches = results[0] as List<Map<String, dynamic>>;
        _expiredBatches = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    } else {
      final batches = _selectedTab == 'expiring' ? _expiringBatches : _expiredBatches;

      content = Column(
        children: [
          // Tab selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('ใกล้หมด (${_expiringBatches.length})'),
                    selected: _selectedTab == 'expiring',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'expiring');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('หมดอายุแล้ว (${_expiredBatches.length})'),
                    selected: _selectedTab == 'expired',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'expired');
                    },
                  ),
                ),
              ],
            ),
          ),

          // Batches list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: batches.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: batches.length,
                      itemBuilder: (context, index) {
                        final batch = batches[index];
                        return _buildBatchCard(batch);
                      },
                    ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ติดตามวันหมดอายุ'),
        elevation: 0,
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildEmptyState() {
    final message = _selectedTab == 'expiring'
        ? 'ไม่มีล็อตที่ใกล้หมดอายุ'
        : 'ไม่มีล็อตที่หมดอายุแล้ว';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedTab == 'expiring'
                    ? Icons.check_circle
                    : Icons.delete_outline,
                size: 64,
                color: _selectedTab == 'expiring'
                    ? Colors.green.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    final productName = batch['product']?['name']?.toString() ?? 'Unknown';
    final productCode = batch['product']?['code']?.toString() ?? '';
    final batchNumber = batch['batch_number']?.toString() ?? 'Unknown';
    final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0;
    final expiryDate = batch['expiry_date']?.toString();

    final now = DateTime.now();
    DateTime? expiry;
    int? daysUntilExpiry;
    Color statusColor = Colors.orange;
    String statusLabel = 'ใกล้หมด';

    if (expiryDate != null) {
      expiry = DateTime.parse(expiryDate);
      daysUntilExpiry = expiry.difference(now).inDays;

      if (daysUntilExpiry < 0) {
        statusColor = Colors.red;
        statusLabel = 'หมดอายุแล้ว';
      } else if (daysUntilExpiry == 0) {
        statusColor = Colors.red;
        statusLabel = 'วันนี้หมดอายุ';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'รหัส: $productCode | ล็อต: $batchNumber',
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
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 12),

            // Expiry info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'หมดอายุ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(expiryDate ?? ''),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'จำนวน',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quantity.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (daysUntilExpiry != null && daysUntilExpiry >= 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เหลือ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$daysUntilExpiry วัน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Action buttons
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_selectedTab == 'expiring')
                  ElevatedButton.icon(
                    onPressed: () => _showMarkAsExpiredDialog(batch),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('ทำเครื่องหมาย'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMarkAsExpiredDialog(Map<String, dynamic> batch) async {
    final batchId = batch['id']?.toString();
    if (batchId == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ทำเครื่องหมายหมดอายุ'),
        content: const Text('ยืนยันการทำเครื่องหมายล็อตนี้เป็นหมดอายุ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await InventoryService.markBatchAsExpired(
          batchId: batchId,
        );

        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ทำเครื่องหมายสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่สามารถทำเครื่องหมาย')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
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
