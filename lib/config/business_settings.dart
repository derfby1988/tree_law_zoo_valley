import 'package:flutter/material.dart';

class AppBusinessSettings {
  AppBusinessSettings._();

  static const String restaurantName = 'TLZ';
  static const String brandShortName = 'TLZ';
  static const String defaultOrderTypeWalkIn = 'walk_in';
  static const String defaultOrderTypeDineIn = 'dine_in';
  static const double defaultTaxRate = 7.0;
  static const double defaultServiceRate = 0.10;
  static const String defaultTaxInclusion = 'included';
  static const int defaultPosProductGridCount = 3;
  static const int defaultPosSidebarWidth = 56;
  static const int defaultPosHeaderHeight = 68;
  static const double defaultPosZoneGap = 12;
  static const double defaultPosCardRadius = 12;
  static const double defaultPosChipRadius = 6;
  static const double defaultPosProductRadius = 8;

  static const List<BusinessPaymentMethod> paymentMethods = [
    BusinessPaymentMethod(
      key: 'cash',
      label: 'เงินสด',
      icon: Icons.money,
      color: Color(0xFF2E7D32),
    ),
    BusinessPaymentMethod(
      key: 'credit_card',
      label: 'เครดิต/เดบิต',
      icon: Icons.credit_card,
      color: Color(0xFF1565C0),
    ),
    BusinessPaymentMethod(
      key: 'transfer',
      label: 'โอน/พร้อมเพย์',
      icon: Icons.phone_android,
      color: Color(0xFFF57C00),
    ),
    BusinessPaymentMethod(
      key: 'qr',
      label: 'QR Code',
      icon: Icons.qr_code_2,
      color: Color(0xFF8E24AA),
    ),
  ];

  static String get defaultTaxRateLabel => defaultTaxRate == defaultTaxRate.roundToDouble()
      ? defaultTaxRate.toStringAsFixed(0)
      : defaultTaxRate.toStringAsFixed(2);

  static String get defaultServiceRateLabel {
    final percent = defaultServiceRate * 100;
    return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toStringAsFixed(2);
  }
}

class BusinessPaymentMethod {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const BusinessPaymentMethod({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}
