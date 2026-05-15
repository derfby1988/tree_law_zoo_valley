import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';
import 'package:tree_law_zoo_valley/models/pos_discount_model.dart';

import 'coupon_admin_card.dart';

class CouponsTabWidget extends StatelessWidget {
  const CouponsTabWidget({
    super.key,
    required this.coupons,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PosDiscount> coupons;
  final String Function(DateTime) formatDate;
  final ValueChanged<PosDiscount> onEdit;
  final ValueChanged<PosDiscount> onDelete;

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีคูปอง',
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        final discountText = coupon.discountType == 'percentage'
            ? '${coupon.value.toStringAsFixed(0)}%'
            : '${coupon.value.toStringAsFixed(0)} บาท';
        return CouponAdminCard(
          coupon: coupon,
          discountText: discountText,
          endDateLabel: coupon.endAt != null ? formatDate(coupon.endAt!) : 'ไม่มีกำหนด',
          onEdit: () => onEdit(coupon),
          onDelete: () => onDelete(coupon),
        );
      },
    );
  }
}
