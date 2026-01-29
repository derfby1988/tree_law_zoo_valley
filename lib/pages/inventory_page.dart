import 'package:flutter/material.dart';
import 'inventory/overview_tab.dart';
import 'inventory/product_tab.dart';
import 'inventory/adjustment_tab.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.white),
            SizedBox(width: 8),
            Text('คลังสินค้า', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Color(0xFF2E7D32),
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'สถิติ / รายงาน'),
            Tab(icon: Icon(Icons.inventory), text: 'จัดการสินค้า'),
            Tab(icon: Icon(Icons.build), text: 'ปรับปรุงคลัง'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OverviewTab(),
          ProductTab(),
          AdjustmentTab(),
        ],
      ),
    );
  }
}
