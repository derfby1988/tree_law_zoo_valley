import 'package:flutter/material.dart';
import '../models/pos_daily_settlement_model.dart';
import '../services/pos_eod_service.dart';
import '../services/permission_service.dart';
import '../theme/app_design_system.dart';

class PosEodSettlementWidget extends StatefulWidget {
  const PosEodSettlementWidget({super.key});

  @override
  State<PosEodSettlementWidget> createState() => _PosEodSettlementWidgetState();
}

class _PosEodSettlementWidgetState extends State<PosEodSettlementWidget> {
  List<PosDailySettlement> _settlements = [];
  bool _isLoading = true;
  String? _errorMessage;

  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _primary => AppDesignSystem.primary;
  Color get _danger => AppDesignSystem.danger;
  Color get _warning => AppDesignSystem.warning;
  Color get _success => AppDesignSystem.success;

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
      final settlements = await PosEodService.getSettlementHistory();
      if (!mounted) return;
      setState(() {
        _settlements = settlements;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: _danger),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: _textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildSettlementList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Color(0xFF2AD49B)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ปิดยอดประจำวัน (EOD)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _checkPermissionAndExecute('pos_eod_create', 'สร้างยอดประจำวัน', _createTodaySettlement),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('สร้างยอดวันนี้'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementList() {
    if (_settlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('ยังไม่มีประวัติปิดยอดประจำวัน', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('กด "สร้างยอดวันนี้" เพื่อเริ่มต้น', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _settlements.length,
      itemBuilder: (context, index) {
        final s = _settlements[index];
        return _buildSettlementCard(s);
      },
    );
  }

  Widget _buildSettlementCard(PosDailySettlement s) {
    final dateStr = _formatDate(s.settlementDate);
    final isClosed = s.isClosed;
    final isReopened = s.isReopened;

    Color statusColor;
    String statusText;
    if (isClosed) {
      statusColor = _success;
      statusText = 'ปิดแล้ว';
    } else if (isReopened) {
      statusColor = _warning;
      statusText = 'เปิดใหม่';
    } else {
      statusColor = _warning;
      statusText = 'ร่าง';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            isClosed ? Icons.lock : Icons.edit_note,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text('วันที่ $dateStr', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${s.shiftIds.length} กะ • ${s.closedByName ?? "-"}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)),
          child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('ยอดขายรวม', '฿${s.totalSales.toStringAsFixed(2)}', _primary),
                _summaryRow('เงินสด', '฿${s.totalCash.toStringAsFixed(2)}', Colors.teal),
                _summaryRow('ไม่ใช่เงินสด', '฿${s.totalCashless.toStringAsFixed(2)}', Colors.blue),
                _summaryRow('ส่วนลด', '฿${s.totalDiscounts.toStringAsFixed(2)}', Colors.red),
                _summaryRow('แต้มที่แลก', '฿${s.totalLoyaltyRedeemed.toStringAsFixed(2)}', Colors.purple),
                _summaryRow('ภาษี', '฿${s.totalTax.toStringAsFixed(2)}', Colors.indigo),
                _summaryRow('ค่าบริการ', '฿${s.totalServiceCharge.toStringAsFixed(2)}', Colors.orange),
                _summaryRow('คืนเงิน', '฿${s.totalRefunds.toStringAsFixed(2)}', Colors.deepOrange),
                _summaryRow('ยกเลิกบิล', '฿${s.totalVoids.toStringAsFixed(2)}', Colors.redAccent),
                const Divider(),
                _summaryRow('เงินที่ควรมี', '฿${s.expectedCash.toStringAsFixed(2)}', Colors.blueGrey),
                if (s.countedCash != null)
                  _summaryRow('เงินนับจริง', '฿${s.countedCash!.toStringAsFixed(2)}', Colors.green),
                if (s.cashDifference != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.cashDifference == 0
                          ? _success.withValues(alpha: 0.1)
                          : _danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          s.cashDifference == 0 ? Icons.check_circle : Icons.warning,
                          size: 16,
                          color: s.cashDifference == 0 ? _success : _danger,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.cashDifference == 0
                              ? 'เงินสดตรง'
                              : 'เงิน${s.cashDifference! > 0 ? "เกิน" : "ขาด"} ฿${s.cashDifference!.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: s.cashDifference == 0 ? _success : _danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (s.note != null && s.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('หมายเหตุ: ${s.note}', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 12),
                if (!isClosed)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _checkPermissionAndExecute('pos_eod_close', 'ปิดยอดประจำวัน', () => _showCloseDialog(s)),
                          icon: const Icon(Icons.lock, size: 16),
                          label: const Text('ปิดยอด'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (isClosed)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _checkPermissionAndExecute('pos_eod_reopen', 'เปิดยอดใหม่', () => _showReopenDialog(s)),
                          icon: const Icon(Icons.lock_open, size: 16),
                          label: const Text('เปิดใหม่ (Admin)'),
                          style: OutlinedButton.styleFrom(foregroundColor: _warning),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final thaiYear = date.year + 543;
    return '${date.day}/${date.month}/$thaiYear';
  }

  Future<void> _checkPermissionAndExecute(String actionId, String actionName, VoidCallback onExecute) async {
    final canAccess = await PermissionService.canAccessAction(actionId);
    if (!canAccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('คุณไม่มีสิทธิ์$actionName'), backgroundColor: _danger),
      );
      return;
    }
    onExecute();
  }

  // =============================================
  // Create Today Settlement
  // =============================================

  Future<void> _createTodaySettlement() async {
    final today = DateTime.now();
    final validation = await PosEodService.validateBeforeClose(today);

    if (!validation['can_close']) {
      if (!mounted) return;
      final errors = List<String>.from(validation['errors']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n')),
          backgroundColor: _warning,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final settlement = await PosEodService.createSettlement(date: today);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (settlement != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้างร่างปิดยอดวันที่ ${_formatDate(today)} แล้ว'), backgroundColor: _success),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('ไม่สามารถสร้างยอดได้ — อาจมียอดของวันนี้อยู่แล้ว'), backgroundColor: _danger),
      );
    }
  }

  // =============================================
  // Close Settlement Dialog
  // =============================================

  Future<void> _showCloseDialog(PosDailySettlement settlement) async {
    final cashController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: _primary),
            const SizedBox(width: 8),
            const Text('ปิดยอดประจำวัน', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('วันที่ ${_formatDate(settlement.settlementDate)}',
                    style: TextStyle(fontSize: 14, color: _textSecondary)),
                const SizedBox(height: 8),
                _infoRow('เงินที่ควรมี', '฿${settlement.expectedCash.toStringAsFixed(2)}'),
                _infoRow('ยอดขายเงินสด', '฿${settlement.totalCash.toStringAsFixed(2)}'),
                _infoRow('คืนเงิน', '฿${settlement.totalRefunds.toStringAsFixed(2)}'),
                const Divider(),
                const SizedBox(height: 8),
                TextFormField(
                  controller: cashController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'เงินสดนับจริง',
                    prefixText: '฿ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกเงินสดนับจริง';
                    final val = double.tryParse(v);
                    if (val == null || val < 0) return 'กรุณากรอกจำนวนเงินที่ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'หมายเหตุ (ถ้ามี)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _success, foregroundColor: Colors.white),
            child: const Text('ยืนยันปิดยอด'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final countedCash = double.parse(cashController.text);
      final note = noteController.text.isNotEmpty ? noteController.text : null;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final closed = await PosEodService.closeSettlement(
        settlementId: settlement.id,
        countedCash: countedCash,
        userId: 'system',
        userName: 'ผู้จัดการ',
        note: note,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (closed != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              closed.cashDifference == 0
                  ? 'ปิดยอดเรียบร้อย — เงินสดตรง'
                  : 'ปิดยอดเรียบร้อย — เงิน${closed.cashDifference! > 0 ? "เกิน" : "ขาด"} ฿${closed.cashDifference!.abs().toStringAsFixed(2)}',
            ),
            backgroundColor: closed.cashDifference == 0 ? _success : _warning,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('ไม่สามารถปิดยอดได้'), backgroundColor: _danger),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: _textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // =============================================
  // Reopen Settlement Dialog (Admin)
  // =============================================

  Future<void> _showReopenDialog(PosDailySettlement settlement) async {
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: _warning),
            const SizedBox(width: 8),
            const Text('เปิดยอดใหม่ (Admin)', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('วันที่ ${_formatDate(settlement.settlementDate)}',
                style: TextStyle(fontSize: 14, color: _textSecondary)),
            const SizedBox(height: 8),
            Text('⚠️ การเปิดยอดใหม่จะเปลี่ยนสถานะเป็น "เปิดใหม่"\nและต้องบันทึกเหตุผล',
                style: TextStyle(color: _warning, fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'เหตุผลที่เปิดใหม่ *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'กรุณากรอกเหตุผล' : null,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _warning, foregroundColor: Colors.white),
            child: const Text('ยืนยันเปิดใหม่'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final reopened = await PosEodService.reopenSettlement(
        settlementId: settlement.id,
        userId: 'system',
        userName: 'ผู้จัดการ',
        note: noteController.text,
      );

      if (reopened != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปิดยอดใหม่แล้ว'), backgroundColor: Colors.orange),
        );
        _loadData();
      }
    }
  }
}
