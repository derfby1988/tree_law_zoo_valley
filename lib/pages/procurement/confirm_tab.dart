import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class ConfirmTab extends StatefulWidget {
  const ConfirmTab({super.key});

  @override
  State<ConfirmTab> createState() => _ConfirmTabState();
}

class _ConfirmTabState extends State<ConfirmTab> {
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
        // Search
        Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ค้นหาออเดอร์ที่รอการยืนยัน...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        // Data table
        Expanded(
          child: _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('ไม่มีออเดอร์ที่รอการยืนยัน', style: TextStyle(color: Colors.grey)),
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
                        title: Text('ออเดอร์ #${order['id'] ?? ''}'),
                        subtitle: Text('สถานะ: ${order['status'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (PermissionService.canAccessActionSync('procurement_confirm_view'))
                              IconButton(
                                icon: Icon(Icons.visibility),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_confirm_view',
                                  'ดูรายละเอียด',
                                  () => _viewOrder(order),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_confirm_approve'))
                              IconButton(
                                icon: Icon(Icons.check_circle, color: Colors.green),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_confirm_approve',
                                  'อนุมัติออเดอร์',
                                  () => _approveOrder(order),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_confirm_reject'))
                              IconButton(
                                icon: Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_confirm_reject',
                                  'ปฏิเสธออเดอร์',
                                  () => _rejectOrder(order),
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

  void _viewOrder(Map<String, dynamic> order) {
    // TODO: Implement view order details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ดูรายละเอียดออเดอร์ยังไม่พร้อมใช้งาน')),
    );
  }

  void _approveOrder(Map<String, dynamic> order) {
    // TODO: Implement approve order
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์อนุมัติออเดอร์ยังไม่พร้อมใช้งาน')),
    );
  }

  void _rejectOrder(Map<String, dynamic> order) {
    // TODO: Implement reject order
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ปฏิเสธออเดอร์ยังไม่พร้อมใช้งาน')),
    );
  }
}
