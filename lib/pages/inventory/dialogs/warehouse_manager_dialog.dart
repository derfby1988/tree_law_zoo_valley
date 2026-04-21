import 'package:flutter/material.dart';

/// Dialog สำหรับกำหนดผู้ดูแลคลัง โดยเชื่อมกับตาราง users จริง
Future<Map<String, String?>?> showWarehouseManagerDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> warehouses,
  required List<Map<String, dynamic>> users,
  String? initialWarehouseId,
  String? initialManagerId,
}) async {
  String? warehouseId = initialWarehouseId ?? (warehouses.isNotEmpty ? warehouses.first['id']?.toString() : null);
  String? managerId = initialManagerId;

  if (warehouses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ยังไม่มีคลังให้กำหนดผู้ดูแล')),
    );
    return null;
  }

  return showDialog<Map<String, String?>?>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final managerOptions = users
              .map((user) {
                final id = user['id']?.toString();
                final displayName =
                    user['full_name']?.toString().trim().isNotEmpty == true
                        ? user['full_name'].toString()
                        : (user['username']?.toString() ?? user['email']?.toString() ?? '-');
                if (id == null) return null;
                return DropdownMenuItem<String?>(value: id, child: Text(displayName));
              })
              .whereType<DropdownMenuItem<String?>>()
              .toList();

          return AlertDialog(
            title: const Text('กำหนดผู้ดูแลคลัง'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  value: warehouseId,
                  items: warehouses
                      .map((warehouse) {
                        final id = warehouse['id']?.toString();
                        if (id == null) return null;
                        return DropdownMenuItem<String?>(
                          value: id,
                          child: Text(warehouse['name']?.toString() ?? 'ไม่ระบุ'),
                        );
                      })
                      .whereType<DropdownMenuItem<String?>>()
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'เลือกคลัง',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => warehouseId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: managerId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ไม่ระบุผู้ดูแล')),
                    ...managerOptions,
                  ],
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'ผู้ดูแลคลัง',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => managerId = value),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'แสดงรายชื่อจากตาราง users โดยตรง หากไม่มีข้อมูลให้เพิ่มผู้ใช้ก่อน',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: warehouseId == null
                    ? null
                    : () => Navigator.of(context).pop({
                          'warehouseId': warehouseId,
                          'managerId': managerId,
                        }),
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      );
    },
  );
}
