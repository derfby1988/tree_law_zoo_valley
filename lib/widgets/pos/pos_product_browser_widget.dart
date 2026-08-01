import 'package:flutter/material.dart';

/// ส่วนแสดงสินค้า / Grid / ค้นหา / บาร์โค้ดของ POS (Zone 4)
///
/// ควรรับ: รายการสินค้า, คำค้นหา, หมวดที่เลือก, callback onAddToCart, onSearchChanged
class PosProductBrowserWidget extends StatelessWidget {
  const PosProductBrowserWidget({
    super.key,
    required this.products,
    required this.searchController,
    required this.barcodeController,
    this.selectedCategoryId,
    required this.onAddToCart,
    required this.onSearchSubmitted,
    required this.onBarcodeSubmitted,
    // สี
    required this.bgColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentGreen,
    required this.borderColor,
  });

  final List<Map<String, dynamic>> products;
  final TextEditingController searchController;
  final TextEditingController barcodeController;
  final String? selectedCategoryId;
  final ValueChanged<Map<String, dynamic>> onAddToCart;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String> onBarcodeSubmitted;
  final Color bgColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentGreen;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    // TODO: ย้าย UI จาก pos_page.dart _buildZone4() มาที่นี้
    return const Placeholder(
      fallbackHeight: 300,
      color: Colors.transparent,
    );
  }
}
