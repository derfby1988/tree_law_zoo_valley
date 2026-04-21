import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showStockAlertConfigDialog({
  required BuildContext context,
  required Map<String, dynamic> product,
}) async {
  final formKey = GlobalKey<FormState>();
  final minQtyController = TextEditingController(
    text: ((product['min_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
  );
  final expiryDaysController = TextEditingController(
    text: (product['expiry_alert_days'] is int)
        ? product['expiry_alert_days'].toString()
        : (int.tryParse(product['expiry_alert_days']?.toString() ?? '') ?? 7).toString(),
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('ตั้งค่าแจ้งเตือน - ${product['name'] ?? '-'}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: minQtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'แจ้งเตือนเมื่อคงเหลือ (หน่วย) *',
                  helperText: 'ระบบจะแจ้งเตือนเมื่อคงเหลือไม่เกินค่านี้',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'กรุณากรอกจำนวนที่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: expiryDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'แจ้งเตือนก่อนหมดอายุ (วัน)',
                  helperText: '0 = ไม่ต้องแจ้งเตือน',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed < 0) {
                    return 'กรอกจำนวนวันให้ถูกต้อง';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('บันทึก'),
          ),
        ],
      );
    },
  );

  if (result != true) {
    minQtyController.dispose();
    expiryDaysController.dispose();
    return null;
  }

  final minQty = double.tryParse(minQtyController.text.trim());
  final expiryDays = int.tryParse(expiryDaysController.text.trim());

  minQtyController.dispose();
  expiryDaysController.dispose();

  if (minQty == null) return null;

  return {
    'min_quantity': minQty,
    'expiry_alert_days': (expiryDays ?? 0).clamp(0, 365),
  };
}
