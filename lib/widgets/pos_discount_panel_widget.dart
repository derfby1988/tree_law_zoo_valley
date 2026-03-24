import 'package:flutter/material.dart';
import '../models/pos_discount_model.dart';
import '../services/pos_discount_service.dart';
import '../theme/app_design_system.dart';

class PosDiscountPanelWidget extends StatefulWidget {
  final Function(PosDiscount, double) onDiscountApplied;
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

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
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
      widget.onDiscountApplied(discount, discountAmount);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Discount Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.local_offer),
            label: const Text('เพิ่มส่วนลด'),
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
                        Text(
                          discountData['pos_discounts']?['name'] ?? 'ส่วนลด',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
