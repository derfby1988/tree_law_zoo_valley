import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';
import '../services/pos_promotion_service.dart';
import '../services/pos_discount_service.dart';
import '../services/pos_coupon_qr_service.dart';
import '../services/user_group_service.dart';
import '../models/pos_promotion_model.dart';
import '../models/pos_discount_model.dart';
import '../models/user_group_model.dart';

class CouponPromotionPage extends StatefulWidget {
  const CouponPromotionPage({super.key});

  @override
  State<CouponPromotionPage> createState() => _CouponPromotionPageState();
}

class _CouponPromotionPageState extends State<CouponPromotionPage> {
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  List<PosDiscount> _coupons = [];
  List<PosPromotion> _promotions = [];
  String? _errorMessage;
  Color _userGroupColor = AppDesignSystem.primary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ดึงข้อมูลทั้งหมด (ไม่กรองตามวันที่) เพื่อให้เห็นข้อมูลที่มี
      final coupons = await PosDiscountService.getAllDiscounts();
      final promotions = await PosPromotionService.getAllPromotions();
      
      debugPrint('Loaded ${coupons.length} coupons');
      debugPrint('Loaded ${promotions.length} promotions');
      
      // โหลดสีกลุ่มผู้ใช้งานปัจจุบัน
      final userGroup = await UserGroupService.getCurrentUserGroup();
      final groupColor = userGroup?.colorValue ?? AppDesignSystem.primary;

      setState(() {
        _coupons = coupons;
        _promotions = promotions;
        _userGroupColor = groupColor;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คูปอง & โปรโมชั่น'),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppDesignSystem.secondary,
                        AppDesignSystem.primary,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tab buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                label: 'คูปอง',
                                index: 0,
                                isSelected: _selectedTabIndex == 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTabButton(
                                label: 'โปรโมชั่น',
                                index: 1,
                                isSelected: _selectedTabIndex == 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: _buildTabContent(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppDesignSystem.primary, width: 2)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppDesignSystem.primary : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildCouponsTab();
      case 1:
        return _buildPromotionsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCouponsTab() {
    if (_coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีคูปองที่ใช้ได้',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _coupons.map((coupon) {
        final discountText = coupon.discountType == 'percentage'
            ? '${coupon.value.toStringAsFixed(0)}%'
            : '${coupon.value.toStringAsFixed(0)} บาท';

        // ใช้รหัสคูปองที่ผู้ใช้กำหนดเอง ถ้าไม่มีให้แสดงข้อความแจ้ง
        final displayCode = coupon.couponCode?.isNotEmpty == true
            ? coupon.couponCode!
            : 'ไม่มีรหัส';

        return Column(
          children: [
            _buildCouponCard(
              coupon: coupon,
              code: displayCode,
              title: coupon.name,
              description: coupon.description ?? '',
              discount: discountText,
              expiryDate: coupon.endAt != null
                  ? _formatDate(coupon.endAt!)
                  : 'ไม่มีกำหนด',
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPromotionsTab() {
    if (_promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีโปรโมชั่นที่ใช้ได้',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _promotions.map((promotion) {
        return Column(
          children: [
            _buildPromotionCard(
              title: promotion.name,
              description: promotion.description ?? 'โปรโมชั่นพิเศษ',
              icon: _getPromotionIcon(promotion.promotionType),
              color: _userGroupColor,
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  IconData _getPromotionIcon(String promotionType) {
    switch (promotionType) {
      case 'bundle':
        return Icons.shopping_bag;
      case 'seasonal':
        return Icons.calendar_today;
      case 'buy_x_get_y':
        return Icons.local_offer;
      default:
        return Icons.celebration;
    }
  }

  Widget _buildCouponCard({
    required PosDiscount coupon,
    required String code,
    required String title,
    required String description,
    required String discount,
    required String expiryDate,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    discount,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รหัสคูปอง',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'หมดอายุ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expiryDate,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // QR Code Display (สำหรับคูปองที่มีรหัส)
            if (coupon.couponCode?.isNotEmpty == true)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppDesignSystem.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 16,
                              color: AppDesignSystem.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'QR Code สำหรับสแกน',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // QR Code
                        Center(
                          child: PosCouponQRService.buildCouponQRCode(
                            coupon: coupon,
                            size: 160,
                            showCode: false, // ไม่แสดงรหัสซ้ำ
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('คัดลอก: $code'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'คัดลอกรหัส',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required String code,
    required String title,
    required String usedDate,
    required String amount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'รหัส: $code',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usedDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
