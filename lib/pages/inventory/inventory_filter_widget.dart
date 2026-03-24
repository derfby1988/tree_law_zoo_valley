import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

class InventoryFilterWidget extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedWarehouse;
  final String selectedShelf;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<String?> onShelfChanged;
  final List<String>? warehouseOptions;
  final List<String>? shelfOptions;
  final bool showNoWarehouseOption;
  final bool showNoShelfOption;

  const InventoryFilterWidget({
    super.key,
    required this.searchController,
    required this.selectedWarehouse,
    required this.selectedShelf,
    required this.onWarehouseChanged,
    required this.onShelfChanged,
    this.warehouseOptions,
    this.shelfOptions,
    this.showNoWarehouseOption = false,
    this.showNoShelfOption = false,
  });

  @override
  Widget build(BuildContext context) {
    var warehouses = warehouseOptions ?? ['ทั้งหมด'];
    var shelves = shelfOptions ?? ['ทั้งหมด'];
    
    // เพิ่มตัวเลือกพิเศษ
    if (showNoWarehouseOption && !warehouses.contains('ยังไม่มีคลัง')) {
      warehouses = [...warehouses, 'ยังไม่มีคลัง'];
    }
    if (showNoShelfOption && !shelves.contains('ยังไม่มีชั้นวาง')) {
      shelves = [...shelves, 'ยังไม่มีชั้นวาง'];
    }

    return Card(
      elevation: 0,
      color: AppDesignSystem.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedWarehouse,
                    decoration: InputDecoration(
                      labelText: 'คลังสินค้า',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingSm),
                    ),
                    items: warehouses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: onWarehouseChanged,
                  ),
                ),
                const SizedBox(width: AppDesignSystem.spacingMd),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedShelf,
                    decoration: InputDecoration(
                      labelText: 'ชั้นวาง',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingMd, vertical: AppDesignSystem.spacingSm),
                    ),
                    items: shelves.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: onShelfChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
