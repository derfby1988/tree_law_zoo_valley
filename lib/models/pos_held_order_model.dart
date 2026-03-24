class PosHeldOrder {
  final String id;
  final String heldBy;
  final String? heldByName;
  final String orderType;
  final String? tableId;
  final String? tableNumber;
  final String? customerId;
  final String? customerName;
  final List<Map<String, dynamic>> cartData;
  final double subtotal;
  final List<Map<String, dynamic>>? discountData;
  final String? note;
  final String status; // 'held' | 'resumed' | 'cancelled'
  final DateTime heldAt;
  final DateTime? resumedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  PosHeldOrder({
    required this.id,
    required this.heldBy,
    this.heldByName,
    this.orderType = 'walk_in',
    this.tableId,
    this.tableNumber,
    this.customerId,
    this.customerName,
    required this.cartData,
    this.subtotal = 0,
    this.discountData,
    this.note,
    this.status = 'held',
    required this.heldAt,
    this.resumedAt,
    this.expiresAt,
    required this.createdAt,
  });

  factory PosHeldOrder.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> parseJsonList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    return PosHeldOrder(
      id: map['id'] as String,
      heldBy: map['held_by'] as String,
      heldByName: map['held_by_name'] as String?,
      orderType: (map['order_type'] as String?) ?? 'walk_in',
      tableId: map['table_id'] as String?,
      tableNumber: map['table_number'] as String?,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      cartData: parseJsonList(map['cart_data']),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      discountData: map['discount_data'] != null ? parseJsonList(map['discount_data']) : null,
      note: map['note'] as String?,
      status: (map['status'] as String?) ?? 'held',
      heldAt: DateTime.parse(map['held_at'] as String),
      resumedAt: map['resumed_at'] != null ? DateTime.parse(map['resumed_at'] as String) : null,
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'held_by': heldBy,
      'held_by_name': heldByName,
      'order_type': orderType,
      'table_id': tableId,
      'table_number': tableNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'cart_data': cartData,
      'subtotal': subtotal,
      'discount_data': discountData,
      'note': note,
      'status': status,
    };
  }

  int get itemCount {
    int count = 0;
    for (final item in cartData) {
      count += (item['qty'] as int? ?? 1);
    }
    return count;
  }

  int get lineCount => cartData.length;

  String get displayLabel {
    if (tableNumber != null && tableNumber!.isNotEmpty) {
      return 'โต๊ะ $tableNumber';
    }
    if (customerName != null && customerName!.isNotEmpty) {
      return customerName!;
    }
    return heldByName ?? 'บิลพัก';
  }
}
