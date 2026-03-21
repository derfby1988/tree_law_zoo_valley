import 'package:flutter/material.dart';

class CancelPODialog extends StatefulWidget {
  final String orderNumber;

  const CancelPODialog({
    super.key,
    required this.orderNumber,
  });

  @override
  State<CancelPODialog> createState() => _CancelPODialogState();
}

class _CancelPODialogState extends State<CancelPODialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(_reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ยกเลิกใบสั่งซื้อ'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ระบุเหตุผลการยกเลิก PO ${widget.orderNumber}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'เหตุผลการยกเลิก',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณาระบุเหตุผลการยกเลิก';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('ยืนยันยกเลิก'),
        ),
      ],
    );
  }
}
