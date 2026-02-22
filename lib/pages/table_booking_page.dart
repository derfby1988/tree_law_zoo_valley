import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/table_management_service.dart';
import '../services/table_booking_service.dart';
import '../services/permission_service.dart';
import '../utils/permission_helpers.dart';

class TableBookingPage extends StatefulWidget {
  const TableBookingPage({super.key, required this.isGuestMode});

  final bool isGuestMode;

  @override
  State<TableBookingPage> createState() => _TableBookingPageState();
}

class _TableBookingPageState extends State<TableBookingPage> {
  String? _selectedTable;
  String? _selectedZoneName;
  String? _activeBookingId;
  String _remainingText = '';
  Timer? _countdownTimer;
  bool _isLoading = true;
  List<Map<String, dynamic>> _zones = [];
  final Set<String> _floorPlanZones = {}; // zone IDs showing floor plan view

  Future<void> _cancelActiveBooking() async {
    if (_activeBookingId == null) return;
    await TableBookingService.cancelBooking(_activeBookingId!);
    if (mounted) {
      setState(() {
        _activeBookingId = null;
        _selectedTable = null;
        _selectedZoneName = null;
        _remainingText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกการจองแล้ว'), backgroundColor: Colors.orange),
      );
    }
    _loadData();
  }

  Future<void> _handleExpired() async {
    if (_activeBookingId != null) {
      await TableBookingService.expireBooking(_activeBookingId!);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('หมดเวลาการจอง กรุณาเลือกโต๊ะใหม่'), backgroundColor: Colors.red),
      );
      setState(() {
        _selectedTable = null;
        _selectedZoneName = null;
        _activeBookingId = null;
        _remainingText = '';
      });
      _loadData();
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final diff = expiresAt.difference(now);
      if (diff.isNegative) {
        timer.cancel();
        _handleExpired();
      } else {
        setState(() {
          final mm = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
          final ss = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
          _remainingText = '${diff.inHours > 0 ? '${diff.inHours}:' : ''}$mm:$ss';
        });
      }
    });
  }

  void _openBookingForm(_TableInfo info, String zoneName) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final sizeCtrl = TextEditingController(text: '2');
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('จองโต๊ะ ${info.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'ชื่อลูกค้า *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'เบอร์โทร *', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sizeCtrl,
                decoration: const InputDecoration(labelText: 'จำนวนคน', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final booking = await TableBookingService.createBooking(
                zoneId: info.zoneId!,
                tableId: info.id!,
                customerName: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                partySize: int.tryParse(sizeCtrl.text) ?? 2,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                expiresInMinutes: 15,
              );
              if (booking != null) {
                final expiresAtStr = booking['expires_at'] as String?;
                DateTime? expiresAt;
                if (expiresAtStr != null) {
                  expiresAt = DateTime.parse(expiresAtStr).toLocal();
                }
                setState(() {
                  _activeBookingId = booking['id'] as String?;
                  _selectedTable = info.name;
                  _selectedZoneName = zoneName;
                });
                if (expiresAt != null) _startCountdown(expiresAt);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('จองโต๊ะ ${info.name} สำเร็จ'), backgroundColor: Colors.green),
                  );
                }
                _loadData();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('จองไม่สำเร็จ'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('ยืนยันจอง'),
          ),
        ],
      ),
    );
  }

  List<_TableGroup> _groupTables(String? zoneId, List<Map<String, dynamic>> tables) {
    // Group by table_type for simple grouping similar to mock layout
    final Map<String, List<_TableInfo>> grouped = {};
    for (final t in tables) {
      final type = (t['table_type'] as String?) ?? 'small';
      grouped.putIfAbsent(type, () => []);
      grouped[type]!.add(_TableInfo(
        id: t['id'] as String?,
        zoneId: zoneId,
        name: t['name'] ?? '',
        status: _mapStatus(t),
        isBookable: t['is_bookable'] as bool? ?? true,
        posX: (t['pos_x'] as num?)?.toDouble(),
        posY: (t['pos_y'] as num?)?.toDouble(),
      ));
    }

    return grouped.entries.map((e) => _TableGroup(label: _typeLabel(e.key), tables: e.value)).toList();
  }

  TableStatus _mapStatus(Map<String, dynamic> t) {
    final status = t['status'] as String? ?? 'available';
    final type = t['table_type'] as String? ?? 'small';
    if (status == 'unavailable') return TableStatus.unavailable;
    switch (type) {
      case 'large':
        return TableStatus.large;
      case 'bar':
        return TableStatus.bar;
      case 'small':
      default:
        return TableStatus.small;
    }
  }

  String? _typeLabel(String type) {
    switch (type) {
      case 'large':
        return 'โต๊ะใหญ่';
      case 'small':
        return 'โต๊ะเล็ก';
      case 'bar':
        return 'บาร์';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await TableManagementService.getZonesWithTables();
      // auto-enable floor plan view for zones that already have positions
      final placedZoneIds = <String>{};
      for (final z in data) {
        final tables = (z['tables'] as List?) ?? [];
        final hasPlaced = tables.any((t) => t['pos_x'] != null && t['pos_y'] != null);
        if (hasPlaced && z['id'] != null) placedZoneIds.add(z['id'] as String);
      }
      setState(() {
        _zones = data;
        _isLoading = false;
        _floorPlanZones
          ..removeWhere((zid) => !_zones.any((z) => z['id'] == zid))
          ..addAll(placedZoneIds);
      });
    } catch (e) {
      debugPrint('Error loadData: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF0FC), Color(0xFF79FFB6)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _loadData,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _zones.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              children: const [
                                SizedBox(height: 120),
                                Icon(Icons.table_restaurant, size: 72, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('ยังไม่มีร้าน/โต๊ะ', style: TextStyle(fontSize: 16, color: Colors.black54)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    if (widget.isGuestMode)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.lock_open, color: Colors.orange, size: 18),
                                            SizedBox(width: 6),
                                            Text('โหมดผู้เยี่ยม', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                          ],
                                        ),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Center(
                                  child: Column(
                                    children: [
                                      Text('เลือก ร้าน & โต๊ะ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                                      SizedBox(height: 4),
                                      Text('TREE LAW ZOO valley', style: TextStyle(fontSize: 14, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildLegend(),
                                const SizedBox(height: 18),
                                ..._zones.map((zone) {
                                  final zoneName = zone['name'] ?? '';
                                  final openTime = zone['open_time'] as String?;
                                  final closeTime = zone['close_time'] as String?;
                                  final time = (openTime != null && closeTime != null)
                                      ? '(เปิด $openTime - $closeTime น.)'
                                      : '';
                                  final tables = List<Map<String, dynamic>>.from(zone['tables'] ?? []);
                                  final note = (tables.any((t) => !(t['is_bookable'] as bool? ?? true)))
                                      ? 'บางโต๊ะ Walk in เท่านั้น'
                                      : 'เลือกโต๊ะเพื่อจอง';
                                  final noteColor = (tables.any((t) => !(t['is_bookable'] as bool? ?? true)))
                                      ? const Color(0xFFE5A000)
                                      : const Color(0xFF1493FF);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 22),
                                    child: _buildRestaurantBlock(
                                      title: zoneName,
                                      time: time,
                                      headerLabel: zoneName,
                                      note: note,
                                      noteColor: noteColor,
                                      tables: _groupTables(zone['id'] as String?, tables),
                                      zoneName: zoneName,
                                      zoneId: zone['id'] as String? ?? '',
                                      rawTables: tables,
                                    ),
                                  );
                                }),
                                const SizedBox(height: 32),
                                Center(
                                  child: Text(
                                    '*จองได้ครั้งละ 1 โต๊ะ ต่อ 1 ใบเสร็จ\n**ร้านที่เลือก ส่งผลต่อรายการอาหารที่สามารถเลือกได้',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text('ตกลง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('ร้าน ', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                        Text(_selectedZoneName ?? 'X', style: const TextStyle(color: Color(0xFFAF52DE), fontSize: 16)),
                        const SizedBox(width: 12),
                        Text('โต๊ะที่ ', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                        Text(_selectedTable ?? 'X', style: const TextStyle(color: Color(0xFFAF52DE), fontSize: 16)),
                        const SizedBox(width: 8),
                        Icon(Icons.close, color: const Color(0xFFAF52DE), size: 18),
                      ],
                    ),
                    if (_remainingText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('เวลาที่เหลือในการชำระเงิน: $_remainingText',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    if (_activeBookingId != null && PermissionService.canAccessActionSync('table_booking_cancel'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('ยกเลิกการจอง', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                          onPressed: _cancelActiveBooking,
                        ),
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

  Widget _buildRestaurantBlock({
    required String title,
    required String time,
    required String headerLabel,
    required String note,
    required Color noteColor,
    required List<_TableGroup> tables,
    required String zoneName,
    required String zoneId,
    required List<Map<String, dynamic>> rawTables,
  }) {
    final hasPlacedTables = rawTables.any((t) => t['pos_x'] != null && t['pos_y'] != null);
    final showFloorPlan = _floorPlanZones.contains(zoneId) && hasPlacedTables;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              if (hasPlacedTables)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_floorPlanZones.contains(zoneId)) {
                        _floorPlanZones.remove(zoneId);
                      } else {
                        _floorPlanZones.add(zoneId);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: showFloorPlan
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          showFloorPlan ? Icons.list : Icons.grid_view,
                          size: 16,
                          color: showFloorPlan ? const Color(0xFF3B82F6) : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          showFloorPlan ? 'รายการ' : 'ผังร้าน',
                          style: TextStyle(
                            fontSize: 11,
                            color: showFloorPlan ? const Color(0xFF3B82F6) : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD2E5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(headerLabel, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    color: noteColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(note, style: const TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (showFloorPlan)
            _buildMiniFloorPlan(tables, zoneName)
          else
            ...tables.map((group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (group.label != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(group.label!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: group.tables
                            .map((info) => _buildTableChip(info, zoneName))
                            .toList(),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  /// Mini floor plan canvas (read-only) for booking page
  Widget _buildMiniFloorPlan(List<_TableGroup> groups, String zoneName) {
    // Flatten all tables from groups
    final allTables = groups.expand((g) => g.tables).toList();
    final placedTables = allTables.where((t) => t.posX != null && t.posY != null).toList();
    final unplacedTables = allTables.where((t) => t.posX == null || t.posY == null).toList();
    const baseHeight = 280.0;
    const tableSize = 52.0;

    double minY = 0, maxY = 0, minDelta = double.infinity;
    if (placedTables.isNotEmpty) {
      final sorted = [...placedTables]..sort((a, b) => (a.posY ?? 0).compareTo(b.posY ?? 0));
      minY = sorted.first.posY ?? 0;
      maxY = sorted.last.posY ?? 0;
      for (int i = 0; i < sorted.length - 1; i++) {
        final dy = (sorted[i + 1].posY ?? 0) - (sorted[i].posY ?? 0);
        if (dy > 0 && dy < minDelta) minDelta = dy;
      }
    }
    // scale height so that smallest gap >= table size (with margin)
    double scaleByDelta = 1.0;
    if (minDelta != double.infinity && minDelta > 0) {
      scaleByDelta = (tableSize * 1.4) / (minDelta * baseHeight);
    }
    final span = (maxY - minY).abs();
    final scaleBySpan = span > 0 ? (span + 0.4) : 1.0; // add padding
    final canvasHeight = baseHeight * math.max(1.0, math.max(scaleByDelta, scaleBySpan));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Floor plan canvas
        LayoutBuilder(
          builder: (context, constraints) {
            final canvasW = constraints.maxWidth;
            final availableH = canvasHeight - tableSize * 0.2;
            final normSpan = span <= 0 ? 1.0 : span;

            return Container(
              width: canvasW,
              height: canvasHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Stack(
                children: [
                  // Grid
                  CustomPaint(
                    size: Size(canvasW, canvasHeight),
                    painter: _MiniGridPainter(),
                  ),
                  // Placed tables
                  ...placedTables.map((info) {
                    final left = info.posX! * canvasW;
                    // normalize Y to fill available height while keeping relative order
                    final normalizedY = (info.posY! - minY) / normSpan;
                    final top = normalizedY * availableH + tableSize * 0.1;
                    final bool isSelected = _selectedTable == info.name && _selectedZoneName == zoneName;
                    final color = info.status.color;

                    return Positioned(
                      left: left.clamp(0, canvasW - tableSize),
                      top: top.clamp(0, canvasHeight - tableSize),
                      child: GestureDetector(
                        onTap: info.status == TableStatus.unavailable || !info.isBookable
                            ? null
                            : () {
                                checkPermissionAndExecute(
                                  context,
                                  'table_booking_create',
                                  'จองโต๊ะ',
                                  () => _openBookingForm(info, zoneName),
                                );
                              },
                        child: Container(
                          width: tableSize,
                          height: tableSize,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isSelected ? 0.85 : 0.65),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : color,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                info.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (info.status == TableStatus.unavailable)
                                const Text('ไม่ว่าง', style: TextStyle(color: Colors.white70, fontSize: 8))
                              else if (!info.isBookable)
                                const Text('Walk-in', style: TextStyle(color: Colors.white70, fontSize: 8)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Empty hint
                  if (placedTables.isEmpty)
                    const Center(
                      child: Text('ยังไม่มีโต๊ะบนผัง', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                ],
              ),
            );
          },
        ),
        // Unplaced tables shown as chips below
        if (unplacedTables.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('โต๊ะที่ยังไม่ได้วางบนผัง:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: unplacedTables.map((info) => _buildTableChip(info, zoneName)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTableChip(_TableInfo info, String zoneName) {
    final bool isSelected = _selectedTable == info.name && _selectedZoneName == zoneName;
    final Color bg = info.status.color.withValues(alpha: isSelected ? 0.8 : 0.4);
    final Color fg = isSelected ? Colors.white : info.status.color;

    return GestureDetector(
      onTap: info.status == TableStatus.unavailable || !info.isBookable
          ? null
          : () {
              checkPermissionAndExecute(
                context,
                'table_booking_create',
                'จองโต๊ะ',
                () => _openBookingForm(info, zoneName),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: info.status.color.withValues(alpha: 0.9)),
        ),
        child: Text(
          info.name,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: const [
          _LegendDot(color: Color(0xFF1493FF), label: 'โต๊ะใหญ่ 6-10 ที่นั่ง'),
          _LegendDot(color: Color(0xFFF19EDC), label: 'โต๊ะเล็ก 2 ที่นั่ง'),
          _LegendDot(color: Color(0xFFF0B400), label: 'บาร์ห้องเย็น'),
          _LegendDot(color: Color(0xFFB3B3B3), label: 'ไม่ว่าง'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

enum TableStatus { large, small, bar, unavailable }

extension TableStatusColor on TableStatus {
  Color get color {
    switch (this) {
      case TableStatus.large:
        return const Color(0xFF1493FF);
      case TableStatus.small:
        return const Color(0xFFF19EDC);
      case TableStatus.bar:
        return const Color(0xFFF0B400);
      case TableStatus.unavailable:
        return const Color(0xFFB3B3B3);
    }
  }
}

class _TableInfo {
  final String? id;
  final String? zoneId;
  final String name;
  final TableStatus status;
  final bool isBookable;
  final double? posX;
  final double? posY;
  const _TableInfo({
    required this.id,
    required this.zoneId,
    required this.name,
    required this.status,
    required this.isBookable,
    this.posX,
    this.posY,
  });
}

class _TableGroup {
  final String? label;
  final List<_TableInfo> tables;
  const _TableGroup({this.label, required this.tables});
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
