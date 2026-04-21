import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../theme/app_design_system.dart';
import 'widgets/consolidated_inventory_widget.dart';

class MultiWarehousePage extends StatefulWidget {
  const MultiWarehousePage({super.key});

  @override
  State<MultiWarehousePage> createState() => _MultiWarehousePageState();
}

class _MultiWarehousePageState extends State<MultiWarehousePage> {
  List<Map<String, dynamic>> _warehouseData = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTab = 'consolidated'; // consolidated, by-warehouse, transfers

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
      final warehouses = await InventoryService.getWarehouses();
      final warehouseData = <Map<String, dynamic>>[];

      for (final warehouse in warehouses) {
        final warehouseId = warehouse['id']?.toString();
        if (warehouseId == null) continue;

        final inventory = await InventoryService.getInventoryByWarehouse(
          warehouseId: warehouseId,
        );

        warehouseData.add({
          ...warehouse,
          'inventory': inventory,
        });
      }

      if (!mounted) return;
      setState(() {
        _warehouseData = warehouseData;
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
      content = Column(
        children: [
          // Tab selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('รวมทั้งหมด'),
                    selected: _selectedTab == 'consolidated',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'consolidated');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('แยกตามคลัง'),
                    selected: _selectedTab == 'by-warehouse',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'by-warehouse');
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _selectedTab == 'consolidated'
                  ? const ConsolidatedInventoryWidget()
                  : _buildWarehouseView(),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ซิงค์สต็อกหลายคลัง'),
        elevation: 0,
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildWarehouseView() {
    if (_warehouseData.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store,
                  size: 64,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ไม่มีข้อมูลคลัง',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _warehouseData.length,
      itemBuilder: (context, index) {
        final warehouse = _warehouseData[index];
        return _buildWarehouseCard(warehouse);
      },
    );
  }

  Widget _buildWarehouseCard(Map<String, dynamic> warehouse) {
    final warehouseName = warehouse['name']?.toString() ?? 'Unknown';
    final warehouseCode = warehouse['code']?.toString() ?? '';
    final inventory = warehouse['inventory'] as Map<String, dynamic>? ?? {};
    final productCount = (inventory['product_count'] as num?)?.toInt() ?? 0;
    final totalQty = (inventory['total_quantity'] as num?)?.toDouble() ?? 0;
    final totalValue = (inventory['total_value'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              warehouseName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'รหัส: $warehouseCode',
              style: TextStyle(
                fontSize: 11,
                color: AppDesignSystem.textSecondary,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$productCount สินค้า',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '${totalQty.toStringAsFixed(2)} หน่วย',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '฿${totalValue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildWarehouseDetails(inventory),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseDetails(Map<String, dynamic> inventory) {
    final products = (inventory['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (products.isEmpty) {
      return Center(
        child: Text(
          'ไม่มีสินค้า',
          style: TextStyle(color: AppDesignSystem.textSecondary),
        ),
      );
    }

    return Column(
      children: List.generate(
        products.length,
        (index) {
          final product = products[index];
          final name = product['name']?.toString() ?? 'Unknown';
          final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
          final price = (product['price'] as num?)?.toDouble() ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${qty.toStringAsFixed(2)} x ฿${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
