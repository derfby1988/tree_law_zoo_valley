import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tree_law_zoo_valley/models/pos_discount_model.dart';
import 'package:tree_law_zoo_valley/services/daily_coupon_gate_sync_service.dart';
import 'package:tree_law_zoo_valley/services/daily_coupon_entry_service.dart';
import 'package:tree_law_zoo_valley/services/pos_coupon_qr_service.dart';
import 'package:tree_law_zoo_valley/services/pos_discount_service.dart';
import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

class DailyCouponGateScannerPage extends StatefulWidget {
  const DailyCouponGateScannerPage({super.key});

  @override
  State<DailyCouponGateScannerPage> createState() => _DailyCouponGateScannerPageState();
}

class _DailyCouponGateScannerPageState extends State<DailyCouponGateScannerPage> {
  final TextEditingController _qrController = TextEditingController();
  final TextEditingController _memberCtrl = TextEditingController();
  Timer? _syncTimer;
  bool _isProcessing = false;
  String _direction = 'enter';
  QRValidationResult? _qrResult;
  PosDiscount? _coupon;
  Map<String, dynamic> _targetingRule = const {};
  String? _statusMessage;
  Color _statusColor = Colors.blueGrey;
  List<Map<String, dynamic>> _recentEntryLogs = [];

  @override
  void initState() {
    super.initState();
    _kickOffQueueSync();
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _syncQueuedEvents(silent: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _qrController.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  Future<void> _kickOffQueueSync() async {
    await _syncQueuedEvents(silent: true);
  }

  Future<void> _syncQueuedEvents({bool silent = false}) async {
    await DailyCouponGateSyncService.pruneExpiredQueue();
    final synced = await DailyCouponGateSyncService.syncQueuedEvents();

    if (!mounted) return;
    if (!silent && synced) {
      setState(() {
        _statusMessage = 'ซิงก์รายการค้างเรียบร้อยแล้ว';
        _statusColor = Colors.green;
      });
    }
  }

  Future<void> _loadRecentEntries(String discountId) async {
    final logs = await DailyCouponEntryService.getEntryLogs(
      discountId: discountId,
      limit: 20,
    );
    if (!mounted) return;
    setState(() => _recentEntryLogs = logs);
  }

  Future<void> _validateQR() async {
    final qrData = _qrController.text.trim();
    if (qrData.isEmpty) {
      setState(() {
        _statusMessage = 'กรุณาวางข้อมูล QR ก่อน';
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _coupon = null;
      _qrResult = null;
    });

    try {
      final qrResult = await PosCouponQRService.validateQRCode(qrData, scannedBy: null);
      if (!qrResult.isValid || qrResult.couponId == null) {
        setState(() {
          _statusMessage = qrResult.errorMessage ?? 'QR ไม่ถูกต้อง';
          _statusColor = Colors.red;
          _qrResult = qrResult;
        });
        return;
      }

      final coupon = await PosDiscountService.getDiscountById(qrResult.couponId!);
      if (coupon == null) {
        setState(() {
          _statusMessage = 'ไม่พบคูปองในระบบ';
          _statusColor = Colors.red;
          _qrResult = qrResult;
        });
        return;
      }

      final rule = Map<String, dynamic>.from(coupon.targetingRule);

      setState(() {
        _qrResult = qrResult;
        _coupon = coupon;
        _targetingRule = Map<String, dynamic>.from(rule);
        _statusMessage = 'ตรวจสอบสำเร็จ: ${coupon.name}';
        _statusColor = Colors.green;
      });

      await _loadRecentEntries(coupon.id);
    } catch (e) {
      setState(() {
        _statusMessage = 'เกิดข้อผิดพลาด: $e';
        _statusColor = Colors.red;
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _logEntry(String status) async {
    final coupon = _coupon;
    if (coupon == null || _qrResult == null) return;

    final entryArea = _targetingRule['entry_area_name']?.toString() ?? 'Unknown area';
    final member = _memberCtrl.text.trim().isEmpty ? null : _memberCtrl.text.trim();
    final qrData = _qrController.text.trim();

    if (qrData.isEmpty) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'กรุณาวางข้อมูล QR ก่อนบันทึก';
        _statusColor = Colors.red;
      });
      return;
    }

    if ((_targetingRule['coupon_audience']?.toString() ?? 'individual') == 'group' &&
        (member == null || member.isEmpty)) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'คูปองรายกลุ่มต้องระบุสมาชิกก่อนบันทึก';
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() => _isProcessing = true);

    final result = await DailyCouponGateSyncService.processGateScan(
      qrData: qrData,
      memberIdentifier: member ?? '',
      entryArea: entryArea,
      scannedBy: null,
      gateId: 'admin_gate',
      direction: _direction,
      deviceInfo: {
        'source': 'daily_coupon_gate_scanner_page',
        'status': status,
      },
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!result.succeeded) {
      setState(() {
        _statusMessage = result.errorMessage ?? 'บันทึกไม่สำเร็จ';
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _statusMessage = result.statusMessage ?? 'บันทึกการ${_direction == 'enter' ? 'เข้า' : 'ออก'}สำเร็จ';
      _statusColor = Colors.green;
    });

    await _loadRecentEntries(coupon.id);

    await _syncQueuedEvents(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Scanner'),
        backgroundColor: AppDesignSystem.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _qrController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'ข้อมูล QR',
                hintText: 'แปะข้อมูล QR JSON ที่สแกนได้',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _qrController.text = data!.text!;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _direction,
                    decoration: const InputDecoration(
                      labelText: 'ทิศทาง',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'enter', child: Text('เข้า')), 
                      DropdownMenuItem(value: 'exit', child: Text('ออก')),
                    ],
                    onChanged: (value) => setState(() => _direction = value ?? 'enter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _memberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'สมาชิก/บัตร (ถ้ามี)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _validateQR,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('ตรวจสอบ QR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!_isProcessing && _coupon != null)
                        ? () => _logEntry('valid')
                        : null,
                    icon: const Icon(Icons.sensor_door_outlined),
                    label: Text('บันทึก${_direction == 'enter' ? 'เข้า' : 'ออก'}'),
                  ),
                ),
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(color: _statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _coupon == null
                  ? const Center(child: Text('ตรวจสอบ QR เพื่อโหลดประวัติล่าสุด'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ประวัติล่าสุด (${_coupon!.name})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _recentEntryLogs.isEmpty
                              ? const Center(child: Text('ยังไม่มีข้อมูลการเข้า/ออกล่าสุด'))
                              : ListView.builder(
                                  itemCount: _recentEntryLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = _recentEntryLogs[index];
                                    final scannedAt = DateTime.tryParse(log['scanned_at']?.toString() ?? '');
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        log['direction'] == 'enter' ? Icons.login : Icons.logout,
                                        color: log['status'] == 'valid' ? Colors.green : Colors.red,
                                      ),
                                      title: Text('สมาชิก: ${log['member_identifier'] ?? '-'}'),
                                      subtitle: Text('พื้นที่: ${log['entry_area'] ?? '-'}'),
                                      trailing: Text(scannedAt != null ? '${scannedAt.hour}:${scannedAt.minute.toString().padLeft(2, '0')}' : '-'),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
