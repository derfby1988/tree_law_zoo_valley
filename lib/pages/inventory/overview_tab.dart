import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import 'inventory_filter_widget.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'ทั้งหมด';
  String _selectedShelf = 'ทั้งหมด';

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final stats = await InventoryService.getOverviewStats();
      setState(() { _stats = stats; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red),
        SizedBox(height: 8),
        Text(_errorMessage!, style: TextStyle(color: Colors.red)),
        SizedBox(height: 12),
        ElevatedButton(onPressed: _loadData, child: Text('ลองใหม่')),
      ])));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InventoryFilterWidget(
              searchController: _searchController,
              selectedWarehouse: _selectedWarehouse,
              selectedShelf: _selectedShelf,
              onWarehouseChanged: (value) => setState(() => _selectedWarehouse = value!),
              onShelfChanged: (value) => setState(() => _selectedShelf = value!),
            ),
            SizedBox(height: 16),
            _buildSummaryCards(),
            SizedBox(height: 16),
            _buildExpandableAlerts(),
            SizedBox(height: 16),
            _buildMovementStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final total = _stats['total'] ?? 0;
    final ready = _stats['ready'] ?? 0;
    final low = _stats['low'] ?? 0;
    final outOfStock = _stats['outOfStock'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ภาพรวมคลังสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ทั้งหมด', '$total', Colors.blue, Icons.inventory_2)),
            SizedBox(width: 8),
            Expanded(child: _buildSummaryCard('พร้อม', '$ready', Colors.green, Icons.check_circle)),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ใกล้หมด', '$low', Colors.orange, Icons.warning)),
            SizedBox(width: 8),
            Expanded(child: _buildSummaryCard('หมด', '$outOfStock', Colors.red, Icons.error)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            Text('รายการ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableAlerts() {
    final lowStockProducts = _stats['lowStockProducts'] as List<Map<String, dynamic>>? ?? [];
    final expiringSoon = _stats['expiringSoon'] as List<Map<String, dynamic>>? ?? [];

    return Column(
      children: [
        _buildAlertExpansionTile(
          title: 'สินค้าใกล้หมด',
          icon: Icons.warning,
          color: Colors.orange,
          count: lowStockProducts.length,
          child: _buildLowStockContent(lowStockProducts),
        ),
        SizedBox(height: 8),
        _buildAlertExpansionTile(
          title: 'วัตถุดิบใกล้หมดอายุ',
          icon: Icons.access_time,
          color: Colors.red,
          count: expiringSoon.length,
          child: _buildExpiringContent(expiringSoon),
        ),
      ],
    );
  }

  Widget _buildAlertExpansionTile({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$count รายการ', style: TextStyle(color: color, fontSize: 12)),
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockContent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(padding: EdgeInsets.all(12), child: Text('ไม่มีสินค้าใกล้หมด', style: TextStyle(color: Colors.grey[600])));
    }
    return Column(
      children: items.map((item) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final unitAbbr = item['unit']?['abbreviation'] ?? '';
        final shelfCode = item['shelf']?['code'] ?? '-';
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('${item['name']} (${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} $unitAbbr) ชั้น $shelfCode')),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpiringContent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(padding: EdgeInsets.all(12), child: Text('ไม่มีวัตถุดิบใกล้หมดอายุ', style: TextStyle(color: Colors.grey[600])));
    }
    final now = DateTime.now();
    return Column(
      children: items.map((item) {
        final expiry = DateTime.tryParse(item['expiry_date']?.toString() ?? '');
        final days = expiry != null ? expiry.difference(now).inDays : 0;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final unitAbbr = item['unit']?['abbreviation'] ?? '';
        final color = _getExpiryColor(days);

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['name']} หมดอายุใน $days วัน', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('(${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} $unitAbbr)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getExpiryColor(int days) {
    if (days <= 2) return Colors.red;
    if (days <= 4) return Colors.orange;
    return Colors.yellow[700]!;
  }

  Widget _buildMovementStatistics() {
    final inToday = _stats['inToday'] ?? 0;
    final outToday = _stats['outToday'] ?? 0;
    final adjustToday = _stats['adjustToday'] ?? 0;
    final totalValue = (_stats['totalValue'] as num?)?.toDouble() ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple),
                SizedBox(width: 8),
                Text('สถิติการเคลื่อนไหวสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            _buildStatRow(Icons.download, 'รับเข้าวันนี้', '$inToday รายการ', Colors.green),
            _buildStatRow(Icons.upload, 'จ่ายออกวันนี้', '$outToday รายการ', Colors.red),
            _buildStatRow(Icons.sync, 'ปรับปรุงวันนี้', '$adjustToday รายการ', Colors.blue),
            _buildStatRow(Icons.attach_money, 'มูลค่าคลัง', '฿${totalValue.toStringAsFixed(0)}', Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
