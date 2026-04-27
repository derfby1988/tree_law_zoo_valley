import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/batch_list_widget.dart';

/// หน้าจัดการ batch สำหรับสินค้าและวัตถุดิบ
/// รองรับการดู batch ทั้งหมด, ใกล้หมดอายุ, และหมดอายุแล้ว
class BatchManagementPage extends StatefulWidget {
  final String itemType; // 'product' | 'ingredient'
  final String itemId;
  final String itemName;

  const BatchManagementPage({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<BatchManagementPage> createState() => _BatchManagementPageState();
}

class _BatchManagementPageState extends State<BatchManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allBatches = [];
  List<Map<String, dynamic>> _expiringBatches = [];
  List<Map<String, dynamic>> _expiredBatches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // โหลด batch ทั้งหมด
      final allBatches = await InventoryService.getBatches(
        productId: widget.itemType == 'product' ? widget.itemId : null,
        ingredientId: widget.itemType == 'ingredient' ? widget.itemId : null,
        itemType: widget.itemType,
        isActive: true,
      );

      // โหลด batch ใกล้หมดอายุ (7 วัน)
      final expiringBatches = await InventoryService.getExpiringBatches(
        daysThreshold: 7,
        itemType: widget.itemType,
      );

      // โหลด batch หมดอายุแล้ว
      final expiredBatches = await InventoryService.getExpiredBatches(
        itemType: widget.itemType,
      );

      // Filter ตาม itemId
      if (mounted) {
        setState(() {
          _allBatches = allBatches.where((b) {
            final id = widget.itemType == 'product' 
                ? b['product_id'] as String? 
                : b['ingredient_id'] as String?;
            return id == widget.itemId;
          }).toList();
          
          _expiringBatches = expiringBatches.where((b) {
            final id = widget.itemType == 'product' 
                ? b['product_id'] as String? 
                : b['ingredient_id'] as String?;
            return id == widget.itemId;
          }).toList();
          
          _expiredBatches = expiredBatches.where((b) {
            final id = widget.itemType == 'product' 
                ? b['product_id'] as String? 
                : b['ingredient_id'] as String?;
            return id == widget.itemId;
          }).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddBatchDialog() {
    // TODO: Implement add batch dialog for manual adjustments
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่ม Batch ใหม่'),
        content: const Text('ฟีเจอร์นี้จะเพิ่มในเวอร์ชันถัดไป'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBatches = _allBatches.length;
    final expiringCount = _expiringBatches.length;
    final expiredCount = _expiredBatches.length;
    final totalQuantity = _allBatches.fold<double>(
      0,
      (sum, b) => sum + ((b['quantity'] as num?)?.toDouble() ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จัดการ Batch: ${widget.itemName}'),
            Text(
              '${totalBatches} batch | ${totalQuantity.toStringAsFixed(totalQuantity == totalQuantity.roundToDouble() ? 0 : 1)} หน่วย',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory),
              text: 'ทั้งหมด ($totalBatches)',
            ),
            Tab(
              icon: Icon(Icons.warning, color: expiringCount > 0 ? Colors.orange : null),
              text: 'ใกล้หมด ($expiringCount)',
            ),
            Tab(
              icon: Icon(Icons.error, color: expiredCount > 0 ? Colors.red : null),
              text: 'หมดอายุ ($expiredCount)',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // All batches tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: BatchListWidget(
                    itemType: widget.itemType,
                    itemId: widget.itemId,
                    itemName: widget.itemName,
                    showActions: true,
                    allowExpiryEdit: true,
                    allowDispose: true,
                    onBatchChanged: _loadData,
                  ),
                ),

                // Expiring batches tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _expiringBatches.isEmpty
                      ? _buildEmptyState('ไม่มี batch ใกล้หมดอายุ', Icons.check_circle, Colors.green)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'มี ${_expiringBatches.length} batch ที่ใกล้หมดอายุใน 7 วัน',
                                      style: TextStyle(color: Colors.orange.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._expiringBatches.map((batch) {
                              return _buildBatchCard(batch, isExpiring: true);
                            }).toList(),
                          ],
                        ),
                ),

                // Expired batches tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _expiredBatches.isEmpty
                      ? _buildEmptyState('ไม่มี batch หมดอายุ', Icons.check_circle, Colors.green)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'มี ${_expiredBatches.length} batch ที่หมดอายุแล้ว ควรทิ้ง',
                                      style: TextStyle(color: Colors.red.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._expiredBatches.map((batch) {
                              return _buildBatchCard(batch, isExpired: true);
                            }).toList(),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: PermissionService.canAccessActionSync('inventory_batch_create')
          ? FloatingActionButton(
              onPressed: _showAddBatchDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch, {bool isExpiring = false, bool isExpired = false}) {
    final batchNumber = batch['batch_number'] as String? ?? '-';
    final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0;
    final expiryDate = batch['expiry_date'] as String? ?? '-';
    final warehouseName = batch['warehouse']?['name'] as String? ?? '-';
    final shelfCode = batch['shelf']?['code'] as String? ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isExpired ? Colors.red.shade50 : isExpiring ? Colors.orange.shade50 : null,
      child: ListTile(
        title: Text(batchNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จำนวน: $quantity หน่วย'),
            Text('หมดอายุ: $expiryDate'),
            Text('ที่ตั้ง: $warehouseName / $shelfCode'),
          ],
        ),
        trailing: isExpired
            ? ElevatedButton.icon(
                onPressed: () => _disposeBatch(batch['id'] as String),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('ทิ้ง'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _disposeBatch(String batchId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการทิ้ง'),
        content: const Text('Batch นี้จะถูก mark ว่าหมดอายุและทิ้งแล้ว'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await InventoryService.markBatchAsExpired(
        batchId: batchId,
        disposed: true,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทิ้ง batch สำเร็จ'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    }
  }
}
