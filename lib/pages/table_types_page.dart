import 'package:flutter/material.dart';
import '../services/table_management_service.dart';
import '../services/permission_service.dart';
import '../utils/permission_helpers.dart';

/// หน้าจัดการประเภทโต๊ะ — ชื่อ, รูปทรง, สี, จำนวนที่นั่ง
class TableTypesPage extends StatefulWidget {
  const TableTypesPage({super.key});
  @override
  State<TableTypesPage> createState() => _TableTypesPageState();
}

class _TableTypesPageState extends State<TableTypesPage> {
  List<Map<String, dynamic>> _types = [];
  bool _isLoading = true;

  static const _shapes = [
    {'value': 'rect', 'label': 'สี่เหลี่ยม', 'icon': Icons.crop_square},
    {'value': 'circle', 'label': 'วงกลม', 'icon': Icons.circle_outlined},
    {'value': 'rounded', 'label': 'มนเหลี่ยม', 'icon': Icons.rounded_corner},
  ];

  static const _presetColors = [
    '#1493FF', '#F19EDC', '#F0B400', '#4CAF50', '#FF5722',
    '#9C27B0', '#607D8B', '#FF9800', '#E91E63', '#00BCD4',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final types = await TableManagementService.getTableTypes();
    setState(() { _types = types; _isLoading = false; });
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _showDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final capacityCtrl = TextEditingController(text: (existing?['default_capacity'] ?? 4).toString());
    String selShape = existing?['shape'] ?? 'rect';
    String selColor = existing?['color'] ?? '#1493FF';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final previewColor = _hexToColor(selColor);
        return AlertDialog(
          title: Text(existing == null ? 'เพิ่มประเภทโต๊ะ' : 'แก้ไขประเภทโต๊ะ'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Preview
            Center(
              child: Container(
                width: 80, height: 80,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: previewColor.withValues(alpha: 0.2),
                  border: Border.all(color: previewColor, width: 2.5),
                  borderRadius: selShape == 'circle'
                      ? BorderRadius.circular(40)
                      : selShape == 'rounded'
                          ? BorderRadius.circular(16)
                          : BorderRadius.circular(6),
                ),
                child: Center(child: Text(
                  nameCtrl.text.isEmpty ? 'A1' : nameCtrl.text.substring(0, nameCtrl.text.length.clamp(0, 3)),
                  style: TextStyle(color: previewColor, fontWeight: FontWeight.bold, fontSize: 16),
                )),
              ),
            ),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'ชื่อประเภทโต๊ะ *', border: OutlineInputBorder(), hintText: 'เช่น โต๊ะกลม 4 ที่'),
              onChanged: (_) => setS(() {}),
            ),
            const SizedBox(height: 12),
            const Text('รูปทรงโต๊ะ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(children: _shapes.map((s) {
              final isSel = selShape == s['value'];
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setS(() => selShape = s['value'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel ? previewColor.withValues(alpha: 0.15) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSel ? previewColor : Colors.grey[300]!, width: isSel ? 2 : 1),
                    ),
                    child: Column(children: [
                      Icon(s['icon'] as IconData, color: isSel ? previewColor : Colors.grey[600], size: 22),
                      const SizedBox(height: 4),
                      Text(s['label'] as String, style: TextStyle(fontSize: 10, color: isSel ? previewColor : Colors.grey[600], fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    ]),
                  ),
                ),
              ));
            }).toList()),
            const SizedBox(height: 12),
            const Text('สีโต๊ะ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: _presetColors.map((hex) {
              final c = _hexToColor(hex);
              final isSel = selColor.toUpperCase() == hex.toUpperCase();
              return GestureDetector(
                onTap: () => setS(() => selColor = hex),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSel ? Colors.black : Colors.transparent, width: 2.5),
                    boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)] : null,
                  ),
                  child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              );
            }).toList()),
            const SizedBox(height: 12),
            TextField(
              controller: capacityCtrl,
              decoration: const InputDecoration(labelText: 'จำนวนที่นั่งเริ่มต้น', border: OutlineInputBorder(), suffixText: 'ที่นั่ง'),
              keyboardType: TextInputType.number,
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                if (existing == null) {
                  await TableManagementService.addTableType(
                    name: nameCtrl.text.trim(),
                    shape: selShape,
                    color: selColor,
                    defaultCapacity: int.tryParse(capacityCtrl.text) ?? 4,
                  );
                } else {
                  await TableManagementService.updateTableType(
                    id: existing['id'],
                    name: nameCtrl.text.trim(),
                    shape: selShape,
                    color: selColor,
                    defaultCapacity: int.tryParse(capacityCtrl.text) ?? 4,
                  );
                }
                _load();
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
        ),
        child: SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ประเภทโต๊ะ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('กำหนดรูปทรง สี และจำนวนที่นั่ง', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
            ]),
          ),
          // Body
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _types.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.table_restaurant, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('ยังไม่มีประเภทโต๊ะ', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                        ]))
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _types.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (newIndex > oldIndex) newIndex--;
                            final updated = List<Map<String, dynamic>>.from(_types);
                            final item = updated.removeAt(oldIndex);
                            updated.insert(newIndex, item);
                            setState(() => _types = updated);
                            await TableManagementService.reorderTableTypes(updated.map((t) => t['id'] as String).toList());
                          },
                          itemBuilder: (context, index) {
                            final t = _types[index];
                            final color = _hexToColor(t['color'] as String? ?? '#1493FF');
                            final shape = t['shape'] as String? ?? 'rect';
                            final capacity = t['default_capacity'] as int? ?? 4;
                            final shapeLabel = _shapes.firstWhere((s) => s['value'] == shape, orElse: () => _shapes[0])['label'] as String;

                            return Card(
                              key: ValueKey(t['id']),
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                leading: ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    width: 52, height: 52,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      border: Border.all(color: color, width: 2),
                                      borderRadius: shape == 'circle'
                                          ? BorderRadius.circular(26)
                                          : shape == 'rounded'
                                              ? BorderRadius.circular(14)
                                              : BorderRadius.circular(6),
                                    ),
                                    child: Center(child: Icon(
                                      shape == 'circle' ? Icons.circle_outlined : shape == 'rounded' ? Icons.rounded_corner : Icons.crop_square,
                                      color: color, size: 24,
                                    )),
                                  ),
                                ),
                                title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                subtitle: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                    child: Text(shapeLabel, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.people, size: 13, color: Colors.grey[500]),
                                  const SizedBox(width: 2),
                                  Text('$capacity ที่นั่ง', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ]),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  if (PermissionService.canAccessActionSync('table_management_types_edit'))
                                    IconButton(icon: const Icon(Icons.edit, size: 18, color: Color(0xFF3B82F6)), onPressed: () => _showDialog(existing: t)),
                                  if (PermissionService.canAccessActionSync('table_management_types_delete'))
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      onPressed: () => checkPermissionAndExecute(context, 'table_management_types_delete', 'ลบประเภทโต๊ะ', () => showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('ลบประเภทโต๊ะ'),
                                          content: Text('ต้องการลบ "${t['name']}" ใช่ไหม?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                              onPressed: () async { Navigator.pop(ctx); await TableManagementService.deleteTableType(t['id']); _load(); },
                                              child: const Text('ลบ'),
                                            ),
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
          ),
        ])),
      ),
      floatingActionButton: PermissionService.canAccessActionSync('table_management_types_add')
          ? FloatingActionButton.extended(
              onPressed: () => _showDialog(),
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มประเภท'),
            )
          : null,
    );
  }
}
