class PosShift {
  final String id;
  final String? shiftNumber;
  final String openedBy;
  final String? openedByName;
  final String? closedBy;
  final String? closedByName;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? cashDifference;
  final double totalSales;
  final int totalOrders;
  final double totalRefunds;
  final double totalDiscounts;
  final String status; // 'open' | 'closed'
  final String? notes;
  final DateTime openedAt;
  final DateTime? closedAt;
  final DateTime createdAt;

  PosShift({
    required this.id,
    this.shiftNumber,
    required this.openedBy,
    this.openedByName,
    this.closedBy,
    this.closedByName,
    required this.openingCash,
    this.closingCash,
    this.expectedCash,
    this.cashDifference,
    this.totalSales = 0,
    this.totalOrders = 0,
    this.totalRefunds = 0,
    this.totalDiscounts = 0,
    this.status = 'open',
    this.notes,
    required this.openedAt,
    this.closedAt,
    required this.createdAt,
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  factory PosShift.fromMap(Map<String, dynamic> map) {
    return PosShift(
      id: map['id'] as String,
      shiftNumber: map['shift_number'] as String?,
      openedBy: map['opened_by'] as String,
      openedByName: map['opened_by_name'] as String?,
      closedBy: map['closed_by'] as String?,
      closedByName: map['closed_by_name'] as String?,
      openingCash: (map['opening_cash'] ?? 0).toDouble(),
      closingCash: map['closing_cash'] != null ? (map['closing_cash']).toDouble() : null,
      expectedCash: map['expected_cash'] != null ? (map['expected_cash']).toDouble() : null,
      cashDifference: map['cash_difference'] != null ? (map['cash_difference']).toDouble() : null,
      totalSales: (map['total_sales'] ?? 0).toDouble(),
      totalOrders: (map['total_orders'] ?? 0) as int,
      totalRefunds: (map['total_refunds'] ?? 0).toDouble(),
      totalDiscounts: (map['total_discounts'] ?? 0).toDouble(),
      status: (map['status'] ?? 'open') as String,
      notes: map['notes'] as String?,
      openedAt: DateTime.parse(map['opened_at'] as String),
      closedAt: map['closed_at'] != null ? DateTime.parse(map['closed_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toOpenMap() {
    return {
      'opened_by': openedBy,
      'opened_by_name': openedByName,
      'opening_cash': openingCash,
      'status': 'open',
      'opened_at': openedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCloseMap() {
    return {
      'closed_by': closedBy,
      'closed_by_name': closedByName,
      'closing_cash': closingCash,
      'expected_cash': expectedCash,
      'cash_difference': cashDifference,
      'total_sales': totalSales,
      'total_orders': totalOrders,
      'total_refunds': totalRefunds,
      'total_discounts': totalDiscounts,
      'status': 'closed',
      'notes': notes,
      'closed_at': closedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}
