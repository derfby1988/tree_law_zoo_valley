import 'package:flutter/material.dart';
import 'procurement/request_tab.dart';
import 'procurement/order_tab.dart';
import 'procurement/confirm_tab.dart';
import 'procurement/ship_tab.dart';
import 'procurement/receive_tab.dart';
import '../services/permission_service.dart';

class ProcurementPage extends StatefulWidget {
  const ProcurementPage({super.key});

  @override
  State<ProcurementPage> createState() => _ProcurementPageState();
}

class _ProcurementPageState extends State<ProcurementPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoadingPermissions = true;

  // Tab definitions with permission IDs
  static const _allTabs = [
    {'id': 'procurement_request', 'label': 'ขอซื้อ', 'icon': Icons.request_page},
    {'id': 'procurement_order', 'label': 'วางใบสั่งซื้อ', 'icon': Icons.description},
    {'id': 'procurement_confirm', 'label': 'Confirm รับออเดอร์', 'icon': Icons.check_circle},
    {'id': 'procurement_ship', 'label': 'ส่งสินค้า', 'icon': Icons.local_shipping},
    {'id': 'procurement_receive', 'label': 'รับสินค้า', 'icon': Icons.inventory_2},
  ];

  List<Map<String, dynamic>> _visibleTabs = [];

  @override
  void initState() {
    super.initState();
    _loadTabPermissions();
  }

  Future<void> _loadTabPermissions() async {
    await PermissionService.loadPermissions();
    
    final visible = <Map<String, dynamic>>[];
    for (final tab in _allTabs) {
      if (PermissionService.canAccessTabSync(tab['id'] as String)) {
        visible.add(tab);
      }
    }
    // ถ้าไม่มี tab ที่อนุญาตเลย ให้แสดงทั้งหมด (กรณียังไม่ได้ตั้งค่า)
    if (visible.isEmpty) {
      visible.addAll(_allTabs);
    }

    setState(() {
      _visibleTabs = visible;
      _tabController = TabController(length: visible.length, vsync: this);
      _isLoadingPermissions = false;
    });
  }

  Widget _buildTabContent(String tabId) {
    switch (tabId) {
      case 'procurement_request':
        return RequestTab();
      case 'procurement_order':
        return OrderTab();
      case 'procurement_confirm':
        return ConfirmTab();
      case 'procurement_ship':
        return ShipTab();
      case 'procurement_receive':
        return ReceiveTab();
      default:
        return Center(child: Text('ไม่พบหน้านี้'));
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions || _tabController == null) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.white),
              SizedBox(width: 8),
              Text('ระบบสั่งซื้อ', style: TextStyle(color: Colors.white)),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10B981), Color(0xFF047857)],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.white),
            SizedBox(width: 8),
            Text('ระบบสั่งซื้อ', style: TextStyle(color: Colors.white)),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF10B981),
                Color(0xFF047857),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: _visibleTabs.map((tab) => Tab(
            icon: Icon(tab['icon'] as IconData),
            text: tab['label'] as String,
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _visibleTabs.map((tab) => _buildTabContent(tab['id'] as String)).toList(),
      ),
    );
  }
}
