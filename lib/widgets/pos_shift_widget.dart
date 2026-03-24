import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_shift_model.dart';
import '../services/pos_shift_service.dart';
import '../theme/app_design_system.dart';

/// Shift chip สำหรับแสดงใน Header ของ POS
class PosShiftChip extends StatelessWidget {
  final PosShift? currentShift;
  final VoidCallback onOpenShift;
  final VoidCallback onCloseShift;

  const PosShiftChip({
    super.key,
    required this.currentShift,
    required this.onOpenShift,
    required this.onCloseShift,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = currentShift != null && currentShift!.isOpen;
    final accentGreen = AppDesignSystem.primary;
    final textSecondary = AppDesignSystem.textSecondary;

    return InkWell(
      onTap: isOpen ? onCloseShift : onOpenShift,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOpen ? accentGreen.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isOpen ? accentGreen.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen ? Icons.lock_open : Icons.lock_outline,
              size: 14,
              color: isOpen ? accentGreen : Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              isOpen ? 'กะเปิด' : 'เปิดกะ',
              style: TextStyle(
                fontSize: 10,
                color: isOpen ? accentGreen : Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isOpen && currentShift?.shiftNumber != null) ...[
              const SizedBox(width: 4),
              Text(
                currentShift!.shiftNumber!.replaceAll('SHIFT-', ''),
                style: TextStyle(fontSize: 9, color: textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper สำหรับเปิด dialog เปิดกะ / ปิดกะ
class PosShiftDialogs {
  static final _iconGradient = AppDesignSystem.accentGradient;

  static Widget _gradientIcon(IconData icon, {double size = 18}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => _iconGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  /// เปิด dialog เปิดกะ — คืน PosShift? เมื่อเปิดสำเร็จ
  static Future<PosShift?> showOpenShiftDialog(BuildContext context) async {
    final bgColor = AppDesignSystem.background;
    final textSecondary = AppDesignSystem.textSecondary;
    final accentGreen = AppDesignSystem.primary;

    final cashController = TextEditingController(text: '0');
    PosShift? result;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                _gradientIcon(Icons.lock_open, size: 22),
                const SizedBox(width: 8),
                const Text('เปิดกะ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ใส่ยอดเงินสดเปิดกะ', style: TextStyle(fontSize: 13, color: textSecondary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'เงินสดเปิดกะ (฿)',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: bgColor,
                    ),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final openingCash = double.tryParse(cashController.text) ?? 0;
                  final user = Supabase.instance.client.auth.currentUser;
                  final userName = _displayFullName(user);

                  final shift = await PosShiftService.openShift(
                    userId: user?.id ?? '',
                    userName: userName,
                    openingCash: openingCash,
                  );

                  if (shift != null && ctx.mounted) {
                    result = shift;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เปิดกะสำเร็จ ${shift.shiftNumber ?? ''} เงินเปิด ฿${openingCash.toStringAsFixed(2)}'),
                        backgroundColor: accentGreen,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.lock_open),
                label: const Text('เปิดกะ'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  /// เปิด dialog ปิดกะ — คืน PosShift? เมื่อปิดสำเร็จ
  static Future<PosShift?> showCloseShiftDialog(BuildContext context, PosShift currentShift) async {
    final bgColor = AppDesignSystem.background;
    final textPrimary = AppDesignSystem.textPrimary;
    final textSecondary = AppDesignSystem.textSecondary;
    final borderColor = AppDesignSystem.border;
    final accentGreen = AppDesignSystem.primary;

    final cashController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    Map<String, dynamic>? summary;
    bool loadingSummary = true;
    PosShift? result;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loadingSummary) {
            loadingSummary = false;
            PosShiftService.getShiftSummary(currentShift.id).then((s) {
              setDialogState(() => summary = s);
            });
          }

          final totalSales = (summary?['total_sales'] ?? 0).toDouble();
          final totalOrders = (summary?['total_orders'] ?? 0) as int;
          final totalDiscounts = (summary?['total_discounts'] ?? 0).toDouble();
          final totalRefunds = (summary?['total_refunds'] ?? 0).toDouble();
          final cashSales = (summary?['cash_sales'] ?? 0).toDouble();
          final openingCash = currentShift.openingCash;
          final expectedCash = openingCash + cashSales - totalRefunds;

          return AlertDialog(
            title: Row(
              children: [
                _gradientIcon(Icons.lock_outline, size: 22),
                const SizedBox(width: 8),
                const Text('ปิดกะ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (currentShift.shiftNumber != null)
                  Text(currentShift.shiftNumber!, style: TextStyle(fontSize: 11, color: textSecondary)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: summary == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('สรุปกะ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                                const Divider(height: 16),
                                _summaryRow('เงินสดเปิดกะ', openingCash),
                                _summaryRow('ยอดขายรวม', totalSales),
                                _summaryRow('ยอดขายเงินสด', cashSales),
                                _summaryRow('จำนวนบิล', totalOrders.toDouble(), isCount: true),
                                _summaryRow('ส่วนลดรวม', totalDiscounts, isNegative: true),
                                _summaryRow('คืนเงินรวม', totalRefunds, isNegative: true),
                                const Divider(height: 16),
                                _summaryRow('เงินสดที่ควรมี', expectedCash, isBold: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: cashController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'เงินสดปิดกะจริง (฿)',
                              prefixIcon: const Icon(Icons.payments_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: bgColor,
                            ),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'หมายเหตุ (ถ้ามี)',
                              prefixIcon: const Icon(Icons.note_alt_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: bgColor,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: summary == null
                    ? null
                    : () async {
                        final closingCash = double.tryParse(cashController.text) ?? 0;
                        final user = Supabase.instance.client.auth.currentUser;
                        final userName = _displayFullName(user);

                        final closed = await PosShiftService.closeShift(
                          shiftId: currentShift.id,
                          userId: user?.id ?? '',
                          userName: userName,
                          closingCash: closingCash,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        );

                        if (closed != null && ctx.mounted) {
                          result = closed;
                          final diff = closed.cashDifference ?? 0;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ปิดกะสำเร็จ ${closed.shiftNumber ?? ''} ส่วนต่าง ฿${diff.toStringAsFixed(2)}'),
                              backgroundColor: accentGreen,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.lock_outline),
                label: const Text('ปิดกะ'),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  static Widget _summaryRow(String label, double value, {bool isNegative = false, bool isBold = false, bool isCount = false}) {
    final textSecondary = AppDesignSystem.textSecondary;
    final textPrimary = AppDesignSystem.textPrimary;
    final accentGreen = AppDesignSystem.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            isCount ? '${value.toInt()} บิล' : '${isNegative ? "-" : ""}฿${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isNegative ? Colors.red.shade400 : (isBold ? accentGreen : textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayFullName(User? user) {
    if (user == null) return 'ไม่ทราบชื่อ';
    final meta = user.userMetadata;
    if (meta == null) return user.email ?? 'ไม่ทราบชื่อ';
    final first = (meta['first_name'] ?? '').toString();
    final last = (meta['last_name'] ?? '').toString();
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    final fn = meta['full_name']?.toString();
    if (fn != null && fn.isNotEmpty) return fn;
    return meta['display_name']?.toString() ?? user.email ?? 'ไม่ทราบชื่อ';
  }
}
