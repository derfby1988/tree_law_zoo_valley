import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.white),
            SizedBox(width: 8),
            Text('รายงาน / แจ้งเตือน', style: TextStyle(color: Colors.white)),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber), text: 'แจ้งเตือน'),
            Tab(icon: Icon(Icons.point_of_sale), text: 'ยอดขาย'),
            Tab(icon: Icon(Icons.history), text: 'Audit Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LowStockAlertTab(),
          _SalesReportTab(),
          _AuditLogTab(),
        ],
      ),
    );
  }
}

// =============================================
// Tab 1: Low Stock Alert
// =============================================
class _LowStockAlertTab extends StatefulWidget {
  const _LowStockAlertTab();

  @override
  State<_LowStockAlertTab> createState() => _LowStockAlertTabState();
}

class _LowStockAlertTabState extends State<_LowStockAlertTab> {
  List<Map<String, dynamic>> _lowStockProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final products = await InventoryService.getLowStockProducts();
    setState(() {
      _lowStockProducts = products;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_lowStockProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text('สต็อกทุกรายการอยู่ในระดับปกติ', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('รีเฟรช'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lowStockProducts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red[700], size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สินค้าคงเหลือต่ำ ${_lowStockProducts.length} รายการ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700], fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'สินค้าเหล่านี้มีจำนวนคงเหลือต่ำกว่าหรือเท่ากับจำนวนขั้นต่ำที่กำหนด',
                              style: TextStyle(color: Colors.red[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final p = _lowStockProducts[index - 1];
          final name = p['name'] ?? '-';
          final qty = (p['quantity'] as num?)?.toDouble() ?? 0;
          final minQty = (p['min_quantity'] as num?)?.toDouble() ?? 0;
          final unit = p['unit'];
          final unitStr = (unit is Map) ? (unit['abbreviation'] ?? unit['name'] ?? '') : '';
          final ratio = minQty > 0 ? (qty / minQty).clamp(0.0, 1.0) : 0.0;
          final isZero = qty <= 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isZero ? Colors.red[100] : Colors.orange[100],
                child: Icon(
                  isZero ? Icons.error : Icons.warning_amber,
                  color: isZero ? Colors.red : Colors.orange,
                  size: 20,
                ),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'คงเหลือ: ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $unitStr',
                        style: TextStyle(color: isZero ? Colors.red : Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(ขั้นต่ำ: ${minQty.toStringAsFixed(minQty == minQty.roundToDouble() ? 0 : 2)})',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(isZero ? Colors.red : Colors.orange),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: isZero
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Text('หมด', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                      child: const Text('ต่ำ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================
// Tab 2: Sales Report
// =============================================
class _SalesReportTab extends StatefulWidget {
  const _SalesReportTab();

  @override
  State<_SalesReportTab> createState() => _SalesReportTabState();
}

class _SalesReportTabState extends State<_SalesReportTab> {
  Map<String, dynamic> _report = {};
  bool _isLoading = true;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = DateTime.now().subtract(const Duration(days: 7));
    _dateTo = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final report = await InventoryService.getSalesReport(dateFrom: _dateFrom, dateTo: _dateTo);
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year + 543}';
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final totalSales = (_report['total_sales'] as num?)?.toDouble() ?? 0;
    final totalTax = (_report['total_tax'] as num?)?.toDouble() ?? 0;
    final totalService = (_report['total_service'] as num?)?.toDouble() ?? 0;
    final totalDiscount = (_report['total_discount'] as num?)?.toDouble() ?? 0;
    final orderCount = (_report['order_count'] as int?) ?? 0;
    final orders = (_report['orders'] as List<Map<String, dynamic>>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date filter
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text('จาก: ${_fmtDate(_dateFrom)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 14),
                    label: Text('ถึง: ${_fmtDate(_dateTo)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Summary cards
            Row(
              children: [
                Expanded(child: _statCard('ยอดขายรวม', '฿${totalSales.toStringAsFixed(2)}', Colors.green, Icons.attach_money)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('จำนวนออเดอร์', '$orderCount', Colors.blue, Icons.receipt)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _statCard('ภาษี', '฿${totalTax.toStringAsFixed(2)}', Colors.orange, Icons.account_balance)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('ค่าบริการ', '฿${totalService.toStringAsFixed(2)}', Colors.purple, Icons.room_service)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('ส่วนลด', '฿${totalDiscount.toStringAsFixed(2)}', Colors.red, Icons.discount)),
              ],
            ),
            const SizedBox(height: 16),
            // Order list
            Text('รายการออเดอร์ (${orders.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('ไม่มีออเดอร์ในช่วงเวลานี้', style: TextStyle(color: Colors.grey[500])),
              ))
            else
              ...orders.map((o) {
                final orderNum = o['order_number'] ?? '-';
                final net = (o['net_total'] as num?)?.toDouble() ?? 0;
                final method = o['payment_method'] ?? '-';
                final userName = o['user_name'] ?? '';
                final createdAt = o['created_at'] != null ? DateTime.tryParse(o['created_at'].toString()) : null;
                final dateStr = createdAt != null
                    ? '${createdAt.toLocal().day}/${createdAt.toLocal().month}/${createdAt.toLocal().year + 543} ${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}'
                    : '-';

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.green[50],
                      child: Icon(Icons.receipt, color: Colors.green[700], size: 16),
                    ),
                    title: Text(orderNum, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('$dateStr • $method • $userName', style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      '฿${net.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 14),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// =============================================
// Tab 3: Audit Log
// =============================================
class _AuditLogTab extends StatefulWidget {
  const _AuditLogTab();

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _selectedType = 'all';

  static const _typeFilters = [
    {'value': 'all', 'label': 'ทั้งหมด'},
    {'value': 'sale', 'label': 'ขาย'},
    {'value': 'purchase', 'label': 'รับเข้า'},
    {'value': 'withdraw', 'label': 'เบิกใช้'},
    {'value': 'damage', 'label': 'สินค้าเสีย'},
    {'value': 'count', 'label': 'ตรวจนับ'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final logs = await InventoryService.getStockMovements(
      limit: 200,
      type: _selectedType == 'all' ? null : _selectedType,
    );
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
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

  String _typeLabel(String type) {
    switch (type) {
      case 'sale': return 'ขาย';
      case 'purchase': case 'receive': return 'รับเข้า';
      case 'withdraw': return 'เบิกใช้';
      case 'damage': return 'สินค้าเสีย';
      case 'count': return 'ตรวจนับ';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _typeFilters.map((f) {
                final isSelected = _selectedType == f['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(f['label'] as String, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                    selectedColor: Colors.blueGrey,
                    onSelected: (_) {
                      setState(() => _selectedType = f['value'] as String);
                      _loadData();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Log list
        Expanded(
          child: _logs.isEmpty
              ? Center(child: Text('ไม่มีรายการ', style: TextStyle(color: Colors.grey[500])))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final product = log['product'] as Map<String, dynamic>?;
                      final productName = product?['name'] ?? '-';
                      final type = log['type'] as String? ?? '';
                      final change = (log['quantity_change'] as num?)?.toDouble() ?? 0;
                      final before = (log['quantity_before'] as num?)?.toDouble() ?? 0;
                      final after = (log['quantity_after'] as num?)?.toDouble() ?? 0;
                      final reason = log['reason'] ?? '';
                      final userName = log['user_name'] ?? '';
                      final unit = product?['unit'];
                      final unitStr = (unit is Map) ? (unit['abbreviation'] ?? unit['name'] ?? '') : '';
                      final createdAt = log['created_at'] != null ? DateTime.tryParse(log['created_at'].toString()) : null;
                      final dateStr = createdAt != null
                          ? '${createdAt.toLocal().day}/${createdAt.toLocal().month}/${createdAt.toLocal().year + 543} ${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}'
                          : '-';
                      final isPositive = change >= 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _typeColor(type).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _typeLabel(type),
                                      style: TextStyle(fontSize: 11, color: _typeColor(type), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                  Text(
                                    '${isPositive ? '+' : ''}${change.toStringAsFixed(change == change.roundToDouble() ? 0 : 2)} $unitStr',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isPositive ? Colors.green[700] : Colors.red[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${before.toStringAsFixed(0)} → ${after.toStringAsFixed(0)} $unitStr',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                  const Spacer(),
                                  Text(dateStr, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                ],
                              ),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(reason, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                              if (userName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('โดย: $userName', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
