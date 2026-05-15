import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';
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
      floatingActionButton: ctrl.selectedTabIndex == 5
          ? null
          : FloatingActionButton(
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
            ),
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
      default:
        return const SizedBox.shrink();
    }
  }
}
