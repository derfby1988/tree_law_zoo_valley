import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class OrderTab extends StatefulWidget {
  const OrderTab({super.key});

  @override
  State<OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<OrderTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      // TODO: Implement actual data loading
      await Future.delayed(Duration(seconds: 1));
      setState(() { 
        _orders = []; 
        _isLoading = false; 
      });
    } catch (e) {
      setState(() { 
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; 
        _isLoading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: Text('ลองใหม่'),
            ),
          ],
        ),
      ));
    }

    return Column(
      children: [
        // Search and actions
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาใบสั่งซื้อ...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (PermissionService.canAccessActionSync('procurement_order_create'))
                ElevatedButton.icon(
                  onPressed: () => checkPermissionAndExecute(
                    context,
                    'procurement_order_create',
                    'สร้างใบสั่งซื้อ',
                    _showCreateOrderDialog,
                  ),
                  icon: Icon(Icons.description),
                  label: Text('สร้างใบสั่งซื้อ'),
                ),
            ],
          ),
        ),
        // Data table
        Expanded(
          child: _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('ไม่มีใบสั่งซื้อ', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('ใบสั่งซื้อ #${order['id'] ?? ''}'),
                        subtitle: Text('สถานะ: ${order['status'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (PermissionService.canAccessActionSync('procurement_order_edit'))
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_order_edit',
                                  'แก้ไขใบสั่งซื้อ',
                                  () => _editOrder(order),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_order_send'))
                              IconButton(
                                icon: Icon(Icons.send),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_order_send',
                                  'ส่งใบสั่งซื้อ',
                                  () => _sendOrder(order),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_order_delete'))
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_order_delete',
                                  'ลบใบสั่งซื้อ',
                                  () => _deleteOrder(order),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateOrderDialog() {
    // TODO: Implement create order dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์สร้างใบสั่งซื้อยังไม่พร้อมใช้งาน')),
    );
  }

  void _editOrder(Map<String, dynamic> order) {
    // TODO: Implement edit order
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์แก้ไขใบสั่งซื้อยังไม่พร้อมใช้งาน')),
    );
  }

  void _sendOrder(Map<String, dynamic> order) {
    // TODO: Implement send order
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ส่งใบสั่งซื้อยังไม่พร้อมใช้งาน')),
    );
  }

  void _deleteOrder(Map<String, dynamic> order) {
    // TODO: Implement delete order
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ลบใบสั่งซื้อยังไม่พร้อมใช้งาน')),
    );
  }
}
