import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../theme/app_design_system.dart';

/// Widget แสดงข้อมูลสต็อกรวมทั้งหมด
class ConsolidatedInventoryWidget extends StatefulWidget {
  const ConsolidatedInventoryWidget({super.key});

  @override
  State<ConsolidatedInventoryWidget> createState() => _ConsolidatedInventoryWidgetState();
}

class _ConsolidatedInventoryWidgetState extends State<ConsolidatedInventoryWidget> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'name'; // name, quantity, value

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        InventoryService.getConsolidatedSummary(),
        InventoryService.getConsolidatedInventory(),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>?;
        _inventory = results[1] as List<Map<String, dynamic>>;
        _sortInventory();
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

  void _sortInventory() {
    switch (_sortBy) {
      case 'quantity':
        _inventory.sort((a, b) {
          final aQty = (a['quantity'] as num?)?.toDouble() ?? 0;
          final bQty = (b['quantity'] as num?)?.toDouble() ?? 0;
          return bQty.compareTo(aQty);
        });
        break;
      case 'value':
        _inventory.sort((a, b) {
          final aVal = ((a['quantity'] as num?)?.toDouble() ?? 0) * ((a['price'] as num?)?.toDouble() ?? 0);
          final bVal = ((b['quantity'] as num?)?.toDouble() ?? 0) * ((b['price'] as num?)?.toDouble() ?? 0);
          return bVal.compareTo(aVal);
        });
        break;
      case 'name':
      default:
        _inventory.sort((a, b) {
          final aName = a['name']?.toString() ?? '';
          final bName = b['name']?.toString() ?? '';
          return aName.compareTo(bName);
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
            ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary cards
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSummaryCards(),
            ),

          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('ชื่อ'),
                  selected: _sortBy == 'name',
                  onSelected: (selected) {
                    setState(() => _sortBy = 'name');
                    _sortInventory();
                  },
                ),
                FilterChip(
                  label: const Text('จำนวน'),
                  selected: _sortBy == 'quantity',
                  onSelected: (selected) {
                    setState(() => _sortBy = 'quantity');
                    _sortInventory();
                  },
                ),
                FilterChip(
                  label: const Text('มูลค่า'),
                  selected: _sortBy == 'value',
                  onSelected: (selected) {
                    setState(() => _sortBy = 'value');
                    _sortInventory();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Inventory list
          if (_inventory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'ไม่มีข้อมูลสต็อก',
                  style: TextStyle(color: AppDesignSystem.textSecondary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _inventory.length,
              itemBuilder: (context, index) {
                final product = _inventory[index];
                return _buildProductCard(product);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _summary!;
    final productCount = (summary['product_count'] as num?)?.toInt() ?? 0;
    final totalQty = (summary['total_quantity'] as num?)?.toDouble() ?? 0;
    final availableQty = (summary['available_quantity'] as num?)?.toDouble() ?? 0;
    final reservedQty = (summary['reserved_quantity'] as num?)?.toDouble() ?? 0;
    final totalValue = (summary['total_value'] as num?)?.toDouble() ?? 0;
    final avgPrice = (summary['average_price'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'สินค้าทั้งหมด',
                value: '$productCount',
                icon: Icons.inventory_2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'จำนวนรวม',
                value: totalQty.toStringAsFixed(2),
                icon: Icons.shopping_cart,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'มูลค่ารวม',
                value: '฿${totalValue.toStringAsFixed(0)}',
                icon: Icons.attach_money,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'พร้อมใช้',
                value: availableQty.toStringAsFixed(2),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'สำรองไว้',
                value: reservedQty.toStringAsFixed(2),
                icon: Icons.lock,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'ราคาเฉลี่ย',
                value: '฿${avgPrice.toStringAsFixed(2)}',
                icon: Icons.trending_up,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? 'Unknown';
    final code = product['code']?.toString() ?? '';
    final quantity = (product['quantity'] as num?)?.toDouble() ?? 0;
    final reserved = (product['reserved_quantity'] as num?)?.toDouble() ?? 0;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final warehouseName = product['warehouse']?['name']?.toString() ?? 'Unknown';
    final warehouseCode = product['warehouse']?['code']?.toString() ?? '';

    final available = quantity - reserved;
    final value = quantity * price;
    final reservedPct = quantity > 0 ? (reserved / quantity * 100) : 0;

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
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'รหัส: $code | คลัง: $warehouseCode',
                        style: TextStyle(
                          fontSize: 10,
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
                    color: AppDesignSystem.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '฿${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quantity info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รวม',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                    Text(
                      quantity.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'พร้อมใช้',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                    Text(
                      available.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สำรอง',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                    Text(
                      reserved.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'มูลค่า',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                    Text(
                      '฿${value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Reserved percentage bar
            if (reserved > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: reservedPct / 100,
                  minHeight: 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
