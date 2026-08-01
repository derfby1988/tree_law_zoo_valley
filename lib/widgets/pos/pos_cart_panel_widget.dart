import 'package:flutter/material.dart';

/// ส่วนแสดงตะกร้า (Cart) ของ POS (Zone 5)
///
/// ควรรับ: รายการในตะกร้า, callback qty update, remove, add note, และ summary values
class PosCartPanelWidget extends StatelessWidget {
  const PosCartPanelWidget({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.discount,
    required this.totalDiscount,
    required this.taxAmount,
    required this.serviceAmount,
    required this.netTotal,
    required this.onQtyChanged,
    required this.onRemove,
    required this.onEditNote,
    // สี
    required this.bgColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentGreen,
    required this.borderColor,
  });

  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final double discount;
  final double totalDiscount;
  final double taxAmount;
  final double serviceAmount;
  final double netTotal;
  final void Function(int index, int delta) onQtyChanged;
  final void Function(int index) onRemove;
  final void Function(int index, String note) onEditNote;
  final Color bgColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentGreen;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    // TODO: ย้าย UI จาก pos_page.dart _buildZone5() มาที่นี้
    return const Placeholder(
      fallbackHeight: 200,
      color: Colors.transparent,
    );
  }
}
