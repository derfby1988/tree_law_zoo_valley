import 'package:flutter/material.dart';

import '../pages/inventory/tax_rules_admin_page.dart';
import '../pages/inventory/stock_movement_page.dart';
import '../pages/inventory_page.dart';
import '../pages/pos_page.dart';
import '../pages/reports_page.dart';
import '../pages/table_management_page.dart';
import '../pages/HRM.dart';
import '../services/permission_service.dart';

class HomeEndDrawer extends StatelessWidget {
  const HomeEndDrawer({super.key, required this.drawerWidth});

  final double drawerWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: (details) {
        if (details.velocity.pixelsPerSecond.dx > 500) {
          Navigator.pop(context);
        }
      },
      child: Container(
        width: drawerWidth,
        color: const Color(0xFF005EBE).withValues(alpha: 0.3),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: const Color(0xFF005EBE).withValues(alpha: 0.5),
              ),
              child: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            if (PermissionService.canAccessPageSync('pos'))
              _item(
                context,
                title: 'ขาย/ POS',
                icon: Icons.point_of_sale,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosPage())),
              ),
            if (PermissionService.canAccessPageSync('table_management'))
              _item(
                context,
                title: 'โซน & ที่นั่ง',
                icon: Icons.table_restaurant,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TableManagementPage())),
              ),
            if (PermissionService.canAccessPageSync('inventory'))
              _item(
                context,
                title: 'คลังสินค้า',
                icon: Icons.inventory,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryPage())),
              ),
            _item(context, title: 'คูปอง/โปรโมชั่น', icon: Icons.inventory),
            _item(context, title: 'โฮมสเตย์', icon: Icons.bed),
            _item(context, title: 'ปล่อยเช่า / ยืม / คืน', icon: Icons.bed),
            _item(context, title: 'ลูกค้า / CRM / สมาชิก', icon: Icons.people),
            _item(context, title: 'เจ้าหนี้ / พาร์ทเนอร์', icon: Icons.handshake),
            _item(context, title: 'ที่จอดรถ', icon: Icons.handshake),
            _item(context, title: 'รายงานยอด', icon: Icons.assessment),
            _item(context, title: 'เอกสาร / ผลการทำงาน', icon: Icons.assessment),
            if (PermissionService.canAccessPageSync('user_groups'))
              _item(
                context,
                title: 'HRM',
                icon: Icons.person,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HRMPage())),
              ),
            if (PermissionService.canAccessPageSync('tax_rules_admin'))
              _item(
                context,
                title: 'จัดการกฎภาษี',
                icon: Icons.rule,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaxRulesAdminPage())),
              ),
            if (PermissionService.canAccessPageSync('stock_movement'))
              _item(
                context,
                title: 'Stock Movement',
                icon: Icons.swap_vert,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockMovementPage())),
              ),
            if (PermissionService.canAccessPageSync('reports'))
              _item(
                context,
                title: 'รายงาน/แจ้งเตือน',
                icon: Icons.bar_chart,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
              ),
            _item(context, title: 'ประวัติการเข้าระบบ', icon: Icons.history),
            _item(context, title: 'Database Test', icon: Icons.storage),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required String title,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      leading: Icon(icon, color: Colors.white),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) onTap();
      },
    );
  }
}
