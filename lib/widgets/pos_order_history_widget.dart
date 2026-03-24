import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/inventory_service.dart';
import '../services/pos_refund_service.dart';
import '../theme/app_design_system.dart';

class PosOrderHistoryWidget extends StatefulWidget {
  final VoidCallback onBackToPos;

  const PosOrderHistoryWidget({super.key, required this.onBackToPos});

  @override
  State<PosOrderHistoryWidget> createState() => _PosOrderHistoryWidgetState();
}

class _PosOrderHistoryWidgetState extends State<PosOrderHistoryWidget> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _selectedOrder;
  bool _isLoading = false;

  Color get _bgColor => AppDesignSystem.background;
  Color get _cardColor => AppDesignSystem.surface;
  Color get _accentGreen => AppDesignSystem.primary;
  Color get _textPrimary => AppDesignSystem.textPrimary;
  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _borderColor => AppDesignSystem.border;
  LinearGradient get _iconGradient => AppDesignSystem.accentGradient;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final orders = await InventoryService.getRecentPosOrders(limit: 50);
      if (!mounted) return;

      Map<String, dynamic>? selected = _selectedOrder;
      if (selected != null) {
        final sid = selected['id']?.toString();
        selected = orders.where((o) => o['id']?.toString() == sid).cast<Map<String, dynamic>>().firstOrNull;
      }

      setState(() {
        _orders
          ..clear()
          ..addAll(orders);
        _selectedOrder = selected ?? (orders.isNotEmpty ? orders.first : null);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return List<Map<String, dynamic>>.from(_orders);
    return _orders.where((o) {
      return (o['order_number'] ?? '').toString().toLowerCase().contains(q) ||
          (o['table_number'] ?? '').toString().toLowerCase().contains(q) ||
          (o['customer_name'] ?? '').toString().toLowerCase().contains(q) ||
          (o['cashier_user_name'] ?? '').toString().toLowerCase().contains(q) ||
          (o['payment_method'] ?? '').toString().toLowerCase().contains(q);
    }).map((o) => Map<String, dynamic>.from(o)).toList();
  }

  // =============================================
  // Build
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: _gradientIcon(Icons.arrow_back, size: 20),
            onPressed: widget.onBackToPos,
            tooltip: 'กลับไป POS',
          ),
          const SizedBox(width: 8),
          _gradientIcon(Icons.receipt_long, size: 20),
          const SizedBox(width: 8),
          Text('ประวัติออเดอร์ / คืนเงิน',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ค้นหาเลขบิล / โต๊ะ / ลูกค้า / พนักงาน',
                  hintStyle: TextStyle(fontSize: 12, color: _textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('รีเฟรช', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final filtered = _filteredOrders;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1000;
        final listPane = SizedBox(
          width: isNarrow ? double.infinity : 380,
          child: _buildOrderList(filtered),
        );

        return Padding(
          padding: const EdgeInsets.all(12),
          child: isNarrow
              ? Column(
                  children: [
                    Expanded(flex: 4, child: listPane),
                    const SizedBox(height: 12),
                    Expanded(flex: 6, child: _buildOrderDetail()),
                  ],
                )
              : Row(
                  children: [
                    listPane,
                    const SizedBox(width: 12),
                    Expanded(child: _buildOrderDetail()),
                  ],
                ),
        );
      },
    );
  }

  // =============================================
  // Order List
  // =============================================

  Widget _buildOrderList(List<Map<String, dynamic>> orders) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _gradientIcon(Icons.list_alt, size: 18),
                const SizedBox(width: 8),
                Text('บิลล่าสุด', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _gradientIcon(Icons.receipt_long, size: 12),
                      const SizedBox(width: 4),
                      Text('${orders.length} รายการ', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? Center(child: Text('ไม่พบบิล', style: TextStyle(color: _textSecondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final isSelected = _selectedOrder?['id']?.toString() == order['id']?.toString();
                          return _buildOrderCard(order, isSelected: isSelected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {required bool isSelected}) {
    final orderNumber = (order['order_number'] ?? '-').toString();
    final tableNumber = (order['table_number'] ?? '-').toString();
    final customerName = (order['customer_name'] ?? '-').toString();
    final createdAt = _parseDateTime(order['created_at']);
    final status = (order['status'] ?? 'completed').toString();
    final netTotal = (order['net_total'] ?? 0).toDouble();

    return InkWell(
      onTap: () => setState(() => _selectedOrder = Map<String, dynamic>.from(order)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _accentGreen.withValues(alpha: 0.08) : _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _accentGreen.withValues(alpha: 0.35) : _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(orderNumber,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 6),
            Text('โต๊ะ: $tableNumber  ลูกค้า: $customerName',
                style: TextStyle(fontSize: 11, color: _textSecondary), overflow: TextOverflow.ellipsis),
            if (createdAt != null)
              Text(_formatThaiDateTime(createdAt), style: TextStyle(fontSize: 10, color: _textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('฿${netTotal.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _accentGreen)),
                const Spacer(),
                Text((order['payment_method'] ?? '').toString(), style: TextStyle(fontSize: 11, color: _textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  // Order Detail
  // =============================================

  Widget _buildOrderDetail() {
    final order = _selectedOrder;
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: order == null
          ? Center(child: Text('เลือกบิลเพื่อดูรายละเอียด', style: TextStyle(color: _textSecondary)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Text((order['order_number'] ?? '-').toString(),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)),
                      ),
                      _statusChip((order['status'] ?? 'completed').toString()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Meta chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metaChip(Icons.table_restaurant, 'โต๊ะ ${(order['table_number'] ?? '-')}'),
                      _metaChip(Icons.person, (order['user_name'] ?? '-').toString()),
                      _metaChip(Icons.badge, (order['cashier_user_name'] ?? '-').toString()),
                      _metaChip(Icons.payments, (order['payment_method'] ?? '-').toString()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Amounts
                  _summaryRow('ยอดสุทธิ', '฿${(order['net_total'] ?? 0).toDouble().toStringAsFixed(2)}', bold: true),
                  _summaryRow('ส่วนลด', '-฿${(order['discount_amount'] ?? 0).toDouble().toStringAsFixed(2)}'),
                  _summaryRow('ภาษี', '฿${(order['tax_amount'] ?? 0).toDouble().toStringAsFixed(2)}'),
                  _summaryRow('ค่าบริการ', '฿${(order['service_amount'] ?? 0).toDouble().toStringAsFixed(2)}'),
                  if ((order['refund_amount'] ?? 0).toDouble() > 0)
                    _summaryRow('คืนเงินแล้ว', '-฿${(order['refund_amount'] ?? 0).toDouble().toStringAsFixed(2)}',
                        color: Colors.red),
                  const Divider(height: 24),
                  Text('รายการสินค้า', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                  const SizedBox(height: 8),
                  Expanded(child: _buildLineItems(order)),
                  const SizedBox(height: 12),
                  // Action buttons
                  _buildActionButtons(order),
                ],
              ),
            ),
    );
  }

  Widget _buildLineItems(Map<String, dynamic> order) {
    final rawLines = order['lines'];
    final lines = rawLines is List ? rawLines.cast<dynamic>() : <dynamic>[];
    if (lines.isEmpty) {
      return Center(child: Text('ไม่มีข้อมูลรายการสินค้า', style: TextStyle(color: _textSecondary)));
    }
    return ListView.separated(
      itemCount: lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = lines[index] as Map<String, dynamic>;
        final name = (item['product_name'] ?? item['name'] ?? '-').toString();
        final qty = (item['qty'] ?? item['quantity'] ?? 1).toDouble();
        final price = (item['unit_price'] ?? item['price'] ?? 0).toDouble();
        final lineTotal = (item['subtotal'] ?? item['line_total'] ?? qty * price).toDouble();
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text('${qty.toInt()} × ฿${price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: _textSecondary)),
                  ],
                ),
              ),
              Text('฿${lineTotal.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _accentGreen)),
            ],
          ),
        );
      },
    );
  }

  // =============================================
  // Action Buttons (Void / Refund)
  // =============================================

  Widget _buildActionButtons(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'completed').toString();
    final canAct = status == 'completed';

    if (!canAct) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          status == 'voided' ? 'บิลนี้ถูก Void แล้ว' : 'บิลนี้ถูกคืนเงินแล้ว',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showVoidDialog(order),
            icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 18),
            label: Text('Void', style: TextStyle(color: Colors.red.shade400)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showRefundDialog(order),
            icon: const Icon(Icons.reply_all, size: 18),
            label: const Text('Refund'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // =============================================
  // Void Dialog
  // =============================================

  void _showVoidDialog(Map<String, dynamic> order) {
    final reasonController = TextEditingController();
    final orderNumber = (order['order_number'] ?? '-').toString();
    final netTotal = (order['net_total'] ?? 0).toDouble();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 22),
            const SizedBox(width: 8),
            Text('Void บิล $orderNumber', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ยอดบิล: ฿${netTotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                    const SizedBox(height: 4),
                    Text('การ Void จะยกเลิกบิลนี้ทั้งหมดและคืน stock สินค้า',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 2,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'เหตุผลในการ Void *',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: _bgColor,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton.icon(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณาระบุเหตุผล'), backgroundColor: Colors.orange),
                );
                return;
              }
              final user = Supabase.instance.client.auth.currentUser;
              final userName = _displayName(user);

              final result = await PosRefundService.voidOrder(
                orderId: order['id'] as String,
                orderTotal: netTotal,
                reason: reason,
                userId: user?.id ?? '',
                userName: userName,
              );

              if (result != null && mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Void บิล $orderNumber สำเร็จ'), backgroundColor: _accentGreen),
                );
                _loadOrders();
              }
            },
            icon: Icon(Icons.remove_circle_outline, color: Colors.white, size: 18),
            label: const Text('ยืนยัน Void'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          ),
        ],
      ),
    );
  }

  // =============================================
  // Refund Dialog
  // =============================================

  void _showRefundDialog(Map<String, dynamic> order) {
    final reasonController = TextEditingController();
    final orderNumber = (order['order_number'] ?? '-').toString();
    final netTotal = (order['net_total'] ?? 0).toDouble();
    final paymentMethod = (order['payment_method'] ?? 'cash').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.reply_all, color: Colors.orange.shade700, size: 22),
            const SizedBox(width: 8),
            Text('คืนเงินบิล $orderNumber', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ยอดคืนเงิน: ฿${netTotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
                    const SizedBox(height: 4),
                    Text('วิธีจ่ายเดิม: $paymentMethod',
                        style: TextStyle(fontSize: 12, color: _textSecondary)),
                    const SizedBox(height: 4),
                    Text('คืนเงินทั้งบิลและคืน stock สินค้า',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade400)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 2,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'เหตุผลในการคืนเงิน *',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: _bgColor,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton.icon(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณาระบุเหตุผล'), backgroundColor: Colors.orange),
                );
                return;
              }
              final user = Supabase.instance.client.auth.currentUser;
              final userName = _displayName(user);

              final result = await PosRefundService.refundFullOrder(
                orderId: order['id'] as String,
                orderTotal: netTotal,
                refundMethod: paymentMethod,
                reason: reason,
                userId: user?.id ?? '',
                userName: userName,
              );

              if (result != null && mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('คืนเงินบิล $orderNumber สำเร็จ ฿${netTotal.toStringAsFixed(2)}'),
                      backgroundColor: _accentGreen),
                );
                _loadOrders();
              }
            },
            icon: const Icon(Icons.reply_all, size: 18),
            label: const Text('ยืนยันคืนเงิน'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  // =============================================
  // Helper widgets
  // =============================================

  Widget _gradientIcon(IconData icon, {double size = 18}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => _iconGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'voided' => Colors.red,
      'refunded' => Colors.orange,
      'partial_refund' => Colors.orange,
      'completed' => _accentGreen,
      _ => _textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'voided':
        return 'Void';
      case 'refunded':
        return 'Refund';
      case 'partial_refund':
        return 'คืนบางส่วน';
      case 'completed':
        return 'สำเร็จ';
      default:
        return status;
    }
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gradientIcon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: _textSecondary, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? (bold ? _accentGreen : _textPrimary))),
        ],
      ),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  String _formatThaiDateTime(DateTime date) {
    const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    final d = date.day.toString().padLeft(2, '0');
    final m = months[date.month - 1];
    final y = (date.year + 543).toString().substring(2);
    final t = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$d $m $y $t น.';
  }

  String _displayName(User? user) {
    if (user == null) return 'ไม่ทราบชื่อ';
    final meta = user.userMetadata;
    if (meta == null) return user.email ?? 'ไม่ทราบชื่อ';
    final fn = meta['full_name']?.toString();
    if (fn != null && fn.isNotEmpty) return fn;
    final first = (meta['first_name'] ?? '').toString();
    final last = (meta['last_name'] ?? '').toString();
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    return meta['display_name']?.toString() ?? user.email ?? 'ไม่ทราบชื่อ';
  }
}
