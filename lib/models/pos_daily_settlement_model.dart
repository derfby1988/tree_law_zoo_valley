class PosDailySettlement {
  final String id;
  final DateTime settlementDate;
  final String? storeId;
  final double totalSales;
  final double totalCash;
  final double totalCashless;
  final double totalRefunds;
  final double totalVoids;
  final double totalDiscounts;
  final double totalLoyaltyRedeemed;
  final double totalTax;
  final double totalServiceCharge;
  final double expectedCash;
  final double? countedCash;
  final double? cashDifference;
  final List<String> shiftIds;
  final String status; // 'draft' | 'closed' | 'reopened'
  final String? closedBy;
  final String? closedByName;
  final DateTime? closedAt;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PosDailySettlement({
    required this.id,
    required this.settlementDate,
    this.storeId,
    this.totalSales = 0,
    this.totalCash = 0,
    this.totalCashless = 0,
    this.totalRefunds = 0,
    this.totalVoids = 0,
    this.totalDiscounts = 0,
    this.totalLoyaltyRedeemed = 0,
    this.totalTax = 0,
    this.totalServiceCharge = 0,
    this.expectedCash = 0,
    this.countedCash,
    this.cashDifference,
    this.shiftIds = const [],
    this.status = 'draft',
    this.closedBy,
    this.closedByName,
    this.closedAt,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status == 'draft';
  bool get isClosed => status == 'closed';
  bool get isReopened => status == 'reopened';

  factory PosDailySettlement.fromMap(Map<String, dynamic> map) {
    return PosDailySettlement(
      id: map['id'] as String,
      settlementDate: DateTime.parse(map['settlement_date'] as String),
      storeId: map['store_id'] as String?,
      totalSales: (map['total_sales'] ?? 0).toDouble(),
      totalCash: (map['total_cash'] ?? 0).toDouble(),
      totalCashless: (map['total_cashless'] ?? 0).toDouble(),
      totalRefunds: (map['total_refunds'] ?? 0).toDouble(),
      totalVoids: (map['total_voids'] ?? 0).toDouble(),
      totalDiscounts: (map['total_discounts'] ?? 0).toDouble(),
      totalLoyaltyRedeemed: (map['total_loyalty_redeemed'] ?? 0).toDouble(),
      totalTax: (map['total_tax'] ?? 0).toDouble(),
      totalServiceCharge: (map['total_service_charge'] ?? 0).toDouble(),
      expectedCash: (map['expected_cash'] ?? 0).toDouble(),
      countedCash: map['counted_cash'] != null ? (map['counted_cash']).toDouble() : null,
      cashDifference: map['cash_difference'] != null ? (map['cash_difference']).toDouble() : null,
      shiftIds: map['shift_ids'] != null
          ? List<String>.from(map['shift_ids'] as List)
          : [],
      status: (map['status'] ?? 'draft') as String,
      closedBy: map['closed_by'] as String?,
      closedByName: map['closed_by_name'] as String?,
      closedAt: map['closed_at'] != null ? DateTime.parse(map['closed_at'] as String) : null,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'settlement_date': settlementDate.toIso8601String().split('T')[0],
      'store_id': storeId,
      'total_sales': totalSales,
      'total_cash': totalCash,
      'total_cashless': totalCashless,
      'total_refunds': totalRefunds,
      'total_voids': totalVoids,
      'total_discounts': totalDiscounts,
      'total_loyalty_redeemed': totalLoyaltyRedeemed,
      'total_tax': totalTax,
      'total_service_charge': totalServiceCharge,
      'expected_cash': expectedCash,
      'counted_cash': countedCash,
      'cash_difference': cashDifference,
      'shift_ids': shiftIds,
      'status': status,
      'closed_by': closedBy,
      'closed_by_name': closedByName,
      'closed_at': closedAt?.toIso8601String(),
      'note': note,
    };
  }

  Map<String, dynamic> toCloseMap() {
    return {
      'counted_cash': countedCash,
      'cash_difference': cashDifference,
      'status': 'closed',
      'closed_by': closedBy,
      'closed_by_name': closedByName,
      'closed_at': closedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'note': note,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
