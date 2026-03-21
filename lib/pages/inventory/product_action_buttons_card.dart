import 'package:flutter/material.dart';
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
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จัดการข้อมูลสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (PermissionService.canAccessActionSync('inventory_products_category'))
                  _buildActionButton('ประเภท', Colors.blue, Icons.folder, () => 
                    checkPermissionAndExecute(context, 'inventory_products_category', 'จัดการประเภท', onShowCategoryDialog)),
                if (PermissionService.canAccessActionSync('inventory_products_unit'))
                  _buildActionButton('หน่วยนับ', Colors.teal, Icons.scale, () => 
                    checkPermissionAndExecute(context, 'inventory_products_unit', 'จัดการหน่วยนับ', onShowUnitDialog)),
                if (PermissionService.canAccessActionSync('inventory_products_add'))
                  _buildActionButton('เพิ่มสินค้า/วัตถุดิบ', Colors.orange, Icons.add_circle, () => 
                    checkPermissionAndExecute(context, 'inventory_products_add', 'เพิ่มสินค้า/วัตถุดิบ', onShowAddProductDialog)),
                if (PermissionService.canAccessActionSync('inventory_products_produce'))
                  _buildActionButton('ผลิตสินค้า', Colors.purple, Icons.factory, () => 
                    checkPermissionAndExecute(context, 'inventory_products_produce', 'ผลิตสินค้า', onShowProduceProductDialog)),
              ],
            ),
            SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey[300]),
            SizedBox(height: 14),
            Text('เครื่องมือจัดซื้อจัดจ้าง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (PermissionService.canAccessTabSync('procurement_purchase'))
                  _buildActionButton('สั่งซื้อสินค้า', Colors.green, Icons.shopping_cart, onNavigateToProcurementPurchase),
                if (PermissionService.canAccessTabSync('procurement_tracking'))
                  _buildActionButton('ติดตาม PO', Colors.indigo, Icons.track_changes, onNavigateToProcurementTracking),
                if (PermissionService.canAccessTabSync('procurement_receive'))
                  _buildActionButton('รับสินค้า', Colors.brown, Icons.inventory, onNavigateToProcurementReceive),
                if (PermissionService.canAccessActionSync('procurement_purchase_approve'))
                  _buildActionButton('อนุมัติ PO', Colors.deepPurple, Icons.verified, onNavigateToProcurementApprove),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
