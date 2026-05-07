/// Model สำหรับสูตร Priority Score
/// เก็บ configuration ทั้งหมดของสูตรคำนวณคะแนนแนะนำสินค้า
class PromotionFormulaConfig {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final bool isDefault;
  
  // ช่วงเวลาใช้งาน
  final DateTime? validFrom;
  final DateTime? validUntil;
  
  // น้ำหนักปัจจัย (รวมต้อง = 1.00)
  final double weightMargin;
  final double weightExpiry;
  final double weightSeasonal;
  final double weightFestival;
  final double weightIngredientExpiry;
  
  // เกณฑ์คะแนนแต่ละปัจจัย (JSONB จาก DB)
  final Map<String, dynamic> marginThresholds;
  final Map<String, dynamic> expiryThresholds;
  final Map<String, dynamic> seasonalThresholds;
  final List<Map<String, dynamic>> festivalThresholds;  // เป็น List เพราะใน SQL เก็บเป็น Array
  final Map<String, dynamic> ingredientThresholds;
  
  // เกณฑ์ส่วนลดที่แนะนำ
  final List<Map<String, dynamic>> discountRanges;
  
  // เปิด/ปิดการใช้งานแต่ละปัจจัย
  final List<String> enabledCriteria;
  
  // Metadata
  final String? createdBy;
  final String? createdByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final String? updatedByEmail;

  PromotionFormulaConfig({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.isDefault,
    this.validFrom,
    this.validUntil,
    required this.weightMargin,
    required this.weightExpiry,
    required this.weightSeasonal,
    required this.weightFestival,
    required this.weightIngredientExpiry,
    required this.marginThresholds,
    required this.expiryThresholds,
    required this.seasonalThresholds,
    required this.festivalThresholds,
    required this.ingredientThresholds,
    required this.discountRanges,
    required this.enabledCriteria,
    this.createdBy,
    this.createdByEmail,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    this.updatedByEmail,
  });

