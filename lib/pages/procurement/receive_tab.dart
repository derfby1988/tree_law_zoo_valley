import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/inventory_service.dart';
import '../../services/procurement_service.dart';
import '../../services/permission_service.dart';
import 'dialogs/receive_goods_dialog.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _recentAdjustments = [];
  List<Map<String, dynamic>> _pendingPOs = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTab = 'receive'; // 'receive', 'history'

  // Permission checks
  bool _canReceiveGoods = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    await PermissionService.loadPermissions();
    
    setState(() {
      _canReceiveGoods = PermissionService.canAccessActionSync('procurement_receive_goods');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        InventoryService.getAdjustments(limit: 50),
        ProcurementService.getPurchaseOrders(status: 'confirmed'), // Ready to receive
      ]);
      
      setState(() {
        _recentAdjustments = results[0]
            .where((a) => a['type'] == 'purchase' || a['type'] == 'receive')
            .toList();
        _pendingPOs = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAdjustments {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _recentAdjustments;
    return _recentAdjustments.where((a) {
      final product = a['product'] as Map<String, dynamic>?;
      final name = (product?['name'] ?? '').toString().toLowerCase();
      final reason = (a['reason'] ?? '').toString().toLowerCase();
      return name.contains(q) || reason.contains(q);
    }).toList();
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
              ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          // Tab selector
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('รับสินค้า'),
                    selected: _selectedTab == 'receive',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'receive');
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('ประวัติ'),
                    selected: _selectedTab == 'history',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'history');
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Content based on selected tab
          Expanded(
            child: _selectedTab == 'receive'
                ? _buildReceiveTab()
                : _buildHistoryTab(),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(child: content),
    );
  }

  Widget _buildReceiveTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'ค้นหาเลขที่ PO หรือชื่อผู้ขาย...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        
        // Pending POs list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _pendingPOs.isEmpty
                ? _wrapEmptyScrollable(_buildEmptyReceiveState())
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _pendingPOs.length,
                    itemBuilder: (context, index) {
                      final po = _pendingPOs[index];
                      return _buildPOCard(po);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'ค้นหาประวัติการรับสินค้า...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        
        // History list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _filteredAdjustments.isEmpty
                ? _wrapEmptyScrollable(_buildEmptyHistoryState())
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _filteredAdjustments.length,
                    itemBuilder: (context, index) {
                      final adjustment = _filteredAdjustments[index];
                      return _buildAdjustmentCard(adjustment);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _wrapEmptyScrollable(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        child,
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildEmptyReceiveState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'ไม่มี PO ที่รอการรับสินค้า',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'ไม่มีประวัติการรับสินค้า',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPOCard(Map<String, dynamic> po) {
    final supplier = po['supplier'] as Map<String, dynamic>? ?? {};
    final totalAmount = (po['total_amount'] as num?)?.toDouble() ?? 0.0;
    final orderDate = po['order_date'] as String?;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _receivePurchaseOrder(po),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      po['order_number'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '฿${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
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
              if (_canReceiveGoods) ...[
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _receivePurchaseOrder(po),
                    icon: Icon(Icons.download),
                    label: Text('รับสินค้า'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentCard(Map<String, dynamic> adjustment) {
    final product = adjustment['product'] as Map<String, dynamic>? ?? {};
    final quantity = (adjustment['quantity'] as num?)?.toDouble() ?? 0.0;
    final createdAt = adjustment['created_at'] as String?;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product['name'] ?? 'ไม่ระบุสินค้า',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${quantity > 0 ? '+' : ''}${quantity.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: quantity > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.history, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    adjustment['reason'] ?? 'ไม่ระบุเหตุผล',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
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

  Future<void> _receivePurchaseOrder(Map<String, dynamic> po) async {
    if (!_canReceiveGoods) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('คุณไม่มีสิทธิ์รับสินค้า'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final detail = await ProcurementService.getPurchaseOrderDetail(po['id']);
    if (!mounted) return;

    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถโหลดรายละเอียด PO ได้'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ReceiveGoodsDialog(
        purchaseOrder: detail,
        currentUserId: currentUserId,
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }
}
