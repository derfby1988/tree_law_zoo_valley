import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

class ExpiringIngredientCard extends StatelessWidget {
  const ExpiringIngredientCard({
    super.key,
    required this.ingredient,
    required this.onCreatePromotion,
  });

  final Map<String, dynamic> ingredient;
  final VoidCallback onCreatePromotion;

  @override
  Widget build(BuildContext context) {
    final expiryStatus = ingredient['expiry_status'] as String? ?? 'normal';
    final promotionReason = ingredient['promotion_reason'] as String? ?? '';
    final promotionMetadata = ingredient['promotion_metadata'] as Map<String, dynamic>? ?? {};
    final suggestedDiscount = promotionMetadata['suggested_discount_percent'] as int? ?? 10;
    final affectedRecipes = promotionMetadata['affected_recipes'] as List<dynamic>? ?? [];

    Color statusColor;
    IconData statusIcon;
    switch (expiryStatus) {
      case 'expired':
        statusColor = Colors.red.shade900;
        statusIcon = Icons.warning_rounded;
        break;
      case 'critical':
        statusColor = Colors.red;
        statusIcon = Icons.timer_off;
        break;
      case 'warning':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.95),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient['ingredient_name'] as String? ?? 'ไม่มีชื่อ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ingredient['category_name'] as String? ?? 'ไม่มีหมวดหมู่',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'ส่วนลด $suggestedDiscount%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      promotionReason,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (affectedRecipes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restaurant_menu, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'เมนูที่ใช้วัตถุดิบนี้ (${affectedRecipes.length} เมนู)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: affectedRecipes.take(5).map<Widget>((recipe) {
                        return Chip(
                          label: Text(
                            recipe['output_product_name'] as String? ?? 'ไม่มีชื่อ',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCreatePromotion,
                    icon: const Icon(Icons.local_offer, size: 16),
                    label: const Text('สร้างโปรโมชั่น'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