  factory PromotionFormulaConfig.fromJson(Map<String, dynamic> json) {
    return PromotionFormulaConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      isDefault: json['is_default'] as bool? ?? false,
      validFrom: json['valid_from'] != null
          ? DateTime.parse(json['valid_from'] as String)
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      weightMargin: (json['weight_margin'] as num?)?.toDouble() ?? 0.25,
      weightExpiry: (json['weight_expiry'] as num?)?.toDouble() ?? 0.35,
      weightSeasonal: (json['weight_seasonal'] as num?)?.toDouble() ?? 0.20,
      weightFestival: (json['weight_festival'] as num?)?.toDouble() ?? 0.10,
      weightIngredientExpiry:
          (json['weight_ingredient_expiry'] as num?)?.toDouble() ?? 0.10,
      marginThresholds: (json['margin_thresholds'] as Map<String, dynamic>?) ??
          _defaultMarginThresholds(),
      expiryThresholds: (json['expiry_thresholds'] as Map<String, dynamic>?) ??
          _defaultExpiryThresholds(),
      seasonalThresholds:
          (json['seasonal_thresholds'] as Map<String, dynamic>?) ??
              _defaultSeasonalThresholds(),
      festivalThresholds: _parseFestivalThresholds(json['festival_thresholds']),
      ingredientThresholds:
          (json['ingredient_thresholds'] as Map<String, dynamic>?) ??
              _defaultIngredientThresholds(),
      discountRanges:
          (json['discount_ranges'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              _defaultDiscountRanges(),
      enabledCriteria:
          (json['enabled_criteria'] as List<dynamic>?)?.cast<String>() ??
              ['margin', 'expiry', 'seasonal', 'festival', 'ingredient'],
      createdBy: json['created_by'] is Map
          ? json['created_by']['id'] as String?
          : json['created_by'] as String?,
      createdByEmail: json['created_by'] is Map
          ? json['created_by']['email'] as String?
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] is Map
          ? json['updated_by']['id'] as String?
          : json['updated_by'] as String?,
      updatedByEmail: json['updated_by'] is Map
          ? json['updated_by']['email'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
      'is_default': isDefault,
      'valid_from': validFrom?.toIso8601String().split('T')[0],
      'valid_until': validUntil?.toIso8601String().split('T')[0],
      'weight_margin': weightMargin,
      'weight_expiry': weightExpiry,
      'weight_seasonal': weightSeasonal,
      'weight_festival': weightFestival,
      'weight_ingredient_expiry': weightIngredientExpiry,
      'margin_thresholds': marginThresholds,
      'expiry_thresholds': expiryThresholds,
      'seasonal_thresholds': seasonalThresholds,
      'festival_thresholds': festivalThresholds,
      'ingredient_thresholds': ingredientThresholds,
      'discount_ranges': discountRanges,
      'enabled_criteria': enabledCriteria,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  /// ดึงช่วงส่วนลดที่แนะนำตามคะแนน
  Map<String, dynamic>? getDiscountRangeForScore(int score) {
    for (final range in discountRanges) {
      final minScore = range['min_score'] as int? ?? 0;
      final maxScore = range['max_score'] as int? ?? 100;
      if (score >= minScore && score <= maxScore) {
        return range;
      }
    }
    return discountRanges.isNotEmpty ? discountRanges.last : null;
  }

  /// ตรวจสอบว่าสูตรใช้งานได้ในวันที่กำหนด
  bool isValidForDate(DateTime date) {
    if (validFrom != null && date.isBefore(validFrom!)) return false;
    if (validUntil != null && date.isAfter(validUntil!)) return false;
    return true;
  }

  /// ตรวจสอบว่าสูตรหมดอายุแล้วหรือไม่
  bool get isExpired {
    if (validUntil == null) return false;
    return DateTime.now().isAfter(validUntil!);
  }

  /// จำนวนวันเหลือก่อนหมดอายุ (null = ไม่หมดอายุ)
  int? get daysUntilExpiry {
    if (validUntil == null) return null;
    return validUntil!.difference(DateTime.now()).inDays;
  }

  /// น้ำหนักรวม (ต้องเป็น 1.00)
  double get totalWeight =>
      weightMargin +
      weightExpiry +
      weightSeasonal +
      weightFestival +
      weightIngredientExpiry;

  /// ตรวจสอบว่าน้ำหนักถูกต้อง
  bool get isWeightValid => (totalWeight - 1.0).abs() < 0.01;

  /// สร้างสำเนาของสูตร (สำหรับสร้างเวอร์ชันใหม่)
  PromotionFormulaConfig copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    bool? isDefault,
    DateTime? validFrom,
    DateTime? validUntil,
    double? weightMargin,
    double? weightExpiry,
    double? weightSeasonal,
    double? weightFestival,
    double? weightIngredientExpiry,
    Map<String, dynamic>? marginThresholds,
    Map<String, dynamic>? expiryThresholds,
    Map<String, dynamic>? seasonalThresholds,
    List<Map<String, dynamic>>? festivalThresholds,
    Map<String, dynamic>? ingredientThresholds,
    List<Map<String, dynamic>>? discountRanges,
    List<String>? enabledCriteria,
  }) {
    return PromotionFormulaConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      weightMargin: weightMargin ?? this.weightMargin,
      weightExpiry: weightExpiry ?? this.weightExpiry,
      weightSeasonal: weightSeasonal ?? this.weightSeasonal,
      weightFestival: weightFestival ?? this.weightFestival,
      weightIngredientExpiry: weightIngredientExpiry ?? this.weightIngredientExpiry,
      marginThresholds: marginThresholds ?? this.marginThresholds,
      expiryThresholds: expiryThresholds ?? this.expiryThresholds,
      seasonalThresholds: seasonalThresholds ?? this.seasonalThresholds,
      festivalThresholds: festivalThresholds ?? this.festivalThresholds,
      ingredientThresholds: ingredientThresholds ?? this.ingredientThresholds,
      discountRanges: discountRanges ?? this.discountRanges,
      enabledCriteria: enabledCriteria ?? this.enabledCriteria,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ============================================
  // Default Values
  // ============================================

  static Map<String, dynamic> _defaultMarginThresholds() => {
        'excellent': {'min_margin_pct': 50, 'score': 100, 'label': 'กำไรดีมาก'},
        'good': {'min_margin_pct': 30, 'score': 70, 'label': 'กำไรดี'},
        'fair': {'min_margin_pct': 10, 'score': 40, 'label': 'กำไรปกติ'},
        'poor': {'min_margin_pct': 0, 'score': 10, 'label': 'กำไรน้อย'},
      };

  static Map<String, dynamic> _defaultExpiryThresholds() => {
        'expired': {'days_remaining': 0, 'score': 100, 'label': 'หมดอายุแล้ว', 'is_critical': true},
        'critical': {'days_remaining': 3, 'score': 90, 'label': 'เหลือ ≤3 วัน', 'is_critical': true},
        'urgent': {'days_remaining': 7, 'score': 70, 'label': 'เหลือ 4-7 วัน'},
        'warning': {'days_remaining': 14, 'score': 50, 'label': 'เหลือ 8-14 วัน'},
        'notice': {'days_remaining': 30, 'score': 30, 'label': 'เหลือ 15-30 วัน'},
      };

  static Map<String, dynamic> _defaultSeasonalThresholds() => {
        'in_season': {'is_in_season': true, 'score': 100, 'label': 'อยู่ในฤดูกาล'},
        'ending_soon': {'days_to_end': 30, 'score': 80, 'label': 'ใกล้สิ้นฤดู'},
        'off_season': {'score': 0, 'label': 'นอกฤดูกาล'},
      };

  static List<Map<String, dynamic>> _defaultFestivalThresholds() => [
        {"days_before": 0, "score": 100, "label": "วันเทศกาล"},
        {"days_before": 3, "score": 95, "label": "อีก 1-3 วัน"},
        {"days_before": 7, "score": 85, "label": "อีก 4-7 วัน"},
        {"days_before": 14, "score": 70, "label": "อีก 8-14 วัน"}
      ];

  // Helper to parse festival_thresholds which can be either Map or List in DB
  static List<Map<String, dynamic>> _parseFestivalThresholds(dynamic value) {
    if (value == null) return _defaultFestivalThresholds();
    
    // If it's already a List, cast it
    if (value is List) {
      return value.cast<Map<String, dynamic>>();
    }
    
    // If it's a Map (old format), convert to List format
    if (value is Map<String, dynamic>) {
      final list = <Map<String, dynamic>>[];
      // Convert map entries to list items
      if (value.containsKey('today')) {
        list.add({
          'days_before': value['today']?['days_before'] ?? 0,
          'score': value['today']?['score'] ?? 100,
          'label': value['today']?['label'] ?? 'วันเทศกาล'
        });
      }
      if (value.containsKey('soon_1_7')) {
        list.add({
          'days_before': value['soon_1_7']?['days_before'] ?? 7,
          'score': value['soon_1_7']?['score'] ?? 90,
          'label': value['soon_1_7']?['label'] ?? 'อีก 1-7 วัน'
        });
      }
      if (value.containsKey('soon_8_14')) {
        list.add({
          'days_before': value['soon_8_14']?['days_before'] ?? 14,
          'score': value['soon_8_14']?['score'] ?? 70,
          'label': value['soon_8_14']?['label'] ?? 'อีก 8-14 วัน'
        });
      }
      if (list.isNotEmpty) return list;
    }
    
    return _defaultFestivalThresholds();
  }

  static Map<String, dynamic> _defaultIngredientThresholds() => {
        'critical': {'days_remaining': 7, 'score': 100, 'label': 'วัตถุดิบหลักเหลือ ≤7 วัน'},
        'warning': {'days_remaining': 14, 'score': 70, 'label': 'วัตถุดิบหลักเหลือ 8-14 วัน'},
        'ok': {'score': 0, 'label': 'ไม่มีวัตถุดิบใกล้หมด'},
      };

  static List<Map<String, dynamic>> _defaultDiscountRanges() => [
        {
          'min_score': 80,
          'max_score': 100,
          'discount_min_pct': 30,
          'discount_max_pct': 50,
          'label': 'ด่วนมาก',
          'color': '#FF4444',
          'priority': 1
        },
        {
          'min_score': 60,
          'max_score': 79,
          'discount_min_pct': 20,
          'discount_max_pct': 30,
          'label': 'ด่วนปานกลาง',
          'color': '#FF8800',
          'priority': 2
        },
        {
          'min_score': 40,
          'max_score': 59,
          'discount_min_pct': 10,
          'discount_max_pct': 20,
          'label': 'ปกติ',
          'color': '#FFAA00',
          'priority': 3
        },
        {
          'min_score': 0,
          'max_score': 39,
          'discount_min_pct': 5,
          'discount_max_pct': 10,
          'label': 'ไม่เร่งด่วน',
          'color': '#44AA44',
          'priority': 4
        },
      ];
}

/// DTO สำหรับสร้างสูตรใหม่
class CreateFormulaRequest {
  final String name;
  final String? description;
  final Map<String, double> weights;
  final Map<String, dynamic>? marginThresholds;
  final Map<String, dynamic>? expiryThresholds;
  final Map<String, dynamic>? seasonalThresholds;
  final Map<String, dynamic>? festivalThresholds;
  final Map<String, dynamic>? ingredientThresholds;
  final List<Map<String, dynamic>>? discountRanges;
  final List<String>? enabledCriteria;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? reason;

  CreateFormulaRequest({
    required this.name,
    this.description,
    required this.weights,
    this.marginThresholds,
    this.expiryThresholds,
    this.seasonalThresholds,
    this.festivalThresholds,
    this.ingredientThresholds,
    this.discountRanges,
    this.enabledCriteria,
    this.validFrom,
    this.validUntil,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'weights': weights,
        'margin_thresholds': marginThresholds,
        'expiry_thresholds': expiryThresholds,
        'seasonal_thresholds': seasonalThresholds,
        'festival_thresholds': festivalThresholds,
        'ingredient_thresholds': ingredientThresholds,
        'discount_ranges': discountRanges,
        'enabled_criteria': enabledCriteria,
        'valid_from': validFrom?.toIso8601String().split('T')[0],
        'valid_until': validUntil?.toIso8601String().split('T')[0],
        'reason': reason,
      };
}

/// DTO สำหรับอัปเดตสูตร
class UpdateFormulaRequest {
  final String? name;
  final String? description;
  final Map<String, double>? weights;
  final Map<String, dynamic>? marginThresholds;
  final Map<String, dynamic>? expiryThresholds;
  final Map<String, dynamic>? seasonalThresholds;
  final Map<String, dynamic>? festivalThresholds;
  final Map<String, dynamic>? ingredientThresholds;
  final List<Map<String, dynamic>>? discountRanges;
  final List<String>? enabledCriteria;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? reason;

  UpdateFormulaRequest({
    this.name,
    this.description,
    this.weights,
    this.marginThresholds,
    this.expiryThresholds,
    this.seasonalThresholds,
    this.festivalThresholds,
    this.ingredientThresholds,
    this.discountRanges,
    this.enabledCriteria,
    this.validFrom,
    this.validUntil,
    this.reason,
  });
}
