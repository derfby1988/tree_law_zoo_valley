import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';
import 'package:tree_law_zoo_valley/models/pos_promotion_model.dart';

import 'promotion_admin_card.dart';

class PromotionsTabWidget extends StatelessWidget {
  const PromotionsTabWidget({
    super.key,
    required this.promotions,
    required this.formatDate,
    required this.getTypeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PosPromotion> promotions;
  final String Function(DateTime) formatDate;
  final String Function(String) getTypeLabel;
  final ValueChanged<PosPromotion> onEdit;
  final ValueChanged<PosPromotion> onDelete;

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีโปรโมชั่น',
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: promotions.length,
      itemBuilder: (context, index) {
        final promotion = promotions[index];
        return PromotionAdminCard(
          promotion: promotion,
          endDateLabel: promotion.endAt != null ? formatDate(promotion.endAt!) : 'ไม่มีกำหนด',
          promotionTypeLabel: getTypeLabel(promotion.promotionType),
          onEdit: () => onEdit(promotion),
          onDelete: () => onDelete(promotion),
        );
      },
    );
  }
}
