import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class ProductActionButtonsCard extends StatelessWidget {
  final VoidCallback onShowCategoryDialog;
  final VoidCallback onShowUnitDialog;
  final VoidCallback onShowAddProductDialog;
  final VoidCallback onShowProduceProductDialog;
  final VoidCallback onNavigateToProcurement;

  const ProductActionButtonsCard({
    super.key,
    required this.onShowCategoryDialog,
    required this.onShowUnitDialog,
    required this.onShowAddProductDialog,
    required this.onShowProduceProductDialog,
    required this.onNavigateToProcurement,
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
                  _buildActionButton('เพิ่มสินค้า', Colors.orange, Icons.add_circle, () => 
                    checkPermissionAndExecute(context, 'inventory_products_add', 'เพิ่มสินค้า', onShowAddProductDialog)),
                if (PermissionService.canAccessActionSync('inventory_products_produce'))
                  _buildActionButton('ผลิตสินค้า', Colors.purple, Icons.factory, () => 
                    checkPermissionAndExecute(context, 'inventory_products_produce', 'ผลิตสินค้า', onShowProduceProductDialog)),
                if (PermissionService.canAccessPageSync('procurement'))
                  _buildActionButton('สั่งซื้อสินค้า', Colors.green, Icons.shopping_cart, onNavigateToProcurement),
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
