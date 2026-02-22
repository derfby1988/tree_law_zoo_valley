import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/table_management_service.dart';
import '../services/permission_service.dart';
import '../utils/permission_helpers.dart';
import 'table_types_page.dart';

// =============================================
// Main Page: จัดการร้าน/โซน
// =============================================
class TableManagementPage extends StatefulWidget {
  const TableManagementPage({super.key});
  @override
  State<TableManagementPage> createState() => _TableManagementPageState();
}

class _TableManagementPageState extends State<TableManagementPage> {
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    final zones = await TableManagementService.getZones();
    setState(() { _zones = zones; _isLoading = false; });
  }

  void _showZoneDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final openCtrl = TextEditingController(text: existing?['open_time'] ?? '');
    final closeCtrl = TextEditingController(text: existing?['close_time'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'เพิ่มร้าน/โซน' : 'แก้ไขร้าน/โซน'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อร้าน *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: openCtrl, decoration: const InputDecoration(labelText: 'เปิด (10:00)', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: closeCtrl, decoration: const InputDecoration(labelText: 'ปิด (20:00)', border: OutlineInputBorder()))),
          ]),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              if (existing == null) {
                await TableManagementService.addZone(name: nameCtrl.text.trim(), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(), openTime: openCtrl.text.trim().isEmpty ? null : openCtrl.text.trim(), closeTime: closeCtrl.text.trim().isEmpty ? null : closeCtrl.text.trim());
              } else {
                await TableManagementService.updateZone(id: existing['id'], name: nameCtrl.text.trim(), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(), openTime: openCtrl.text.trim().isEmpty ? null : openCtrl.text.trim(), closeTime: closeCtrl.text.trim().isEmpty ? null : closeCtrl.text.trim());
              }
              _loadZones();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

  }


  void _confirmDeleteZone(Map<String, dynamic> zone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบร้าน/โซน'),
        content: Text('ต้องการลบ "${zone['name']}" และโต๊ะทั้งหมดในร้านนี้ใช่ไหม?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async { Navigator.pop(ctx); await TableManagementService.deleteZone(zone['id']); _loadZones(); },
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)])),
        child: SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ที่นั่งของแต่ละร้าน', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('ออกแบบผังโต๊ะก่อนเปิดร้าน', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              if (PermissionService.canAccessTabSync('table_management_types'))
                IconButton(
                  icon: const Icon(Icons.category, color: Colors.white),
                  tooltip: 'ประเภทโต๊ะ',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TableTypesPage())),
                ),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadZones),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _zones.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.store_mall_directory, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('ยังไม่มีร้าน/โซน', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('กด + เพิ่มร้าน เพื่อเริ่มต้น', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ]))
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _zones.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (newIndex > oldIndex) newIndex--;
                            final updated = List<Map<String, dynamic>>.from(_zones);
                            final item = updated.removeAt(oldIndex);
                            updated.insert(newIndex, item);
                            setState(() => _zones = updated);
                            await TableManagementService.reorderZones(updated.map((z) => z['id'] as String).toList());
                          },
                          itemBuilder: (context, index) {
                            final zone = _zones[index];
                            final openTime = zone['open_time'] as String?;
                            final closeTime = zone['close_time'] as String?;
                            final timeStr = (openTime != null && closeTime != null) ? '$openTime - $closeTime น.' : '';
                            return Card(
                              key: ValueKey(zone['id']),
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ZoneTablesPage(zone: zone))).then((_) => _loadZones()),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(children: [
                                    ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle, color: Colors.grey)),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.store, color: Color(0xFF3B82F6), size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(zone['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      if (timeStr.isNotEmpty) Text('เปิด $timeStr', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                      if ((zone['description'] as String?)?.isNotEmpty == true)
                                        Text(zone['description'], style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ])),
                                    if (PermissionService.canAccessActionSync('table_management_zones_edit'))
                                      IconButton(icon: const Icon(Icons.edit, size: 18, color: Color(0xFF3B82F6)), onPressed: () => _showZoneDialog(existing: zone)),
                                    if (PermissionService.canAccessActionSync('table_management_zones_delete'))
                                      IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteZone(zone)),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ])),
      ),
      floatingActionButton: PermissionService.canAccessActionSync('table_management_zones_add')
          ? FloatingActionButton.extended(
              onPressed: () => _showZoneDialog(),
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business),
              label: const Text('เพิ่มร้าน'),
            )
          : null,
    );
  }
}

// =============================================
// Zone Tables Page
// =============================================
class ZoneTablesPage extends StatefulWidget {
  const ZoneTablesPage({super.key, required this.zone});
  final Map<String, dynamic> zone;
  @override
  State<ZoneTablesPage> createState() => _ZoneTablesPageState();
}

