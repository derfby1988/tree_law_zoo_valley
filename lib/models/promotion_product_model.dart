/// Standardized Product Model for Promotion Product Picker
/// Ensures consistent data structure across all tabs and APIs

class PromotionProduct {
  final String id;
  final String name;
  final String? code;
  final String? sku;
  final String? description;
  final double price;
  final double cost;
  final String? categoryId;
  final String? categoryName;
  final String? imageUrl;
  final bool isActive;
  
  // Stock information
  final StockInfo stock;
  
  // Tab-specific data
  final ExpiringInfo? expiring;
  final MarginInfo? margin;
  final AvailabilityInfo? availability;
  final String? recommendationReason;
  final String? season;
  final String? festival;

  PromotionProduct({
    required this.id,
    required this.name,
    this.code,
    this.sku,
    this.description,
    required this.price,
    required this.cost,
    this.categoryId,
    this.categoryName,
    this.imageUrl,
    this.isActive = true,
    required this.stock,
    this.expiring,
    this.margin,
    this.availability,
    this.recommendationReason,
    this.season,
    this.festival,
  });

  factory PromotionProduct.fromMap(Map<String, dynamic> map) {
    // Extract stock info
    final stockDetails = map['stock_details'] as Map<String, dynamic>?;
    final stock = StockInfo.fromMap(stockDetails ?? map);
    
    // Extract expiring info
    final expiringData = map['expiring_batches'] as List?;
    ExpiringInfo? expiring;
    if (expiringData != null && expiringData.isNotEmpty) {
      expiring = ExpiringInfo(
        expiringQuantity: (map['expiring_quantity'] as num?)?.toDouble() ?? 0,
        nearestExpiryDate: map['nearest_expiry_date'] as String?,
        batches: expiringData.map((b) => BatchInfo.fromMap(b)).toList(),
      );
    }
    
    // Extract margin info
    MarginInfo? margin;
    if (map.containsKey('margin_percent')) {
      margin = MarginInfo(
        percent: (map['margin_percent'] as num?)?.toDouble() ?? 0,
        amount: (map['margin_amount'] as num?)?.toDouble() ?? 0,
      );
    }
    
    // Extract availability info
    AvailabilityInfo? availability;
    if (map.containsKey('availability')) {
      final availMap = map['availability'] as Map<String, dynamic>;
      availability = AvailabilityInfo.fromMap(availMap);
    }
    
    return PromotionProduct(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString(),
      sku: map['sku']?.toString(),
      description: map['description']?.toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      categoryId: map['category_id']?.toString(),
      categoryName: map['category_name']?.toString(),
      imageUrl: map['image_url']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
      stock: stock,
      expiring: expiring,
      margin: margin,
      availability: availability,
      recommendationReason: map['recommendation_reason']?.toString(),
      season: map['season']?.toString(),
      festival: map['festival']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'sku': sku,
      'description': description,
      'price': price,
      'cost': cost,
      'category_id': categoryId,
      'category_name': categoryName,
      'image_url': imageUrl,
      'is_active': isActive,
      'stock_details': stock.toMap(),
      if (expiring != null) ...{
        'expiring_quantity': expiring!.expiringQuantity,
        'nearest_expiry_date': expiring!.nearestExpiryDate,
        'expiring_batches': expiring!.batches.map((b) => b.toMap()).toList(),
      },
      if (margin != null) ...{
        'margin_percent': margin!.percent,
        'margin_amount': margin!.amount,
      },
      if (availability != null) ...{
        'availability': availability!.toMap(),
      },
      if (recommendationReason != null) 'recommendation_reason': recommendationReason,
      if (season != null) 'season': season,
      if (festival != null) 'festival': festival,
    };
  }

