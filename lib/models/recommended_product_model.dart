import 'package:supabase_flutter/supabase_flutter.dart';

/// Model สำหรับสินค้าแนะนำจาก Priority Score
class RecommendedProduct {
  final String productId;
  final String productName;
  final String? sku;
  final double price;
  final double cost;
  final double marginPct;
  final int? daysRemaining;
  final int stockQuantity;
  final String? imageUrl;
  final String? categoryId;
  final String? categoryName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // คะแนนทั้งหมด
  final int marginScore;
  final int expiryScore;
  final int seasonalScore;
  final int festivalScore;
  final int ingredientScore;
  final double priorityScore;

  // การจัดอันดับ
  final int overallRank;
  final int priorityQuartile;
  final String priorityLevel;

  // ข้อมูลเพิ่มเติม
  final bool isInSeason;
  final bool hasUpcomingFestival;
  final bool hasCriticalIngredients;

  // คำแนะนำ
  final double suggestedDiscountPct;
  final List<String> recommendationReasons;

  // Metadata
  final DateTime calculationDate;
  final int calculationTimestamp;

  const RecommendedProduct({
    required this.productId,
    required this.productName,
    this.sku,
    required this.price,
    required this.cost,
    required this.marginPct,
    this.daysRemaining,
    required this.stockQuantity,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.marginScore,
    required this.expiryScore,
    required this.seasonalScore,
    required this.festivalScore,
    required this.ingredientScore,
    required this.priorityScore,
    required this.overallRank,
    required this.priorityQuartile,
    required this.priorityLevel,
    required this.isInSeason,
    required this.hasUpcomingFestival,
    required this.hasCriticalIngredients,
    required this.suggestedDiscountPct,
    required this.recommendationReasons,
    required this.calculationDate,
    required this.calculationTimestamp,
  });

