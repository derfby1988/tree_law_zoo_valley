import 'package:flutter/material.dart';
import '../../services/procurement_service.dart';

class TrackingTab extends StatefulWidget {
  const TrackingTab({super.key});

  @override
  State<TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends State<TrackingTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _purchaseOrders = [];
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
      final orders = await ProcurementService.getPurchaseOrders(status: 'sent'); // Only sent orders
      
      setState(() { 
        _purchaseOrders = orders;
        _isLoading = false; 
      });
    } catch (e) {
      setState(() { 
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; 
        _isLoading = false; 
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    var filtered = _purchaseOrders;
    
    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((order) {
        final orderNumber = (order['order_number'] as String? ?? '').toLowerCase();
        final supplierName = (order['supplier']?['name'] as String? ?? '').toLowerCase();
        return orderNumber.contains(query) || supplierName.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาเลขที่ PO หรือชื่อผู้ขาย...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          
          // PO list
          Expanded(
            child: _filteredOrders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = _filteredOrders[index];
                      return _buildPurchaseOrderCard(order);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'ไม่พบรายการที่ค้นหา'
                : 'ไม่มีใบสั่งซื้อที่กำลังดำเนินการ',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseOrderCard(Map<String, dynamic> order) {
    final supplier = order['supplier'] as Map<String, dynamic>? ?? {};
    final status = order['status'] as String? ?? 'draft';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final orderDate = order['order_date'] as String?;
    final expectedDate = order['expected_date'] as String?;
    
    Color statusColor;
    String statusText;
    switch (status) {
      case 'sent':
        statusColor = Colors.blue;
        statusText = 'รอการยืนยัน';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'ยืนยันแล้ว';
        break;
      case 'partial_received':
        statusColor = Colors.orange;
        statusText = 'รับบางส่วน';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _viewPurchaseOrder(order),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // PO Number and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['order_number'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '฿${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green[700],
                        ),
                      ),
                      if (orderDate != null)
                        Text(
                          _formatDate(orderDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Supplier and expected date
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      supplier['name'] ?? 'ไม่ระบุผู้ขาย',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  if (expectedDate != null) ...[
                    Icon(Icons.event, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'คาดวัน: ${_formatDate(expectedDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year + 543}'; // Convert to Buddhist year
    } catch (e) {
      return dateString;
    }
  }

  void _viewPurchaseOrder(Map<String, dynamic> order) {
    // TODO: Implement view purchase order details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ดูรายละเอียด PO: ${order['order_number']}')),
    );
  }
}
