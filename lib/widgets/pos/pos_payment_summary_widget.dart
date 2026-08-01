import 'package:flutter/material.dart';

/// ส่วนสรุปยอดและชำระเงินของ POS (Zone 1, 2, 3)
///
/// ควรรับ: ยอดต่างๆ, วิธีชำระเงิน, callback onPayment, onSplitPayment, onVoid, onHold
class PosPaymentSummaryWidget extends StatelessWidget {
  const PosPaymentSummaryWidget({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.totalDiscount,
    required this.preTaxTotal,
    required this.taxAmount,
    required this.serviceAmount,
    required this.netTotal,
    required this.paidTotal,
    required this.balanceDue,
    required this.onPayment,
    required this.onHold,
    required this.onVoid,
    this.isSplitPayment = false,
    this.paymentSplits = const [],
    // สี
    required this.bgColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentGreen,
    required this.borderColor,
  });

  final double subtotal;
  final double discount;
  final double totalDiscount;
  final double preTaxTotal;
  final double taxAmount;
  final double serviceAmount;
  final double netTotal;
  final double paidTotal;
  final double balanceDue;
  final VoidCallback onPayment;
  final VoidCallback onHold;
  final VoidCallback onVoid;
  final bool isSplitPayment;
  final List<Map<String, dynamic>> paymentSplits;
  final Color bgColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentGreen;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    // TODO: ย้าย UI จาก pos_page.dart _buildZone1(), _buildZone2(), _buildZone3() มาที่นี้
    return const Placeholder(
      fallbackHeight: 300,
      color: Colors.transparent,
    );
  }
}
