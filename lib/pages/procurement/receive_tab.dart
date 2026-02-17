import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../utils/permission_helpers.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _recentAdjustments = [];
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
      final adjustments = await InventoryService.getAdjustments(limit: 50);
      setState(() {
        _recentAdjustments = adjustments
            .where((a) => a['type'] == 'purchase' || a['type'] == 'receive')
            .toList();
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
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(
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
      ));
    }

    return Column(
      children: [
        // Top bar: search + add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหารายการรับสินค้า...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('รับสินค้าเข้า'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () => checkPermissionAndExecute(
                  context,
                  'procurement_receive_add',
                  'รับสินค้าเข้า',
                  () => _showReceiveDialog(),
                ),
              ),
            ],
          ),
        ),
        // History list
        Expanded(
          child: _filteredAdjustments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('ไม่มีรายการรับสินค้า', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredAdjustments.length,
                  itemBuilder: (context, index) {
                    final adj = _filteredAdjustments[index];
                    final product = adj['product'] as Map<String, dynamic>?;
                    final name = product?['name'] ?? '-';
                    final unit = product?['unit'];
                    final unitName = (unit is Map) ? (unit['abbreviation'] ?? unit['name'] ?? '') : '';
                    final change = (adj['quantity_change'] as num?)?.toDouble() ?? 0;
                    final reason = adj['reason'] ?? '';
                    final createdAt = adj['created_at'] != null
                        ? DateTime.tryParse(adj['created_at'].toString())
                        : null;
                    final dateStr = createdAt != null
                        ? '${createdAt.day}/${createdAt.month}/${createdAt.year + 543} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                        : '-';
                    final userName = adj['user_name'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[50],
                          child: Icon(Icons.add_shopping_cart, color: Colors.green[700], size: 20),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$reason\n$dateStr • $userName', style: const TextStyle(fontSize: 12)),
                        isThreeLine: true,
                        trailing: Text(
                          '+${change.toStringAsFixed(change == change.roundToDouble() ? 0 : 2)} $unitName',
                          style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =============================================
  // Receive Dialog
  // =============================================
  void _showReceiveDialog() {
    final qtyController = TextEditingController();
    final costController = TextEditingController();
    final noteController = TextEditingController();
    Map<String, dynamic>? selectedProduct;
    List<Map<String, dynamic>> searchResults = [];
    final searchCtrl = TextEditingController();
    bool isSearching = false;
    bool isSaving = false;
    DateTime? expiryDate;
    DateTime? productionDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> doSearch(String q) async {
            if (q.trim().isEmpty) {
              setDialogState(() => searchResults = []);
              return;
            }
            setDialogState(() => isSearching = true);
            final results = await InventoryService.searchProductsByName(q);
            setDialogState(() {
              searchResults = results;
              isSearching = false;
            });
          }

          Future<void> pickDate(bool isExpiry) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setDialogState(() {
                if (isExpiry) {
                  expiryDate = picked;
                } else {
                  productionDate = picked;
                }
              });
            }
          }

          String fmtDate(DateTime? d) {
            if (d == null) return '-';
            return '${d.day}/${d.month}/${d.year + 543}';
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_shopping_cart, color: Colors.green),
                SizedBox(width: 8),
                Text('รับสินค้าเข้าคลัง', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product search
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ค้นหาสินค้า',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => doSearch(v),
                    ),
                    if (isSearching) const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    if (searchResults.isNotEmpty && selectedProduct == null)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          itemBuilder: (_, i) {
                            final p = searchResults[i];
                            final unit = p['unit'];
                            final unitStr = (unit is Map) ? (unit['abbreviation'] ?? unit['name'] ?? '') : '';
                            return ListTile(
                              dense: true,
                              title: Text(p['name'] ?? ''),
                              subtitle: Text(unitStr),
                              onTap: () {
                                setDialogState(() {
                                  selectedProduct = p;
                                  searchResults = [];
                                  searchCtrl.text = p['name'] ?? '';
                                });
                              },
                            );
                          },
                        ),
                      ),
                    if (selectedProduct != null) ...[
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(selectedProduct!['name'] ?? ''),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setDialogState(() {
                          selectedProduct = null;
                          searchCtrl.clear();
                        }),
                      ),
                      const SizedBox(height: 12),
                      // Quantity
                      TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'จำนวนที่รับ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cost
                      TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ต้นทุนต่อหน่วย (บาท)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text('ผลิต: ${fmtDate(productionDate)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () => pickDate(false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event, size: 16),
                              label: Text('หมดอายุ: ${fmtDate(expiryDate)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () => pickDate(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Note
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'หมายเหตุ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: (selectedProduct == null || isSaving)
                    ? null
                    : () async {
                        final qty = double.tryParse(qtyController.text) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('กรุณากรอกจำนวนที่ถูกต้อง'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);

                        final productId = selectedProduct!['id'] as String;
                        // Fetch current quantity
                        final products = await InventoryService.getProducts();
                        final current = products.firstWhere(
                          (p) => p['id'] == productId,
                          orElse: () => {'quantity': 0},
                        );
                        final currentQty = (current['quantity'] as num?)?.toDouble() ?? 0;
                        final newQty = currentQty + qty;

                        final user = Supabase.instance.client.auth.currentUser;
                        final userName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'พนักงาน';

                        final cost = double.tryParse(costController.text) ?? 0;
                        final note = noteController.text.trim();
                        final reason = 'รับสินค้าเข้าคลัง${cost > 0 ? ' (ต้นทุน ฿${cost.toStringAsFixed(2)}/หน่วย)' : ''}${note.isNotEmpty ? ' - $note' : ''}';

                        // Lot barcode entries
                        List<Map<String, dynamic>>? lotEntries;
                        if (productionDate != null || expiryDate != null) {
                          lotEntries = [
                            {
                              'quantity': qty,
                              'production_date': productionDate?.toIso8601String(),
                              'expiry_date': expiryDate?.toIso8601String(),
                            }
                          ];
                        }

                        final success = await InventoryService.addAdjustment(
                          productId: productId,
                          type: 'purchase',
                          quantityBefore: currentQty,
                          quantityAfter: newQty,
                          reason: reason,
                          userName: userName,
                          lotBarcodeEntries: lotEntries,
                        );

                        // Update cost if provided
                        if (success && cost > 0) {
                          await InventoryService.updateProduct(productId, {'cost': cost});
                        }

                        setDialogState(() => isSaving = false);

                        if (success) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('รับสินค้า "${selectedProduct!['name']}" จำนวน ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} สำเร็จ'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('เกิดข้อผิดพลาดในการรับสินค้า'), backgroundColor: Colors.red),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('ยืนยันรับสินค้า'),
              ),
            ],
          );
        },
      ),
    );
  }
}
