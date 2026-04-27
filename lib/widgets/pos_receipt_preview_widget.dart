import 'package:flutter/material.dart';
import '../config/business_settings.dart';
import '../theme/app_design_system.dart';
import '../utils/thai_date_utils.dart';

class PosReceiptPreviewWidget extends StatelessWidget {
  final String orderNumber;
  final String orderType;
  final String? tableNumber;
  final String? customerName;
  final String? cashierName;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double serviceAmount;
  final double netTotal;
  final String paymentMethod;
  final DateTime createdAt;

  const PosReceiptPreviewWidget({
    super.key,
    required this.orderNumber,
    required this.orderType,
    this.tableNumber,
    this.customerName,
    this.cashierName,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceAmount,
    required this.netTotal,
    required this.paymentMethod,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ตัวอย่างใบเสร็จ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Receipt Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Store Name
                    Text(
                      AppBusinessSettings.restaurantName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppDesignSystem.border),
                    const SizedBox(height: 12),
                    // Order Info
                    _receiptRow('เลขที่บิล:', orderNumber),
                    _receiptRow('ประเภท:', _getOrderTypeLabel(orderType)),
                    if (tableNumber != null) _receiptRow('โต๊ะ:', tableNumber!),
                    if (customerName != null) _receiptRow('ลูกค้า:', customerName!),
                    _receiptRow('เวลา:', ThaiDateUtils.formatBuddhistDateTime(createdAt)),
                    const SizedBox(height: 12),
                    Divider(color: AppDesignSystem.border),
                    const SizedBox(height: 12),
                    // Items
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'รายการสินค้า',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final qty = item['quantity'] ?? 1;
                      final price = (item['unit_price'] ?? 0).toDouble();
                      final total = qty * price;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['product_name'] ?? 'สินค้า',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$qty x ฿${price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppDesignSystem.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '฿${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Divider(color: AppDesignSystem.border),
                    const SizedBox(height: 12),
                    // Summary
                    _summaryRow('ยอดรวม:', subtotal),
                    if (discountAmount > 0)
                      _summaryRow('ส่วนลด:', -discountAmount, isDiscount: true),
                    _summaryRow('ภาษี (7%):', taxAmount, isTax: true),
                    _summaryRow('ค่าบริการ:', serviceAmount, isService: true),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _summaryRow('ยอดสุทธิ:', netTotal, isTotal: true),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppDesignSystem.border),
                    const SizedBox(height: 12),
                    // Payment Method
                    _receiptRow('วิธีชำระ:', _getPaymentMethodLabel(paymentMethod)),
                    if (cashierName != null) _receiptRow('แคชเชียร์:', cashierName!),
                    const SizedBox(height: 12),
                    Divider(color: AppDesignSystem.border),
                    const SizedBox(height: 12),
                    // Footer
                    Text(
                      'ขอบคุณที่ใช้บริการ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppDesignSystem.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('พิมพ์'),
                      onPressed: () {
                        // TODO: Implement print functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ฟังก์ชันพิมพ์จะเพิ่มเร็วๆ')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('ปิด'),
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppDesignSystem.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double value, {
    bool isDiscount = false,
    bool isTax = false,
    bool isService = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppDesignSystem.primary : AppDesignSystem.textSecondary,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}฿${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? Colors.red : (isTotal ? AppDesignSystem.primary : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  String _getOrderTypeLabel(String type) {
    switch (type) {
      case 'dine_in':
        return 'ทานที่ร้าน';
      case 'takeaway':
        return 'กลับบ้าน';
      case 'delivery':
        return 'เดลิเวอรี่';
      default:
        return 'ทั่วไป';
    }
  }

  String _getPaymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'เงินสด';
      case 'card':
        return 'บัตรเครดิต/เดบิต';
      case 'transfer':
        return 'โอนเงิน';
      case 'qr':
        return 'QR Code';
      default:
        return method;
    }
  }

}
