import 'package:flutter/material.dart';
import '../models/pos_discount_model.dart';
import '../services/pos_discount_service.dart';
import '../theme/app_design_system.dart';

typedef DiscountAppliedCallback = void Function(
  PosDiscount discount,
  double amount, {
  String? couponCode,
});

class PosDiscountPanelWidget extends StatefulWidget {
  final DiscountAppliedCallback onDiscountApplied;
  final Function(String) onDiscountRemoved;
  final double orderAmount;
  final List<Map<String, dynamic>> appliedDiscounts;

  const PosDiscountPanelWidget({
    super.key,
    required this.onDiscountApplied,
    required this.onDiscountRemoved,
    required this.orderAmount,
    this.appliedDiscounts = const [],
  });

  @override
  State<PosDiscountPanelWidget> createState() => _PosDiscountPanelWidgetState();
}

class _PosDiscountPanelWidgetState extends State<PosDiscountPanelWidget> {
  List<PosDiscount> _availableDiscounts = [];
  bool _isLoading = false;
  final _couponController = TextEditingController();
  bool _isApplyingCoupon = false;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscounts() async {
    setState(() => _isLoading = true);
    final discounts = await PosDiscountService.getActiveDiscounts();
    setState(() {
      _availableDiscounts = discounts;
      _isLoading = false;
    });
  }

  void _applyDiscount(PosDiscount discount) {
    final discountAmount = discount.calculateDiscount(widget.orderAmount);
    if (discountAmount > 0) {
      widget.onDiscountApplied(discount, discountAmount, couponCode: null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ใช้ส่วนลด ${discount.name} ฿${discountAmount.toStringAsFixed(2)}'),
          backgroundColor: AppDesignSystem.primary,
        ),
      );
    }
  }

  void _showDiscountDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
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
                      'เลือกส่วนลด',
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
              // Discount List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _availableDiscounts.isEmpty
                        ? Center(
                            child: Text(
                              'ไม่มีส่วนลดที่ใช้ได้',
                              style: TextStyle(color: AppDesignSystem.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _availableDiscounts.length,
                            itemBuilder: (context, index) {
                              final discount = _availableDiscounts[index];
                              final discountAmount = discount.calculateDiscount(widget.orderAmount);

                              return ListTile(
                                title: Text(discount.name),
                                subtitle: Text(
                                  discount.discountType == 'percentage'
                                      ? '${discount.value}% (สูงสุด ฿${discount.maxDiscount?.toStringAsFixed(2) ?? 'ไม่จำกัด'})'
                                      : '฿${discount.value.toStringAsFixed(2)}',
                                ),
                                trailing: Text(
                                  '฿${discountAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                onTap: () {
                                  _applyDiscount(discount);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyCouponCode() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรหัสคูปอง')),
      );
      return;
    }

    // Check if coupon already applied
    final alreadyApplied = widget.appliedDiscounts.any(
      (d) => d['coupon_code']?.toString().toUpperCase() == code,
    );
    if (alreadyApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คูปองนี้ถูกใช้แล้ว')),
      );
      return;
    }

    setState(() => _isApplyingCoupon = true);

    final discount = await PosDiscountService.validateCouponCode(
      couponCode: code,
      orderAmount: widget.orderAmount,
      channel: 'pos',
    );

    setState(() => _isApplyingCoupon = false);

    if (discount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสคูปองไม่ถูกต้องหรือไม่สามารถใช้ได้'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate discount amount
    final discountAmount = discount.calculateDiscount(widget.orderAmount);
    if (discountAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถใช้คูปองนี้กับยอดปัจจุบัน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Apply the discount with coupon code
    widget.onDiscountApplied(
      discount,
      discountAmount,
      couponCode: code,
    );
    _couponController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ใช้คูปอง ${discount.name} สำเร็จ (฿${discountAmount.toStringAsFixed(2)})'),
        backgroundColor: AppDesignSystem.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coupon Code Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppDesignSystem.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppDesignSystem.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รหัสคูปอง',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      decoration: InputDecoration(
                        hintText: 'เช่น SONGKRAN2026',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: _couponController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _couponController.clear(),
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      enabled: !_isApplyingCoupon,
                      onSubmitted: (_) => _applyCouponCode(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isApplyingCoupon ? null : _applyCouponCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isApplyingCoupon
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('ใช้'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Discount Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.local_offer),
            label: const Text('เลือกส่วนลด'),
            onPressed: _showDiscountDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Applied Discounts List
        if (widget.appliedDiscounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'ส่วนลดที่ใช้',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppDesignSystem.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.appliedDiscounts.map((discountData) {
            final discountId = discountData['discount_id'] ?? '';
            final discountAmount = (discountData['discount_amount'] ?? 0).toDouble();
            final couponCode = discountData['coupon_code'];
            final isCoupon = couponCode != null && couponCode.toString().isNotEmpty;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isCoupon)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'คูปอง',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                discountData['pos_discounts']?['name'] ?? 'ส่วนลด',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isCoupon)
                          Text(
                            'รหัส: $couponCode',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppDesignSystem.textSecondary,
                            ),
                          ),
                        Text(
                          '฿${discountAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      widget.onDiscountRemoved(discountId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ลบส่วนลดแล้ว')),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
