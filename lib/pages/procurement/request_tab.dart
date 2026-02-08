import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class RequestTab extends StatefulWidget {
  const RequestTab({super.key});

  @override
  State<RequestTab> createState() => _RequestTabState();
}

class _RequestTabState extends State<RequestTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _requests = [];
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
        _requests = []; 
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
                    hintText: 'ค้นหาใบขอซื้อ...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (PermissionService.canAccessActionSync('procurement_request_create'))
                ElevatedButton.icon(
                  onPressed: () => checkPermissionAndExecute(
                    context,
                    'procurement_request_create',
                    'สร้างใบขอซื้อ',
                    _showCreateRequestDialog,
                  ),
                  icon: Icon(Icons.add),
                  label: Text('สร้างใบขอซื้อ'),
                ),
            ],
          ),
        ),
        // Data table
        Expanded(
          child: _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.request_page, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('ไม่มีใบขอซื้อ', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('ใบขอซื้อ #${request['id'] ?? ''}'),
                        subtitle: Text('สถานะ: ${request['status'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (PermissionService.canAccessActionSync('procurement_request_edit'))
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_request_edit',
                                  'แก้ไขใบขอซื้อ',
                                  () => _editRequest(request),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_request_delete'))
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_request_delete',
                                  'ลบใบขอซื้อ',
                                  () => _deleteRequest(request),
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

  void _showCreateRequestDialog() {
    // TODO: Implement create request dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์สร้างใบขอซื้อยังไม่พร้อมใช้งาน')),
    );
  }

  void _editRequest(Map<String, dynamic> request) {
    // TODO: Implement edit request
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์แก้ไขใบขอซื้อยังไม่พร้อมใช้งาน')),
    );
  }

  void _deleteRequest(Map<String, dynamic> request) {
    // TODO: Implement delete request
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ลบใบขอซื้อยังไม่พร้อมใช้งาน')),
    );
  }
}
