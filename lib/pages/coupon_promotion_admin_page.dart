import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';
import 'package:tree_law_zoo_valley/models/pos_discount_model.dart';
import 'package:tree_law_zoo_valley/services/inventory_service.dart';
import 'package:tree_law_zoo_valley/utils/permission_helpers.dart';
import 'package:tree_law_zoo_valley/widgets/promotion_formula_tab_widget.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/coupon_promotion_admin_controller.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/coupon_promotion_admin_dialogs.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/coupons_tab_widget.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/promotions_tab_widget.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/expiring_tab_widget.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/expiring_product_card.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/expiring_ingredient_card.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/analytics_tab_widget.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/daily_coupons_tab_widget.dart';
import 'package:tree_law_zoo_valley/pages/daily_coupon_gate_scanner_page.dart';

class CouponPromotionAdminPage extends StatelessWidget {
  const CouponPromotionAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CouponPromotionAdminController()..loadData(),
      child: const _CouponPromotionAdminView(),
    );
  }
}

class _CouponPromotionAdminView extends StatefulWidget {
  const _CouponPromotionAdminView();

  @override
  State<_CouponPromotionAdminView> createState() => _CouponPromotionAdminViewState();
}

class _CouponPromotionAdminViewState extends State<_CouponPromotionAdminView>
    with CouponPromotionAdminDialogs {
  static const int _dailyCouponTabIndex = 6;

  @override
  CouponPromotionAdminController get controller =>
      context.read<CouponPromotionAdminController>();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CouponPromotionAdminController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการคูปอง & โปรโมชั่น'),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield),
            tooltip: 'การควบคุมและตรวจสอบ',
            onPressed: () => navigateToGovernancePage(context),
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'วิเคราะห์การใช้งาน',
            onPressed: () => controller.selectTab(4),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Gate Scanner',
            onPressed: () => checkPermissionAndExecute(
              context,
              'coupon_promotion_daily_gate_scanner',
              'เปิด Gate Scanner',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyCouponGateScannerPage()),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ctrl.isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.primary),
              ),
            )
          : ctrl.errorMessage != null
              ? _buildErrorView(ctrl)
              : _buildContent(ctrl),
      floatingActionButton: _buildFloatingAction(ctrl),
    );
  }

  Widget _buildErrorView(CouponPromotionAdminController ctrl) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            ctrl.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ctrl.loadData(),
            child: const Text('ลองใหม่'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => InventoryService.clearAllCache(),
            icon: const Icon(Icons.refresh),
            label: const Text('ล้างแคช'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(CouponPromotionAdminController ctrl) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppDesignSystem.secondary, AppDesignSystem.primary],
        ),
      ),
      child: Column(
        children: [
          _buildTabBar(ctrl),
          Expanded(child: _buildTabContent(ctrl)),
        ],
      ),
    );
  }

  Widget _buildTabBar(CouponPromotionAdminController ctrl) {
    final labels = [
      'คูปอง', 'โปรโมชั่น', 'สินค้าใกล้หมดอายุ',
      'วัตถุดิบใกล้หมดอายุ', 'วิเคราะห์การใช้งาน', 'ตั้งค่าสูตรแนะนำ',
      'คูปองรายวัน',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final index = entry.key;
          final isSelected = index == ctrl.selectedTabIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < labels.length - 1 ? 12 : 0,
              ),
              child: GestureDetector(
                onTap: () => controller.selectTab(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(color: AppDesignSystem.primary, width: 2)
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppDesignSystem.primary : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(CouponPromotionAdminController ctrl) {
    switch (ctrl.selectedTabIndex) {
      case 0:
        return CouponsTabWidget(
          coupons: ctrl.coupons,
          formatDate: ctrl.formatDate,
          onEdit: (coupon) => checkPermissionAndExecute(
            context,
            'coupon_promotion_edit_coupon',
            'แก้ไขคูปอง',
            () => showEditCouponDialog(context, coupon),
          ),
          onDelete: (coupon) => checkPermissionAndExecute(
            context,
            'coupon_promotion_delete_coupon',
            'ลบคูปอง',
            () => showDeleteConfirmDialog(
              context,
              title: 'ลบคูปอง',
              message: 'คุณแน่ใจหรือว่าต้องการลบคูปอง "${coupon.name}"',
              onConfirm: () => deleteCoupon(context, coupon.id),
            ),
          ),
        );
      case 1:
        return PromotionsTabWidget(
          promotions: ctrl.promotions,
          formatDate: ctrl.formatDate,
          getTypeLabel: ctrl.getPromotionTypeLabel,
          onEdit: (promotion) => checkPermissionAndExecute(
            context,
            'coupon_promotion_edit_promotion',
            'แก้ไขโปรโมชั่น',
            () => showEditPromotionDialog(context, promotion),
          ),
          onDelete: (promotion) => checkPermissionAndExecute(
            context,
            'coupon_promotion_delete_promotion',
            'ลบโปรโมชั่น',
            () => showDeleteConfirmDialog(
              context,
              title: 'ลบโปรโมชั่น',
              message: 'คุณแน่ใจหรือว่าต้องการลบโปรโมชั่น "${promotion.name}"',
              onConfirm: () => deletePromotion(context, promotion.id),
            ),
          ),
        );
      case 2:
        return ExpiringTabWidget(
          items: ctrl.expiringProducts,
          isLoading: ctrl.isLoadingExpiry,
          expiryFilter: ctrl.expiryFilter,
          emptyMessage: 'ไม่มีสินค้าใกล้หมดอายุ',
          emptySubMessage: 'ในช่วง ${ctrl.expiryFilter}',
          emptyIcon: Icons.inventory_2_outlined,
          onFilterChanged: (value) => controller.setExpiryFilter(value),
          cardBuilder: (context, item) => ExpiringProductCard(
            product: item,
            onCreatePromotion: () => createPromotionFromExpiringProduct(context, item),
          ),
        );
      case 3:
        return ExpiringTabWidget(
          items: ctrl.expiringIngredients,
          isLoading: ctrl.isLoadingExpiry,
          expiryFilter: ctrl.expiryFilter,
          emptyMessage: 'ไม่มีวัตถุดิบใกล้หมดอายุ',
          emptySubMessage: 'ในช่วง ${ctrl.expiryFilter}',
          emptyIcon: Icons.kitchen_outlined,
          onFilterChanged: (value) => controller.setExpiryFilter(value),
          cardBuilder: (context, item) => ExpiringIngredientCard(
            ingredient: item,
            onCreatePromotion: () => createPromotionFromExpiringIngredient(context, item),
          ),
        );
      case 4:
        return AnalyticsTabWidget(
          summary: ctrl.analyticsSummary,
          usageData: ctrl.usageData,
          isLoading: ctrl.isLoadingAnalytics,
          startDate: ctrl.analyticsStartDate,
          endDate: ctrl.analyticsEndDate,
          onSelectDate: (isStart) => selectDate(context, isStart),
          onApplyFilter: () => loadAnalyticsDataWithFeedback(context),
          onUsageTap: (usage) => showUsageDetails(context, usage),
        );
      case 5:
        return const PromotionFormulaTabWidget();
      case _dailyCouponTabIndex:
        return DailyCouponsTabWidget(
          coupons: ctrl.dailyCoupons,
          getTargetingRule: ctrl.getTargetingRule,
          formatDate: ctrl.formatDate,
          selectedCoupon: ctrl.selectedDailyCoupon,
          onSelectCoupon: controller.selectDailyCouponForHistory,
          isLoadingHistory: ctrl.isLoadingDailyHistory,
          dailyEntryLogs: ctrl.dailyEntryLogs,
          dailyPosHistory: ctrl.dailyPosHistory,
          dailyEntrySummary: ctrl.dailyEntrySummary,
          onRefreshHistory: () async => controller.loadDailyCouponHistory(),
          historyRangeDays: ctrl.dailyHistoryRangeDays,
          onHistoryRangeChanged: controller.setDailyHistoryRange,
          shareToken: ctrl.selectedDailyShareToken,
          isLoadingShareToken: ctrl.isLoadingDailyShareToken,
          onRefreshShareToken: (coupon) async {
            await controller.createOrRefreshDailyCouponShareToken(coupon: coupon, forceNew: true);
          },
          dailyAlerts: ctrl.dailyAlerts,
          onViewDetail: (coupon) => _showDailyCouponInfo(context, coupon),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFloatingAction(CouponPromotionAdminController ctrl) {
    if (ctrl.selectedTabIndex == 5) return null;
    if (ctrl.selectedTabIndex == _dailyCouponTabIndex) {
      return FloatingActionButton.extended(
        onPressed: () => checkPermissionAndExecute(
          context,
          'coupon_promotion_daily_add',
          'สร้างคูปองรายวัน',
          () => showCouponDialog(
            context,
            title: 'สร้างคูปองรายวัน',
            defaultDailyMode: true,
          ),
        ),
        backgroundColor: AppDesignSystem.primary,
        icon: const Icon(Icons.qr_code_2),
        label: const Text('คูปองรายวัน'),
      );
    }

    return FloatingActionButton(
      onPressed: () {
        if (ctrl.selectedTabIndex == 0) {
          checkPermissionAndExecute(
            context,
            'coupon_promotion_add_coupon',
            'เพิ่มคูปอง',
            () => showAddCouponDialog(context),
          );
        } else {
          checkPermissionAndExecute(
            context,
            'coupon_promotion_add_promotion',
            'เพิ่มโปรโมชั่น',
            () => showAddPromotionDialog(context),
          );
        }
      },
      backgroundColor: AppDesignSystem.primary,
      child: const Icon(Icons.add),
    );
  }

  void _showDailyCouponInfo(BuildContext context, PosDiscount coupon) {
    final rule = controller.getTargetingRule(coupon);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DailyCouponInfoSheet(
        coupon: coupon,
        rule: rule,
        formatDate: controller.formatDate,
      ),
    );
  }
}

class _DailyCouponInfoSheet extends StatelessWidget {
  const _DailyCouponInfoSheet({
    required this.coupon,
    required this.rule,
    required this.formatDate,
  });

  final PosDiscount coupon;
  final Map<String, dynamic> rule;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    final audience = (rule['coupon_audience'] ?? 'individual').toString();
    final isGroup = audience == 'group';
    final groupSize = rule['group_size'];
    final entryArea = (rule['entry_area_name'] ?? '-').toString();
    final entryLimit = rule['entry_limit_per_day'];
    final discountLimit = rule['discount_limit_per_day'];
    final sameDay = rule['entry_requires_same_day'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              coupon.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              coupon.description ?? 'ไม่มีคำอธิบาย',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoTile(
                  icon: Icons.badge_outlined,
                  title: 'ประเภทคูปอง',
                  value: isGroup ? 'รายกลุ่ม' : 'รายบุคคล',
                ),
                if (isGroup && groupSize != null)
                  _InfoTile(
                    icon: Icons.groups_2,
                    title: 'จำนวนสมาชิก',
                    value: '${groupSize ?? '-'} คน',
                  ),
                _InfoTile(
                  icon: Icons.place_outlined,
                  title: 'พื้นที่',
                  value: entryArea,
                ),
                _InfoTile(
                  icon: Icons.qr_code,
                  title: 'รหัสคูปอง',
                  value: coupon.couponCode ?? 'ไม่ระบุ',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.door_front_door_outlined,
                    title: 'เข้าได้ต่อวัน',
                    value: entryLimit != null ? '$entryLimit ครั้ง' : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.percent,
                    title: 'ลดได้ต่อวัน',
                    value: discountLimit != null ? '$discountLimit ครั้ง' : '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.play_circle_outline,
                    title: 'เริ่ม',
                    value: coupon.startAt != null ? formatDate(coupon.startAt!) : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.stop_circle_outlined,
                    title: 'สิ้นสุด',
                    value: coupon.endAt != null ? formatDate(coupon.endAt!) : 'ไม่มีกำหนด',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FlagBadge(
                  icon: Icons.lock_clock,
                  label: sameDay ? 'ต้องใช้สิทธิ์ภายในวันเดียว' : 'ใช้สิทธิ์ข้ามวันได้',
                ),
                _FlagBadge(
                  icon: Icons.layers,
                  label: coupon.stackable ? 'ซ้อนกับส่วนลดอื่นได้' : 'ไม่อนุญาตให้ซ้อน',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'กติกาพื้นฐาน',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _RuleRow(label: 'สถานะ', value: coupon.lifecycleStatus),
            _RuleRow(
              label: 'เริ่มใช้งาน',
              value: coupon.startAt != null ? formatDate(coupon.startAt!) : '-',
            ),
            _RuleRow(
              label: 'สิ้นสุด',
              value: coupon.endAt != null ? formatDate(coupon.endAt!) : 'ไม่มีกำหนด',
            ),
            _RuleRow(
              label: 'Visibility (แท็บลูกค้า)',
              value: coupon.showInCouponTab ? 'เปิดแสดง' : 'ซ่อน',
            ),
            _RuleRow(
              label: 'Visibility (POS)',
              value: coupon.showInPosDiscountDialog ? 'เปิดแสดง' : 'ซ่อน',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppDesignSystem.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[800]),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
