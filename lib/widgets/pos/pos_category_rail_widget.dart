import 'package:flutter/material.dart';

/// แถบหมวดหมู่สินค้าด้านซ้ายของ POS
///
/// ควรรับ: รายการหมวด, หมวดที่เลือก, ไอคอน, callback onCategorySelected
class PosCategoryRailWidget extends StatelessWidget {
  const PosCategoryRailWidget({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
    // สีและสไตล์
    required this.bgColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentGreen,
    required this.borderColor,
    required this.selectedSurface,
  });

  final List<Map<String, dynamic>> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final Color bgColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentGreen;
  final Color borderColor;
  final Color selectedSurface;

  @override
  Widget build(BuildContext context) {
    // TODO: ย้าย UI จาก pos_page.dart _buildLeftIconBar() มาที่นี้
    return const Placeholder(
      fallbackHeight: 200,
      color: Colors.transparent,
    );
  }
}
