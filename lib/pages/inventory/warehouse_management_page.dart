import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../services/supabase_service.dart';
import '../../services/inventory_event_bus.dart';
import '../../theme/app_design_system.dart';
import 'dialogs/shelf_tree_dialog.dart';
import 'dialogs/transfer_request_dialog.dart';
import 'dialogs/warehouse_form_dialog.dart';
import 'dialogs/warehouse_manager_dialog.dart';

class WarehouseManagementPage extends StatefulWidget {
  const WarehouseManagementPage({super.key});

  @override
  State<WarehouseManagementPage> createState() => _WarehouseManagementPageState();
}

class _WarehouseManagementPageState extends State<WarehouseManagementPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _shelves = [];
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, double> _warehouseUtilization = {};
  Map<String, int> _warehouseCapacity = {};
  Map<String, int> _activeShelves = {};
  Map<String, int> _warehouseCapacityLimit = {};
  List<Map<String, dynamic>> _movementHistory = [];
  bool _isLoadingMovementHistory = true;
  String? _movementWarehouseFilter;
  List<Map<String, dynamic>> _transferRequests = [];
  bool _isLoadingTransferRequests = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Widget _buildMovementHistoryCard() {
    final warehouseItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
      ..._warehouses.map((warehouse) {
        final id = warehouse['id']?.toString();
        return DropdownMenuItem(
          value: id,
          child: Text(warehouse['name']?.toString() ?? '-'),
        );
      }),
    ];

    Widget buildRow(Map<String, dynamic> movement) {
      final product = movement['product'] as Map<String, dynamic>? ?? {};
      final shelf = product['shelf'] as Map<String, dynamic>? ?? {};
      final warehouse = shelf['warehouse'] as Map<String, dynamic>?;
      final shelfCode = shelf['code']?.toString() ?? 'ไม่ระบุ';
      final warehouseName = warehouse?['name']?.toString() ?? 'ไม่ระบุคลัง';
      final change = (movement['quantity_change'] as num?)?.toDouble() ?? 0.0;
      final quantityLabel = change == 0
          ? '0'
          : '${change > 0 ? '+' : '-'}${change.abs().toStringAsFixed(change == change.truncateToDouble() ? 0 : 1)}';
      final createdAt = DateTime.tryParse(movement['created_at']?.toString() ?? '');
      final timeLabel = createdAt != null
          ? '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
          : 'ไม่ระบุเวลา';
      final reason = movement['reason']?.toString();
      final subtitle = '$warehouseName • ชั้น $shelfCode${reason != null && reason.isNotEmpty ? ' • $reason' : ''}';
      final iconColor = change >= 0 ? AppDesignSystem.success : AppDesignSystem.danger;
      final typeLabel = (movement['type'] as String? ?? '').replaceAll('_', ' ');

      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.15),
          child: Icon(
            change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            color: iconColor,
            size: 18,
          ),
        ),
        title: Text(product['name']?.toString() ?? 'ไม่ระบุสินค้า'),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(quantityLabel, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
            Text(typeLabel, style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12)),
            Text(timeLabel, style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 10)),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_vert, color: AppDesignSystem.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('ประวัติการเคลื่อนย้าย/ปรับคลัง', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: AppDesignSystem.spacingSm),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _movementWarehouseFilter,
                    items: warehouseItems,
                    onChanged: (value) => _loadMovementHistory(warehouseId: value),
                    isDense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (_isLoadingMovementHistory)
              const Center(child: CircularProgressIndicator())
            else if (_movementHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm),
                child: Text('ยังไม่มีประวัติการเคลื่อนย้ายสินค้า', style: TextStyle(color: AppDesignSystem.textSecondary)),
              )
            else
              SizedBox(
                height: math.min(260, _movementHistory.length * 78.0),
                child: ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) => buildRow(_movementHistory[index]),
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemCount: _movementHistory.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateTransfer() async {
    if (!mounted) return;
    final data = await showTransferRequestDialog(
      context: context,
      products: _products,
      warehouses: _warehouses,
      shelves: _shelves,
    );
    if (data == null) return;
    final productId = data['productId']?.toString();
    final sourceWarehouseId = data['sourceWarehouseId']?.toString();
    final targetWarehouseId = data['targetWarehouseId']?.toString();
    final quantity = (data['quantity'] as double?) ?? 0;
    if (productId == null || sourceWarehouseId == null || targetWarehouseId == null || quantity <= 0) return;
    final id = await InventoryService.createTransfer(
      productId: productId,
      quantity: quantity,
      sourceWarehouseId: sourceWarehouseId,
      sourceShelfId: data['sourceShelfId']?.toString(),
      targetWarehouseId: targetWarehouseId,
      targetShelfId: data['targetShelfId']?.toString(),
      reason: data['reason'],
      note: data['note'],
    );
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('สร้างคำขอโอนไม่สำเร็จ')));
      return;
    }
    await InventoryService.submitTransfer(id: id);
    await _loadTransferRequests();
    InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งคำขอโอนไปยังผู้อนุมัติแล้ว')));
  }

  Future<void> _handleApproveTransfer(Map<String, dynamic> transfer) async {
    final id = transfer['id']?.toString();
    if (id == null) return;
    final approverId = Supabase.instance.client.auth.currentUser?.id;
    if (approverId == null) return;
    final ok = await InventoryService.approveTransfer(id: id, approverId: approverId);
    if (!mounted) return;
    if (ok) {
      await _loadTransferRequests();
      await _loadMovementHistory(warehouseId: _movementWarehouseFilter);
      InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อนุมัติคำขอโอนแล้ว')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อนุมัติไม่สำเร็จ')));
    }
  }

  Future<void> _handleRejectTransfer(Map<String, dynamic> transfer) async {
    final id = transfer['id']?.toString();
    if (id == null) return;
    final approverId = Supabase.instance.client.auth.currentUser?.id;
    if (approverId == null) return;
    final ok = await InventoryService.rejectTransfer(id: id, approverId: approverId);
    if (!mounted) return;
    if (ok) {
      await _loadTransferRequests();
      InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ปฏิเสธคำขอโอนแล้ว')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ปฏิเสธไม่สำเร็จ')));
    }
  }

  Widget _buildTransferRequestsCard() {
    final canRequestTransfer = PermissionService.canAccessActionSync('inventory_transfer_request');
    final canApproveTransfer = PermissionService.canAccessActionSync('inventory_transfer_approve');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.transfer_within_a_station, color: AppDesignSystem.secondary),
                const SizedBox(width: 8),
                const Expanded(child: Text('คำขอโอนสินค้า', style: TextStyle(fontWeight: FontWeight.bold))),
                if (canRequestTransfer)
                  ElevatedButton.icon(
                    onPressed: _handleCreateTransfer,
                    icon: const Icon(Icons.add_business),
                    label: const Text('สร้างคำขอ'),
                  ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (_isLoadingTransferRequests)
              const Center(child: CircularProgressIndicator())
            else if (_transferRequests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDesignSystem.spacingSm),
                child: Text('ยังไม่มีคำขอโอนสินค้ารออนุมัติ', style: TextStyle(color: AppDesignSystem.textSecondary)),
              )
            else
              Column(
                children: _transferRequests.map((transfer) {
                  final product = transfer['product'] as Map<String, dynamic>?;
                  final source = transfer['source_warehouse'] as Map<String, dynamic>?;
                  final target = transfer['target_warehouse'] as Map<String, dynamic>?;
                  final qty = (transfer['quantity'] as num?)?.toDouble() ?? 0;
                  final status = transfer['status']?.toString() ?? 'draft';
                  final reason = transfer['reason']?.toString() ?? '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product?['name']?.toString() ?? '-'),
                    subtitle: Text('${source?['name'] ?? '-'} → ${target?['name'] ?? '-'} • $reason'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('จำนวน ${qty.toStringAsFixed(qty == qty.truncateToDouble() ? 0 : 1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('สถานะ: $status', style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12)),
                        if (status == 'pending' && canApproveTransfer)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(onPressed: () => _handleRejectTransfer(transfer), child: const Text('ปฏิเสธ')),
                              TextButton(onPressed: () => _handleApproveTransfer(transfer), child: const Text('อนุมัติ')),
                            ],
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildAlertsPanel() {
    if (_warehouses.isEmpty) return null;
    final alertRows = <Widget>[];
    for (final warehouse in _warehouses) {
      final id = warehouse['id']?.toString();
      if (id == null) continue;
      final name = warehouse['name']?.toString() ?? '-';
      final capacity = _warehouseCapacity[id] ?? 0;
      final utilization = _warehouseUtilization[id] ?? 0;
      final percent = (utilization * 100).clamp(0, 100).toStringAsFixed(0);
      final limit = _warehouseCapacityLimit[id] ?? 0;

      if (limit > 0 && capacity > limit) {
        alertRows.add(_buildAlertTile(
          warehouse: warehouse,
          icon: Icons.error_outline,
          color: AppDesignSystem.danger,
          title: '$name ใช้เกินขีดจำกัด',
          subtitle: 'ขีดจำกัด $limit หน่วย • ใช้งานอยู่ $capacity หน่วย',
        ));
        continue;
      }

      if (utilization >= 0.85) {
        alertRows.add(_buildAlertTile(
          warehouse: warehouse,
          icon: Icons.warning_amber_rounded,
          color: AppDesignSystem.warning,
          title: '$name ใกล้เต็ม ($percent%)',
          subtitle: 'ตั้งขีดจำกัดหรือย้ายสินค้าบางส่วนออกเพื่อป้องกันการล้น',
        ));
      }
    }

    if (alertRows.isEmpty) return null;

    return Card(
      elevation: 0,
      color: AppDesignSystem.warning.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: BorderSide(color: AppDesignSystem.warning.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.notifications_active, color: AppDesignSystem.warning),
                SizedBox(width: 8),
                Text('แจ้งเตือนการใช้งานคลัง', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            ...alertRows,
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile({
    required Map<String, dynamic> warehouse,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
      padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: AppDesignSystem.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, size: 18),
            tooltip: 'ตั้งค่าขีดจำกัด',
            color: AppDesignSystem.textSecondary,
            onPressed: () => _showCapacityLimitDialog(warehouse),
          ),
        ],
      ),
    );
  }

  Future<void> _showCapacityLimitDialog(Map<String, dynamic> warehouse) async {
    final controller = TextEditingController(
      text: (_warehouseCapacityLimit[warehouse['id']?.toString()] ?? 0).toString(),
    );
    int? limit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ตั้งค่าขีดจำกัดความจุ - ${warehouse['name'] ?? '-'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'จำนวนหน่วยสูงสุด (0 = ไม่กำหนด)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => limit = int.tryParse(value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('บันทึก')),
        ],
      ),
    );

    if (confirmed == true) {
      final parsed = limit ?? int.tryParse(controller.text.trim()) ?? 0;
      final ok = await InventoryService.updateWarehouseCapacityLimit(
        id: warehouse['id'].toString(),
        capacityLimit: parsed <= 0 ? null : parsed,
      );
      if (!mounted) return;
      if (ok) {
        await _loadData();
        InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกขีดจำกัดความจุเรียบร้อย')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกไม่สำเร็จ')));
      }
    }
    controller.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        InventoryService.getWarehouses(includeInactive: true),
        InventoryService.getShelves(includeInactive: true),
        InventoryService.getWarehouseZones(includeInactive: true),
        InventoryService.getProducts(),
        SupabaseService.getUsers(),
        InventoryService.getWarehouseUtilizationSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0];
        _shelves = results[1];
        _zones = results[2];
        _products = results[3];
        _users = List<Map<String, dynamic>>.from(results[4]);
      });
      _computeWarehouseMetrics(cachedSummary: results.elementAtOrNull(5));
      _warehouseCapacityLimit = {
        for (final warehouse in _warehouses)
          if (warehouse['id'] != null)
            warehouse['id'].toString(): warehouse['capacity_limit'] is int
                ? warehouse['capacity_limit'] as int
                : int.tryParse(warehouse['capacity_limit']?.toString() ?? '0') ?? 0,
      };
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      await _loadMovementHistory(warehouseId: _movementWarehouseFilter);
      await _loadTransferRequests();
    }
  }

  Future<void> _loadMovementHistory({String? warehouseId}) async {
    if (!mounted) return;
    setState(() => _isLoadingMovementHistory = true);
    final history = await InventoryService.getStockMovements(
      limit: 20,
      warehouseId: warehouseId,
    );
    if (!mounted) return;
    setState(() {
      _movementHistory = history;
      _movementWarehouseFilter = warehouseId;
      _isLoadingMovementHistory = false;
    });
  }

  Future<void> _loadTransferRequests() async {
    if (!mounted) return;
    setState(() => _isLoadingTransferRequests = true);
    final requests = await InventoryService.getTransfers(status: 'pending');
    if (!mounted) return;
    setState(() {
      _transferRequests = requests;
      _isLoadingTransferRequests = false;
    });
  }

  void _computeWarehouseMetrics({dynamic cachedSummary}) {
    final productCountByShelf = <String, int>{};
    for (final product in _products) {
      final shelfId = product['shelf_id']?.toString();
      if (shelfId == null) continue;
      productCountByShelf[shelfId] = (productCountByShelf[shelfId] ?? 0) + 1;
    }

    final capacityByWarehouse = <String, int>{};
    final usageByWarehouse = <String, int>{};
    final activeShelves = <String, int>{};

    for (final shelf in _shelves) {
      final warehouseId = shelf['warehouse_id']?.toString();
      if (warehouseId == null) continue;
      final shelfId = shelf['id']?.toString();
      final capacity = shelf['capacity'] is int
          ? shelf['capacity'] as int
          : int.tryParse(shelf['capacity']?.toString() ?? '0') ?? 0;
      capacityByWarehouse[warehouseId] = (capacityByWarehouse[warehouseId] ?? 0) + capacity;
      final used = shelfId != null ? (productCountByShelf[shelfId] ?? 0) : 0;
      usageByWarehouse[warehouseId] = (usageByWarehouse[warehouseId] ?? 0) + used;
      if (shelf['is_active'] != false) {
        activeShelves[warehouseId] = (activeShelves[warehouseId] ?? 0) + 1;
      }
    }

    if (cachedSummary is List<Map<String, dynamic>> && cachedSummary.isNotEmpty) {
      final utilization = <String, double>{};
      final capacityMap = <String, int>{};
      final activeMap = <String, int>{};
      for (final entry in cachedSummary) {
        final warehouseId = entry['warehouse_id']?.toString();
        if (warehouseId == null) continue;
        final capacity = entry['capacity'] as int? ?? 0;
        final used = entry['used'] as int? ?? 0;
        final active = entry['activeShelves'] as int? ?? 0;
        utilization[warehouseId] = capacity <= 0
            ? (used > 0 ? 1.0 : 0.0)
            : (used / capacity).clamp(0, 1).toDouble();
        capacityMap[warehouseId] = capacity;
        activeMap[warehouseId] = active;
      }
      setState(() {
        _warehouseCapacity = capacityMap;
        _warehouseUtilization = utilization;
        _activeShelves = activeMap;
      });
      return;
    }

    final utilization = <String, double>{};
    capacityByWarehouse.forEach((warehouseId, capacity) {
      final used = usageByWarehouse[warehouseId] ?? 0;
      if (capacity <= 0) {
        utilization[warehouseId] = used > 0 ? 1.0 : 0.0;
      } else {
        utilization[warehouseId] = (used / capacity).clamp(0, 1).toDouble();
      }
    });

    setState(() {
      _warehouseCapacity = capacityByWarehouse;
      _warehouseUtilization = utilization;
      _activeShelves = activeShelves;
    });
  }

  String _resolveManagerName(String? managerId) {
    if (managerId == null || managerId.isEmpty) return 'ไม่ระบุ';
    final match = _users.firstWhere(
      (user) => user['id']?.toString() == managerId,
      orElse: () => const {},
    );
    if (match.isEmpty) return 'ไม่พบข้อมูล';
    final name = match['full_name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final username = match['username']?.toString();
    if (username != null && username.trim().isNotEmpty) return username.trim();
    final email = match['email']?.toString();
    if (email != null && email.trim().isNotEmpty) return email.trim();
    return 'ไม่ระบุ';
  }

  int? _parseCapacityLimit(Map<String, dynamic>? warehouse) {
    if (warehouse == null) return null;
    final raw = warehouse['capacity_limit'];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  int? _parseDialogCapacity(dynamic value) {
    if (value == null) return null;
    if (value is int) return value <= 0 ? null : value;
    if (value is num) {
      final intValue = value.toInt();
      return intValue <= 0 ? null : intValue;
    }
    final parsed = int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  Future<void> _showWarehouseForm({Map<String, dynamic>? warehouse}) async {
    if (!mounted) return;
    final result = await showWarehouseFormDialog(
      context: context,
      title: warehouse == null ? 'เพิ่มคลังใหม่' : 'แก้ไขคลัง',
      submitLabel: warehouse == null ? 'บันทึก' : 'อัปเดต',
      users: _users,
      initialName: warehouse?['name']?.toString(),
      initialLocation: warehouse?['location']?.toString(),
      initialManagerId: warehouse?['manager']?.toString(),
      initialIsActive: warehouse?['is_active'] != false,
      initialCapacityLimit: _parseCapacityLimit(warehouse),
    );
    if (result == null) return;

    final name = result['name']?.toString();
    final location = result['location']?.toString();
    final managerId = result['managerId']?.toString();
    final isActive = result['isActive'] == true;
    final capacityLimit = _parseDialogCapacity(result['capacityLimit']);
    bool ok;
    if (warehouse == null) {
      ok = await InventoryService.addWarehouse(
        name: name ?? '-',
        location: location,
        manager: managerId,
        isActive: isActive,
        capacityLimit: capacityLimit,
      );
    } else {
      ok = await InventoryService.updateWarehouse(
        id: warehouse['id'].toString(),
        name: name ?? '-',
        location: location,
        manager: managerId,
        isActive: isActive,
        capacityLimit: capacityLimit,
      );
    }

    if (!mounted) return;
    if (ok) {
      await _loadData();
      InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(warehouse == null ? 'เพิ่มคลังสำเร็จ' : 'อัปเดตคลังสำเร็จ')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก')),
      );
    }
  }

  Future<void> _showManagerDialog({Map<String, dynamic>? warehouse}) async {
    if (_warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีคลังให้กำหนดผู้ดูแล')),
      );
      return;
    }
    final result = await showWarehouseManagerDialog(
      context: context,
      warehouses: _warehouses,
      users: _users,
      initialWarehouseId: warehouse?['id']?.toString(),
      initialManagerId: warehouse?['manager']?.toString(),
    );
    if (result == null || result['warehouseId'] == null) return;
    final ok = await InventoryService.updateWarehouseManager(
      id: result['warehouseId']!,
      managerId: result['managerId']?.isEmpty == true ? null : result['managerId'],
    );
    if (!mounted) return;
    if (ok) {
      await _loadData();
      InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตผู้ดูแลคลังเรียบร้อย')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่สามารถบันทึกข้อมูลได้')));
    }
  }

  // ✅ Dialog ตรวจนับวัตถุดิบ (ย้ายไปที่ adjustment_tab.dart แล้ว)
  // ignore: unused_element
  void _showCountIngredientDialog() {
    final Map<String, dynamic> countData = {};
    bool isLoading = false;
    List<Map<String, dynamic>> ingredients = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // ดึงข้อมูลวัตถุดิบจาก _ingredients (ต้องเพิ่ม state นี้ใน _loadData)
          // สำหรับตอนนี้ ใช้ placeholder
          if (ingredients.isEmpty) {
            ingredients = [
              {'id': '1', 'name': 'ไข่ไก่', 'quantity': 10, 'unit': {'abbreviation': 'ฟอง'}},
              {'id': '2', 'name': 'นำ้มันพืช', 'quantity': 5, 'unit': {'abbreviation': 'ลิตร'}},
              {'id': '3', 'name': 'แป้งสาลี', 'quantity': 20, 'unit': {'abbreviation': 'กก.'}},
            ];
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.checklist, color: Colors.purple),
                SizedBox(width: 8),
                Text('ตรวจนับวัตถุดิบ'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('จำนวนวัตถุดิบ: ${ingredients.length} รายการ', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  ...ingredients.map((ing) {
                    final ingId = ing['id'] as String;
                    final ingName = ing['name'] as String? ?? '-';
                    final currentQty = (ing['quantity'] as num?)?.toDouble() ?? 0;
                    final unit = ing['unit']?['abbreviation'] ?? '';
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ingName, style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ระบบ: $currentQty $unit', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: 'นับได้',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      countData[ingId] = double.tryParse(value) ?? 0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () async {
                  setDialogState(() => isLoading = true);
                  // TODO: บันทึกข้อมูลตรวจนับ
                  await Future.delayed(Duration(milliseconds: 500));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('บันทึกตรวจนับแล้ว'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: isLoading
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.save),
                label: Text('บันทึก'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteWarehouse(Map<String, dynamic> warehouse) async {
    final warehouseName = warehouse['name']?.toString() ?? '-';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบคลังสินค้า'),
        content: Text('ต้องการลบคลัง "$warehouseName" หรือไม่?\n\nต้องไม่มีชั้นวางที่ใช้งานอยู่ก่อนลบ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบคลัง')),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await InventoryService.deleteWarehouse(warehouse['id'].toString());
    if (!mounted) return;
    if (ok) {
      await _loadData();
      InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบคลัง "$warehouseName" สำเร็จ')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถลบคลังได้ (อาจยังมีชั้นวางใช้งานอยู่)')),
      );
    }
  }

  Future<void> _openShelfTree(Map<String, dynamic> warehouse) async {
    final warehouseId = warehouse['id']?.toString();
    if (warehouseId == null) return;
    await ShelfTreeDialog.show(
      context: context,
      warehouse: warehouse,
      zones: _zones.where((zone) => zone['warehouse_id']?.toString() == warehouseId).toList(),
      shelves: _shelves.where((shelf) => shelf['warehouse_id']?.toString() == warehouseId).toList(),
      products: _products,
      onChanged: () {
        _loadData();
        InventoryEventBus.emit(InventoryEventType.storageStructureChanged);
      },
    );
  }

  List<Map<String, dynamic>> _topShelves() {
    final productCountByShelf = <String, int>{};
    for (final product in _products) {
      final shelfId = product['shelf_id']?.toString();
      if (shelfId == null) continue;
      productCountByShelf[shelfId] = (productCountByShelf[shelfId] ?? 0) + 1;
    }
    final sortedShelves = List<Map<String, dynamic>>.from(_shelves)
      ..sort((a, b) {
        final countA = productCountByShelf[a['id']?.toString() ?? ''] ?? 0;
        final countB = productCountByShelf[b['id']?.toString() ?? ''] ?? 0;
        return countB.compareTo(countA);
      });
    return sortedShelves.take(5).toList();
  }

  Widget _buildSummaryCards() {
    final totalWarehouses = _warehouses.length;
    final activeWarehouses = _warehouses.where((w) => w['is_active'] != false).length;
    final totalShelves = _shelves.length;
    final avgUtilization = _warehouseUtilization.values.isEmpty
        ? 0.0
        : _warehouseUtilization.values.reduce((a, b) => a + b) / _warehouseUtilization.length;

    final cards = [
      _SummaryCard(
        title: 'จำนวนคลังทั้งหมด',
        value: totalWarehouses.toString(),
        subtitle: 'ใช้งานอยู่ $activeWarehouses คลัง',
        icon: Icons.warehouse,
        color: AppDesignSystem.primary,
      ),
      _SummaryCard(
        title: 'ชั้นวางทั้งหมด',
        value: totalShelves.toString(),
        subtitle: 'ใช้งานอยู่ ${_shelves.where((s) => s['is_active'] != false).length}',
        icon: Icons.shelves,
        color: AppDesignSystem.secondary,
      ),
      _SummaryCard(
        title: 'อัตราการใช้งานเฉลี่ย',
        value: '${(avgUtilization * 100).toStringAsFixed(1)}%',
        subtitle: 'คิดจากข้อมูลสินค้าที่มีอยู่',
        icon: Icons.insights,
        color: AppDesignSystem.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map((card) => SizedBox(
                    width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                    child: card,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildWarehouseTable() {
    if (_warehouses.isEmpty) {
      return _EmptyStateCard(
        title: 'ยังไม่มีข้อมูลคลัง',
        message: 'เริ่มต้นด้วยการเพิ่มคลังใหม่',
        icon: Icons.warehouse_outlined,
      );
    }

    final canEditWarehouse = PermissionService.canAccessActionSync('inventory_adjustment_warehouse_edit');
    final canManageShelves = PermissionService.canAccessActionSync('inventory_adjustment_shelf');
    final canManageManager = PermissionService.canAccessActionSync('inventory_adjustment_warehouse_add');
    final canDeleteWarehouse = PermissionService.canAccessActionSync('inventory_adjustment_warehouse_delete');
    final canSetCapacityLimit = PermissionService.canAccessActionSync('inventory_warehouse_manage');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 64,
          dataRowMaxHeight: 120,
          columns: const [
            DataColumn(label: Text('ชื่อคลัง')),
            DataColumn(label: Text('ผู้ดูแล')),
            DataColumn(label: Text('สถานะ')),
            DataColumn(label: Text('ความจุ (หน่วย)')),
            DataColumn(label: Text('ขีดจำกัด')),
            DataColumn(label: Text('การใช้งาน')),
            DataColumn(label: Text('จัดการ')),
          ],
          rows: _warehouses.map((warehouse) {
            final id = warehouse['id']?.toString() ?? '';
            final utilization = _warehouseUtilization[id] ?? 0;
            final capacity = _warehouseCapacity[id] ?? 0;
            final usedPercent = (utilization * 100).clamp(0, 100).toStringAsFixed(0);
            final capacityLimit = _warehouseCapacityLimit[id] ?? 0;
            final limitExceeded = capacityLimit > 0 && capacity > capacityLimit;
            return DataRow(cells: [
              DataCell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(warehouse['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    warehouse['location']?.toString() ?? 'ไม่ระบุที่อยู่',
                    style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12),
                  ),
                ],
              )),
              DataCell(Text(_resolveManagerName(warehouse['manager']?.toString()))),
              DataCell(_StatusBadge(isActive: warehouse['is_active'] != false)),
              DataCell(Text(capacity.toString(), style: TextStyle(color: limitExceeded ? AppDesignSystem.danger : null))),
              DataCell(Row(
                children: [
                  Text(
                    capacityLimit > 0 ? capacityLimit.toString() : 'ไม่กำหนด',
                    style: TextStyle(color: limitExceeded ? AppDesignSystem.danger : AppDesignSystem.textPrimary),
                  ),
                  if (canSetCapacityLimit)
                    IconButton(
                      tooltip: 'ตั้งค่าขีดจำกัดความจุ',
                      icon: const Icon(Icons.tune, size: 18),
                      onPressed: () => _showCapacityLimitDialog(warehouse),
                    ),
                ],
              )),
              DataCell(SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: utilization.clamp(0, 1)),
                    const SizedBox(height: 4),
                    Text('$usedPercent%'),
                  ],
                ),
              )),
              DataCell(Row(
                children: [
                  IconButton(
                    tooltip: 'แก้ไขคลัง',
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: canEditWarehouse ? () => _showWarehouseForm(warehouse: warehouse) : null,
                  ),
                  IconButton(
                    tooltip: 'กำหนดผู้ดูแล',
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    onPressed: canManageManager ? () => _showManagerDialog(warehouse: warehouse) : null,
                  ),
                  IconButton(
                    tooltip: 'จัดการตำแหน่งเก็บ',
                    icon: const Icon(Icons.account_tree, size: 18),
                    onPressed: canManageShelves ? () => _openShelfTree(warehouse) : null,
                  ),
                  IconButton(
                    tooltip: 'ลบคลัง',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: canDeleteWarehouse ? () => _confirmDeleteWarehouse(warehouse) : null,
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUtilizationPanel() {
    if (_warehouses.isEmpty) return const SizedBox.shrink();
    final sorted = List<Map<String, dynamic>>.from(_warehouses)
      ..sort((a, b) {
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        final utilA = _warehouseUtilization[idA] ?? 0;
        final utilB = _warehouseUtilization[idB] ?? 0;
        return utilB.compareTo(utilA);
      });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_graph, color: AppDesignSystem.primary),
                SizedBox(width: 8),
                Text('การใช้งานคลัง (Utilization Overview)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            ...sorted.map((warehouse) {
              final id = warehouse['id']?.toString() ?? '';
              final util = _warehouseUtilization[id] ?? 0;
              final percent = (util * 100).clamp(0, 100).toStringAsFixed(0);
              final capacity = _warehouseCapacity[id] ?? 0;
              final active = _activeShelves[id] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(warehouse['name']?.toString() ?? '-')),
                        Text('$percent%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: util.clamp(0, 1)),
                    Text('ความจุ $capacity หน่วย • ชั้นวางใช้งาน $active'),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopShelvesCard() {
    final topShelves = _topShelves();
    if (topShelves.isEmpty) {
      return _EmptyStateCard(
        title: 'ยังไม่มีชั้นวางที่มีสินค้า',
        message: 'ระบบจะสรุป 5 ชั้นวางที่มีสินค้ามากที่สุดเมื่อมีข้อมูลจริง',
        icon: Icons.inventory_2_outlined,
      );
    }

    final productCountByShelf = <String, int>{};
    for (final product in _products) {
      final shelfId = product['shelf_id']?.toString();
      if (shelfId == null) continue;
      productCountByShelf[shelfId] = (productCountByShelf[shelfId] ?? 0) + 1;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.star, color: AppDesignSystem.warning),
                SizedBox(width: 8),
                Text('Top Shelves (จำนวนสินค้ามากที่สุด)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            ...topShelves.map((shelf) {
              final shelfId = shelf['id']?.toString() ?? '';
              final count = productCountByShelf[shelfId] ?? 0;
              final warehouseName = _warehouses
                      .firstWhere(
                        (w) => w['id']?.toString() == shelf['warehouse_id']?.toString(),
                        orElse: () => const {},
                      )['name']
                      ?.toString() ??
                  '-';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppDesignSystem.secondary.withOpacity(0.15),
                  child: Text(count.toString()),
                ),
                title: Text(shelf['code']?.toString() ?? '-'),
                subtitle: Text('คลัง: $warehouseName'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center),
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

    final canAddWarehouse = PermissionService.canAccessActionSync('inventory_adjustment_warehouse_add');
    final canManageManager = PermissionService.canAccessActionSync('inventory_adjustment_warehouse_add');
    final alertsPanel = _buildAlertsPanel();

    return _buildWarehouseContent(canAddWarehouse, canManageManager, alertsPanel ?? const SizedBox.shrink());
  }

  Widget _buildLoadingShimmer() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warehouse cards shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingMd),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
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

  Widget _buildWarehouseContent(bool canAddWarehouse, bool canManageManager, Widget alertsPanel) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final actionButtons = <Widget>[
                    if (canManageManager)
                      TextButton.icon(
                        onPressed: () => _showManagerDialog(),
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('ผู้ดูแลคลัง'),
                      ),
                    ElevatedButton.icon(
                      onPressed: canAddWarehouse ? () => _showWarehouseForm() : null,
                      icon: const Icon(Icons.add_business),
                      label: const Text('เพิ่มคลัง'),
                    ),
                  ];

                  final titleColumn = Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('สถานที่เก็บและชั้นวาง', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('จัดการคลัง ผู้ดูแล และโครงสร้างโซน/ชั้นวางแบบ Tree view', maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );

                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleColumn,
                        const SizedBox(height: AppDesignSystem.spacingSm),
                        Wrap(
                          spacing: AppDesignSystem.spacingSm,
                          runSpacing: AppDesignSystem.spacingSm,
                          children: actionButtons,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      titleColumn,
                      const Spacer(),
                      ...actionButtons.expand((widget) sync* {
                        yield widget;
                        if (widget != actionButtons.last) {
                          yield const SizedBox(width: AppDesignSystem.spacingSm);
                        }
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildSummaryCards(),
              if (alertsPanel != null) ...[
                const SizedBox(height: AppDesignSystem.spacingLg),
                alertsPanel,
              ],
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildWarehouseTable(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildUtilizationPanel(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildTopShelvesCard(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildMovementHistoryCard(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildTransferRequestsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppDesignSystem.textSecondary)),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(subtitle, style: TextStyle(color: AppDesignSystem.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppDesignSystem.success : AppDesignSystem.border;
    final text = isActive ? 'ใช้งาน' : 'ปิดอยู่';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _EmptyStateCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppDesignSystem.textSecondary.withOpacity(0.7)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppDesignSystem.textSecondary)),
          ],
        ),
      ),
    );
  }
}
