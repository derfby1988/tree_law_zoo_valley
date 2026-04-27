import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

//! keep new LayoutBuilder version

/// ข้อมูลจำนวนสำหรับแสดงใน dropdown
class DropdownCountInfo {
  final int productCount;
  final int ingredientCount;

  const DropdownCountInfo({
    this.productCount = 0,
    this.ingredientCount = 0,
  });

  int get total => productCount + ingredientCount;
}

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
  // ✅ ข้อมูลจำนวนสินค้า/วัตถุดิบสำหรับแต่ละตัวเลือก
  final Map<String, DropdownCountInfo>? warehouseCounts;
  final Map<String, DropdownCountInfo>? shelfCounts;

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
    this.searchHint = 'ค้นหาสินค้า',
    this.warehouseCounts,
    this.shelfCounts,
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
            menuMaxHeight: 320, // ✅ แสดง ~10 รายการ + scrollbar
            items: warehouses
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: _buildCountItem(
                      label: e,
                      countInfo: warehouseCounts?[e],
                      isHighlighted: highlightedWarehouseOptions.contains(e),
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
            menuMaxHeight: 320, // ✅ แสดง ~10 รายการ + scrollbar
            items: shelves
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: _buildCountItem(
                      label: e,
                      countInfo: shelfCounts?[e],
                      isHighlighted: highlightedShelfOptions.contains(e),
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
                // ✅ แสดงจำนวนรวมที่เลือก (ถ้ามี)
                if (warehouseCounts != null || shelfCounts != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2, size: 12, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'สินค้า',
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_dining, size: 12, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'วัตถุดิบ',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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

  /// ✅ สร้าง widget แสดงชื่อ + จำนวนสินค้า/วัตถุดิบ
  Widget _buildCountItem({
    required String label,
    DropdownCountInfo? countInfo,
    required bool isHighlighted,
  }) {
    if (countInfo == null || countInfo.total == 0) {
      return Text(
        label,
        style: TextStyle(
          color: isHighlighted ? Colors.green.shade700 : null,
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isHighlighted ? Colors.green.shade700 : null,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // จำนวนสินค้า (สีน้ำเงิน)
        if (countInfo.productCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${countInfo.productCount}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        // จำนวนวัตถุดิบ (สีส้ม)
        if (countInfo.ingredientCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${countInfo.ingredientCount}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
