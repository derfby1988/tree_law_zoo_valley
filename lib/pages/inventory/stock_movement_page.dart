import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';

class StockMovementPage extends StatefulWidget {
  const StockMovementPage({super.key});

  @override
  State<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends State<StockMovementPage> {
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String _selectedType = 'all';
  String? _selectedProductId;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _typeOptions = [
    {'value': 'all', 'label': 'ทั้งหมด', 'icon': Icons.list, 'color': Colors.blueGrey},
    {'value': 'sale', 'label': 'ขาย', 'icon': Icons.point_of_sale, 'color': Colors.red},
    {'value': 'purchase', 'label': 'รับเข้า', 'icon': Icons.add_shopping_cart, 'color': Colors.green},
    {'value': 'withdraw', 'label': 'เบิกใช้', 'icon': Icons.outbox, 'color': Colors.cyan},
    {'value': 'damage', 'label': 'สินค้าเสีย', 'icon': Icons.delete_forever, 'color': Colors.orange},
    {'value': 'count', 'label': 'ตรวจนับ', 'icon': Icons.inventory_2, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _dateFrom = DateTime.now().subtract(const Duration(days: 30));
    _dateTo = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        InventoryService.getStockMovements(
          limit: 200,
          type: _selectedType == 'all' ? null : _selectedType,
          productId: _selectedProductId,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        ),
        InventoryService.getProducts(),
        InventoryService.getMovementSummary(dateFrom: _dateFrom, dateTo: _dateTo),
      ]);
      setState(() {
        _movements = results[0] as List<Map<String, dynamic>>;
        _products = results[1] as List<Map<String, dynamic>>;
        _summary = results[2] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year + 543}';
  }

  String _fmtDateTime(String? isoStr) {
    if (isoStr == null) return '-';
    final d = DateTime.tryParse(isoStr);
    if (d == null) return '-';
    final local = d.toLocal();
    return '${local.day}/${local.month}/${local.year + 543} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'sale': return Colors.red;
      case 'purchase': case 'receive': return Colors.green;
      case 'withdraw': return Colors.cyan;
      case 'damage': return Colors.orange;
      case 'count': return Colors.purple;
      default: return Colors.blueGrey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'sale': return Icons.point_of_sale;
      case 'purchase': case 'receive': return Icons.add_shopping_cart;
      case 'withdraw': return Icons.outbox;
      case 'damage': return Icons.delete_forever;
      case 'count': return Icons.inventory_2;
      default: return Icons.swap_vert;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'sale': return 'ขาย';
      case 'purchase': return 'รับเข้า';
      case 'receive': return 'รับเข้า';
      case 'withdraw': return 'เบิกใช้';
      case 'damage': return 'สินค้าเสีย';
      case 'count': return 'ตรวจนับ';
      default: return type;
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _dateFrom = picked;
        else _dateTo = picked;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.swap_vert, color: Colors.white),
            SizedBox(width: 8),
            Text('Stock Movement', style: TextStyle(color: Colors.white)),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 16),
                        _buildFilters(),
                        const SizedBox(height: 16),
                        _buildMovementList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final totalIn = (_summary['total_in'] as num?)?.toDouble() ?? 0;
    final totalOut = (_summary['total_out'] as num?)?.toDouble() ?? 0;
    final saleCount = (_summary['sale_count'] as int?) ?? 0;
    final purchaseCount = (_summary['purchase_count'] as int?) ?? 0;
    final adjustCount = (_summary['adjust_count'] as int?) ?? 0;
    final totalCount = (_summary['total_count'] as int?) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'สรุป ${_fmtDate(_dateFrom)} - ${_fmtDate(_dateTo)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _summaryCard('รับเข้า', '+${totalIn.toStringAsFixed(0)}', Colors.green, Icons.arrow_downward, purchaseCount)),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard('จ่ายออก', '-${totalOut.toStringAsFixed(0)}', Colors.red, Icons.arrow_upward, saleCount)),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard('ปรับปรุง', '$adjustCount', Colors.orange, Icons.build, adjustCount)),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard('ทั้งหมด', '$totalCount', Colors.blueGrey, Icons.list, totalCount)),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color color, IconData icon, int count) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text('$count รายการ', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ตัวกรอง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            // Type filter chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _typeOptions.map((opt) {
                final isSelected = _selectedType == opt['value'];
                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt['icon'] as IconData, size: 14, color: isSelected ? Colors.white : opt['color'] as Color),
                      const SizedBox(width: 4),
                      Text(opt['label'] as String, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                    ],
                  ),
                  selectedColor: opt['color'] as Color,
                  backgroundColor: (opt['color'] as Color).withValues(alpha: 0.1),
                  onSelected: (_) {
                    setState(() => _selectedType = opt['value'] as String);
                    _loadData();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Date range + product filter
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text('จาก: ${_fmtDate(_dateFrom)}', style: const TextStyle(fontSize: 11)),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 14),
                    label: Text('ถึง: ${_fmtDate(_dateTo)}', style: const TextStyle(fontSize: 11)),
                    onPressed: () => _pickDate(false),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'สินค้า',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    value: _selectedProductId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('ทั้งหมด', style: TextStyle(fontSize: 12))),
                      ..._products.map((p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedProductId = v);
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementList() {
    if (_movements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.swap_vert, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('ไม่พบรายการ movement', style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('รายการ (${_movements.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(width: 32),
              Expanded(flex: 3, child: Text('สินค้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('ประเภท', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('เปลี่ยนแปลง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('คงเหลือ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
              Expanded(flex: 3, child: Text('วันที่/ผู้ทำ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
            ],
          ),
        ),
        // Movement rows
        ...List.generate(_movements.length, (i) {
          final m = _movements[i];
          final product = m['product'] as Map<String, dynamic>?;
          final productName = product?['name'] ?? '-';
          final unit = product?['unit'];
          final unitStr = (unit is Map) ? (unit['abbreviation'] ?? unit['name'] ?? '') : '';
          final type = m['type'] as String? ?? '';
          final change = (m['quantity_change'] as num?)?.toDouble() ?? 0;
          final after = (m['quantity_after'] as num?)?.toDouble() ?? 0;
          final reason = m['reason'] ?? '';
          final userName = m['user_name'] ?? '';
          final dateStr = _fmtDateTime(m['created_at']?.toString());
          final isPositive = change >= 0;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Icon(_typeIcon(type), size: 18, color: _typeColor(type)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      if (reason.isNotEmpty)
                        Text(reason, style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor(type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _typeLabel(type),
                      style: TextStyle(fontSize: 11, color: _typeColor(type), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(change == change.roundToDouble() ? 0 : 2)} $unitStr',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green[700] : Colors.red[700],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${after.toStringAsFixed(after == after.roundToDouble() ? 0 : 2)} $unitStr',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateStr, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      Text(userName, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
