import 'package:flutter/material.dart';

/// Dialog แบบ reusable สำหรับเพิ่ม/แก้ไขคลังสินค้า
Future<Map<String, dynamic>?> showWarehouseFormDialog({
  required BuildContext context,
  required String title,
  required String submitLabel,
  List<Map<String, dynamic>>? users,
  String? initialName,
  String? initialLocation,
  String? initialManagerId,
  bool initialIsActive = true,
  int? initialCapacityLimit,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: initialName ?? '');
  final locationController = TextEditingController(text: initialLocation ?? '');
  final capacityController = TextEditingController(text: initialCapacityLimit?.toString() ?? '');
  String? managerId = initialManagerId;
  bool isActive = initialIsActive;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อคลัง *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณากรอกชื่อคลัง';
                    }
                    if (value.trim().length < 2) {
                      return 'ชื่อคลังต้องมีความยาวอย่างน้อย 2 ตัวอักษร';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'สถานที่ / อ้างอิง',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ขีดจำกัดความจุ (หน่วย)',
                    border: OutlineInputBorder(),
                    helperText: 'ปล่อยว่างหรือ 0 = ไม่จำกัด',
                  ),
                ),
                if (users != null && users.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: managerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'ผู้ดูแลคลัง',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
                      ...users.map((user) {
                        final id = user['id']?.toString();
                        final displayName =
                            user['full_name']?.toString().trim().isNotEmpty == true
                                ? user['full_name'].toString()
                                : (user['username']?.toString() ?? user['email']?.toString() ?? '-');
                        if (id == null) return null;
                        return DropdownMenuItem<String?>(value: id, child: Text(displayName));
                      }).whereType<DropdownMenuItem<String?>>(),
                    ],
                    onChanged: (value) => managerId = value,
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: isActive,
                  onChanged: (value) => isActive = value,
                  title: const Text('สถานะคลัง (ใช้งานอยู่)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'location': locationController.text.trim(),
                'managerId': managerId,
                'isActive': isActive,
                'capacityLimit': int.tryParse(capacityController.text.trim()),
              });
            },
            child: Text(submitLabel),
          ),
        ],
      );
    },
  );

  nameController.dispose();
  locationController.dispose();
  capacityController.dispose();
  return result;
}
