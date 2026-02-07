import 'package:flutter/material.dart';
import 'inventory/overview_tab.dart';
import 'inventory/product_tab.dart';
import 'inventory/adjustment_tab.dart';
import 'inventory/recipe_tab.dart';
import '../services/permission_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoadingPermissions = true;

  // Tab definitions with permission IDs
  static const _allTabs = [
    {'id': 'inventory_overview', 'label': 'สถิติ / รายงาน', 'icon': Icons.dashboard},
    {'id': 'inventory_products', 'label': 'จัดการสินค้า', 'icon': Icons.inventory},
    {'id': 'inventory_adjustment', 'label': 'ปรับปรุงคลัง', 'icon': Icons.build},
    {'id': 'inventory_recipe', 'label': 'สูตรอาหาร', 'icon': Icons.restaurant_menu},
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
      case 'inventory_overview':
        return OverviewTab();
      case 'inventory_products':
        return ProductTab();
      case 'inventory_adjustment':
        return AdjustmentTab();
      case 'inventory_recipe':
        return RecipeTab();
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
              Icon(Icons.inventory_2, color: Colors.white),
              SizedBox(width: 8),
              Text('คลังสินค้า', style: TextStyle(color: Colors.white)),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
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
            Icon(Icons.inventory_2, color: Colors.white),
            SizedBox(width: 8),
            Text('คลังสินค้า', style: TextStyle(color: Colors.white)),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF1E3A8A),
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
