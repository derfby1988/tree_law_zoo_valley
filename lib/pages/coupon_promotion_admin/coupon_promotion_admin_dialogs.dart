import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';
import 'package:tree_law_zoo_valley/models/pos_discount_model.dart';
import 'package:tree_law_zoo_valley/models/pos_promotion_model.dart';
import 'package:tree_law_zoo_valley/services/permission_service.dart';
import 'package:tree_law_zoo_valley/utils/permission_helpers.dart';
import 'package:tree_law_zoo_valley/pages/promotion_form_page.dart';
import 'package:tree_law_zoo_valley/pages/promotion_product_picker_page.dart';
import 'package:tree_law_zoo_valley/pages/promotion_governance_page.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/coupon_promotion_admin_controller.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/dialogs/coupon_form_dialog.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/dialogs/promotion_form_dialog.dart';
import 'package:tree_law_zoo_valley/pages/coupon_promotion_admin/widgets/confirmation_dialog.dart';

mixin CouponPromotionAdminDialogs {
  CouponPromotionAdminController get controller;

  // =============================================
  // Coupon Dialogs
  // =============================================

  void showAddCouponDialog(BuildContext context) {
    showCouponDialog(context, title: 'เพิ่มคูปองใหม่');
  }

  void showEditCouponDialog(BuildContext context, PosDiscount coupon) {
    showCouponDialog(context, title: 'แก้ไขคูปอง', existing: coupon);
  }

  void showCouponDialog(BuildContext context, {required String title, PosDiscount? existing}) {
    showDialog(
      context: context,
      builder: (_) => CouponFormDialog(
        title: title,
        existing: existing,
        categories: controller.categories,
        products: controller.allProducts,
        onSubmit: (result) async {
          bool success;
          if (existing == null) {
            success = await controller.addCoupon(
              name: result.name,
              description: result.description,
              discountType: result.discountType,
              scope: result.scope,
              value: result.value,
              maxDiscount: result.maxDiscount,
              minAmount: result.minAmount,
              stackable: result.stackable,
              isActive: result.isActive,
              applicableCategoryIds: result.applicableCategoryIds,
              applicableProductIds: result.applicableProductIds,
              couponCode: result.couponCode,
              usageLimit: result.usageLimit,
              usageLimitPerCustomer: result.usageLimitPerCustomer,
              usageLimitPerDay: result.usageLimitPerDay,
              lifecycleStatus: result.lifecycleStatus,
              applicableChannels: result.applicableChannels,
              requireInStock: result.requireInStock,
              requireSufficientIngredients: result.requireSufficientIngredients,
              includePendingProcurement: result.includePendingProcurement,
              showInCouponTab: result.showInCouponTab,
              showInPosDiscountDialog: result.showInPosDiscountDialog,
              startAt: result.startAt,
              endAt: result.endAt,
            );
          } else {
            success = await controller.updateCoupon(
              id: existing.id,
              name: result.name,
              description: result.description,
              discountType: result.discountType,
              scope: result.scope,
              value: result.value,
              maxDiscount: result.maxDiscount,
              minAmount: result.minAmount,
              stackable: result.stackable,
              isActive: result.isActive,
              applicableCategoryIds: result.applicableCategoryIds,
              applicableProductIds: result.applicableProductIds,
              couponCode: result.couponCode,
              usageLimit: result.usageLimit,
              usageLimitPerCustomer: result.usageLimitPerCustomer,
              usageLimitPerDay: result.usageLimitPerDay,
              lifecycleStatus: result.lifecycleStatus,
              applicableChannels: result.applicableChannels,
              requireInStock: result.requireInStock,
              requireSufficientIngredients: result.requireSufficientIngredients,
              includePendingProcurement: result.includePendingProcurement,
              showInCouponTab: result.showInCouponTab,
              showInPosDiscountDialog: result.showInPosDiscountDialog,
              startAt: result.startAt,
              endAt: result.endAt,
            );
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(success
                ? (existing == null ? 'เพิ่มคูปองสำเร็จ' : 'แก้ไขคูปองสำเร็จ')
                : (existing == null ? 'เพิ่มคูปองไม่สำเร็จ' : 'แก้ไขคูปองไม่สำเร็จ')),
              backgroundColor: success ? AppDesignSystem.primary : AppDesignSystem.danger,
            ));
          }
        },
      ),
    );
  }

  // =============================================
  // Promotion Dialogs
  // =============================================

  void showAddPromotionDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PromotionFormPage(),
      ),
    ).then((result) {
      if (result == true) {
        controller.loadData();
      }
    });
  }

  void showEditPromotionDialog(BuildContext context, PosPromotion promotion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionFormPage(promotionId: promotion.id),
      ),
    ).then((result) {
      if (result == true) {
        controller.loadData();
      }
    });
  }

  void showPromotionDialog(BuildContext context, {required String title, PosPromotion? existing}) {
    showDialog(
      context: context,
      builder: (_) => PromotionFormDialog(
        title: title,
        existing: existing,
        coupons: controller.coupons,
        userGroups: controller.userGroups,
        products: controller.allProducts,
        onSubmit: (result) async {
          bool success;
          if (existing == null) {
            success = await controller.addPromotion(
              name: result.name,
              description: result.description,
              promotionType: result.promotionType,
              discountId: result.discountId,
              applicableUserGroupIds: result.applicableUserGroupIds,
              isActive: result.isActive,
              startAt: result.startAt,
              endAt: result.endAt,
              items: result.items,
            );
          } else {
            success = await controller.updatePromotion(
              id: existing.id,
              name: result.name,
              description: result.description,
              promotionType: result.promotionType,
              discountId: result.discountId,
              applicableUserGroupIds: result.applicableUserGroupIds,
              isActive: result.isActive,
              startAt: result.startAt,
              endAt: result.endAt,
              items: result.items,
            );
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(success
                ? (existing == null ? 'เพิ่มโปรโมชั่นสำเร็จ' : 'แก้ไขโปรโมชั่นสำเร็จ')
                : (existing == null ? 'เพิ่มโปรโมชั่นไม่สำเร็จ' : 'แก้ไขโปรโมชั่นไม่สำเร็จ')),
              backgroundColor: success ? AppDesignSystem.primary : AppDesignSystem.danger,
            ));
          }
        },
      ),
    );
  }

  // =============================================
  // Delete Confirmation
  // =============================================

  void showDeleteConfirmDialog(BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'ลบ',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // Analytics Dialogs
  // =============================================

  Future<void> selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? controller.analyticsStartDate ?? DateTime.now()
          : controller.analyticsEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isStartDate) {
        controller.setAnalyticsStartDate(picked);
      } else {
        controller.setAnalyticsEndDate(picked);
      }
    }
  }

  void showUsageDetails(BuildContext context, Map<String, dynamic> usage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(usage['name'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ประเภท: ${usage['type'] == 'coupon' ? 'คูปอง' : 'โปรโมชั่น'}'),
            const SizedBox(height: 8),
            Text('จำนวนครั้งที่ใช้: ${usage['usage_count']}'),
            const SizedBox(height: 8),
            Text('ส่วนลดรวม: ${(usage['total_discount'] ?? 0).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('จำนวนออเดอร์: ${usage['order_count'] ?? 0}'),
            const SizedBox(height: 8),
            Text('ลูกค้าที่ใช้: ${usage['unique_customers'] ?? 0}'),
            const SizedBox(height: 8),
            Text('ใช้ครั้งล่าสุด: ${usage['last_used_at'] != null ? '${DateTime.parse(usage['last_used_at']).day}/${DateTime.parse(usage['last_used_at']).month}/${DateTime.parse(usage['last_used_at']).year + 543}' : '-'}'),
            if (usage['avg_discount_per_use'] != null) ...[
              const SizedBox(height: 8),
              Text('ส่วนลดเฉลี่ยต่อครั้ง: ${usage['avg_discount_per_use'].toStringAsFixed(2)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showOrderDetails(context, usage);
            },
            child: const Text('ดูรายละเอียดออเดอร์'),
          ),
        ],
      ),
    );
  }

  void showOrderDetails(BuildContext context, Map<String, dynamic> usage) async {
    controller.isLoadingAnalytics = true;
    controller.notifyListeners();

    try {
      final orderDetails = await controller.getOrderDetailsForDiscount(usage);

      controller.isLoadingAnalytics = false;
      controller.notifyListeners();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'รายละเอียดออเดอร์: ${usage['name']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: orderDetails.isEmpty
                        ? const Center(child: Text('ไม่มีข้อมูลออเดอร์'))
                        : ListView.builder(
                            itemCount: orderDetails.length,
                            itemBuilder: (context, index) {
                              final order = orderDetails[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'ออเดอร์ #${order['order_number'] ?? 'N/A'}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '${(order['discount_amount'] ?? 0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'วันที่: ${order['order_date'] != null ? '${DateTime.parse(order['order_date']).day}/${DateTime.parse(order['order_date']).month}/${DateTime.parse(order['order_date']).year + 543}' : '-'}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                      if (order['customer_name'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text('ลูกค้า: ${order['customer_name']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                      if (order['product_name'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text('สินค้า: ${order['product_name']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                      if (order['applied_by_name'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text('ผู้ใช้: ${order['applied_by_name']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                ),
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
    } catch (e) {
      controller.isLoadingAnalytics = false;
      controller.notifyListeners();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  // =============================================
  // Expiry Promotion Creation
  // =============================================

  Future<void> createPromotionFromExpiringProduct(BuildContext context, Map<String, dynamic> product) async {
    final promotionMetadata = product['promotion_metadata'] as Map<String, dynamic>? ?? {};
    final suggestedDiscount = promotionMetadata['suggested_discount_percent'] as int? ?? 20;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionFormPage(
          initialName: 'โปรโมชั่นระบาย ${product['product_name']}',
          initialDescription: product['promotion_reason'] as String? ?? 'สินค้าใกล้หมดอายุ',
          initialDiscountPercent: suggestedDiscount.toDouble(),
          initialSelectedProducts: [product['product_id'] as String],
        ),
      ),
    );

    if (result == true) {
      controller.loadData();
      controller.loadExpiringData();
    }
  }

  Future<void> createPromotionFromExpiringIngredient(BuildContext context, Map<String, dynamic> ingredient) async {
    final promotionMetadata = ingredient['promotion_metadata'] as Map<String, dynamic>? ?? {};
    final suggestedDiscount = promotionMetadata['suggested_discount_percent'] as int? ?? 20;
    final affectedRecipes = promotionMetadata['affected_recipes'] as List<dynamic>? ?? [];

    final productIds = affectedRecipes
        .map((r) => r['output_product_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionFormPage(
          initialName: 'โปรโมชั่นระบายวัตถุดิบ ${ingredient['ingredient_name']}',
          initialDescription: ingredient['promotion_reason'] as String? ?? 'วัตถุดิบใกล้หมดอายุ',
          initialDiscountPercent: suggestedDiscount.toDouble(),
          initialSelectedProducts: productIds,
        ),
      ),
    );

    if (result == true) {
      controller.loadData();
      controller.loadExpiringData();
    }
  }

  // =============================================
  // Product Picker
  // =============================================

  Future<void> openProductPicker(BuildContext context) async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => const PromotionProductPickerPage(
          initiallySelectedProducts: [],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      debugPrint('Selected ${result.length} products for promotion');
    }
  }

  // =============================================
  // Governance Navigation
  // =============================================

  void navigateToGovernancePage(BuildContext context) async {
    try {
      final hasPermission = await PermissionService.hasPermission('governance_view');

      if (!hasPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('คุณไม่มีสิทธิเข้าถึงการควบคุมและตรวจสอบ'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PromotionGovernancePage(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // =============================================
  // Delete Actions (with snackbar feedback)
  // =============================================

  Future<void> deleteCoupon(BuildContext context, String couponId) async {
    final success = await controller.deleteCoupon(couponId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'ลบคูปองสำเร็จ' : 'ลบคูปองไม่สำเร็จ'),
        backgroundColor: success ? AppDesignSystem.primary : AppDesignSystem.danger,
      ));
    }
  }

  Future<void> deletePromotion(BuildContext context, String promotionId) async {
    final success = await controller.deletePromotion(promotionId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'ลบโปรโมชั่นสำเร็จ' : 'ลบโปรโมชั่นไม่สำเร็จ'),
        backgroundColor: success ? AppDesignSystem.primary : AppDesignSystem.danger,
      ));
    }
  }

  // =============================================
  // Analytics with error handling
  // =============================================

  Future<void> loadAnalyticsDataWithFeedback(BuildContext context) async {
    try {
      await controller.loadAnalyticsData();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }
}
