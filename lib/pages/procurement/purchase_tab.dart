import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/procurement_service.dart';
import '../../services/permission_service.dart';
import '../../services/inventory_service.dart';
import 'dialogs/cancel_po_dialog.dart';
import 'dialogs/send_po_dialog.dart';
import 'dialogs/approve_po_dialog.dart';

class PurchaseTab extends StatefulWidget {
  const PurchaseTab({super.key});

  @override
  State<PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends State<PurchaseTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _purchaseOrders = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  String _selectedStatus = 'all';
  String? _selectedSupplierId;

  // Permission checks
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canSend = false;
  bool _canApprove5000 = false;
  bool _canApprove50000 = false;
  bool _canApproveUnlimited = false;
  bool _canCancel = false;
  String? _currentUserId;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
    _loadUserInfo();
    _loadPermissions();
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  List<Widget> _buildPriorityBadges(
    Map<String, dynamic> order,
    String status,
    double totalAmount,
  ) {
    final badges = <Widget>[];
    final expectedDateRaw = order['expected_date']?.toString();
    final expectedDate = expectedDateRaw == null ? null : DateTime.tryParse(expectedDateRaw);

    if (totalAmount >= 50000) {
      badges.add(_buildPriorityBadge('ยอดสูง', Colors.deepPurple, Icons.paid));
    }

    if (expectedDate != null && ['sent', 'confirmed', 'partial_received'].contains(status)) {
      final today = DateTime.now();
      final dueDate = DateTime(expectedDate.year, expectedDate.month, expectedDate.day);
      final nowDate = DateTime(today.year, today.month, today.day);
      final daysDiff = dueDate.difference(nowDate).inDays;

      if (daysDiff < 0) {
        badges.add(_buildPriorityBadge('เกินกำหนดรับ ${daysDiff.abs()} วัน', Colors.red, Icons.warning_amber_rounded));
      } else if (daysDiff <= 2) {
        badges.add(_buildPriorityBadge('ใกล้ถึงกำหนดรับ', Colors.orange, Icons.schedule));
      }
    }

    if (badges.isEmpty) {
      return const [];
    }

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: badges,
      ),
    ];
  }

  Widget _buildPriorityBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    await PermissionService.loadPermissions();
    if (!mounted) return;
    
    setState(() {
      _canCreate = PermissionService.canAccessActionSync('procurement_purchase_create');
      _canEdit = PermissionService.canAccessActionSync('procurement_purchase_edit');
      _canDelete = PermissionService.canAccessActionSync('procurement_purchase_delete');
      _canSend = PermissionService.canAccessActionSync('procurement_purchase_send');
      _canApprove5000 = PermissionService.canAccessActionSync('procurement_purchase_approve_5000');
      _canApprove50000 = PermissionService.canAccessActionSync('procurement_purchase_approve_50000');
      _canApproveUnlimited = PermissionService.canAccessActionSync('procurement_purchase_approve_unlimited');
      _canCancel = PermissionService.canAccessActionSync('procurement_purchase_cancel');
    });
  }

  Future<void> _loadUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() {
      _currentUserId = user.id;
      _userRole = user.userMetadata?['role'] as String? ?? 'store_manager';
    });
  }

  Future<void> _loadData() async {
    setState(() {
      if (_hasLoadedOnce) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ProcurementService.getPurchaseOrders(),
        ProcurementService.getSuppliers(),
        InventoryService.getProducts(),
      ]);
      
      setState(() { 
        _purchaseOrders = results[0];
        _suppliers = results[1];
        _products = results[2];
        _isLoading = false;
        _isRefreshing = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      setState(() { 
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; 
        _isLoading = false;
        _isRefreshing = false;
        _hasLoadedOnce = true;
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
    
    // Apply status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((order) => order['status'] == _selectedStatus).toList();
    }
    
    // Apply supplier filter
    if (_selectedSupplierId != null) {
      filtered = filtered.where((order) => order['supplier_id'] == _selectedSupplierId).toList();
    }
    
    return filtered;
  }

  double get _filteredTotalAmount {
    return _filteredOrders.fold<double>(
      0,
      (sum, order) => sum + ((order['total_amount'] as num?)?.toDouble() ?? 0),
    );
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
          // Filter Header - ใช้ SingleChildScrollView เพื่อป้องกันล้นจอ
          Container(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาเลขที่ PO หรือชื่อผู้ขาย...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Dropdowns ใช้ Wrap แทน LayoutBuilder เพื่อป้องกัน overflow
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('status_$_selectedStatus'),
                          initialValue: _selectedStatus,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'สถานะ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                            DropdownMenuItem(value: 'draft', child: Text('ฉบับร่าง')),
                            DropdownMenuItem(value: 'sent', child: Text('ส่งแล้ว')),
                            DropdownMenuItem(value: 'confirmed', child: Text('ยืนยันแล้ว')),
                            DropdownMenuItem(value: 'partial_received', child: Text('รับบางส่วน')),
                            DropdownMenuItem(value: 'completed', child: Text('เสร็จสมบูรณ์')),
                            DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
                          ],
                          onChanged: (value) => setState(() => _selectedStatus = value ?? 'all'),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('supplier_${_selectedSupplierId ?? 'all'}'),
                          initialValue: _selectedSupplierId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'ผู้ขาย',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                            ..._suppliers.map((supplier) => DropdownMenuItem(
                                  value: supplier['id'],
                                  child: Text(
                                    supplier['name'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (value) => setState(() => _selectedSupplierId = value),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Status chips - horizontal scroll
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusChip('all', 'ทั้งหมด'),
                        SizedBox(width: 8),
                        _buildStatusChip('draft', 'ฉบับร่าง'),
                        SizedBox(width: 8),
                        _buildStatusChip('sent', 'ส่งแล้ว'),
                        SizedBox(width: 8),
                        _buildStatusChip('confirmed', 'ยืนยันแล้ว'),
                        SizedBox(width: 8),
                        _buildStatusChip('partial_received', 'รับบางส่วน'),
                        SizedBox(width: 8),
                        _buildStatusChip('completed', 'เสร็จสมบูรณ์'),
                        SizedBox(width: 8),
                        _buildStatusChip('cancelled', 'ยกเลิก'),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'ผลการกรอง: ${_filteredOrders.length} รายการ | มูลค่ารวม ฿${_filteredTotalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isRefreshing
                ? _buildLoadingSkeletonList()
                : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _buildOrderCard(order);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_canCreate)
            FloatingActionButton.small(
              heroTag: 'createPO',
              onPressed: _showCreatePurchaseOrderDialog,
              child: Icon(Icons.add),
              tooltip: 'สร้าง PO',
            ),
          SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'refresh',
            onPressed: _loadData,
            child: Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasActiveFilters =
        _searchController.text.isNotEmpty || _selectedStatus != 'all' || _selectedSupplierId != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              hasActiveFilters ? 'ไม่พบรายการที่ค้นหา' : 'ยังไม่มีรายการสั่งซื้อ',
              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'ลองล้างตัวกรองหรือเปลี่ยนคำค้นหาเพื่อดูรายการเพิ่มเติม'
                  : _canCreate
                      ? 'เริ่มต้นด้วยการสร้างใบสั่งซื้อฉบับแรก'
                      : 'บัญชีนี้ยังไม่มีสิทธิ์สร้าง PO กรุณาติดต่อผู้ดูแลระบบ',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            if (hasActiveFilters)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedStatus = 'all';
                    _selectedSupplierId = null;
                  });
                },
                icon: Icon(Icons.filter_alt_off),
                label: Text('ล้างตัวกรอง'),
              )
            else if (_canCreate)
              ElevatedButton.icon(
                onPressed: _showCreatePurchaseOrderDialog,
                icon: Icon(Icons.add),
                label: Text('สร้างใบสั่งซื้อแรก'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final supplier = order['supplier'] as Map<String, dynamic>? ?? {};
    final status = order['status'] as String? ?? 'draft';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final orderDate = order['order_date'] as String?;
    
    Color statusColor;
    String statusText;
    switch (status) {
      case 'draft':
        statusColor = Colors.grey;
        statusText = 'ฉบับร่าง';
        break;
      case 'sent':
        statusColor = Colors.blue;
        statusText = 'ส่งแล้ว';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'ยืนยันแล้ว';
        break;
      case 'partial_received':
        statusColor = Colors.orange;
        statusText = 'รับบางส่วน';
        break;
      case 'completed':
        statusColor = Colors.purple;
        statusText = 'เสร็จสมบูรณ์';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ยกเลิก';
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
              Builder(
                builder: (context) {
                  final badges = _buildPriorityBadges(order, status, totalAmount);
                  if (badges.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...badges,
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
              
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 400;
                  return Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          supplier['name'] ?? 'ไม่ระบุผู้ขาย',
                          style: TextStyle(color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildOrderActions(order, status, isCompact),
                    ],
                  );
                },
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
    final poId = order['id']?.toString();
    if (poId == null || poId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัส PO')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: ProcurementService.getPurchaseOrderDetail(poId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final detail = snapshot.data;
            if (detail == null) {
              return AlertDialog(
                title: const Text('รายละเอียดใบสั่งซื้อ'),
                content: const Text('ไม่สามารถโหลดรายละเอียด PO ได้'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ปิด'),
                  ),
                ],
              );
            }

            final lines = detail['lines'] as List<dynamic>? ?? [];
            final statusValue = detail['status']?.toString() ?? '-';
            final expectedDate = detail['expected_date']?.toString();
            final createdAt = detail['created_at']?.toString();
            final sentAt = detail['sent_at']?.toString();
            final approvedAt = detail['approved_at']?.toString();
            final cancelledAt = detail['cancelled_at']?.toString();
            final cancellationReason = detail['cancellation_reason']?.toString();
            return AlertDialog(
              title: Text('รายละเอียด ${detail['order_number'] ?? ''}'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ผู้ขาย: ${detail['supplier']?['name'] ?? '-'}'),
                            const SizedBox(height: 4),
                            Text('สถานะ: $statusValue'),
                            const SizedBox(height: 4),
                            Text('ยอดรวม: ฿${((detail['total_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
                            if (expectedDate != null) ...[
                              const SizedBox(height: 4),
                              Text('กำหนดรับ: ${_formatDate(expectedDate)}'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ข้อมูลการดำเนินการ', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            if (createdAt != null) Text('สร้างเมื่อ: ${_formatDateTime(createdAt)}'),
                            if (sentAt != null) Text('ส่งเมื่อ: ${_formatDateTime(sentAt)}'),
                            if (approvedAt != null) Text('อนุมัติเมื่อ: ${_formatDateTime(approvedAt)}'),
                            if (cancelledAt != null) Text('ยกเลิกเมื่อ: ${_formatDateTime(cancelledAt)}'),
                          ],
                        ),
                      ),
                      if ((cancellationReason?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Text('เหตุผลยกเลิก: $cancellationReason'),
                        ),
                      ],
                      if ((detail['notes']?.toString().trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 8),
                        Text('หมายเหตุ: ${detail['notes']}'),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'รายการสินค้า',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (lines.isEmpty)
                        const Text('ไม่มีรายการสินค้า')
                      else
                        ...lines.map((line) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      line['product_name']?.toString().isNotEmpty == true
                                          ? line['product_name']
                                          : (line['product']?['name'] ?? '-'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (line['quantity'] as num?)?.toString() ?? '0',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '฿${((line['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editPurchaseOrder(Map<String, dynamic> order) async {
    final poId = order['id']?.toString();
    if (poId == null || poId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัส PO')),
      );
      return;
    }

    final detail = await ProcurementService.getPurchaseOrderDetail(poId);
    if (!mounted) return;
    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโหลดข้อมูล PO ได้')),
      );
      return;
    }

    final lines = (detail['lines'] as List<dynamic>? ?? []).map((line) {
      return {
        'product_name': line['product_name']?.toString() ?? line['product']?['name']?.toString() ?? '',
        'quantity': (line['quantity'] as num?)?.toDouble() ?? 1,
        'unit_price': (line['unit_price'] as num?)?.toDouble() ?? 0,
      };
    }).toList();

    final formData = await _showPurchaseOrderFormDialog(
      title: 'แก้ไขใบสั่งซื้อ',
      submitLabel: 'บันทึก',
      initialSupplierId: detail['supplier_id']?.toString(),
      initialNotes: detail['notes']?.toString(),
      initialExpectedDate: detail['expected_date']?.toString(),
      initialItems: lines,
    );

    if (formData == null) {
      return;
    }

    final success = await ProcurementService.updatePurchaseOrder(
      poId,
      {
        'supplier_id': formData['supplierId'],
        'expected_date': (formData['expectedDate'] as DateTime?)?.toIso8601String(),
        'notes': formData['notes'],
      },
      (formData['items'] as List).cast<Map<String, dynamic>>(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'บันทึก PO สำเร็จ' : 'ไม่สามารถบันทึก PO ได้'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _loadData();
    }
  }

  Future<void> _deletePurchaseOrder(Map<String, dynamic> order) async {
    final poId = order['id']?.toString();
    if (poId == null || poId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัส PO')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบใบสั่งซื้อ'),
        content: Text('ต้องการลบ PO ${order['order_number'] ?? ''} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    final success = await ProcurementService.deletePurchaseOrder(poId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'ลบ PO สำเร็จ' : 'ไม่สามารถลบ PO ได้'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _loadData();
    }
  }

  Future<void> _cancelPurchaseOrder(Map<String, dynamic> order) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถระบุผู้ใช้ได้'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => CancelPODialog(
        orderNumber: order['order_number']?.toString() ?? '-',
      ),
    );

    if (reason == null) {
      return;
    }

    final poId = order['id']?.toString();
    if (poId == null || poId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบรหัส PO'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await ProcurementService.cancelPurchaseOrder(
      poId,
      currentUserId,
      reason,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยกเลิก PO สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถยกเลิก PO ได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendPurchaseOrder(Map<String, dynamic> order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SendPODialog(
        purchaseOrder: order,
        currentUserId: _currentUserId,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _approvePurchaseOrder(Map<String, dynamic> order) async {
    if (_currentUserId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถระบุผู้ใช้ได้')),
      );
      return;
    }

    final poId = order['id']?.toString();
    if (poId == null || poId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัส PO')),
      );
      return;
    }

    final detail = await ProcurementService.getPurchaseOrderDetail(poId);
    if (!mounted) return;
    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโหลดรายละเอียด PO ได้')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ApprovePODialog(
        purchaseOrder: detail,
        currentUserId: _currentUserId!,
        userRole: _userRole!,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _showCreatePurchaseOrderDialog() async {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีข้อมูลผู้ขาย กรุณาเพิ่มผู้ขายก่อน')),
      );
      return;
    }

    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีข้อมูลสินค้า กรุณาเพิ่มสินค้าก่อนสร้าง PO')),
      );
      return;
    }

    final formData = await _showPurchaseOrderFormDialog(
      title: 'สร้างใบสั่งซื้อใหม่',
      submitLabel: 'สร้าง PO',
      initialItems: [
        {
          'product_id': null,
          'product_name': '',
          'quantity': 1.0,
          'unit_price': 0.0,
        }
      ],
    );

    if (formData == null) {
      return;
    }

    final created = await ProcurementService.createPurchaseOrder(
      supplierId: formData['supplierId'] as String,
      expectedDate: formData['expectedDate'] as DateTime?,
      notes: formData['notes']?.toString(),
      createdBy: _currentUserId,
      items: (formData['items'] as List).cast<Map<String, dynamic>>(),
    );

    if (!mounted) return;

    final success = created != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'สร้าง PO สำเร็จ' : 'ไม่สามารถสร้าง PO ได้'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _loadData();
    }
  }

  Future<Map<String, dynamic>?> _showPurchaseOrderFormDialog({
    required String title,
    required String submitLabel,
    String? initialSupplierId,
    String? initialNotes,
    String? initialExpectedDate,
    List<Map<String, dynamic>>? initialItems,
  }) async {
    final formKey = GlobalKey<FormState>();
    final notesController = TextEditingController(text: initialNotes ?? '');
    String? supplierId = initialSupplierId;
    DateTime? expectedDate = initialExpectedDate != null ? DateTime.tryParse(initialExpectedDate) : null;
    final items = (initialItems ?? [])
        .map(
          (item) => {
            'product_id': item['product_id']?.toString(),
            'product_name': item['product_name']?.toString() ?? '',
            'quantity': (item['quantity'] as num?)?.toDouble() ?? 1,
            'unit_price': (item['unit_price'] as num?)?.toDouble() ?? 0,
          },
        )
        .toList();

    if (items.isEmpty) {
      items.add({'product_id': null, 'product_name': '', 'quantity': 1.0, 'unit_price': 0.0});
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 620,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormSectionTitle('ข้อมูลหัวเอกสาร'),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: supplierId,
                                    decoration: const InputDecoration(
                                      labelText: 'ผู้ขาย *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _suppliers
                                        .map(
                                          (supplier) => DropdownMenuItem<String>(
                                            value: supplier['id']?.toString(),
                                            child: Text(supplier['name']?.toString() ?? '-'),
                                          ),
                                        )
                                        .toList(),
                                    validator: (value) => value == null || value.isEmpty ? 'กรุณาเลือกผู้ขาย' : null,
                                    onChanged: (value) => setDialogState(() => supplierId = value),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: expectedDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => expectedDate = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'วันที่คาดว่าจะรับ',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        expectedDate == null
                                            ? 'ไม่ระบุ'
                                            : '${expectedDate!.day}/${expectedDate!.month}/${expectedDate!.year + 543}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: notesController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'หมายเหตุ',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFormSectionTitle('รายการสินค้า'),
                            ...items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final selectedProductId = item['product_id']?.toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              initialValue: selectedProductId,
                                              decoration: const InputDecoration(
                                                labelText: 'สินค้า',
                                                border: OutlineInputBorder(),
                                              ),
                                              isExpanded: true,
                                              items: _products
                                                  .map(
                                                    (product) => DropdownMenuItem<String>(
                                                      value: product['id']?.toString(),
                                                      child: Text(
                                                        product['name']?.toString() ?? '-',
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return 'เลือกสินค้า';
                                                }
                                                return null;
                                              },
                                              onChanged: (value) {
                                                final selectedProduct = _products.firstWhere(
                                                  (product) => product['id']?.toString() == value,
                                                  orElse: () => <String, dynamic>{},
                                                );
                                                item['product_id'] = value;
                                                item['product_name'] = selectedProduct['name']?.toString() ?? '';
                                              },
                                            ),
                                          ),
                                          if (items.length > 1)
                                            IconButton(
                                              onPressed: () {
                                                setDialogState(() => items.removeAt(index));
                                              },
                                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                                              tooltip: 'ลบรายการ',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: (item['quantity'] as num?)?.toString() ?? '1',
                                              decoration: const InputDecoration(
                                                labelText: 'จำนวน',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              validator: (value) {
                                                final parsed = double.tryParse((value ?? '').trim());
                                                if (parsed == null || parsed <= 0) {
                                                  return 'จำนวนต้องมากกว่า 0';
                                                }
                                                return null;
                                              },
                                              onChanged: (value) => item['quantity'] = double.tryParse(value) ?? 0,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: (item['unit_price'] as num?)?.toString() ?? '0',
                                              decoration: const InputDecoration(
                                                labelText: 'ราคาต่อหน่วย',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              validator: (value) {
                                                final parsed = double.tryParse((value ?? '').trim());
                                                if (parsed == null || parsed < 0) {
                                                  return 'ราคาไม่ถูกต้อง';
                                                }
                                                return null;
                                              },
                                              onChanged: (value) => item['unit_price'] = double.tryParse(value) ?? 0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  items.add({'product_id': null, 'product_name': '', 'quantity': 1.0, 'unit_price': 0.0});
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่มรายการสินค้า'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey[300]!)),
                      ),
                      child: Text(
                        'ตรวจสอบข้อมูลให้ครบก่อนกด $submitLabel',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }

                  if (supplierId == null || supplierId!.isEmpty) {
                    return;
                  }

                  final sanitizedItems = items
                      .map((item) => {
                            'product_id': item['product_id']?.toString(),
                            'product_name': item['product_name']?.toString().trim() ?? '',
                            'quantity': (item['quantity'] as num?)?.toDouble() ?? 0,
                            'unit_price': (item['unit_price'] as num?)?.toDouble() ?? 0,
                          })
                      .toList();

                  Navigator.of(context).pop({
                    'supplierId': supplierId,
                    'expectedDate': expectedDate,
                    'notes': notesController.text.trim(),
                    'items': sanitizedItems,
                  });
                },
                child: Text(submitLabel),
              ),
            ],
          );
        },
      ),
    );

    notesController.dispose();
    return result;
  }

  Widget _buildStatusChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedStatus == value,
      onSelected: (_) => setState(() => _selectedStatus = value),
    );
  }

  Widget _buildFormSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildOrderActions(Map<String, dynamic> order, String status, bool isCompact) {
    final actions = <_OrderActionConfig>[
      if (_canEdit && status == 'draft')
        _OrderActionConfig(
          key: 'edit',
          label: 'แก้ไข',
          icon: Icons.edit,
          color: null,
        ),
      if (_canDelete && status == 'draft')
        _OrderActionConfig(
          key: 'delete',
          label: 'ลบ',
          icon: Icons.delete,
          color: Colors.red,
        ),
      if (_canSend && status == 'draft')
        _OrderActionConfig(
          key: 'send',
          label: 'ส่ง PO',
          icon: Icons.send,
          color: null,
        ),
      if ((_canApprove5000 || _canApprove50000 || _canApproveUnlimited) && status == 'sent')
        _OrderActionConfig(
          key: 'approve',
          label: 'อนุมัติ',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
      if (_canCancel && ['draft', 'sent', 'confirmed'].contains(status))
        _OrderActionConfig(
          key: 'cancel',
          label: 'ยกเลิก',
          icon: Icons.cancel,
          color: Colors.red,
        ),
    ];

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isCompact) {
      return PopupMenuButton<String>(
        tooltip: 'คำสั่ง',
        onSelected: (actionKey) => _handleOrderAction(actionKey, order),
        itemBuilder: (context) => actions
            .map(
              (action) => PopupMenuItem<String>(
                value: action.key,
                child: Row(
                  children: [
                    Icon(action.icon, color: action.color, size: 18),
                    const SizedBox(width: 8),
                    Text(action.label),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .map(
            (action) => IconButton(
              icon: Icon(action.icon, size: 20, color: action.color),
              onPressed: () => _handleOrderAction(action.key, order),
              tooltip: action.label,
            ),
          )
          .toList(),
    );
  }

  void _handleOrderAction(String actionKey, Map<String, dynamic> order) {
    switch (actionKey) {
      case 'edit':
        _editPurchaseOrder(order);
        break;
      case 'delete':
        _deletePurchaseOrder(order);
        break;
      case 'send':
        _sendPurchaseOrder(order);
        break;
      case 'approve':
        _approvePurchaseOrder(order);
        break;
      case 'cancel':
        _cancelPurchaseOrder(order);
        break;
    }
  }

  Widget _buildLoadingSkeletonList() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(width: 160, height: 16),
                const SizedBox(height: 8),
                _skeletonBox(width: 80, height: 12),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _skeletonBox(height: 12)),
                    const SizedBox(width: 12),
                    _skeletonBox(width: 64, height: 12),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _skeletonBox({double? width, double height = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _OrderActionConfig {
  final String key;
  final String label;
  final IconData icon;
  final Color? color;

  _OrderActionConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}
