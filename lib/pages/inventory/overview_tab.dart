import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/inventory_service.dart';
import 'inventory_filter_widget.dart';
import 'dialogs/stock_alert_dialog.dart';
import 'count_history_page.dart';
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
  bool _updatingAlert = false;

  // ✅ ประวัติการตรวจนับ
  List<Map<String, dynamic>> _stockCountHistory = [];
  List<Map<String, dynamic>> _ingredientCountHistory = [];

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
      final results = await Future.wait([
        InventoryService.getOverviewStats(),
        InventoryService.getStockCountHistory(limit: 10),
        InventoryService.getIngredientCountHistory(limit: 10),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _stockCountHistory = results[1] as List<Map<String, dynamic>>;
        _ingredientCountHistory = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingShimmer();
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

    return _buildOverviewContent();
  }

  Widget _buildLoadingShimmer() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Container(height: 120, color: Colors.white)),
                      const SizedBox(width: AppDesignSystem.spacingSm),
                      Expanded(child: Container(height: 120, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: AppDesignSystem.spacingSm),
                  Row(
                    children: [
                      Expanded(child: Container(height: 120, color: Colors.white)),
                      const SizedBox(width: AppDesignSystem.spacingSm),
                      Expanded(child: Container(height: 120, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingLg),
            // Alert cards shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: [
                  Container(height: 80, color: Colors.white),
                  const SizedBox(height: AppDesignSystem.spacingSm),
                  Container(height: 80, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingLg),
            // Statistics card shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                  child: Column(
                    children: List.generate(
                      4,
                      (index) => Padding(
                        padding: EdgeInsets.only(bottom: index < 3 ? AppDesignSystem.spacingSm : 0),
                        child: Row(
                          children: [
                            Container(width: 20, height: 20, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(child: Container(height: 16, color: Colors.white)),
                            Container(width: 80, height: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewContent() {
    return SafeArea(
      child: RefreshIndicator(
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
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildCountHistorySection(),
            ],
          ),
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
          trailing: _buildAlertActionButton(lowStockProducts),
        ),
        const SizedBox(height: AppDesignSystem.spacingSm),
        _buildAlertExpansionTile(
          title: 'วัตถุดิบใกล้หมดอายุ',
          icon: Icons.access_time,
          color: _dangerColor,
          count: expiringSoon.length,
          child: _buildExpiringContent(expiringSoon),
          trailing: _buildAlertActionButton(expiringSoon, expiryFocus: true),
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
    Widget? trailing,
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
        trailing: trailing,
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
        final minQty = (item['min_quantity'] as num?)?.toDouble() ?? 0;
        final reorderQty = (minQty * 2).clamp(minQty, double.infinity);
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
              IconButton(
                icon: const Icon(Icons.settings, size: 18),
                tooltip: 'ตั้งค่าแจ้งเตือน',
                onPressed: () => _openStockAlertDialog(item),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart, size: 18),
                tooltip: 'สั่งซื้อด่วน',
                onPressed: () => _handleQuickPO(item, reorderQty),
              ),
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
              IconButton(
                icon: const Icon(Icons.settings, size: 18),
                tooltip: 'ตั้งค่าแจ้งเตือน',
                onPressed: () => _openStockAlertDialog(item, expiryFocus: true),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget? _buildAlertActionButton(List<Map<String, dynamic>> products, {bool expiryFocus = false}) {
    if (products.isEmpty) return null;
    return IconButton(
      icon: const Icon(Icons.tune),
      tooltip: 'ตั้งค่าแจ้งเตือน',
      onPressed: _updatingAlert
          ? null
          : () {
              _openStockAlertDialog(products.first, expiryFocus: expiryFocus);
            },
    );
  }

  Future<void> _openStockAlertDialog(Map<String, dynamic> product, {bool expiryFocus = false}) async {
    if (_updatingAlert) return;
    setState(() => _updatingAlert = true);
    try {
      final result = await showStockAlertConfigDialog(context: context, product: product);
      if (result == null) return;
      final success = await InventoryService.updateProduct(product['id'].toString(), {
        'min_quantity': result['min_quantity'],
        'expiry_alert_days': result['expiry_alert_days'],
      });
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกแจ้งเตือนสำหรับ ${product['name']} แล้ว')),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกไม่สำเร็จ')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAlert = false);
      }
    }
  }

  Future<void> _handleQuickPO(Map<String, dynamic> product, double quantity) async {
    final productId = product['id']?.toString();
    final supplierId = product['supplier_id']?.toString();
    if (productId == null || supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สินค้านี้ยังไม่มีข้อมูลผู้ขาย')),
      );
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final ok = await InventoryService.createAutoPOForLowStock(
      productId: productId,
      supplierId: supplierId,
      quantity: quantity,
      createdBy: userId,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้าง PO สำหรับ ${product['name']} แล้ว')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สร้าง PO ไม่สำเร็จ')),
      );
    }
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

  // ✅ ส่วนแสดงประวัติการตรวจนับ
  Widget _buildCountHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: _secondaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text('ประวัติการตรวจนับ', style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CountHistoryPage()),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('ดูทั้งหมด'),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingMd),
        _buildAlertExpansionTile(
          title: 'ประวัติตรวจนับสต็อกสินค้า',
          icon: Icons.inventory_2,
          color: Colors.orange,
          count: _stockCountHistory.length,
          child: _buildStockCountHistoryContent(),
        ),
        const SizedBox(height: AppDesignSystem.spacingSm),
        _buildAlertExpansionTile(
          title: 'ประวัติตรวจนับวัตถุดิบ',
          icon: Icons.checklist,
          color: Colors.purple,
          count: _ingredientCountHistory.length,
          child: _buildIngredientCountHistoryContent(),
        ),
      ],
    );
  }

  Widget _buildStockCountHistoryContent() {
    if (_stockCountHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Text('ยังไม่มีประวัติตรวจนับสต็อก', style: TextStyle(color: _textSecondary)),
      );
    }
    return Column(
      children: _stockCountHistory.map((rec) {
        final productName = rec['inventory_products']?['name'] ?? '-';
        final before = (rec['quantity_before'] as num?)?.toDouble() ?? 0;
        final after = (rec['quantity_after'] as num?)?.toDouble() ?? 0;
        final change = (rec['quantity_change'] as num?)?.toDouble() ?? (after - before);
        final createdAt = rec['created_at']?.toString() ?? '';
        final isIncrease = change >= 0;
        final changeColor = isIncrease ? _successColor : _dangerColor;

        return Container(
          margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
          padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('${_formatDate(createdAt)} | $before → $after', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              Text(
                '${isIncrease ? '+' : ''}${change.toStringAsFixed(change == change.roundToDouble() ? 0 : 2)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: changeColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIngredientCountHistoryContent() {
    if (_ingredientCountHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Text('ยังไม่มีประวัติตรวจนับวัตถุดิบ', style: TextStyle(color: _textSecondary)),
      );
    }
    return Column(
      children: _ingredientCountHistory.map((rec) {
        final ingName = rec['inventory_ingredients']?['name'] ?? '-';
        final before = (rec['quantity_before'] as num?)?.toDouble() ?? 0;
        final counted = (rec['quantity_counted'] as num?)?.toDouble() ?? 0;
        final diff = counted - before;
        final countedAt = rec['counted_at']?.toString() ?? '';
        final isIncrease = diff >= 0;
        final diffColor = diff == 0 ? _textSecondary : (isIncrease ? _successColor : _dangerColor);

        return Container(
          margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
          padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.checklist, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ingName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('${_formatDate(countedAt)} | ระบบ: $before → นับได้: $counted', style: TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              Text(
                diff == 0 ? '✓' : '${isIncrease ? '+' : ''}${diff.toStringAsFixed(diff == diff.roundToDouble() ? 0 : 2)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: diffColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final buddhistYear = date.year + 543;
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');
      return '${date.day}/${date.month}/$buddhistYear $hh:$mm';
    } catch (_) {
      return isoString;
    }
  }
}
