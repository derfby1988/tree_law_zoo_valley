import 'package:flutter/material.dart';

class InventoryFilterWidget extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedWarehouse;
  final String selectedShelf;
  final ValueChanged<String?> onWarehouseChanged;
  final ValueChanged<String?> onShelfChanged;
  final List<String>? warehouseOptions;
  final List<String>? shelfOptions;

  const InventoryFilterWidget({
    super.key,
    required this.searchController,
    required this.selectedWarehouse,
    required this.selectedShelf,
    required this.onWarehouseChanged,
    required this.onShelfChanged,
    this.warehouseOptions,
    this.shelfOptions,
  });

  @override
  Widget build(BuildContext context) {
    final warehouses = warehouseOptions ?? ['ทั้งหมด', 'คลังหลัก', 'คลังสำรอง', 'คลังครัว'];
    final shelves = shelfOptions ?? ['ทั้งหมด', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'C3', 'D1', 'D2', 'E1'];

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedWarehouse,
                    decoration: InputDecoration(
                      labelText: 'คลังสินค้า',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: warehouses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: onWarehouseChanged,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedShelf,
                    decoration: InputDecoration(
                      labelText: 'ชั้นวาง',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