class _ZoneTablesPageState extends State<ZoneTablesPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _elements = [];
  bool _isLoading = true;
  bool _isSavingLayout = false;
  late TabController _tabController;
  bool _hasChanges = false;
  bool _hasElementChanges = false;
  String? _selectedElementId;
  static const double _tableSize = 56;
  bool _openTabShowPlan = true;

  // Toolbar tool: null=select, 'text', 'rect', 'circle', 'rounded'
  String? _activeTool;

  static const _typeOptions = [
    {'value': 'large', 'label': 'โต๊ะใหญ่ (6-10)', 'color': Color(0xFF1493FF)},
    {'value': 'small', 'label': 'โต๊ะเล็ก (2)', 'color': Color(0xFFF19EDC)},
    {'value': 'bar', 'label': 'บาร์/พิเศษ', 'color': Color(0xFFF0B400)},
  ];

  @override
  void initState() {
    super.initState();
    final showLayout = PermissionService.canAccessTabSync('table_management_layout');
    _tabController = TabController(length: showLayout ? 3 : 2, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final tables = await TableManagementService.getTablesForZone(widget.zone['id']);
    final elements = await TableManagementService.getElementsForZone(widget.zone['id']);
    setState(() { 
      _tables = tables; 
      _elements = elements; 
      _isLoading = false; 
    });
  }

  Future<void> _loadTables() async {
    final tables = await TableManagementService.getTablesForZone(widget.zone['id']);
    if (mounted) setState(() => _tables = tables);
  }

  Future<void> _loadElements() async {
    final elements = await TableManagementService.getElementsForZone(widget.zone['id']);
    if (mounted) setState(() => _elements = elements);
  }

  Widget _buildLoadingSkeleton(bool showLayout) {
    Widget skeletonBox({double width = double.infinity, double height = 16, EdgeInsets margin = EdgeInsets.zero}) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: skeletonBox(height: 18, margin: const EdgeInsets.only(right: 8))),
          skeletonBox(width: 70, height: 18),
        ]),
        const SizedBox(height: 12),
        skeletonBox(height: 140, margin: const EdgeInsets.only(bottom: 16)),
        ...List.generate(3, (i) =>
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                skeletonBox(width: 44, height: 44, margin: const EdgeInsets.only(right: 12)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  skeletonBox(height: 14, width: 120, margin: const EdgeInsets.only(bottom: 6)),
                  skeletonBox(height: 12, width: 180),
                ])),
                const SizedBox(width: 12),
                skeletonBox(width: 32, height: 32, margin: const EdgeInsets.only(right: 8)),
                skeletonBox(width: 32, height: 32),
              ]),
            ),
          ),
        ),
        if (showLayout)
          skeletonBox(height: 220, margin: const EdgeInsets.only(top: 8)),
      ]),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _placedTables => _tables.where((t) => t['pos_x'] != null && t['pos_y'] != null).toList();
  List<Map<String, dynamic>> get _unplacedTables => _tables.where((t) => t['pos_x'] == null || t['pos_y'] == null).toList();
  bool get _canEditLayout => PermissionService.canAccessActionSync('table_management_layout_move');

  Future<void> _saveAllPositions() async {
    if (_isSavingLayout) return;
    setState(() => _isSavingLayout = true);

    int savedTables = 0;
    String? errorMsg;
    final List<String> failedTables = [];
    try {
      // Save table positions
      for (final t in _placedTables) {
        final ok = await TableManagementService.updateTablePosition(
          t['id'] as String, (t['pos_x'] as num).toDouble(), (t['pos_y'] as num).toDouble(), tableName: t['name']?.toString());
        if (ok) {
          savedTables++;
        } else {
          final name = t['name']?.toString() ?? '';
          failedTables.add(name.isEmpty ? 'โต๊ะไม่ทราบชื่อ' : name);
        }
      }

      // Save elements
      if (failedTables.isEmpty && _hasElementChanges) {
        final ok = await TableManagementService.saveAllElements(_elements);
        if (!ok) errorMsg = 'บันทึกองค์ประกอบไม่สำเร็จ';
      }

      if (failedTables.isNotEmpty) {
        errorMsg = 'บันทึกโต๊ะไม่สำเร็จ: ${failedTables.join(', ')}';
      }

      if (errorMsg == null) {
        // reload from DB to ensure persistence then return to table tab
        await Future.wait([_loadTables(), _loadElements()]);
        if (mounted) {
          setState(() { _hasChanges = false; _hasElementChanges = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('บันทึกผังร้านสำเร็จ ($savedTables โต๊ะ + ${_elements.length} องค์ประกอบ)'), backgroundColor: Colors.green));
          _tabController.animateTo(1);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg!), backgroundColor: Colors.red));
        }
      }
    } finally {
      if (mounted) setState(() => _isSavingLayout = false);
    }
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _showElementEditDialog(Map<String, dynamic> el) {
    final labelCtrl = TextEditingController(text: el['label'] ?? '');
    String selColor = el['color'] as String? ?? '#607D8B';
    double fontSize = (el['font_size'] as num?)?.toDouble() ?? 14;
    const presetColors = [
      '#1E3A8A', '#3B82F6', '#1493FF', '#4CAF50', '#F0B400',
      '#F19EDC', '#FF5722', '#9C27B0', '#607D8B', '#E91E63',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text('แก้ไข${el['element_type'] == 'text' ? 'ข้อความ' : 'รูปทรง'}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: labelCtrl,
            decoration: const InputDecoration(labelText: 'ข้อความ / ชื่อ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          const Text('สี', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: presetColors.map((hex) {
            final c = _hexToColor(hex);
            final isSel = selColor.toUpperCase() == hex.toUpperCase();
            return GestureDetector(
              onTap: () => setS(() => selColor = hex),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                  border: Border.all(color: isSel ? Colors.black : Colors.transparent, width: 2.5)),
                child: isSel ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
              ),
            );
          }).toList()),
          if (el['element_type'] == 'text') ...[
            const SizedBox(height: 12),
            Row(children: [
              const Text('ขนาดตัวอักษร', style: TextStyle(fontSize: 13)),
              const Spacer(),
              Text('${fontSize.round()} px', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            Slider(
              value: fontSize,
              min: 10, max: 32,
              divisions: 11,
              onChanged: (v) => setS(() => fontSize = v),
            ),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                final idx = _elements.indexWhere((e) => e['id'] == el['id']);
                if (idx >= 0) {
                  _elements[idx] = {..._elements[idx], 'label': labelCtrl.text, 'color': selColor, 'font_size': fontSize};
                  _hasElementChanges = true;
                }
              });
            },
            child: const Text('บันทึก'),
          ),
        ],
      )),
    );
  }

  Widget _buildElementWidget(Map<String, dynamic> el, {bool isDragging = false}) {
    final type = el['element_type'] as String? ?? 'rect';
    final label = el['label'] as String? ?? '';
    final color = _hexToColor(el['color'] as String? ?? '#607D8B');
    final fontSize = (el['font_size'] as num?)?.toDouble() ?? 14;
    final isSelected = _selectedElementId == el['id'];

    if (type == 'line') {
      return CustomPaint(
        painter: _LinePainter(color: color, isSelected: isSelected, isDragging: isDragging),
      );
    }

    if (type == 'text') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDragging || isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: color, width: 1.5, style: BorderStyle.solid) : null,
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600)),
      );
    }

    final BorderRadius br;
    if (type == 'circle') {
      br = BorderRadius.circular(100);
    } else if (type == 'rounded') {
      br = BorderRadius.circular(16);
    } else if (type == 'rect_wide') {
      br = BorderRadius.circular(4);
    } else {
      br = BorderRadius.circular(6);
    }

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDragging ? 0.35 : 0.18),
        borderRadius: br,
        border: Border.all(color: color, width: isSelected ? 2.5 : 1.5),
        boxShadow: isDragging ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)] : null,
      ),
      child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
    );
  }

  /// Wraps element with rotation + resize/rotate handles when selected
  Widget _buildElementOnCanvas(Map<String, dynamic> el, double w, double h, double canvasW, double canvasH) {
    final rotation = (el['rotation'] as num?)?.toDouble() ?? 0.0;
    final rotRad = rotation * math.pi / 180.0;
    final isSelected = _selectedElementId == el['id'];
    const handleSize = 18.0;

    Widget inner = SizedBox(width: w, height: h, child: _buildElementWidget(el));

    if (rotation != 0) {
      inner = Transform.rotate(angle: rotRad, child: inner);
    }

    if (!isSelected) return inner;

    // Resize handle (bottom-right corner)
    final resizeHandle = Positioned(
      right: 0, bottom: 0,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final idx = _elements.indexWhere((e) => e['id'] == el['id']);
            if (idx < 0) return;
            final newW = ((el['width'] as num).toDouble() + d.delta.dx / canvasW).clamp(0.04, 0.95);
            final newH = ((el['height'] as num).toDouble() + d.delta.dy / canvasH).clamp(0.02, 0.95);
            _elements[idx] = {..._elements[idx], 'width': newW, 'height': newH};
            _hasElementChanges = true;
          });
        },
        child: Container(
          width: handleSize, height: handleSize,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Icon(Icons.open_in_full, color: Colors.white, size: 10),
        ),
      ),
    );

    // Rotate handle (top-right corner)
    final rotateHandle = Positioned(
      right: 0, top: 0,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final idx = _elements.indexWhere((e) => e['id'] == el['id']);
            if (idx < 0) return;
            final curRot = ((_elements[idx]['rotation'] as num?)?.toDouble() ?? 0.0);
            final newRot = (curRot + d.delta.dx * 1.5) % 360;
            _elements[idx] = {..._elements[idx], 'rotation': newRot};
            _hasElementChanges = true;
          });
        },
        child: Container(
          width: handleSize, height: handleSize,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(handleSize / 2),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Icon(Icons.rotate_right, color: Colors.white, size: 10),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        inner,
        resizeHandle,
        rotateHandle,
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);

  Widget _buildTableWidget(Map<String, dynamic> t, Color color, {bool isDragging = false}) {
    final type = t['table_type'] as String? ?? 'small';
    final name = t['name'] ?? '';
    final capacity = t['capacity'] as int? ?? 2;
    final status = t['status'] as String? ?? 'available';
    final isUnavailable = status == 'unavailable';
    return Container(
      width: _tableSize, height: _tableSize,
      decoration: BoxDecoration(
        color: (isUnavailable ? Colors.grey : color).withValues(alpha: isDragging ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(type == 'bar' ? 6 : 10),
        border: Border.all(color: isDragging ? Colors.white : color, width: isDragging ? 2 : 1.5),
        boxShadow: isDragging ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_typeIcon(type), color: Colors.white, size: 16),
        const SizedBox(height: 2),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('$capacity ที่', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 8)),
      ]),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'large': return Icons.table_restaurant;
      case 'bar': return Icons.local_bar;
      default: return Icons.chair;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'large': return const Color(0xFF1493FF);
      case 'small': return const Color(0xFFF19EDC);
      case 'bar': return const Color(0xFFF0B400);
      default: return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'large': return 'ใหญ่';
      case 'small': return 'เล็ก';
      case 'bar': return 'บาร์';
      default: return type;
    }
  }

  void _showTableDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final capacityCtrl = TextEditingController(text: (existing?['capacity'] ?? 2).toString());
    final notesCtrl = TextEditingController(text: existing?['notes'] ?? '');
    String selType = existing?['table_type'] ?? 'small';
    String selStatus = existing?['status'] ?? 'available';
    bool isBookable = existing?['is_bookable'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(existing == null ? 'เพิ่มโต๊ะ' : 'แก้ไขโต๊ะ'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อโต๊ะ * (เช่น A1)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          const Text('ประเภทโต๊ะ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: _typeOptions.map((t) {
            final isSel = selType == t['value'];
            return ChoiceChip(
              label: Text(t['label'] as String, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
              selected: isSel,
              selectedColor: t['color'] as Color,
              onSelected: (_) => setS(() => selType = t['value'] as String),
            );
          }).toList()),
          const SizedBox(height: 10),
          TextField(controller: capacityCtrl, decoration: const InputDecoration(labelText: 'จำนวนที่นั่ง', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          const Text('สถานะ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            ChoiceChip(label: const Text('ว่าง'), selected: selStatus == 'available', selectedColor: Colors.green, labelStyle: TextStyle(color: selStatus == 'available' ? Colors.white : null), onSelected: (_) => setS(() => selStatus = 'available')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('ไม่ว่าง'), selected: selStatus == 'unavailable', selectedColor: Colors.grey, labelStyle: TextStyle(color: selStatus == 'unavailable' ? Colors.white : null), onSelected: (_) => setS(() => selStatus = 'unavailable')),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('รับการจองล่วงหน้า', style: TextStyle(fontSize: 13)),
            subtitle: Text(isBookable ? 'เปิดรับจอง' : 'Walk-in เท่านั้น', style: const TextStyle(fontSize: 11)),
            value: isBookable,
            onChanged: (v) => setS(() => isBookable = v),
          ),
          TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder()), maxLines: 2),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              if (existing == null) {
                await TableManagementService.addTable(zoneId: widget.zone['id'], name: nameCtrl.text.trim(), tableType: selType, capacity: int.tryParse(capacityCtrl.text) ?? 2, isBookable: isBookable, notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
              } else {
                await TableManagementService.updateTable(id: existing['id'], name: nameCtrl.text.trim(), tableType: selType, capacity: int.tryParse(capacityCtrl.text) ?? 2, isBookable: isBookable, status: selStatus, notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
              }
              _loadTables();
            },
            child: const Text('บันทึก'),
          ),
        ],
      )),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) {
    final zoneName = widget.zone['name'] ?? '';
    final openTime = widget.zone['open_time'] as String?;
    final closeTime = widget.zone['close_time'] as String?;
    final timeStr = (openTime != null && closeTime != null) ? 'เปิด $openTime - $closeTime น.' : '';
    final showLayout = PermissionService.canAccessTabSync('table_management_layout');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)])),
        child: SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(zoneName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                if (timeStr.isNotEmpty) Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              Text('${_tables.length} โต๊ะ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (_hasChanges && _canEditLayout)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed: _saveAllPositions,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('บันทึก'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                ),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadTables),
            ]),
          ),
          if (showLayout)
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.meeting_room, size: 18), text: 'เปิดโต๊ะ'),
                Tab(icon: Icon(Icons.table_restaurant, size: 18), text: 'เพิ่มโต๊ะ'),
                Tab(icon: Icon(Icons.grid_view, size: 18), text: 'ผังร้าน'),
              ],
            )
          else
            const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: _isLoading
                  ? _buildLoadingSkeleton(showLayout)
                  : showLayout
                      ? TabBarView(
                          controller: _tabController,
                          children: [_buildOpenTableTab(), _buildTableListTab(), _buildFloorPlanTab()],
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [_buildOpenTableTab(), _buildTableListTab()],
                        ),
            ),
          ),
        ])),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final onTableTab = _tabController.index == 1;
          if (onTableTab && PermissionService.canAccessActionSync('table_management_tables_add')) {
            return FloatingActionButton.extended(
              onPressed: () => _showTableDialog(),
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มโต๊ะ'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTableListTab() {
    if (_tables.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.table_restaurant, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('ยังไม่มีโต๊ะในร้านนี้', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
      ]));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Card(
          elevation: 0, color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(spacing: 14, runSpacing: 6, children: [
              _chip('โต๊ะใหญ่', const Color(0xFF1493FF)),
              _chip('โต๊ะเล็ก', const Color(0xFFF19EDC)),
              _chip('บาร์', const Color(0xFFF0B400)),
              _chip('ไม่ว่าง', Colors.grey),
              _chip('Walk-in', Colors.orange),
            ]),
          ),
        ),
      ),
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          itemCount: _tables.length,
          onReorder: (oldIndex, newIndex) async {
            if (newIndex > oldIndex) newIndex--;
            final updated = List<Map<String, dynamic>>.from(_tables);
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            setState(() => _tables = updated);
            await TableManagementService.reorderTables(updated.map((t) => t['id'] as String).toList());
          },
          itemBuilder: (context, index) {
            final table = _tables[index];
            final type = table['table_type'] as String? ?? 'small';
            final status = table['status'] as String? ?? 'available';
            final isBookable = table['is_bookable'] as bool? ?? true;
            final capacity = table['capacity'] as int? ?? 2;
            final isUnavailable = status == 'unavailable';
            final color = isUnavailable ? Colors.grey : _typeColor(type);
            return Card(
              key: ValueKey(table['id']),
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.5))),
                    child: Center(child: Text(table['name'] ?? '', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                  ),
                ),
                title: Wrap(spacing: 4, children: [
                  Text(table['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  _chip(_typeLabel(type), color),
                  if (isUnavailable) _chip('ไม่ว่าง', Colors.grey),
                  if (!isBookable) _chip('Walk-in', Colors.orange),
                ]),
                subtitle: Text('$capacity ที่นั่ง${(table['notes'] as String?)?.isNotEmpty == true ? ' • ${table['notes']}' : ''}', style: const TextStyle(fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (PermissionService.canAccessActionSync('table_management_tables_edit'))
                    IconButton(icon: const Icon(Icons.edit, size: 18, color: Color(0xFF3B82F6)), onPressed: () => _showTableDialog(existing: table)),
                  if (PermissionService.canAccessActionSync('table_management_tables_delete'))
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => checkPermissionAndExecute(context, 'table_management_tables_delete', 'ลบโต๊ะ', () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('ลบโต๊ะ'),
                          content: Text('ต้องการลบโต๊ะ "${table['name']}" ใช่ไหม?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { Navigator.pop(ctx); await TableManagementService.deleteTable(table['id']); _loadTables(); }, child: const Text('ลบ')),
                          ],
                        ),
                      )),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildOpenTableTab() {
    final placed = _placedTables;
    final unplaced = _unplacedTables;

    // scale height based on y positions to reduce overlap (similar to booking mini plan)
    const baseHeight = 320.0;
    const tableSize = 52.0;
    double minY = 0, maxY = 0, minDelta = double.infinity;
    if (placed.isNotEmpty) {
      final sorted = [...placed]
        ..sort((a, b) => ((a['pos_y'] ?? 0) as num).compareTo((b['pos_y'] ?? 0) as num));
      minY = (sorted.first['pos_y'] as num?)?.toDouble() ?? 0;
      maxY = (sorted.last['pos_y'] as num?)?.toDouble() ?? 0;
      for (int i = 0; i < sorted.length - 1; i++) {
        final dy = ((sorted[i + 1]['pos_y'] ?? 0) as num).toDouble() - ((sorted[i]['pos_y'] ?? 0) as num).toDouble();
        if (dy > 0 && dy < minDelta) minDelta = dy;
      }
    }
    double scaleByDelta = 1.0;
    if (minDelta != double.infinity && minDelta > 0) {
      scaleByDelta = (tableSize * 1.4) / (minDelta * baseHeight);
    }
    final span = (maxY - minY).abs();
    final scaleBySpan = span > 0 ? (span + 0.4) : 1.0;
    final canvasHeight = baseHeight * math.max(1.0, math.max(scaleByDelta, scaleBySpan));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('มุมมอง', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('ผังร้าน'),
                selected: _openTabShowPlan,
                onSelected: (_) => setState(() => _openTabShowPlan = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('รายการ'),
                selected: !_openTabShowPlan,
                onSelected: (_) => setState(() => _openTabShowPlan = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: _openTabShowPlan
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                CustomPaint(size: Size(canvasW, canvasHeight), painter: _ZoneGridPainter()),
                                ...placed.map((t) {
                                  final px = (t['pos_x'] as num).toDouble();
                                  final py = (t['pos_y'] as num).toDouble();
                                  final normY = (py - minY) / normSpan;
                                  final left = px * canvasW;
                                  final top = normY * availableH + tableSize * 0.1;
                                  final type = t['table_type'] as String? ?? 'small';
                                  final status = t['status'] as String? ?? 'available';
                                  final isUnavailable = status == 'unavailable';
                                  final color = isUnavailable ? Colors.grey : _typeColor(type);
                                  return Positioned(
                                    left: left.clamp(0, canvasW - tableSize),
                                    top: top.clamp(0, canvasHeight - tableSize),
                                    child: GestureDetector(
                                      onLongPress: _canEditLayout ? () => _showRemoveFromPlanDialog(t) : null,
                                      child: Container(
                                        width: tableSize,
                                        height: tableSize,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(type == 'bar' ? 6 : 10),
                                          border: Border.all(color: color, width: 1.5),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (t['name'] ?? '').toString(),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (placed.isEmpty)
                                  const Center(child: Text('ยังไม่มีโต๊ะบนผัง', style: TextStyle(color: Colors.grey))),
                              ],
                            ),
                          );
                        },
                      ),
                      if (unplaced.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('โต๊ะที่ยังไม่ได้วางบนผัง', style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: unplaced
                              .map((t) => _chip(
                                    t['name']?.toString() ?? '-',
                                    _typeColor(t['table_type'] as String? ?? 'small'),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                )
              : _buildTableListTab(),
        ),
      ],
    );
  }

  Widget _buildFloorPlanTab() {
    final unplaced = _unplacedTables;
    final placed = _placedTables;

    return Column(children: [
      // ── Toolbar ──────────────────────────────────────────────
      if (_canEditLayout)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
          ),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            // Tool buttons
            _toolBtn(null, Icons.near_me, 'เลือก'),
            const SizedBox(width: 4),
            _toolBtn('text', Icons.text_fields, 'ข้อความ'),
            const SizedBox(width: 4),
            _toolBtn('rect', Icons.crop_square, 'สี่เหลี่ยมจัตุรัส'),
            const SizedBox(width: 4),
            _toolBtn('rect_wide', Icons.rectangle_outlined, 'สี่เหลี่ยมผืนผ้า'),
            const SizedBox(width: 4),
            _toolBtn('circle', Icons.circle_outlined, 'วงกลม'),
            const SizedBox(width: 4),
            _toolBtn('rounded', Icons.rounded_corner, 'มนเหลี่ยม'),
            const SizedBox(width: 4),
            _toolBtn('line', Icons.horizontal_rule, 'เส้นตรง'),
            const SizedBox(width: 8),
            Container(width: 1, height: 28, color: Colors.grey[300]),
            const SizedBox(width: 8),
            // Selected element actions
            if (_selectedElementId != null) ...[
              Builder(builder: (ctx) {
                final el = _elements.firstWhere((e) => e['id'] == _selectedElementId, orElse: () => {});
                final rot = el.isEmpty ? 0.0 : (el['rotation'] as num?)?.toDouble() ?? 0.0;
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  // Rotate -15
                  Tooltip(
                    message: 'หมุนซ้าย 15°',
                    child: GestureDetector(
                      onTap: () {
                        final idx = _elements.indexWhere((e) => e['id'] == _selectedElementId);
                        if (idx >= 0) setState(() { _elements[idx] = {..._elements[idx], 'rotation': (rot - 15) % 360}; _hasElementChanges = true; });
                      },
                      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.withValues(alpha: 0.4))),
                        child: const Icon(Icons.rotate_left, size: 16, color: Colors.orange)),
                    ),
                  ),
                  const SizedBox(width: 3),
                  // Rotation display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                    child: Text('${rot.round()}°', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 3),
                  // Rotate +15
                  Tooltip(
                    message: 'หมุนขวา 15°',
                    child: GestureDetector(
                      onTap: () {
                        final idx = _elements.indexWhere((e) => e['id'] == _selectedElementId);
                        if (idx >= 0) setState(() { _elements[idx] = {..._elements[idx], 'rotation': (rot + 15) % 360}; _hasElementChanges = true; });
                      },
                      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.withValues(alpha: 0.4))),
                        child: const Icon(Icons.rotate_right, size: 16, color: Colors.orange)),
                    ),
                  ),
                  const SizedBox(width: 6),
                ]);
              }),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 20),
                tooltip: 'แก้ไของค์ประกอบ',
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  final el = _elements.firstWhere((e) => e['id'] == _selectedElementId, orElse: () => {});
                  if (el.isNotEmpty) _showElementEditDialog(el);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                tooltip: 'ลบองค์ประกอบที่เลือก',
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () async {
                  final id = _selectedElementId!;
                  final el = _elements.firstWhere((e) => e['id'] == id, orElse: () => {});
                  if (el.isEmpty) return;
                  if (!id.startsWith('new_')) {
                    await TableManagementService.deleteElement(id);
                  }
                  setState(() {
                    _elements.removeWhere((e) => e['id'] == id);
                    _selectedElementId = null;
                    _hasElementChanges = true;
                  });
                },
              ),
              const SizedBox(width: 4),
            ],
            Text('${_elements.length} องค์ประกอบ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ])),
        ),
      // ── Unplaced tray ────────────────────────────────────────
      if (unplaced.isNotEmpty && _canEditLayout)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Text('โต๊ะที่ยังไม่ได้วาง (${unplaced.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber)),
              const Spacer(),
              Text('ลากไปวางบนผังด้านล่าง', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: unplaced.map((t) {
                final type = t['table_type'] as String? ?? 'small';
                final status = t['status'] as String? ?? 'available';
                final color = status == 'unavailable' ? Colors.grey : _typeColor(type);
                return Draggable<Map<String, dynamic>>(
                  data: {'kind': 'table', ...t},
                  feedback: Material(elevation: 8, borderRadius: BorderRadius.circular(10), child: _buildTableWidget(t, color, isDragging: true)),
                  childWhenDragging: Opacity(opacity: 0.3, child: _buildTableWidget(t, color)),
                  child: _buildTableWidget(t, color),
                );
              }).toList(),
            ),
          ]),
        )
      else if (unplaced.isEmpty && _tables.isNotEmpty && _canEditLayout)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Card(
            elevation: 0, color: Colors.green.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.green.withValues(alpha: 0.3))),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                SizedBox(width: 6),
                Text('โต๊ะทุกโต๊ะวางบนผังแล้ว', style: TextStyle(fontSize: 11, color: Colors.green)),
              ]),
            ),
          ),
        ),
      // ── Legend ───────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Card(
          elevation: 0, color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              _legendDot(const Color(0xFF1493FF), 'ใหญ่'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFF19EDC), 'เล็ก'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFF0B400), 'บาร์'),
              const SizedBox(width: 10),
              _legendDot(Colors.grey, 'ไม่ว่าง'),
              const Spacer(),
              Text('${placed.length}/${_tables.length} โต๊ะ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ),
        ),
      ),
      // ── Canvas ───────────────────────────────────────────────
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: LayoutBuilder(builder: (context, constraints) {
            final canvasW = constraints.maxWidth;
            final canvasH = constraints.maxHeight;
            return GestureDetector(
              onTapDown: (details) {
                if (!_canEditLayout) return;
                if (_activeTool != null) {
                  // Place new element at tap position
                  final relX = (details.localPosition.dx / canvasW).clamp(0.0, 0.85);
                  final relY = (details.localPosition.dy / canvasH).clamp(0.0, 0.85);
                  final String label;
                  final double elW, elH;
                  final String elColor;
                  switch (_activeTool) {
                    case 'text': label = 'ข้อความ'; elW = 0.18; elH = 0.06; elColor = '#1E3A8A';
                    case 'rect': label = 'สี่เหลี่ยม'; elW = 0.12; elH = 0.12; elColor = '#607D8B';
                    case 'rect_wide': label = 'สี่เหลี่ยมผืนผ้า'; elW = 0.22; elH = 0.10; elColor = '#607D8B';
                    case 'circle': label = 'วงกลม'; elW = 0.12; elH = 0.12; elColor = '#3B82F6';
                    case 'rounded': label = 'มนเหลี่ยม'; elW = 0.14; elH = 0.10; elColor = '#4CAF50';
                    case 'line': label = ''; elW = 0.25; elH = 0.03; elColor = '#607D8B';
                    default: label = 'รูปทรง'; elW = 0.12; elH = 0.10; elColor = '#607D8B';
                  }
                  final newEl = {
                    'id': 'new_${DateTime.now().millisecondsSinceEpoch}',
                    'zone_id': widget.zone['id'],
                    'element_type': _activeTool,
                    'label': label,
                    'pos_x': relX,
                    'pos_y': relY,
                    'width': elW,
                    'height': elH,
                    'color': elColor,
                    'font_size': 14.0,
                    'rotation': 0.0,
                    'sort_order': _elements.length,
                  };
                  setState(() {
                    _elements = [..._elements, newEl];
                    _selectedElementId = newEl['id'] as String;
                    _hasElementChanges = true;
                    _activeTool = null;
                  });
                } else {
                  // Deselect
                  setState(() => _selectedElementId = null);
                }
              },
              child: DragTarget<Map<String, dynamic>>(
                onAcceptWithDetails: (details) {
                  if (!_canEditLayout) return;
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.offset);
                  final data = details.data;
                  final kind = data['kind'] as String? ?? 'table';
                  if (kind == 'element') {
                    final relX = (localPos.dx / canvasW).clamp(0.0, 0.88);
                    final relY = (localPos.dy / canvasH).clamp(0.0, 0.88);
                    setState(() {
                      final idx = _elements.indexWhere((e) => e['id'] == data['id']);
                      if (idx >= 0) { _elements[idx] = {..._elements[idx], 'pos_x': relX, 'pos_y': relY}; _hasElementChanges = true; }
                    });
                  } else {
                    final relX = (localPos.dx / canvasW).clamp(0.0, 1.0 - _tableSize / canvasW);
                    final relY = (localPos.dy / canvasH).clamp(0.0, 1.0 - _tableSize / canvasH);
                    setState(() {
                      final idx = _tables.indexWhere((t) => t['id'] == data['id']);
                      if (idx >= 0) { _tables[idx] = {..._tables[idx], 'pos_x': relX, 'pos_y': relY}; _hasChanges = true; }
                    });
                  }
                },
                builder: (context, candidateData, _) {
                  final isHovering = candidateData.isNotEmpty;
                  return Container(
                    width: canvasW, height: canvasH,
                    decoration: BoxDecoration(
                      color: _activeTool != null
                          ? Colors.blue.withValues(alpha: 0.03)
                          : isHovering ? Colors.blue.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _activeTool != null
                            ? Colors.blue.withValues(alpha: 0.4)
                            : isHovering ? Colors.blue.withValues(alpha: 0.5) : Colors.grey[300]!,
                        width: (_activeTool != null || isHovering) ? 2 : 1,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: Stack(children: [
                      CustomPaint(size: Size(canvasW, canvasH), painter: _ZoneGridPainter()),
                      Center(child: Text(widget.zone['name'] ?? '', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.withValues(alpha: 0.07)))),
                      // Hint when tool active
                      if (_activeTool != null)
                        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.touch_app, size: 40, color: Colors.blue.withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Text('แตะบนผังเพื่อวาง${_activeTool == 'text' ? 'ข้อความ' : 'รูปทรง'}', style: TextStyle(color: Colors.blue.withValues(alpha: 0.5), fontSize: 13)),
                        ])),
                      // ── Elements (text/shapes) ──
                      ..._elements.map((el) {
                        final posX = (el['pos_x'] as num).toDouble();
                        final posY = (el['pos_y'] as num).toDouble();
                        final elW = (el['width'] as num?)?.toDouble() ?? 0.15;
                        final elH = (el['height'] as num?)?.toDouble() ?? 0.08;
                        final left = posX * canvasW;
                        final top = posY * canvasH;
                        final w = elW * canvasW;
                        final h = elH * canvasH;
                        if (_canEditLayout) {
                          return Positioned(
                            left: left, top: top,
                            child: Draggable<Map<String, dynamic>>(
                              data: {'kind': 'element', ...el},
                              feedback: Material(
                                elevation: 6, color: Colors.transparent,
                                child: SizedBox(width: w, height: h, child: _buildElementWidget(el, isDragging: true)),
                              ),
                              childWhenDragging: Opacity(opacity: 0.2, child: SizedBox(width: w, height: h, child: _buildElementWidget(el))),
                              onDragEnd: (dragDetails) {
                                final RenderBox? box = context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                final localPos = box.globalToLocal(dragDetails.offset);
                                final relX = (localPos.dx / canvasW).clamp(0.0, 0.88);
                                final relY = (localPos.dy / canvasH).clamp(0.0, 0.88);
                                setState(() {
                                  final idx = _elements.indexWhere((e) => e['id'] == el['id']);
                                  if (idx >= 0) { _elements[idx] = {..._elements[idx], 'pos_x': relX, 'pos_y': relY}; _hasElementChanges = true; }
                                });
                              },
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedElementId = el['id'] as String?),
                                onDoubleTap: () => _showElementEditDialog(el),
                                child: SizedBox(
                                  width: w + 20, height: h + 20,
                                  child: _buildElementOnCanvas(el, w, h, canvasW, canvasH),
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Positioned(left: left, top: top, child: SizedBox(width: w, height: h, child: _buildElementWidget(el)));
                        }
                      }),
                      // ── Tables ──
                      ...placed.map((t) {
                        final posX = (t['pos_x'] as num).toDouble();
                        final posY = (t['pos_y'] as num).toDouble();
                        final type = t['table_type'] as String? ?? 'small';
                        final status = t['status'] as String? ?? 'available';
                        final color = status == 'unavailable' ? Colors.grey : _typeColor(type);
                        final left = posX * canvasW;
                        final top = posY * canvasH;
                        if (_canEditLayout) {
                          return Positioned(
                            left: left, top: top,
                            child: Draggable<Map<String, dynamic>>(
                              data: {'kind': 'table', ...t},
                              feedback: Material(elevation: 8, borderRadius: BorderRadius.circular(10), child: _buildTableWidget(t, color, isDragging: true)),
                              childWhenDragging: Opacity(opacity: 0.2, child: _buildTableWidget(t, color)),
                              onDragEnd: (dragDetails) {
                                final RenderBox? box = context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                final localPos = box.globalToLocal(dragDetails.offset);
                                final relX = (localPos.dx / canvasW).clamp(0.0, 1.0 - _tableSize / canvasW);
                                final relY = (localPos.dy / canvasH).clamp(0.0, 1.0 - _tableSize / canvasH);
                                setState(() {
                                  final idx = _tables.indexWhere((tt) => tt['id'] == t['id']);
                                  if (idx >= 0) { _tables[idx] = {..._tables[idx], 'pos_x': relX, 'pos_y': relY}; _hasChanges = true; }
                                });
                              },
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedElementId = null),
                                onLongPress: () => _showRemoveFromPlanDialog(t),
                                child: _buildTableWidget(t, color),
                              ),
                            ),
                          );
                        } else {
                          return Positioned(left: left, top: top, child: _buildTableWidget(t, color));
                        }
                      }),
                    ]),
                  );
                },
              ),
            );
          }),
        ),
      ),
    ]);
  }

  Widget _toolBtn(String? tool, IconData icon, String tooltip) {
    final isActive = _activeTool == tool;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _activeTool = isActive ? null : tool),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3B82F6) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? const Color(0xFF3B82F6) : Colors.grey[300]!),
          ),
          child: Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey[700]),
        ),
      ),
    );
  }

  void _showRemoveFromPlanDialog(Map<String, dynamic> t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('โต๊ะ ${t['name']}'),
        content: const Text('ต้องการนำโต๊ะนี้ออกจากผังร้านไหม?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                final idx = _tables.indexWhere((tt) => tt['id'] == t['id']);
                if (idx >= 0) { _tables[idx] = {..._tables[idx], 'pos_x': null, 'pos_y': null}; _hasChanges = true; }
              });
            },
            child: const Text('นำออก'),
          ),
        ],
      ),
    );
  }
}

class _ZoneGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    const spacing = 40.0;
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

class _LinePainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  final bool isDragging;
  const _LinePainter({required this.color, this.isSelected = false, this.isDragging = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = isSelected ? 3.0 : 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    if (isSelected) {
      // Draw endpoint handles
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(0, size.height / 2), 4, dotPaint);
      canvas.drawCircle(Offset(size.width, size.height / 2), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.color != color || old.isSelected != isSelected;
}
