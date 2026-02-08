import 'package:flutter/material.dart';
import '../services/permission_service.dart';

/// Helper สำหรับตรวจสอบสิทธิ์ก่อนทำ action
/// ใช้ครอบปุ่มทุกปุ่มที่ต้องตรวจสอบสิทธิ์
///
/// ตัวอย่าง:
/// ```dart
/// ElevatedButton(
///   onPressed: () => checkPermissionAndExecute(
///     context,
///     'inventory_products_save',
///     'บันทึกสินค้า',
///     () => _saveProduct(),
///   ),
///   child: Text('บันทึก'),
/// )
/// ```
Future<void> checkPermissionAndExecute(
  BuildContext context,
  String actionId,
  String actionName,
  VoidCallback onExecute,
) async {
  final canAccess = await PermissionService.canAccessAction(actionId);
  if (!canAccess) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('คุณไม่มีสิทธิ์$actionName'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }
  onExecute();
}
