import 'package:flutter/material.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class ShipTab extends StatefulWidget {
  const ShipTab({super.key});

  @override
  State<ShipTab> createState() => _ShipTabState();
}

class _ShipTabState extends State<ShipTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _shipments = [];
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
        _shipments = []; 
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
                    hintText: 'ค้นหาการจัดส่ง...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (PermissionService.canAccessActionSync('procurement_ship_create'))
                ElevatedButton.icon(
                  onPressed: () => checkPermissionAndExecute(
                    context,
                    'procurement_ship_create',
                    'สร้างใบส่งของ',
                    _showCreateShipmentDialog,
                  ),
                  icon: Icon(Icons.local_shipping),
                  label: Text('สร้างใบส่งของ'),
                ),
            ],
          ),
        ),
        // Data table
        Expanded(
          child: _shipments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('ไม่มีการจัดส่ง', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _shipments.length,
                  itemBuilder: (context, index) {
                    final shipment = _shipments[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('ใบส่งของ #${shipment['id'] ?? ''}'),
                        subtitle: Text('สถานะ: ${shipment['status'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (PermissionService.canAccessActionSync('procurement_ship_track'))
                              IconButton(
                                icon: Icon(Icons.gps_fixed),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_ship_track',
                                  'ติดตามการส่ง',
                                  () => _trackShipment(shipment),
                                ),
                              ),
                            if (PermissionService.canAccessActionSync('procurement_ship_complete'))
                              IconButton(
                                icon: Icon(Icons.done_all, color: Colors.green),
                                onPressed: () => checkPermissionAndExecute(
                                  context,
                                  'procurement_ship_complete',
                                  'ยืนยันการส่ง',
                                  () => _completeShipment(shipment),
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

  void _showCreateShipmentDialog() {
    // TODO: Implement create shipment dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์สร้างใบส่งของยังไม่พร้อมใช้งาน')),
    );
  }

  void _trackShipment(Map<String, dynamic> shipment) {
    // TODO: Implement track shipment
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ติดตามการส่งยังไม่พร้อมใช้งาน')),
    );
  }

  void _completeShipment(Map<String, dynamic> shipment) {
    // TODO: Implement complete shipment
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ฟีเจอร์ยืนยันการส่งยังไม่พร้อมใช้งาน')),
    );
  }
}
