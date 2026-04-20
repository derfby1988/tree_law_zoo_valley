import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import 'inventory_filter_widget.dart';
import '../../theme/app_design_system.dart';

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

  Color get _surface => AppDesignSystem.surface;
  Color get _surfaceAlt => AppDesignSystem.background;
  Color get _textPrimary => AppDesignSystem.textPrimary;
  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _borderColor => AppDesignSystem.border;
  Color get _primaryColor => AppDesignSystem.primary;
  Color get _secondaryColor => AppDesignSystem.secondary;
  Color get _successColor => AppDesignSystem.success;
  Color get _warningColor => AppDesignSystem.warning;
  Color get _dangerColor => AppDesignSystem.danger;

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
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: _dangerColor),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: _dangerColor)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }

<<<<<<< HEAD
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
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
            const SizedBox(height: AppDesignSystem.spacingLg),
            _buildSummaryCards(),
            const SizedBox(height: AppDesignSystem.spacingLg),
            _buildExpandableAlerts(),
            const SizedBox(height: AppDesignSystem.spacingLg),
            _buildMovementStatistics(),
          ],
=======
    return SafeArea(
      child: RefreshIndicator(
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
>>>>>>> UI inventory
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
        Text('ภาพรวมคลังสินค้า', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDesignSystem.spacingMd),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ทั้งหมด', '$total', _primaryColor, Icons.inventory_2)),
            const SizedBox(width: AppDesignSystem.spacingSm),
            Expanded(child: _buildSummaryCard('พร้อม', '$ready', _successColor, Icons.check_circle)),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingSm),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ใกล้หมด', '$low', _warningColor, Icons.warning)),
            const SizedBox(width: AppDesignSystem.spacingSm),
            Expanded(child: _buildSummaryCard('หมด', '$outOfStock', _dangerColor, Icons.error)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color, IconData icon) {
    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 14, color: _textSecondary)),
            Text('รายการ', style: TextStyle(fontSize: 12, color: _textSecondary.withValues(alpha: 0.8))),
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
          color: _warningColor,
          count: lowStockProducts.length,
          child: _buildLowStockContent(lowStockProducts),
        ),
        const SizedBox(height: AppDesignSystem.spacingSm),
        _buildAlertExpansionTile(
          title: 'วัตถุดิบใกล้หมดอายุ',
          icon: Icons.access_time,
          color: _dangerColor,
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
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
        subtitle: Text('$count รายการ', style: TextStyle(color: color, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockContent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(padding: const EdgeInsets.all(AppDesignSystem.spacingMd), child: Text('ไม่มีสินค้าใกล้หมด', style: TextStyle(color: _textSecondary)));
    }
    return Column(
      children: items.map((item) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final unitAbbr = item['unit']?['abbreviation'] ?? '';
        final shelfCode = item['shelf']?['code'] ?? '-';
        return Container(
          margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
          padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
          decoration: BoxDecoration(
            color: _warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
            border: Border.all(color: _warningColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: _warningColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${item['name']} (${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} $unitAbbr) ชั้น $shelfCode')),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpiringContent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(padding: const EdgeInsets.all(AppDesignSystem.spacingMd), child: Text('ไม่มีวัตถุดิบใกล้หมดอายุ', style: TextStyle(color: _textSecondary)));
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
          margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
          padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['name']} หมดอายุใน $days วัน', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('(${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} $unitAbbr)', style: TextStyle(color: _textSecondary, fontSize: 12)),
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
    if (days <= 2) return _dangerColor;
    if (days <= 4) return _warningColor;
    return _secondaryColor;
  }

  Widget _buildMovementStatistics() {
    final inToday = _stats['inToday'] ?? 0;
    final outToday = _stats['outToday'] ?? 0;
    final adjustToday = _stats['adjustToday'] ?? 0;
    final totalValue = (_stats['totalValue'] as num?)?.toDouble() ?? 0;

    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: _secondaryColor),
                const SizedBox(width: 8),
                Text('สถิติการเคลื่อนไหวสินค้า', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            _buildStatRow(Icons.download, 'รับเข้าวันนี้', '$inToday รายการ', _successColor),
            _buildStatRow(Icons.upload, 'จ่ายออกวันนี้', '$outToday รายการ', _dangerColor),
            _buildStatRow(Icons.sync, 'ปรับปรุงวันนี้', '$adjustToday รายการ', _secondaryColor),
            _buildStatRow(Icons.attach_money, 'มูลค่าคลัง', '฿${totalValue.toStringAsFixed(0)}', _warningColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
