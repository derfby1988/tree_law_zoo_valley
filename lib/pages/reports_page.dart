import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/inventory_service.dart';
import '../services/pos_shift_service.dart';
import '../utils/thai_date_utils.dart';
import '../widgets/pos_eod_settlement_widget.dart';

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
    _tabController = TabController(length: 7, vsync: this);
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
            Tab(icon: Icon(Icons.badge), text: 'สรุปกะ'),
            Tab(icon: Icon(Icons.undo), text: 'คืนเงิน/Void'),
            Tab(icon: Icon(Icons.trending_up), text: 'สินค้าขายดี'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'ปิดยอด'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LowStockAlertTab(),
          _SalesReportTab(),
          _AuditLogTab(),
          _ShiftSummaryTab(),
          _RefundVoidAuditTab(),
          _SalesInsightsTab(),
          const PosEodSettlementWidget(),
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

          final p = _lowStockProducts[index - 2];
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
    return ThaiDateUtils.formatBuddhistDate(d, emptyText: '-');
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await ThaiDateUtils.showThaiDatePicker(
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

// =============================================
// Tab 4: Shift Summary Report
// =============================================
class _ShiftSummaryTab extends StatefulWidget {
  const _ShiftSummaryTab();

  @override
  State<_ShiftSummaryTab> createState() => _ShiftSummaryTabState();
}

class _ShiftSummaryTabState extends State<_ShiftSummaryTab> {
  List<dynamic> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final shifts = await PosShiftService.getShiftHistory(limit: 30);
    setState(() {
      _shifts = shifts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('ยังไม่มีประวัติกะ', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('รีเฟรช')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _shifts.length,
        itemBuilder: (context, index) {
          final shift = _shifts[index];
          final shiftNumber = shift.shiftNumber;
          final openedAt = shift.openedAt;
          final closedAt = shift.closedAt;
          final status = shift.status;
          final openedByName = shift.openedByName ?? '-';
          final startingCash = shift.startingCash;
          final endingCash = shift.endingCash;

          final openedStr = openedAt != null
              ? '${openedAt.toLocal().day}/${openedAt.toLocal().month}/${openedAt.toLocal().year + 543} ${openedAt.toLocal().hour.toString().padLeft(2, '0')}:${openedAt.toLocal().minute.toString().padLeft(2, '0')}'
              : '-';
          final closedStr = closedAt != null
              ? '${closedAt.toLocal().day}/${closedAt.toLocal().month}/${closedAt.toLocal().year + 543} ${closedAt.toLocal().hour.toString().padLeft(2, '0')}:${closedAt.toLocal().minute.toString().padLeft(2, '0')}'
              : 'ยังเปิดอยู่';

          final isOpen = status == 'open';
          final color = isOpen ? Colors.green : Colors.blueGrey;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.badge, color: color, size: 20),
              ),
              title: Text('กะที่ $shiftNumber', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('$openedStr → $closedStr • $openedByName', style: const TextStyle(fontSize: 11)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Text(isOpen ? 'เปิด' : 'ปิด', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: PosShiftService.getShiftSummary(shift.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator());
                    }
                    final s = snapshot.data!;
                    final totalSales = (s['total_sales'] ?? 0).toDouble();
                    final totalOrders = (s['total_orders'] ?? 0) as int;
                    final totalRefunds = (s['total_refunds'] ?? 0).toDouble();
                    final totalDiscounts = (s['total_discounts'] ?? 0).toDouble();
                    final cashSales = (s['cash_sales'] ?? 0).toDouble();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shiftRow('ยอดขายรวม', '฿${totalSales.toStringAsFixed(2)}', Colors.green),
                          _shiftRow('จำนวนออเดอร์', '$totalOrders บิล', Colors.blue),
                          _shiftRow('ขายเงินสด', '฿${cashSales.toStringAsFixed(2)}', Colors.teal),
                          _shiftRow('ส่วนลดรวม', '฿${totalDiscounts.toStringAsFixed(2)}', Colors.red),
                          _shiftRow('คืนเงินรวม', '฿${totalRefunds.toStringAsFixed(2)}', Colors.orange),
                          const Divider(),
                          _shiftRow('เงินทุนต้นกะ', '฿${startingCash.toStringAsFixed(2)}', Colors.purple),
                          if (endingCash != null)
                            _shiftRow('เงินปลายกะ', '฿${endingCash.toStringAsFixed(2)}', Colors.indigo),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shiftRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// =============================================
// Tab 5: Refund/Void Audit Log
// =============================================
class _RefundVoidAuditTab extends StatefulWidget {
  const _RefundVoidAuditTab();

  @override
  State<_RefundVoidAuditTab> createState() => _RefundVoidAuditTabState();
}

class _RefundVoidAuditTabState extends State<_RefundVoidAuditTab> {
  List<Map<String, dynamic>> _refunds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('pos_refunds')
          .select('''
            *,
            order:pos_orders(order_number, net_total, payment_method)
          ''')
          .order('created_at', ascending: false)
          .limit(100);
      setState(() {
        _refunds = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading refund audit: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_refunds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('ไม่มีประวัติคืนเงิน/Void', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('รีเฟรช')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _refunds.length,
        itemBuilder: (context, index) {
          final r = _refunds[index];
          final refundType = (r['refund_type'] ?? '-').toString();
          final refundAmount = (r['refund_amount'] ?? 0).toDouble();
          final reason = (r['reason'] ?? '-').toString();
          final refundedByName = (r['refunded_by_name'] ?? '-').toString();
          final approvedByName = (r['approved_by_name'] ?? '-').toString();
          final refundMethod = (r['refund_method'] ?? '-').toString();
          final orderData = r['order'] as Map<String, dynamic>?;
          final orderNumber = orderData?['order_number'] ?? '-';
          final createdAt = r['created_at'] != null ? DateTime.tryParse(r['created_at'].toString()) : null;
          final dateStr = createdAt != null
              ? '${createdAt.toLocal().day}/${createdAt.toLocal().month}/${createdAt.toLocal().year + 543} ${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}'
              : '-';

          final typeColor = refundType == 'void' ? Colors.red : Colors.orange;
          final typeLabel = refundType == 'void' ? 'Void' : (refundType == 'full' ? 'คืนเงินทั้งบิล' : 'คืนบางส่วน');

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(typeLabel, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('บิล $orderNumber', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Text('-฿${refundAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: typeColor, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('เหตุผล: $reason', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('โดย: $refundedByName', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(width: 12),
                      Text('อนุมัติ: $approvedByName', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(dateStr, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      const Spacer(),
                      if (refundMethod != 'null' && refundMethod != '-')
                        Text('คืนผ่าน: $refundMethod', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================
// Tab 6: Sales Insights Dashboard
// =============================================
class _SalesInsightsTab extends StatefulWidget {
  const _SalesInsightsTab();

  @override
  State<_SalesInsightsTab> createState() => _SalesInsightsTabState();
}

class _SalesInsightsTabState extends State<_SalesInsightsTab> {
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, double> _paymentBreakdown = {};
  Map<int, double> _hourlySales = {};
  bool _isLoading = true;
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _dateTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final fromStr = _dateFrom.toIso8601String().split('T')[0];
      final toStr = _dateTo.toIso8601String().split('T')[0];

      final orders = await client
          .from('pos_orders')
          .select('id, net_total, payment_method, created_at')
          .gte('created_at', fromStr)
          .lte('created_at', '${toStr}T23:59:59')
          .neq('status', 'voided')
          .order('created_at', ascending: false);

      final orderIds = (orders as List).map((o) => o['id'] as String).toList();

      // Top products
      if (orderIds.isNotEmpty) {
        final lines = await client
            .from('pos_order_lines')
            .select('product_name, quantity, line_total')
            .inFilter('order_id', orderIds);

        final productMap = <String, Map<String, double>>{};
        for (final line in lines) {
          final name = (line['product_name'] ?? '-').toString();
          final qty = (line['quantity'] ?? 0).toDouble();
          final total = (line['line_total'] ?? 0).toDouble();
          if (productMap.containsKey(name)) {
            productMap[name]!['qty'] = productMap[name]!['qty']! + qty;
            productMap[name]!['revenue'] = productMap[name]!['revenue']! + total;
          } else {
            productMap[name] = {'qty': qty, 'revenue': total};
          }
        }

        final sorted = productMap.entries.toList()
          ..sort((a, b) => b.value['qty']!.compareTo(a.value['qty']!));

        setState(() {
          _topProducts = sorted.take(15).map((e) => {
            'name': e.key,
            'qty': e.value['qty'],
            'revenue': e.value['revenue'],
          }).toList();
        });
      }

      // Payment breakdown + hourly sales
      _paymentBreakdown.clear();
      _hourlySales.clear();
      for (final o in orders) {
        final method = (o['payment_method'] ?? 'other').toString();
        final net = (o['net_total'] ?? 0).toDouble();
        _paymentBreakdown[method] = (_paymentBreakdown[method] ?? 0) + net;

        final createdAt = o['created_at'] != null ? DateTime.tryParse(o['created_at'].toString()) : null;
        if (createdAt != null) {
          final hour = createdAt.toLocal().hour;
          _hourlySales[hour] = (_hourlySales[hour] ?? 0) + net;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading sales insights: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await ThaiDateUtils.showThaiDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
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

    final maxQty = _topProducts.isEmpty ? 1.0 : _topProducts.first['qty'] as double;
    final maxHourly = _hourlySales.values.fold(0.0, (a, b) => a > b ? a : b);

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
                    label: Text('จาก: ${ThaiDateUtils.formatBuddhistDate(_dateFrom)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 14),
                    label: Text('ถึง: ${ThaiDateUtils.formatBuddhistDate(_dateTo)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Products
            Text('สินค้าขายดี Top 15', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (_topProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey[500]))),
              )
            else
              ..._topProducts.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                final name = p['name'] as String;
                final qty = p['qty'] as double;
                final revenue = p['revenue'] as double;
                final ratio = maxQty > 0 ? qty / maxQty : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: i < 3 ? Colors.amber[700] : Colors.grey)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(i < 3 ? Colors.amber : Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: Text('${qty.toStringAsFixed(0)} ชิ้น', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: Text('฿${revenue.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 20),

            // Payment Method Breakdown
            Text('ยอดขายตามวิธีชำระเงิน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (_paymentBreakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey[500]))),
              )
            else
              ...(() {
                final entries = _paymentBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                return entries.map((e) {
                final total = _paymentBreakdown.values.fold(0.0, (a, b) => a + b);
                final ratio = total > 0 ? e.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text(e.key, style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation(Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text('฿${e.value.toStringAsFixed(0)} (${(ratio * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }).toList();
              })(),

            const SizedBox(height: 20),

            // Hourly Sales
            Text('ยอดขายตามชั่วโมง', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (_hourlySales.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey[500]))),
              )
            else
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(24, (hour) {
                    final sales = _hourlySales[hour] ?? 0.0;
                    final barHeight = maxHourly > 0 ? (sales / maxHourly) * 120 : 0.0;
                    final hasData = sales > 0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hasData)
                              Text('${sales.toStringAsFixed(0)}', style: const TextStyle(fontSize: 7, color: Colors.grey)),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: hasData ? Colors.blue : Colors.grey[200],
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              ),
                            ),
                            Text('$hour', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
