class PosPaymentSplit {
  final String id;
  final String orderId;
  final String paymentMethod; // 'cash' | 'credit_debit' | 'transfer' | 'qr_code'
  final double amount;
  final String? referenceNumber;
  final String? note;
  final DateTime paidAt;
  final DateTime createdAt;

  PosPaymentSplit({
    required this.id,
    required this.orderId,
    required this.paymentMethod,
    required this.amount,
    this.referenceNumber,
    this.note,
    required this.paidAt,
    required this.createdAt,
  });

  factory PosPaymentSplit.fromMap(Map<String, dynamic> map) {
    return PosPaymentSplit(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      paymentMethod: map['payment_method'] as String,
      amount: (map['amount'] ?? 0).toDouble(),
      referenceNumber: map['reference_number'] as String?,
      note: map['note'] as String?,
      paidAt: DateTime.parse(map['paid_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'payment_method': paymentMethod,
      'amount': amount,
      'reference_number': referenceNumber,
      'note': note,
      'paid_at': paidAt.toIso8601String(),
    };
  }

  String get methodLabel {
    switch (paymentMethod) {
      case 'cash':
        return 'เงินสด';
      case 'credit_debit':
        return 'เครดิต/เดบิต';
      case 'transfer':
        return 'โอน/พร้อมเพย์';
      case 'qr_code':
        return 'QR Code';
      default:
        return paymentMethod;
    }
  }
}
