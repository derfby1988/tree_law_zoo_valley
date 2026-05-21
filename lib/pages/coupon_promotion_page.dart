import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_design_system.dart';
import '../services/pos_promotion_service.dart';
import '../services/daily_coupon_share_token_service.dart';
import '../models/daily_coupon_share_token_model.dart';
import '../services/pos_discount_service.dart';
import '../services/daily_coupon_entry_service.dart';
import '../services/pos_coupon_qr_service.dart';
import '../services/user_group_service.dart';
import '../models/pos_promotion_model.dart';
import '../models/pos_discount_model.dart';

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
  Map<String, DailyCouponShareToken> _activeShareTokens = {};
  String? _errorMessage;
  Color _userGroupColor = AppDesignSystem.primary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Map<String, dynamic> _getTargetingRule(PosDiscount coupon) {
    return coupon.targetingRule;
  }

  bool _isDailyCoupon(PosDiscount coupon) {
    final rule = _getTargetingRule(coupon);
    return rule['daily_unified_enabled'] == true;
  }

  Widget _buildDailyBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareTokenStatusCard({
    required PosDiscount coupon,
    DailyCouponShareToken? token,
  }) {
    if (!DailyCouponShareTokenService.isGroupShareable(coupon)) {
      return const SizedBox.shrink();
    }

    final currentToken = token;
    if (currentToken == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.group_off_outlined, color: Colors.black54, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยังไม่มี share token สำหรับคูปองนี้ กด “แชร์ให้สมาชิก” เพื่อสร้าง token และติดตามจำนวนที่ใช้แล้ว/เหลือได้ทันที',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

    final progress = currentToken.maxUses <= 0
        ? 0.0
        : (currentToken.usesCount / currentToken.maxUses).clamp(0.0, 1.0);
    final statusColor = currentToken.isActive ? Colors.green : Colors.red;
    final statusLabel = currentToken.isActive ? 'ใช้งานได้' : 'หมดอายุ/ถูกยกเลิก';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'สถานะการแชร์',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ใช้แล้ว ${currentToken.usesCount}/${currentToken.maxUses} • เหลือ ${currentToken.remainingUses}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDailyBadge(
                label: 'สมาชิก ${currentToken.groupSize} คน',
                icon: Icons.groups_2_outlined,
                color: AppDesignSystem.primary,
              ),
              _buildDailyBadge(
                label: 'หมดอายุ ${_formatDate(currentToken.expiresAt)}',
                icon: Icons.schedule_outlined,
                color: Colors.indigo,
              ),
              if (currentToken.lastUsedAt != null)
                _buildDailyBadge(
                  label: 'ใช้ล่าสุด ${_formatDate(currentToken.lastUsedAt!)}',
                  icon: Icons.history,
                  color: Colors.teal,
                ),
            ],
          ),
          if ((currentToken.lastUsedMemberIdentifier ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'สมาชิกล่าสุด: ${currentToken.lastUsedMemberIdentifier}',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Future<Map<String, DailyCouponShareToken>> _loadActiveShareTokens(List<PosDiscount> coupons) async {
    final shareableCoupons = coupons.where(DailyCouponShareTokenService.isGroupShareable).toList();
    if (shareableCoupons.isEmpty) {
      return {};
    }

    final results = await Future.wait(
      shareableCoupons.map((coupon) async {
        final token = await DailyCouponShareTokenService.getActiveShareToken(coupon.id);
        return MapEntry(coupon.id, token);
      }),
    );

    return {
      for (final entry in results)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<void> _shareDailyCoupon(PosDiscount coupon) async {
    String shareText = coupon.couponCode ?? coupon.id;
    DailyCouponShareToken? token;

    if (DailyCouponShareTokenService.isGroupShareable(coupon)) {
      token = await DailyCouponShareTokenService.createOrRefreshShareToken(coupon: coupon);
      if (token != null) {
        shareText = DailyCouponShareTokenService.buildShareClipboardText(token, coupon: coupon);
      }
    }

    if (!mounted) return;
    if (token != null) {
      setState(() {
        _activeShareTokens = {
          ..._activeShareTokens,
          coupon.id: token!,
        };
      });
    }

    await Clipboard.setData(ClipboardData(text: shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          token != null
              ? 'คัดลอกข้อมูลแชร์สำหรับ ${coupon.name} แล้ว • ใช้แล้ว ${token.usesCount}/${token.maxUses} เหลือ ${token.remainingUses}'
              : 'คัดลอกข้อมูลแชร์สำหรับ ${coupon.name} แล้ว',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showDailyHistorySheet(PosDiscount coupon) async {
    final start = DateTime.now().subtract(const Duration(days: 7));
    final end = DateTime.now();
    final activeToken = _activeShareTokens[coupon.id];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                DailyCouponEntryService.getEntryLogs(
                  discountId: coupon.id,
                  startDate: start,
                  endDate: end,
                  limit: 100,
                ),
                PosDiscountService.getUsageAnalytics(
                  startDate: start,
                  endDate: end,
                  discountId: coupon.id,
                  limit: 100,
                ),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Text('ไม่สามารถโหลดประวัติ: ${snapshot.error ?? 'ไม่ทราบสาเหตุ'}'),
                  );
                }
                final entryLogs = (snapshot.data![0] as List).cast<Map<String, dynamic>>();
                final posLogs = (snapshot.data![1] as List).cast<Map<String, dynamic>>();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Text(
                        'ประวัติการใช้พื้นที่ / ส่วนลด (${coupon.name})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (DailyCouponShareTokenService.isGroupShareable(coupon)) ...[
                        _buildShareTokenStatusCard(coupon: coupon, token: activeToken),
                        const SizedBox(height: 16),
                      ],
                      const Text('เข้า/ออกพื้นที่ (Gate)', style: TextStyle(fontWeight: FontWeight.w600)),
                      if (entryLogs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('ยังไม่มีประวัติในช่วง 7 วันล่าสุด', style: TextStyle(color: Colors.black54)),
                        )
                      else
                        ...entryLogs.map((log) => _buildEntryHistoryTile(log)),
                      const SizedBox(height: 16),
                      const Text('การใช้ส่วนลด (POS)', style: TextStyle(fontWeight: FontWeight.w600)),
                      if (posLogs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('ยังไม่มีการใช้ส่วนลดในช่วง 7 วันล่าสุด', style: TextStyle(color: Colors.black54)),
                        )
                      else
                        ...posLogs.map((log) => _buildPosHistoryTile(log)),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEntryHistoryTile(Map<String, dynamic> log) {
    final scannedAt = DateTime.tryParse(log['scanned_at']?.toString() ?? '');
    final member = log['member_identifier'] ?? '-';
    final area = log['entry_area'] ?? '-';
    final status = (log['status'] ?? 'pending').toString();
    final direction = (log['direction'] ?? 'enter').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(direction == 'enter' ? 'เข้า' : 'ออก', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                scannedAt != null ? _formatDate(scannedAt) : '-',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('สมาชิก: $member', style: const TextStyle(fontSize: 12)),
          Text('พื้นที่: $area', style: const TextStyle(fontSize: 12)),
          Text('สถานะ: ${status.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          if ((log['reason_code'] ?? '').toString().isNotEmpty)
            Text('เหตุผล: ${log['reason_code']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildPosHistoryTile(Map<String, dynamic> log) {
    final appliedAt = DateTime.tryParse(log['applied_at']?.toString() ?? '');
    final amount = (log['discount_amount'] ?? 0).toString();
    final orderId = log['order_id']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('POS', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                appliedAt != null ? _formatDate(appliedAt) : '-',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Order: $orderId', style: const TextStyle(fontSize: 12)),
          Text('ลดไป: $amount บาท', style: const TextStyle(fontSize: 12, color: Colors.green)),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // โหลดสีกลุ่มผู้ใช้งานปัจจุบันก่อน
      final userGroup = await UserGroupService.getCurrentUserGroup();
      final groupColor = userGroup?.colorValue ?? AppDesignSystem.primary;
      final userGroupId = userGroup?.id;
      
      // ดึงคูปองที่แสดงในแถบคูปองเท่านั้น (filter ตาม visibility)
      final coupons = await PosDiscountService.getVisibleCouponsForCouponTab(userGroupId: userGroupId);
      final promotions = await PosPromotionService.getAllPromotions();
      final activeShareTokens = await _loadActiveShareTokens(coupons);
      
      debugPrint('Loaded ${coupons.length} coupons (visible in coupon tab)');
      debugPrint('Loaded ${promotions.length} promotions');

      setState(() {
        _coupons = coupons;
        _promotions = promotions;
        _activeShareTokens = activeShareTokens;
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
              : Colors.white.withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีคูปองที่ใช้ได้',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
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
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีโปรโมชั่นที่ใช้ได้',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
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
              promotion: promotion,
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
    final isDailyCoupon = _isDailyCoupon(coupon);
    final rule = _getTargetingRule(coupon);
    final audience = (rule['coupon_audience'] ?? 'individual').toString();
    final isGroup = audience == 'group';
    final groupSize = rule['group_size'];
    final entryArea = (rule['entry_area_name'] ?? '-').toString();
    final activeToken = _activeShareTokens[coupon.id];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                    color: AppDesignSystem.primary.withValues(alpha: 0.1),
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
            if (isDailyCoupon) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDailyBadge(
                    label: isGroup ? 'รายวัน • รายกลุ่ม' : 'รายวัน • รายบุคคล',
                    icon: isGroup ? Icons.groups_2 : Icons.person,
                    color: AppDesignSystem.primary,
                  ),
                  if (isGroup && groupSize != null)
                    _buildDailyBadge(
                      label: 'สมาชิก ${groupSize ?? '-'} คน',
                      icon: Icons.badge_outlined,
                      color: AppDesignSystem.secondary,
                    ),
                  _buildDailyBadge(
                    label: 'พื้นที่: $entryArea',
                    icon: Icons.place_outlined,
                    color: Colors.indigo,
                  ),
                ],
              ),
              if (isGroup) ...[
                const SizedBox(height: 10),
                _buildShareTokenStatusCard(coupon: coupon, token: activeToken),
              ],
            ],
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
                        color: AppDesignSystem.primary.withValues(alpha: 0.2),
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
            if (isDailyCoupon && isGroup)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareDailyCoupon(coupon),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('แชร์ให้สมาชิก'),
                ),
              ),
            if (isDailyCoupon && isGroup) const SizedBox(height: 8),
            if (isDailyCoupon)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showDailyHistorySheet(coupon),
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('ดูประวัติการใช้พื้นที่'),
                ),
              ),
            if (isDailyCoupon) const SizedBox(height: 8),
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
    required PosPromotion promotion,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final promotionCode = promotion.code ?? 'PROMO_${promotion.id.substring(0, 8).toUpperCase()}';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
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
              ],
            ),
            
            // QR Code Display
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 16,
                        color: color,
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
                  Center(
                    child: PosCouponQRService.buildPromotionQRCode(
                      promotion: promotion,
                      size: 140,
                      showCode: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // รหัสโปรโมชัน
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      promotionCode,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
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

}
