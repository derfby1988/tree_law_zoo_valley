import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class ProductActionButtonsCard extends StatelessWidget {
  final VoidCallback onShowCategoryDialog;
  final VoidCallback onShowUnitDialog;
  final VoidCallback onShowAddProductDialog;
  final VoidCallback onShowProduceProductDialog;
  final VoidCallback onNavigateToProcurementPurchase;
  final VoidCallback onNavigateToProcurementTracking;
  final VoidCallback onNavigateToProcurementReceive;
  final VoidCallback onNavigateToProcurementApprove;

  const ProductActionButtonsCard({
    super.key,
    required this.onShowCategoryDialog,
    required this.onShowUnitDialog,
    required this.onShowAddProductDialog,
    required this.onShowProduceProductDialog,
    required this.onNavigateToProcurementPurchase,
    required this.onNavigateToProcurementTracking,
    required this.onNavigateToProcurementReceive,
    required this.onNavigateToProcurementApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppDesignSystem.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'จัดการข้อมูลสินค้า',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            Wrap(
              spacing: AppDesignSystem.spacingSm,
              runSpacing: AppDesignSystem.spacingSm,
              children: [
                if (PermissionService.canAccessActionSync('inventory_products_category'))
                  _buildActionButton('ประเภท', AppDesignSystem.secondary, Icons.folder, () => 
                    checkPermissionAndExecute(context, 'inventory_products_category', 'จัดการประเภท', onShowCategoryDialog)),
                if (PermissionService.canAccessActionSync('inventory_products_unit'))
                  _buildActionButton('หน่วยนับ', AppDesignSystem.primary, Icons.scale, () => 
                    checkPermissionAndExecute(context, 'inventory_products_unit', 'จัดการหน่วยนับ', onShowUnitDialog)),
                if (PermissionService.canAccessActionSync('inventory_products_add'))
                  _buildActionButton('เพิ่มสินค้า/วัตถุดิบ', AppDesignSystem.warning, Icons.add_circle, () => 
                    checkPermissionAndExecute(context, 'inventory_products_add', 'เพิ่มสินค้า/วัตถุดิบ', onShowAddProductDialog)),
                if (PermissionService.canAccessActionSync('inventory_products_produce'))
                  _buildActionButton('ผลิตสินค้า', AppDesignSystem.secondary, Icons.factory, () => 
                    checkPermissionAndExecute(context, 'inventory_products_produce', 'ผลิตสินค้า', onShowProduceProductDialog)),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingLg),
            const Divider(height: 1, color: AppDesignSystem.border),
            const SizedBox(height: AppDesignSystem.spacingLg),
            Text(
              'เครื่องมือจัดซื้อจัดจ้าง',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            Wrap(
              spacing: AppDesignSystem.spacingSm,
              runSpacing: AppDesignSystem.spacingSm,
              children: [
                if (PermissionService.canAccessTabSync('procurement_purchase'))
                  _buildActionButton('สั่งซื้อสินค้า', AppDesignSystem.success, Icons.shopping_cart, onNavigateToProcurementPurchase),
                if (PermissionService.canAccessTabSync('procurement_tracking'))
                  _buildActionButton('ติดตาม PO', AppDesignSystem.secondary, Icons.track_changes, onNavigateToProcurementTracking),
                if (PermissionService.canAccessTabSync('procurement_receive'))
                  _buildActionButton('รับสินค้า', AppDesignSystem.warning, Icons.inventory, onNavigateToProcurementReceive),
                if (PermissionService.canAccessActionSync('procurement_purchase_approve'))
                  _buildActionButton('อนุมัติ PO', AppDesignSystem.primary, Icons.verified, onNavigateToProcurementApprove),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingLg, vertical: AppDesignSystem.spacingMd),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
