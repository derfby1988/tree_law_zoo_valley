class PosRefund {
  final String id;
  final String orderId;
  final String refundType; // 'full' | 'partial' | 'void'
  final double refundAmount;
  final String? refundMethod;
  final String reason;
  final String? approvedBy;
  final String? approvedByName;
  final String? refundedBy;
  final String? refundedByName;
  final String status; // 'pending' | 'approved' | 'completed' | 'rejected'
  final DateTime? refundedAt;
  final DateTime createdAt;

  PosRefund({
    required this.id,
    required this.orderId,
    required this.refundType,
    required this.refundAmount,
    this.refundMethod,
    required this.reason,
    this.approvedBy,
    this.approvedByName,
    this.refundedBy,
    this.refundedByName,
    this.status = 'pending',
    this.refundedAt,
    required this.createdAt,
  });

  bool get isVoid => refundType == 'void';
  bool get isFull => refundType == 'full';
  bool get isPartial => refundType == 'partial';
  bool get isCompleted => status == 'completed';

  factory PosRefund.fromMap(Map<String, dynamic> map) {
    return PosRefund(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      refundType: map['refund_type'] as String,
      refundAmount: (map['refund_amount'] ?? 0).toDouble(),
      refundMethod: map['refund_method'] as String?,
      reason: map['reason'] as String,
      approvedBy: map['approved_by'] as String?,
      approvedByName: map['approved_by_name'] as String?,
      refundedBy: map['refunded_by'] as String?,
      refundedByName: map['refunded_by_name'] as String?,
      status: (map['status'] ?? 'pending') as String,
      refundedAt: map['refunded_at'] != null ? DateTime.parse(map['refunded_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'order_id': orderId,
      'refund_type': refundType,
      'refund_amount': refundAmount,
      'refund_method': refundMethod,
      'reason': reason,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
      'refunded_by': refundedBy,
      'refunded_by_name': refundedByName,
      'status': status,
      if (refundedAt != null) 'refunded_at': refundedAt!.toIso8601String(),
    };
  }
}

class PosRefundItem {
  final String id;
  final String refundId;
  final String orderLineId;
  final int quantity;
  final double refundAmount;
  final DateTime createdAt;

  PosRefundItem({
    required this.id,
    required this.refundId,
    required this.orderLineId,
    required this.quantity,
    required this.refundAmount,
    required this.createdAt,
  });

  factory PosRefundItem.fromMap(Map<String, dynamic> map) {
    return PosRefundItem(
      id: map['id'] as String,
      refundId: map['refund_id'] as String,
      orderLineId: map['order_line_id'] as String,
      quantity: (map['quantity'] ?? 1) as int,
      refundAmount: (map['refund_amount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'refund_id': refundId,
      'order_line_id': orderLineId,
      'quantity': quantity,
      'refund_amount': refundAmount,
    };
  }
}
