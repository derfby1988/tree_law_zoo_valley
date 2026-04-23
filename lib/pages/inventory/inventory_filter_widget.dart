import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

//! keep new LayoutBuilder version
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
  final Set<String> highlightedWarehouseOptions;
  final Set<String> highlightedShelfOptions;
  final String searchHint;

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
    this.highlightedWarehouseOptions = const {},
    this.highlightedShelfOptions = const {},
    this.searchHint = 'ค้นหาสินค้า...',
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final dropdownPadding = const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingMd,
            vertical: AppDesignSystem.spacingSm,
          );
          final warehouseDropdown = DropdownButtonFormField<String>(
            value: selectedWarehouse,
            decoration: InputDecoration(
              labelText: 'คลังสินค้า',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
              contentPadding: dropdownPadding,
            ),
            items: warehouses
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(
                        color: highlightedWarehouseOptions.contains(e) ? Colors.green.shade700 : null,
                        fontWeight: highlightedWarehouseOptions.contains(e) ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onWarehouseChanged,
          );
          final shelfDropdown = DropdownButtonFormField<String>(
            value: selectedShelf,
            decoration: InputDecoration(
              labelText: 'ชั้นวาง',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
              contentPadding: dropdownPadding,
            ),
            items: shelves
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: TextStyle(
                        color: highlightedShelfOptions.contains(e) ? Colors.green.shade700 : null,
                        fontWeight: highlightedShelfOptions.contains(e) ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onShelfChanged,
          );

          return Padding(
            padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingMd),
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      warehouseDropdown,
                      const SizedBox(height: AppDesignSystem.spacingSm),
                      shelfDropdown,
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: warehouseDropdown),
                      const SizedBox(width: AppDesignSystem.spacingMd),
                      Expanded(child: shelfDropdown),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