  factory RecommendedProduct.fromSupabase(Map<String, dynamic> json) {
    return RecommendedProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      sku: json['sku'] as String?,
      price: (json['price'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
      marginPct: (json['margin_pct'] as num).toDouble(),
      daysRemaining: json['days_remaining'] as int?,
      stockQuantity: json['stock_quantity'] as int,
      imageUrl: json['image_url'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      marginScore: json['margin_score'] as int,
      expiryScore: json['expiry_score'] as int,
      seasonalScore: json['seasonal_score'] as int,
      festivalScore: json['festival_score'] as int,
      ingredientScore: json['ingredient_score'] as int,
      priorityScore: (json['priority_score'] as num).toDouble(),
      overallRank: json['overall_rank'] as int,
      priorityQuartile: json['priority_quartile'] as int,
      priorityLevel: json['priority_level'] as String,
      isInSeason: json['is_in_season'] as bool,
      hasUpcomingFestival: json['has_upcoming_festival'] as bool,
      hasCriticalIngredients: json['has_critical_ingredients'] as bool,
      suggestedDiscountPct: (json['suggested_discount_pct'] as num).toDouble(),
      recommendationReasons: (json['recommendation_reasons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      calculationDate: DateTime.parse(json['calculation_date'] as String),
      calculationTimestamp: json['calculation_timestamp'] as int,
    );
  }

  /// แปลงเป็น Map สำหรับเก็บใน cache
  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'sku': sku,
      'price': price,
      'cost': cost,
      'margin_pct': marginPct,
      'days_remaining': daysRemaining,
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'category_id': categoryId,
      'category_name': categoryName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'margin_score': marginScore,
      'expiry_score': expiryScore,
      'seasonal_score': seasonalScore,
      'festival_score': festivalScore,
      'ingredient_score': ingredientScore,
      'priority_score': priorityScore,
      'overall_rank': overallRank,
      'priority_quartile': priorityQuartile,
      'priority_level': priorityLevel,
      'is_in_season': isInSeason,
      'has_upcoming_festival': hasUpcomingFestival,
      'has_critical_ingredients': hasCriticalIngredients,
      'suggested_discount_pct': suggestedDiscountPct,
      'recommendation_reasons': recommendationReasons,
      'calculation_date': calculationDate.toIso8601String(),
      'calculation_timestamp': calculationTimestamp,
    };
  }

  /// คัดลอกพร้อมแก้ไขค่าบางอย่าง
  RecommendedProduct copyWith({
    String? productId,
    String? productName,
    String? sku,
    double? price,
    double? cost,
    double? marginPct,
    int? daysRemaining,
    int? stockQuantity,
    String? imageUrl,
    String? categoryId,
    String? categoryName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? marginScore,
    int? expiryScore,
    int? seasonalScore,
    int? festivalScore,
    int? ingredientScore,
    double? priorityScore,
    int? overallRank,
    int? priorityQuartile,
    String? priorityLevel,
    bool? isInSeason,
    bool? hasUpcomingFestival,
    bool? hasCriticalIngredients,
    double? suggestedDiscountPct,
    List<String>? recommendationReasons,
    DateTime? calculationDate,
    int? calculationTimestamp,
  }) {
    return RecommendedProduct(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      marginPct: marginPct ?? this.marginPct,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      marginScore: marginScore ?? this.marginScore,
      expiryScore: expiryScore ?? this.expiryScore,
      seasonalScore: seasonalScore ?? this.seasonalScore,
      festivalScore: festivalScore ?? this.festivalScore,
      ingredientScore: ingredientScore ?? this.ingredientScore,
      priorityScore: priorityScore ?? this.priorityScore,
      overallRank: overallRank ?? this.overallRank,
      priorityQuartile: priorityQuartile ?? this.priorityQuartile,
      priorityLevel: priorityLevel ?? this.priorityLevel,
      isInSeason: isInSeason ?? this.isInSeason,
      hasUpcomingFestival: hasUpcomingFestival ?? this.hasUpcomingFestival,
      hasCriticalIngredients: hasCriticalIngredients ?? this.hasCriticalIngredients,
      suggestedDiscountPct: suggestedDiscountPct ?? this.suggestedDiscountPct,
      recommendationReasons: recommendationReasons ?? this.recommendationReasons,
      calculationDate: calculationDate ?? this.calculationDate,
      calculationTimestamp: calculationTimestamp ?? this.calculationTimestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecommendedProduct && other.productId == productId;
  }

  @override
  int get hashCode => productId.hashCode;

  @override
  String toString() {
    return 'RecommendedProduct(productId: $productId, productName: $productName, priorityScore: $priorityScore)';
  }

  /// ดึงข้อความสาเหตุการแนะนำ
  String get recommendationReasonsText {
    if (recommendationReasons.isEmpty) return 'ไม่ระบุ';
    return recommendationReasons.join(', ');
  }

  /// ดึงข้อความระดับความสำคัญ
  String get priorityLevelText {
    switch (priorityLevel) {
      case 'critical':
        return 'ด่วนที่สุด';
      case 'high':
        return 'ด่วน';
      case 'medium':
        return 'ปานกลาง';
      case 'low':
        return 'ต่ำ';
      case 'minimal':
        return 'น้อยมาก';
      default:
        return 'ไม่ระบุ';
    }
  }

  /// ดึงสีสำหรับระดับความสำคัญ
  String get priorityLevelColor {
    switch (priorityLevel) {
      case 'critical':
        return '#FF4444'; // แดง
      case 'high':
        return '#FF8800'; // ส้ม
      case 'medium':
        return '#FFBB33'; // เหลือง
      case 'low':
        return '#00C851'; // เขียว
      case 'minimal':
        return '#33B5E5'; // น้ำเงิน
      default:
        return '#888888'; // เทา
    }
  }

  /// ตรวจสอบว่าใกล้หมดอายุหรือไม่
  bool get isExpiringSoon {
    return daysRemaining != null && daysRemaining! <= 14;
  }

  /// ตรวจสอบว่าหมดอายุแล้วหรือไม่
  bool get isExpired {
    return daysRemaining != null && daysRemaining! < 0;
  }

  /// ตรวจสอบว่ามีกำไรสูงหรือไม่
  bool get isHighMargin {
    return marginPct >= 30;
  }

  /// ตรวจสอบว่ามีสต็อกน้อยหรือไม่
  bool get isLowStock {
    return stockQuantity <= 10;
  }
}
