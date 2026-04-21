import 'package:flutter/material.dart';

import '../../../services/inventory_service.dart';

class ShelfTreeDialog extends StatefulWidget {
  final Map<String, dynamic> warehouse;
  final List<Map<String, dynamic>> initialZones;
  final List<Map<String, dynamic>> initialShelves;
  final List<Map<String, dynamic>> products;

  const ShelfTreeDialog({
    super.key,
    required this.warehouse,
    required this.initialZones,
    required this.initialShelves,
    required this.products,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> warehouse,
    required List<Map<String, dynamic>> zones,
    required List<Map<String, dynamic>> shelves,
    required List<Map<String, dynamic>> products,
    required VoidCallback onChanged,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => _ShelfTreeDialogWrapper(
        warehouse: warehouse,
        zones: zones,
        shelves: shelves,
        products: products,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<ShelfTreeDialog> createState() => _ShelfTreeDialogState();
}

class _ShelfTreeDialogState extends State<ShelfTreeDialog> {
  late List<Map<String, dynamic>> _zones;
  late List<Map<String, dynamic>> _shelves;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _zones = List<Map<String, dynamic>>.from(widget.initialZones);
    _shelves = List<Map<String, dynamic>>.from(widget.initialShelves);
  }

  int _productCountForShelf(String shelfId) {
    return widget.products.where((p) => p['shelf_id']?.toString() == shelfId).length;
  }

  List<Map<String, dynamic>> _shelvesForZone(String? zoneId) {
    return _shelves
        .where((shelf) =>
            (shelf['zone_id'] == null && zoneId == null) ||
            (shelf['zone_id']?.toString() == zoneId?.toString()))
        .toList()
      ..sort((a, b) => ((a['display_order'] ?? 0) as int).compareTo((b['display_order'] ?? 0) as int));
  }

  Future<void> _reload() async {
    setState(() => _isLoading = true);
    final warehouseId = widget.warehouse['id']?.toString();
    final results = await Future.wait([
      InventoryService.getWarehouseZones(warehouseId: warehouseId, includeInactive: true),
      InventoryService.getShelves(warehouseId: warehouseId, includeInactive: true),
    ]);
    if (!mounted) return;
    setState(() {
      _zones = results[0];
      _shelves = results[1];
      _isLoading = false;
    });
  }

  Future<void> _addZone() async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('สร้างโซนใหม่'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'ชื่อโซน',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('บันทึก')),
        ],
      ),
    );
    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      await InventoryService.addWarehouseZone(
        warehouseId: widget.warehouse['id'].toString(),
        name: nameController.text.trim(),
      );
      await _reload();
    }
    nameController.dispose();
  }

  Future<void> _renameZone(Map<String, dynamic> zone) async {
    final controller = TextEditingController(text: zone['name']?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เปลี่ยนชื่อโซน'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('บันทึก')),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await InventoryService.updateWarehouseZone(id: zone['id'].toString(), name: controller.text.trim());
      await _reload();
    }
    controller.dispose();
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final hasShelves = _shelves.any((shelf) => shelf['zone_id']?.toString() == zone['id']?.toString());
    if (hasShelves) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โซนนี้ยังมีชั้นวางอยู่ กรุณาย้ายชั้นวางก่อนลบ')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบโซน'),
        content: Text('ต้องการลบโซน "${zone['name']}" ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirmed == true) {
      await InventoryService.deleteWarehouseZone(zone['id'].toString());
      await _reload();
    }
  }

  Future<void> _toggleZoneStatus(Map<String, dynamic> zone, bool value) async {
    await InventoryService.updateWarehouseZone(id: zone['id'].toString(), isActive: value);
    await _reload();
  }

  Future<void> _addShelf({required String? zoneId}) async {
    final controller = TextEditingController();
    final capacityController = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มชั้นวาง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'ชื่อ / รหัสชั้นวาง', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(labelText: 'ความจุ (หน่วย)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('บันทึก')),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final capacity = int.tryParse(capacityController.text.trim()) ?? 0;
      await InventoryService.addShelf(
        warehouseId: widget.warehouse['id'].toString(),
        code: controller.text.trim(),
        capacity: capacity,
        zoneId: zoneId,
      );
      await _reload();
    }
    controller.dispose();
    capacityController.dispose();
  }

  Future<void> _editShelf(Map<String, dynamic> shelf) async {
    final nameController = TextEditingController(text: shelf['code']?.toString() ?? '');
    final capacityController = TextEditingController(text: (shelf['capacity'] ?? 0).toString());
    int capacity = shelf['capacity'] is int
        ? shelf['capacity'] as int
        : int.tryParse(shelf['capacity']?.toString() ?? '0') ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขชั้นวาง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'ชื่อ / รหัส', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ความจุ', border: OutlineInputBorder()),
              onChanged: (value) => capacity = int.tryParse(value.trim()) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('บันทึก')),
        ],
      ),
    );
    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      await InventoryService.updateShelf(
        id: shelf['id'].toString(),
        code: nameController.text.trim(),
        capacity: capacity,
      );
      await _reload();
    }
    nameController.dispose();
    capacityController.dispose();
  }

  Future<void> _toggleShelfStatus(Map<String, dynamic> shelf, bool value) async {
    await InventoryService.updateShelf(id: shelf['id'].toString(), isActive: value);
    await _reload();
  }

  Future<void> _reorderZones(int oldIndex, int newIndex) async {
    final working = List<Map<String, dynamic>>.from(_zones);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = working.removeAt(oldIndex);
    working.insert(newIndex, moved);
    setState(() => _zones = working);
    await InventoryService.updateZoneOrder(
      widget.warehouse['id'].toString(),
      working.map((z) => z['id'].toString()).toList(),
    );
    await _reload();
  }

  Future<void> _reorderShelves(String? zoneId, int oldIndex, int newIndex) async {
    final current = _shelvesForZone(zoneId);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    final other = _shelves.where((shelf) {
      final belongsToZone = (shelf['zone_id'] == null && zoneId == null) ||
          (shelf['zone_id']?.toString() == zoneId?.toString());
      return !belongsToZone;
    }).toList();
    setState(() => _shelves = [...current, ...other]);
    await InventoryService.updateShelfOrder(current.map((s) => s['id'].toString()).toList());
    await _reload();
  }

  Widget _buildZoneCard({required Map<String, dynamic>? zone, bool enableDrag = true}) {
    final zoneId = zone?['id']?.toString();
    final zoneName = zone == null ? 'ยังไม่มีโซน' : (zone['name']?.toString() ?? '-');
    final shelves = _shelvesForZone(zoneId);

    final card = Card(
      key: ValueKey(zoneId ?? 'unassigned'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(zoneName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (zone != null)
                  Chip(
                    label: Text(zone['is_active'] == true ? 'ใช้งาน' : 'ปิดอยู่'),
                    backgroundColor: zone['is_active'] == true ? Colors.green[50] : Colors.grey[200],
                  ),
                const Spacer(),
                if (zone != null) ...[
                  IconButton(
                    tooltip: 'เปลี่ยนชื่อโซน',
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _renameZone(zone),
                  ),
                  Switch(
                    value: zone['is_active'] != false,
                    onChanged: (value) => _toggleZoneStatus(zone, value),
                  ),
                  IconButton(
                    tooltip: 'ลบโซน',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deleteZone(zone),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: shelves.isEmpty ? 56 : (shelves.length * 70).clamp(140, 320).toDouble(),
              child: shelves.isEmpty
                  ? Center(
                      child: Text(
                        zone == null ? 'ยังไม่มีชั้นวางในโซนทั่วไป' : 'โซนนี้ยังไม่มีชั้นวาง',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ReorderableListView.builder(
                      key: ValueKey('shelf_list_${zoneId ?? 'general'}'),
                      itemCount: shelves.length,
                      onReorder: (oldIdx, newIdx) => _reorderShelves(zoneId, oldIdx, newIdx),
                      padding: EdgeInsets.zero,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final shelf = shelves[index];
                        final shelfId = shelf['id'].toString();
                        final productCount = _productCountForShelf(shelfId);
                        return Card(
                          key: ValueKey(shelfId),
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: ListTile(
                            title: Text(shelf['code']?.toString() ?? '-'),
                            subtitle: Text('ความจุ ${shelf['capacity'] ?? 0} | ${productCount} รายการ'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                Switch(
                                  value: shelf['is_active'] != false,
                                  onChanged: (value) => _toggleShelfStatus(shelf, value),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editShelf(shelf),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addShelf(zoneId: zone?['id']?.toString()),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มชั้นวาง'),
                ),
                const Spacer(),
                if (zone == null)
                  Text(
                    'ชั้นวางที่ยังไม่ถูกจัดกลุ่ม',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!enableDrag) {
      return card;
    }
    return ReorderableDragStartListener(
      index: _zones.indexWhere((z) => z['id'] == zoneId),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 720,
      height: 520,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addZone,
                      icon: const Icon(Icons.category),
                      label: const Text('เพิ่มโซนใหม่'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _reload(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('รีเฟรช'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _zones.length + 1,
                    onReorder: (oldIdx, newIdx) {
                      if (oldIdx == _zones.length || newIdx == _zones.length) {
                        return;
                      }
                      _reorderZones(oldIdx, newIdx);
                    },
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      if (index == _zones.length) {
                        return _buildZoneCard(zone: null, enableDrag: false);
                      }
                      final zone = _zones[index];
                      return _buildZoneCard(zone: zone);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ShelfTreeDialogWrapper extends StatelessWidget {
  final Map<String, dynamic> warehouse;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> shelves;
  final List<Map<String, dynamic>> products;
  final VoidCallback onChanged;

  const _ShelfTreeDialogWrapper({
    required this.warehouse,
    required this.zones,
    required this.shelves,
    required this.products,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('จัดการชั้นวางใน ${warehouse['name'] ?? '-'}'),
      content: ShelfTreeDialog(
        warehouse: warehouse,
        initialZones: zones,
        initialShelves: shelves,
        products: products,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onChanged();
          },
          child: const Text('ปิด'),
        ),
      ],
    );
  }
}