  PromotionProduct copyWith({
    String? id,
    String? name,
    String? code,
    String? sku,
    String? description,
    double? price,
    double? cost,
    String? categoryId,
    String? categoryName,
    String? imageUrl,
    bool? isActive,
    StockInfo? stock,
    ExpiringInfo? expiring,
    MarginInfo? margin,
    AvailabilityInfo? availability,
    String? recommendationReason,
    String? season,
    String? festival,
  }) {
    return PromotionProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      stock: stock ?? this.stock,
      expiring: expiring ?? this.expiring,
      margin: margin ?? this.margin,
      availability: availability ?? this.availability,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      season: season ?? this.season,
      festival: festival ?? this.festival,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromotionProduct && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class StockInfo {
  final double totalQuantity;
  final double availableQuantity;
  final double reservedQuantity;
  final double reservedPercentage;

  StockInfo({
    required this.totalQuantity,
    required this.availableQuantity,
    required this.reservedQuantity,
    required this.reservedPercentage,
  });

  factory StockInfo.fromMap(Map<String, dynamic> map) {
    return StockInfo(
      totalQuantity: (map['total_quantity'] as num?)?.toDouble() ?? 0,
      availableQuantity: (map['available_quantity'] as num?)?.toDouble() ?? 0,
      reservedQuantity: (map['reserved_quantity'] as num?)?.toDouble() ?? 0,
      reservedPercentage: (map['reserved_percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_quantity': totalQuantity,
      'available_quantity': availableQuantity,
      'reserved_quantity': reservedQuantity,
      'reserved_percentage': reservedPercentage,
    };
  }
}

class ExpiringInfo {
  final double expiringQuantity;
  final String? nearestExpiryDate;
  final List<BatchInfo> batches;

  ExpiringInfo({
    required this.expiringQuantity,
    this.nearestExpiryDate,
    required this.batches,
  });

  factory ExpiringInfo.fromMap(Map<String, dynamic> map) {
    final batchesList = (map['batches'] as List?) ?? [];
    return ExpiringInfo(
      expiringQuantity: (map['expiring_quantity'] as num?)?.toDouble() ?? 0,
      nearestExpiryDate: map['nearest_expiry_date'] as String?,
      batches: batchesList.map((b) => BatchInfo.fromMap(b)).toList(),
    );
  }
}

class BatchInfo {
  final String id;
  final String batchNumber;
  final double quantity;
  final String? expiryDate;

  BatchInfo({
    required this.id,
    required this.batchNumber,
    required this.quantity,
    this.expiryDate,
  });

  factory BatchInfo.fromMap(Map<String, dynamic> map) {
    return BatchInfo(
      id: map['id']?.toString() ?? '',
      batchNumber: map['batch_number']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      expiryDate: map['expiry_date']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_number': batchNumber,
      'quantity': quantity,
      'expiry_date': expiryDate,
    };
  }
}

class MarginInfo {
  final double percent;
  final double amount;

  MarginInfo({
    required this.percent,
    required this.amount,
  });

  factory MarginInfo.fromMap(Map<String, dynamic> map) {
    return MarginInfo(
      percent: (map['percent'] as num?)?.toDouble() ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AvailabilityInfo {
  final bool hasStock;
  final bool canProduce;
  final double? availableQuantity;
  final List<Map<String, dynamic>>? ingredientsStatus;

  AvailabilityInfo({
    required this.hasStock,
    required this.canProduce,
    this.availableQuantity,
    this.ingredientsStatus,
  });

  factory AvailabilityInfo.fromMap(Map<String, dynamic> map) {
    return AvailabilityInfo(
      hasStock: map['has_stock'] as bool? ?? false,
      canProduce: map['can_produce'] as bool? ?? false,
      availableQuantity: (map['available_quantity'] as num?)?.toDouble(),
      ingredientsStatus: (map['ingredients_status'] as List?)?.cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'has_stock': hasStock,
      'can_produce': canProduce,
      'available_quantity': availableQuantity,
      'ingredients_status': ingredientsStatus,
    };
  }
}
