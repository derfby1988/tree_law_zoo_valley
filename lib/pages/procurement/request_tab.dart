import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/procurement_service.dart';
import '../../services/permission_service.dart';
import '../../services/inventory_service.dart';
import '../../utils/permission_helpers.dart';
import 'dialogs/send_po_dialog.dart';
import 'dialogs/approve_po_dialog.dart';
import 'dialogs/cancel_po_dialog.dart';
import 'widgets/purchase_order_form_dialog.dart';

/// แท็บสั่งซื้อ - แสดงรายการ PO และจัดการ workflow

class RequestTab extends StatefulWidget {
  const RequestTab({super.key});

  @override
  State<RequestTab> createState() => _RequestTabState();
}

class _RequestTabState extends State<RequestTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _purchaseOrders = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'all';

  // User info
  String? _currentUserId;
  String? _userRole;
  bool _canCancel = false;
  bool _canReceiveGoods = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _cancelPO(Map<String, dynamic> order) async {
    if (_currentUserId == null) {
      if (!mounted) return;
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
      _currentUserId!,
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

  Future<void> _loadUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await PermissionService.loadPermissions();
      if (!mounted) return;
      setState(() {
        _currentUserId = user.id;
        _userRole = user.userMetadata?['role'] as String? ?? 'store_manager';
        _canCancel = PermissionService.canAccessActionSync('procurement_purchase_cancel');
        _canReceiveGoods = PermissionService.canAccessActionSync('procurement_receive_goods');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ProcurementService.getPurchaseOrders(),
        ProcurementService.getSuppliers(),
        InventoryService.getProducts(),
      ]);

      if (!mounted) return;
      setState(() {
        _purchaseOrders = results[0];
        _suppliers = results[1];
        _products = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    var filtered = _purchaseOrders;
    
    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((order) => order['status'] == _filterStatus).toList();
    }
    
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

  Future<void> _sendPO(Map<String, dynamic> order) async {
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

  Future<void> _approvePO(Map<String, dynamic> order) async {
    if (_currentUserId == null || _userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถระบุผู้ใช้ได้')),
      );
      return;
    }

    final detail = await ProcurementService.getPurchaseOrderDetail(order['id']);
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

  Future<void> _deletePO(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบ PO ${order['order_number'] ?? ''} หรือไม่?\n(สามารถลบได้เฉพาะ PO ที่ยังเป็นร่าง)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ProcurementService.deletePurchaseOrder(order['id']);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบ PO สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถลบ PO ได้ (อาจไม่ใช่สถานะร่างหรือมีข้อผิดพลาด)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'partial_received':
        return Colors.amber;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'draft':
        return 'ร่าง';
      case 'sent':
        return 'รออนุมัติ';
      case 'confirmed':
        return 'อนุมัติแล้ว';
      case 'partial_received':
        return 'รับบางส่วน';
      case 'completed':
        return 'รับครบแล้ว';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ระบุ';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          // Search, filter and actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 520;
                    final searchField = TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาเลขที่ PO หรือชื่อผู้ขาย...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    );
                    final createButton = PermissionService.canAccessActionSync('procurement_purchase_create')
                        ? ElevatedButton.icon(
                            onPressed: () => checkPermissionAndExecute(
                              context,
                              'procurement_purchase_create',
                              'สร้าง PO',
                              () => _showCreatePODialog(),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('สร้าง PO'),
                          )
                        : const SizedBox.shrink();

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchField,
                          const SizedBox(height: 8),
                          if (createButton is! SizedBox) createButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 8),
                        if (createButton is! SizedBox) createButton,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Status filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'ทั้งหมด'),
                      _buildFilterChip('draft', 'ร่าง'),
                      _buildFilterChip('sent', 'รออนุมัติ'),
                      _buildFilterChip('confirmed', 'อนุมัติแล้ว'),
                      _buildFilterChip('completed', 'รับครบแล้ว'),
                      _buildFilterChip('cancelled', 'ยกเลิก'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Data table
          Expanded(
            child: _filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _purchaseOrders.isEmpty
                              ? 'ยังไม่มีรายการสั่งซื้อ'
                              : 'ไม่พบรายการที่ตรงกับเงื่อนไข',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        ElevatedButton(
                          onPressed: _showCreatePODialog,
                          child: const Text('สร้าง PO'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return _buildPOCard(order);
                      },
                    ),
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: content),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _filterStatus = value);
          }
        },
      ),
    );
  }

  Widget _buildPOCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'draft';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final orderNumber = order['order_number'] ?? 'N/A';
    final supplier = order['supplier']?['name'] ?? 'ไม่ระบุ';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final orderDate = order['order_date'] != null 
        ? DateTime.tryParse(order['order_date']) 
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
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
                const Spacer(),
                Text(
                  orderNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    supplier,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  orderDate != null 
                      ? '${orderDate.day}/${orderDate.month}/${orderDate.year}'
                      : 'ไม่ระบุวันที่',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  '${totalAmount.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActionButtons(order, status),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(Map<String, dynamic> order, String status) {
    final buttons = <Widget>[];

    // View button - always available
    buttons.add(
      TextButton.icon(
        onPressed: () => _viewPODetail(order),
        icon: const Icon(Icons.visibility, size: 18),
        label: const Text('ดู'),
      ),
    );

    // Actions based on status and permissions
    if (status == 'draft') {
      // Send button
      if (PermissionService.canAccessActionSync('procurement_purchase_send')) {
        buttons.add(
          TextButton.icon(
            onPressed: () => _sendPO(order),
            icon: const Icon(Icons.send, size: 18, color: Colors.blue),
            label: const Text('ส่ง', style: TextStyle(color: Colors.blue)),
          ),
        );
      }
      // Edit button
      if (PermissionService.canAccessActionSync('procurement_purchase_edit')) {
        buttons.add(
          TextButton.icon(
            onPressed: () => _showEditPODialog(order),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('แก้ไข'),
          ),
        );
      }
      // Delete button
      if (PermissionService.canAccessActionSync('procurement_purchase_delete')) {
        buttons.add(
          TextButton.icon(
            onPressed: () => _deletePO(order),
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            label: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        );
      }
    } else if (status == 'sent') {
      // Approve button
      if (PermissionService.canAccessActionSync('procurement_purchase_approve_5000') ||
          PermissionService.canAccessActionSync('procurement_purchase_approve_50000') ||
          PermissionService.canAccessActionSync('procurement_purchase_approve_unlimited')) {
        buttons.add(
          ElevatedButton.icon(
            onPressed: () => _approvePO(order),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('อนุมัติ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        );
      }
    }

    if (_canCancel && ['draft', 'sent', 'confirmed'].contains(status)) {
      buttons.add(
        TextButton.icon(
          onPressed: () => _cancelPO(order),
          icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
          label: const Text('ยกเลิก', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_canReceiveGoods && status == 'confirmed') {
      buttons.add(
        TextButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ไปที่แท็บ "รับสินค้า" เพื่อทำรายการรับสินค้า')),
            );
          },
          icon: const Icon(Icons.inventory_2, size: 18, color: Colors.orange),
          label: const Text('รับสินค้า', style: TextStyle(color: Colors.orange)),
        ),
      );
    }

    return buttons;
  }

  Future<void> _viewPODetail(Map<String, dynamic> order) async {
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
        return FutureBuilder<Map<String, dynamic>?> (
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

  Future<void> _showCreatePODialog() async {
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

    final formData = await showPurchaseOrderFormDialog(
      context: context,
      suppliers: _suppliers,
      products: _products,
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

  Future<void> _showEditPODialog(Map<String, dynamic> order) async {
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
        'product_id': line['product_id']?.toString() ?? line['product']?['id']?.toString(),
        'product_name': line['product_name']?.toString() ?? line['product']?['name']?.toString() ?? '',
        'quantity': (line['quantity'] as num?)?.toDouble() ?? 1,
        'unit_price': (line['unit_price'] as num?)?.toDouble() ?? 0,
      };
    }).toList();

    final formData = await showPurchaseOrderFormDialog(
      context: context,
      suppliers: _suppliers,
      products: _products,
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year + 543}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
