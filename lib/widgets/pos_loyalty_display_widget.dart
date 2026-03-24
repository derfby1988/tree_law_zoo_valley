import 'package:flutter/material.dart';
import '../models/pos_loyalty_model.dart';
import '../services/pos_loyalty_service.dart';
import '../theme/app_design_system.dart';

class PosLoyaltyDisplayWidget extends StatefulWidget {
  final String? customerId;
  final double orderAmount;
  final Function(double) onPointsRedeemed;

  const PosLoyaltyDisplayWidget({
    super.key,
    this.customerId,
    required this.orderAmount,
    required this.onPointsRedeemed,
  });

  @override
  State<PosLoyaltyDisplayWidget> createState() => _PosLoyaltyDisplayWidgetState();
}

class _PosLoyaltyDisplayWidgetState extends State<PosLoyaltyDisplayWidget> {
  bool _isLoading = false;
  PosCustomerLoyaltyWallet? _wallet;
  PosLoyaltyProgram? _program;
  double _earnedPoints = 0;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _loadLoyaltyInfo();
    }
  }

  @override
  void didUpdateWidget(PosLoyaltyDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      if (widget.customerId != null) {
        _loadLoyaltyInfo();
      } else {
        setState(() {
          _wallet = null;
          _program = null;
          _earnedPoints = 0;
        });
      }
    }
    if (oldWidget.orderAmount != widget.orderAmount) {
      _calculateEarnedPoints();
    }
  }

  Future<void> _loadLoyaltyInfo() async {
    if (widget.customerId == null) return;

    setState(() => _isLoading = true);

    try {
      // Get active loyalty program
      final programs = await PosLoyaltyService.getActiveLoyaltyPrograms();
      if (programs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final program = programs.first;
      final wallet = await PosLoyaltyService.createOrGetWallet(
        widget.customerId!,
        program.id,
      );

      setState(() {
        _program = program;
        _wallet = wallet;
        _isLoading = false;
      });

      _calculateEarnedPoints();
    } catch (e) {
      debugPrint('Error loading loyalty info: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateEarnedPoints() {
    if (_program == null) return;
    final points = widget.orderAmount * _program!.pointsPerBaht;
    setState(() => _earnedPoints = points);
  }

  void _showRedeemDialog() {
    if (_wallet == null) return;

    final availablePoints = _wallet!.availablePoints;
    final redeemController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'แลกแต้ม',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignSystem.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('แต้มที่มี:'),
                        Text(
                          '${availablePoints.toStringAsFixed(0)} แต้ม',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('อัตราแลก:'),
                        Text(
                          '1 แต้ม = ฿1',
                          style: TextStyle(color: AppDesignSystem.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: redeemController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'จำนวนแต้มที่ต้องการแลก',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final points = double.tryParse(redeemController.text) ?? 0;
                      if (points <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณากรอกจำนวนแต้ม')),
                        );
                        return;
                      }

                      if (points > availablePoints) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('แต้มไม่เพียงพอ')),
                        );
                        return;
                      }

                      final success = await PosLoyaltyService.redeemPoints(
                        walletId: _wallet!.id,
                        points: points,
                        reason: 'แลกจากการซื้อ',
                      );

                      if (success && mounted) {
                        widget.onPointsRedeemed(points);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('แลกแต้ม ${points.toStringAsFixed(0)} แต้มสำเร็จ'),
                            backgroundColor: AppDesignSystem.primary,
                          ),
                        );
                        Navigator.pop(context);
                        _loadLoyaltyInfo();
                      }
                    },
                    child: const Text('แลกแต้ม'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customerId == null || _wallet == null) {
      if (_isLoading) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppDesignSystem.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignSystem.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignSystem.primary.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, size: 14, color: AppDesignSystem.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Text(
                  '${_wallet!.availablePoints.toStringAsFixed(0)} แต้ม',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(width: 6),
                Text(
                  '(+${_earnedPoints.toStringAsFixed(0)})',
                  style: TextStyle(fontSize: 11, color: AppDesignSystem.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: _wallet!.availablePoints > 0 ? _showRedeemDialog : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                backgroundColor: AppDesignSystem.primary,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: Size.zero,
              ),
              child: const Text('แลก', style: TextStyle(fontSize: 11, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
