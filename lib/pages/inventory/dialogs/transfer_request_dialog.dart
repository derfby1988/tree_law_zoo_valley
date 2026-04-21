import 'package:flutter/material.dart';

import '../../../theme/app_design_system.dart';

Future<Map<String, dynamic>?> showTransferRequestDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> warehouses,
  required List<Map<String, dynamic>> shelves,
}) async {
  final formKey = GlobalKey<FormState>();
  String? selectedProductId;
  String? sourceWarehouseId;
  String? targetWarehouseId;
  String? sourceShelfId;
  String? targetShelfId;
  final quantityController = TextEditingController();
  final reasonController = TextEditingController();
  final noteController = TextEditingController();

  List<Map<String, dynamic>> _shelvesFor(String? warehouseId) {
    if (warehouseId == null) return [];
    return shelves.where((s) => s['warehouse_id']?.toString() == warehouseId).toList();
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('สร้างคำขอโอนสินค้า'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'สินค้า'),
                      items: products.map((product) {
                        final name = product['name']?.toString() ?? 'ไม่ระบุ';
                        return DropdownMenuItem(value: product['id']?.toString(), child: Text(name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedProductId = value),
                      validator: (value) => value == null ? 'กรุณาเลือกสินค้า' : null,
                    ),
                    const SizedBox(height: AppDesignSystem.spacingSm),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'คลังต้นทาง'),
                      items: warehouses.map((warehouse) {
                        return DropdownMenuItem(value: warehouse['id']?.toString(), child: Text(warehouse['name']?.toString() ?? '-'));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          sourceWarehouseId = value;
                          sourceShelfId = null;
                        });
                      },
                      validator: (value) => value == null ? 'กรุณาเลือกคลังต้นทาง' : null,
                    ),
                    if (sourceWarehouseId != null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'ชั้นวางต้นทาง'),
                        items: _shelvesFor(sourceWarehouseId).map((shelf) {
                          final code = shelf['code']?.toString() ?? shelf['name']?.toString() ?? 'ไม่ระบุ';
                          return DropdownMenuItem(value: shelf['id']?.toString(), child: Text(code));
                        }).toList(),
                        onChanged: (value) => setState(() => sourceShelfId = value),
                      ),
                    const SizedBox(height: AppDesignSystem.spacingSm),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'คลังปลายทาง'),
                      items: warehouses.map((warehouse) {
                        return DropdownMenuItem(value: warehouse['id']?.toString(), child: Text(warehouse['name']?.toString() ?? '-'));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          targetWarehouseId = value;
                          targetShelfId = null;
                        });
                      },
                      validator: (value) => value == null ? 'กรุณาเลือกคลังปลายทาง' : null,
                    ),
                    if (targetWarehouseId != null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'ชั้นวางปลายทาง'),
                        items: _shelvesFor(targetWarehouseId).map((shelf) {
                          final code = shelf['code']?.toString() ?? shelf['name']?.toString() ?? 'ไม่ระบุ';
                          return DropdownMenuItem(value: shelf['id']?.toString(), child: Text(code));
                        }).toList(),
                        onChanged: (value) => setState(() => targetShelfId = value),
                      ),
                    const SizedBox(height: AppDesignSystem.spacingSm),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'จำนวน'),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) return 'กรุณากรอกจำนวนที่มากกว่า 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDesignSystem.spacingSm),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(labelText: 'เหตุผล (ไม่บังคับ)'),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingSm),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'หมายเหตุเพิ่มเติม'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('ส่งคำขอ'),
          ),
        ],
      );
    },
  );

  if (result != true) {
    return null;
  }

  return {
    'productId': selectedProductId,
    'sourceWarehouseId': sourceWarehouseId,
    'sourceShelfId': sourceShelfId,
    'targetWarehouseId': targetWarehouseId,
    'targetShelfId': targetShelfId,
    'quantity': double.tryParse(quantityController.text.trim()) ?? 0,
    'reason': reasonController.text.trim(),
    'note': noteController.text.trim(),
  };
}
