import 'package:flutter/material.dart';
import 'inventory/overview_tab.dart';
import 'inventory/product_tab.dart';
import 'inventory/ingredient_tab.dart';
import 'inventory/adjustment_tab.dart';
import 'inventory/recipe_tab.dart';
import 'inventory/warehouse_management_page.dart';
import 'inventory/expiry_summary_page.dart';
import 'inventory/reports_tab.dart';
import '../services/permission_service.dart';
import '../utils/responsive_helper.dart';

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
    {'id': 'inventory_overview', 'label': 'สถิติ', 'icon': Icons.dashboard},
    {'id': 'inventory_products', 'label': 'สินค้า', 'icon': Icons.inventory},
    {'id': 'inventory_adjustment', 'label': 'คลัง', 'icon': Icons.build},
    {'id': 'inventory_warehouse', 'label': 'สถานที่เก็บ', 'icon': Icons.warehouse},
    {'id': 'inventory_ingredients', 'label': 'วัตถุดิบ', 'icon': Icons.restaurant_menu},
    {'id': 'inventory_recipe', 'label': 'สูตรอาหาร', 'icon': Icons.dinner_dining},
    {'id': 'inventory_reports', 'label': 'รายงาน', 'icon': Icons.insights},
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
      case 'inventory_ingredients':
        return IngredientTab();
      case 'inventory_adjustment':
        return AdjustmentTab();
      case 'inventory_warehouse':
        return WarehouseManagementPage();
      case 'inventory_recipe':
        return RecipeTab();
      case 'inventory_reports':
        return const ReportsTab();
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
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            tooltip: 'สรุปวันหมดอายุ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpirySummaryPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: ResponsiveHelper.isMobile(context) ? true : false,
          labelStyle: TextStyle(
            fontSize: ResponsiveHelper.isMobile(context) ? 12 : 13,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: ResponsiveHelper.isMobile(context) ? 11 : 12,
          ),
          tabs: _visibleTabs.map((tab) => Tab(
            icon: Icon(tab['icon'] as IconData),
            text: tab['label'] as String,
            iconMargin: const EdgeInsets.only(bottom: 6),
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
