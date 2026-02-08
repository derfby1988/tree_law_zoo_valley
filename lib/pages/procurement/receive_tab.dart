import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _receivings = [];
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
        _receivings = []; 
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
              hintText: 'ค้นหารายการรับสินค้า...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        // Data table
        Expanded(
          child: _receivings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('ไม่มีรายการรับสินค้า', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _receivings.length,
                  itemBuilder: (context, index) {
                    final receiving = _receivings[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('รับสินค้า #${receiving['id'] ?? ''}'),
                        subtitle: Text('สถานะ: ${receiving['status'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (PermissionService.canAccessActionSync('procurement_receive_inspect'))
                              IconButton(
                                icon: Icon(Icons.search),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_receive_inspect',
                                  'ตรวจสอบสินค้า',
                                  () => _inspectReceiving(receiving),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_receive_confirm'))
                              IconButton(
                                icon: Icon(Icons.inventory_2, color: Colors.green),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_receive_confirm',
                                  'ยืนยันรับของ',
                                  () => _confirmReceiving(receiving),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_receive_return'))
                              IconButton(
                                icon: Icon(Icons.keyboard_return, color: Colors.orange),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_receive_return',
                                  'คืนสินค้า',
                                  () => _returnReceiving(receiving),
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

  void _inspectReceiving(Map<String, dynamic> receiving) {
    // TODO: Implement inspect receiving
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ตรวจสอบสินค้ายังไม่พร้อมใช้งาน')),
    );
  }

  void _confirmReceiving(Map<String, dynamic> receiving) {
    // TODO: Implement confirm receiving
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ยืนยันรับของยังไม่พร้อมใช้งาน')),
    );
  }

  void _returnReceiving(Map<String, dynamic> receiving) {
    // TODO: Implement return receiving
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์คืนสินค้ายังไม่พร้อมใช้งาน')),
    );
  }
}
