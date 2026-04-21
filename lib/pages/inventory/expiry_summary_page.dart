import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_design_system.dart';

class ExpirySummaryPage extends StatefulWidget {
  const ExpirySummaryPage({super.key});

  @override
  State<ExpirySummaryPage> createState() => _ExpirySummaryPageState();
}

class _ExpirySummaryPageState extends State<ExpirySummaryPage> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortBy = 'expiry_date'; // 'expiry_date', 'quantity', 'days_left'
  bool _showExpiredOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final products = await InventoryService.getProducts();
      final now = DateTime.now();
      final expiringProducts = products.where((p) {
        final expiryDate = DateTime.tryParse(p['expiry_date']?.toString() ?? '');
        if (expiryDate == null) return false;
        if (_showExpiredOnly) {
          return expiryDate.isBefore(now);
        }
        return expiryDate.isBefore(now.add(const Duration(days: 90)));
      }).toList();

      expiringProducts.sort((a, b) {
        final expiryA = DateTime.tryParse(a['expiry_date']?.toString() ?? '');
        final expiryB = DateTime.tryParse(b['expiry_date']?.toString() ?? '');
        if (expiryA == null || expiryB == null) return 0;

        switch (_sortBy) {
          case 'quantity':
            return (b['quantity'] as num?)?.compareTo(a['quantity'] as num? ?? 0) ?? 0;
          case 'days_left':
            final daysA = expiryA.difference(now).inDays;
            final daysB = expiryB.difference(now).inDays;
            return daysA.compareTo(daysB);
          default:
            return expiryA.compareTo(expiryB);
        }
      });

      if (!mounted) return;
      setState(() {
        _products = expiringProducts;
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

  Map<String, List<Map<String, dynamic>>> _groupByExpiryDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();

    for (final product in _products) {
      final expiryDate = DateTime.tryParse(product['expiry_date']?.toString() ?? '');
      if (expiryDate == null) continue;

      final daysLeft = expiryDate.difference(now).inDays;
      String groupKey;

      if (daysLeft < 0) {
        groupKey = 'หมดอายุแล้ว (${(-daysLeft)} วันที่แล้ว)';
      } else if (daysLeft == 0) {
        groupKey = 'หมดอายุวันนี้';
      } else if (daysLeft <= 7) {
        groupKey = 'ใกล้หมดอายุ ($daysLeft วัน)';
      } else if (daysLeft <= 30) {
        groupKey = 'ประมาณ 1 เดือน ($daysLeft วัน)';
      } else {
        groupKey = 'ยังไกล ($daysLeft วัน)';
      }

      grouped.putIfAbsent(groupKey, () => []).add(product);
    }

    return grouped;
  }

  Color _getExpiryColor(int daysLeft) {
    if (daysLeft < 0) return AppDesignSystem.danger;
    if (daysLeft == 0) return Colors.red;
    if (daysLeft <= 7) return AppDesignSystem.warning;
    if (daysLeft <= 30) return Colors.orange;
    return AppDesignSystem.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปวันหมดอายุ'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _sortBy = value);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'expiry_date', child: Text('เรียงตามวันหมดอายุ')),
              const PopupMenuItem(value: 'days_left', child: Text('เรียงตามวันที่เหลือ')),
              const PopupMenuItem(value: 'quantity', child: Text('เรียงตามจำนวน')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: FilterChip(
                label: const Text('หมดอายุแล้ว'),
                selected: _showExpiredOnly,
                onSelected: (selected) {
                  setState(() => _showExpiredOnly = selected);
                  _loadData();
                },
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppDesignSystem.danger),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, style: TextStyle(color: AppDesignSystem.danger)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
                      ],
                    ),
                  ),
                )
              : _products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 48, color: AppDesignSystem.success),
                            const SizedBox(height: 8),
                            const Text('ไม่มีสินค้าใกล้หมดอายุ'),
                          ],
                        ),
                      ),
                    )
                  : SafeArea(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
                          child: Column(
                            children: _buildGroupedList(),
                          ),
                        ),
                      ),
                    ),
    );
  }

  List<Widget> _buildGroupedList() {
    final grouped = _groupByExpiryDate();
    final widgets = <Widget>[];

    grouped.forEach((groupKey, products) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm),
                child: Text(
                  groupKey,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              ...products.map((product) => _buildProductCard(product)).toList(),
            ],
          ),
        ),
      );
    });

    return widgets;
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final expiryDate = DateTime.tryParse(product['expiry_date']?.toString() ?? '');
    final now = DateTime.now();
    final daysLeft = expiryDate != null ? expiryDate.difference(now).inDays : 0;
    final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
    final unitAbbr = product['unit']?['abbreviation'] ?? '';
    final shelfCode = product['shelf']?['code'] ?? '-';
    final color = _getExpiryColor(daysLeft);
    final canCreatePO = PermissionService.hasPermission('inventory_quick_po');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'หมดอายุ: ${expiryDate?.day}/${expiryDate?.month}/${(expiryDate?.year ?? 0) + 543}',
                        style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    daysLeft < 0 ? 'หมดอายุแล้ว' : '$daysLeft วัน',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingSm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'จำนวน: ${qty.toStringAsFixed(qty == qty.truncateToDouble() ? 0 : 1)} $unitAbbr',
                    style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'ชั้น: $shelfCode',
                    style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (canCreatePO) ...[
              const SizedBox(height: AppDesignSystem.spacingSm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleQuickPOForExpiry(product),
                  icon: const Icon(Icons.shopping_cart, size: 16),
                  label: const Text('สั่งซื้อด่วน'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.3),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleQuickPOForExpiry(Map<String, dynamic> product) async {
    final productId = product['id']?.toString();
    final productName = product['name']?.toString() ?? 'Unknown';
    final qty = (product['quantity'] as num?)?.toDouble() ?? 0;

    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถสร้าง PO ได้'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('สั่งซื้อด่วน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สินค้า: $productName'),
            const SizedBox(height: 8),
            Text('จำนวนในคลัง: ${qty.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            const Text('กรุณาเลือก Supplier:'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => _selectSupplierAndCreatePO(productId, productName, qty),
            child: const Text('ถัดไป'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectSupplierAndCreatePO(String productId, String productName, double qty) async {
    Navigator.pop(context);
    
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _getSuppliers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              title: Text('โหลด Supplier'),
              content: CircularProgressIndicator(),
            );
          }

          final suppliers = snapshot.data ?? [];
          if (suppliers.isEmpty) {
            return AlertDialog(
              title: const Text('ไม่พบ Supplier'),
              content: const Text('กรุณาสร้าง Supplier ก่อน'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
              ],
            );
          }

          return AlertDialog(
            title: const Text('เลือก Supplier'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return ListTile(
                    title: Text(supplier['name']?.toString() ?? 'Unknown'),
                    onTap: () {
                      Navigator.pop(context);
                      _createAutoPOForExpiry(productId, supplier['id'], qty);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getSuppliers() async {
    try {
      final response = await InventoryService.getSuppliers();
      return response;
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
      return [];
    }
  }

  Future<void> _createAutoPOForExpiry(String productId, String supplierId, double qty) async {
    try {
      final userId = PermissionService.currentUserId;
      final success = await InventoryService.createAutoPOForExpiringStock(
        productId: productId,
        supplierId: supplierId,
        quantity: qty,
        createdBy: userId,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สร้าง PO สำหรับสินค้าใกล้หมดอายุสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถสร้าง PO ได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
