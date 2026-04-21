import 'package:flutter/material.dart';
import '../../../theme/app_design_system.dart';

Future<Map<String, dynamic>?> showAdjustmentApprovalDialog({
  required BuildContext context,
  required Map<String, dynamic> adjustment,
  required String title,
}) async {
  final noteController = TextEditingController();
  String? action;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection('ข้อมูลการปรับปรุง', [
                    _buildInfoRow('สินค้า', adjustment['product']?['name']?.toString() ?? '-'),
                    _buildInfoRow('ประเภท', adjustment['type']?.toString() ?? '-'),
                    _buildInfoRow('จำนวนก่อน', '${adjustment['quantity_before']}'),
                    _buildInfoRow('จำนวนหลัง', '${adjustment['quantity_after']}'),
                    _buildInfoRow('เปลี่ยนแปลง', '${adjustment['quantity_change']}'),
                  ]),
                  const SizedBox(height: AppDesignSystem.spacingMd),
                  _buildInfoSection('เหตุผล', [
                    Container(
                      padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                      ),
                      child: Text(
                        adjustment['reason']?.toString() ?? 'ไม่มีเหตุผล',
                        style: TextStyle(color: AppDesignSystem.textSecondary),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppDesignSystem.spacingMd),
                  _buildInfoSection('ผู้สร้าง', [
                    _buildInfoRow('ชื่อ', adjustment['user_name']?.toString() ?? '-'),
                    _buildInfoRow('วันที่', _formatDate(adjustment['created_at']?.toString())),
                  ]),
                  const SizedBox(height: AppDesignSystem.spacingMd),
                  Text(
                    'หมายเหตุการอนุมัติ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'เพิ่มหมายเหตุ (ถ้ามี)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                      ),
                    ),
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
            ElevatedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('ปฏิเสธ'),
              style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.danger),
              onPressed: () {
                action = 'reject';
                Navigator.of(context).pop({
                  'action': 'reject',
                  'note': noteController.text.trim(),
                });
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('อนุมัติ'),
              style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.success),
              onPressed: () {
                Navigator.of(context).pop({
                  'action': 'approve',
                  'note': noteController.text.trim(),
                });
              },
            ),
          ],
        );
      },
    ),
  );

  noteController.dispose();
  return result;
}

Widget _buildInfoSection(String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
          border: Border.all(color: AppDesignSystem.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ],
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

String _formatDate(String? dateStr) {
  if (dateStr == null) return '-';
  try {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return dateStr;
  }
}
