import 'package:flutter/material.dart';
import '../services/table_management_service.dart';
import '../services/permission_service.dart';

/// หน้าผังร้าน (Floor Plan) — ลากโต๊ะวางบน canvas เพื่อจัดเลเอาท์
class FloorPlanPage extends StatefulWidget {
  const FloorPlanPage({super.key, required this.zone, this.readOnly = false});
  final Map<String, dynamic> zone;
  final bool readOnly;

  @override
  State<FloorPlanPage> createState() => _FloorPlanPageState();
}

class _FloorPlanPageState extends State<FloorPlanPage> {
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  // Canvas config
  static const double _tableSize = 56;

  // Unplaced tables (pos_x/pos_y == null)
  List<Map<String, dynamic>> get _placedTables =>
      _tables.where((t) => t['pos_x'] != null && t['pos_y'] != null).toList();

  List<Map<String, dynamic>> get _unplacedTables =>
      _tables.where((t) => t['pos_x'] == null || t['pos_y'] == null).toList();

  bool get _canEdit =>
      !widget.readOnly &&
      PermissionService.canAccessActionSync('table_management_layout_move');

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    final tables =
        await TableManagementService.getTablesForZone(widget.zone['id']);
    setState(() {
      _tables = tables;
      _isLoading = false;
    });
  }

  Future<void> _saveAllPositions() async {
    int saved = 0;
    for (final t in _placedTables) {
      final ok = await TableManagementService.updateTablePosition(
        t['id'] as String,
        (t['pos_x'] as num).toDouble(),
        (t['pos_y'] as num).toDouble(),
      );
      if (ok) saved++;
    }
    if (mounted) {
      setState(() => _hasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกตำแหน่ง $saved โต๊ะสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'large':
        return const Color(0xFF1493FF);
      case 'small':
        return const Color(0xFFF19EDC);
      case 'bar':
        return const Color(0xFFF0B400);
      default:
        return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'large':
        return 'ใหญ่';
      case 'small':
        return 'เล็ก';
      case 'bar':
        return 'บาร์';
      default:
        return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'large':
        return Icons.table_restaurant;
      case 'bar':
        return Icons.local_bar;
      default:
        return Icons.chair;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneName = widget.zone['name'] ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ผังร้าน: $zoneName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.readOnly
                                ? 'ดูผังร้าน (อ่านอย่างเดียว)'
                                : 'ลากโต๊ะวางบนผังร้าน แล้วกดบันทึก',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_canEdit && _hasChanges)
                      ElevatedButton.icon(
                        onPressed: _saveAllPositions,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('บันทึก'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadTables,
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _tables.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.table_restaurant,
                                      size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'ยังไม่มีโต๊ะในร้านนี้\nเพิ่มโต๊ะในหน้า "จัดการโต๊ะ" ก่อน',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Unplaced tables tray
                                if (_unplacedTables.isNotEmpty && _canEdit)
                                  _buildUnplacedTray(),

                                // Legend
                                _buildLegend(),

                                // Canvas
                                Expanded(child: _buildCanvas()),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _legendItem(const Color(0xFF1493FF), 'โต๊ะใหญ่'),
              const SizedBox(width: 14),
              _legendItem(const Color(0xFFF19EDC), 'โต๊ะเล็ก'),
              const SizedBox(width: 14),
              _legendItem(const Color(0xFFF0B400), 'บาร์'),
              const SizedBox(width: 14),
              _legendItem(Colors.grey, 'ไม่ว่าง'),
              const Spacer(),
              Text(
                '${_placedTables.length}/${_tables.length} วางแล้ว',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  /// Tray ด้านบนสำหรับโต๊ะที่ยังไม่ได้วาง — ลากจากที่นี่ลงไปวางบน canvas
  Widget _buildUnplacedTray() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                'โต๊ะที่ยังไม่ได้วาง (${_unplacedTables.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber,
                ),
              ),
              const Spacer(),
              Text(
                'ลากไปวางบนผังด้านล่าง',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _unplacedTables.map((t) {
              final type = t['table_type'] as String? ?? 'small';
              final status = t['status'] as String? ?? 'available';
              final color =
                  status == 'unavailable' ? Colors.grey : _typeColor(type);

              return Draggable<Map<String, dynamic>>(
                data: t,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  child: _buildTableWidget(t, color, isDragging: true),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildTableWidget(t, color),
                ),
                child: _buildTableWidget(t, color),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Canvas ที่แสดงผังร้าน — โต๊ะที่วางแล้วจะอยู่ตามตำแหน่ง
  Widget _buildCanvas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasW = constraints.maxWidth;
          final canvasH = constraints.maxHeight;

          return DragTarget<Map<String, dynamic>>(
            onAcceptWithDetails: (details) {
              if (!_canEdit) return;
              // Calculate drop position relative to canvas
              final RenderBox renderBox =
                  context.findRenderObject() as RenderBox;
              final localPos = renderBox.globalToLocal(details.offset);

              // Convert to relative position (0.0 - 1.0)
              final relX =
                  ((localPos.dx - 16) / canvasW).clamp(0.0, 1.0 - _tableSize / canvasW);
              final relY =
                  ((localPos.dy) / canvasH).clamp(0.0, 1.0 - _tableSize / canvasH);

              final table = details.data;
              setState(() {
                final idx =
                    _tables.indexWhere((t) => t['id'] == table['id']);
                if (idx >= 0) {
                  _tables[idx] = {
                    ..._tables[idx],
                    'pos_x': relX,
                    'pos_y': relY,
                  };
                  _hasChanges = true;
                }
              });
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Container(
                width: canvasW,
                height: canvasH,
                decoration: BoxDecoration(
                  color: isHovering
                      ? Colors.blue.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHovering
                        ? Colors.blue.withValues(alpha: 0.5)
                        : Colors.grey[300]!,
                    width: isHovering ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Grid lines
                    CustomPaint(
                      size: Size(canvasW, canvasH),
                      painter: _GridPainter(),
                    ),

                    // Zone name watermark
                    Center(
                      child: Text(
                        widget.zone['name'] ?? '',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                    ),

                    // Placed tables
                    ..._placedTables.map((t) {
                      final posX = (t['pos_x'] as num).toDouble();
                      final posY = (t['pos_y'] as num).toDouble();
                      final type = t['table_type'] as String? ?? 'small';
                      final status = t['status'] as String? ?? 'available';
                      final color = status == 'unavailable'
                          ? Colors.grey
                          : _typeColor(type);

                      final left = posX * canvasW;
                      final top = posY * canvasH;

                      if (_canEdit) {
                        return Positioned(
                          left: left,
                          top: top,
                          child: Draggable<Map<String, dynamic>>(
                            data: t,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(10),
                              child: _buildTableWidget(t, color,
                                  isDragging: true),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.2,
                              child: _buildTableWidget(t, color),
                            ),
                            onDragEnd: (dragDetails) {
                              // Update position on drag end within canvas
                              final RenderBox? box =
                                  context.findRenderObject() as RenderBox?;
                              if (box == null) return;
                              final localPos =
                                  box.globalToLocal(dragDetails.offset);
                              final relX = (localPos.dx / canvasW)
                                  .clamp(0.0, 1.0 - _tableSize / canvasW);
                              final relY = (localPos.dy / canvasH)
                                  .clamp(0.0, 1.0 - _tableSize / canvasH);

                              setState(() {
                                final idx = _tables
                                    .indexWhere((tt) => tt['id'] == t['id']);
                                if (idx >= 0) {
                                  _tables[idx] = {
                                    ..._tables[idx],
                                    'pos_x': relX,
                                    'pos_y': relY,
                                  };
                                  _hasChanges = true;
                                }
                              });
                            },
                            child: GestureDetector(
                              onLongPress: () => _showTableInfo(t),
                              child: _buildTableWidget(t, color),
                            ),
                          ),
                        );
                      } else {
                        // Read-only mode
                        return Positioned(
                          left: left,
                          top: top,
                          child: GestureDetector(
                            onTap: () => _showTableInfo(t),
                            child: _buildTableWidget(t, color),
                          ),
                        );
                      }
                    }),

                    // Empty state hint
                    if (_placedTables.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_view,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(
                              _canEdit
                                  ? 'ลากโต๊ะจากด้านบนมาวางที่นี่'
                                  : 'ยังไม่มีโต๊ะบนผัง',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTableWidget(Map<String, dynamic> t, Color color,
      {bool isDragging = false}) {
    final type = t['table_type'] as String? ?? 'small';
    final name = t['name'] ?? '';
    final capacity = t['capacity'] as int? ?? 2;
    final status = t['status'] as String? ?? 'available';
    final isUnavailable = status == 'unavailable';

    return Container(
      width: _tableSize,
      height: _tableSize,
      decoration: BoxDecoration(
        color: isUnavailable
            ? Colors.grey.withValues(alpha: isDragging ? 0.9 : 0.7)
            : color.withValues(alpha: isDragging ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(type == 'bar' ? 6 : 10),
        border: Border.all(
          color: isDragging ? Colors.white : color,
          width: isDragging ? 2 : 1.5,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _typeIcon(type),
            color: Colors.white,
            size: isDragging ? 18 : 16,
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: isDragging ? 11 : 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$capacity ที่',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  void _showTableInfo(Map<String, dynamic> t) {
    final type = t['table_type'] as String? ?? 'small';
    final status = t['status'] as String? ?? 'available';
    final capacity = t['capacity'] as int? ?? 2;
    final isBookable = t['is_bookable'] as bool? ?? true;
    final notes = t['notes'] as String?;
    final color = status == 'unavailable' ? Colors.grey : _typeColor(type);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(type), color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text('โต๊ะ ${t['name']}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('ประเภท', _typeLabel(type)),
            _infoRow('ที่นั่ง', '$capacity คน'),
            _infoRow(
                'สถานะ', status == 'unavailable' ? 'ไม่ว่าง' : 'ว่าง'),
            _infoRow('รับจอง', isBookable ? 'ใช่' : 'Walk-in เท่านั้น'),
            if (notes != null && notes.isNotEmpty)
              _infoRow('หมายเหตุ', notes),
            if (t['pos_x'] != null)
              _infoRow(
                'ตำแหน่ง',
                'X: ${(t['pos_x'] as num).toStringAsFixed(2)}, Y: ${(t['pos_y'] as num).toStringAsFixed(2)}',
              ),
          ],
        ),
        actions: [
          if (_canEdit && t['pos_x'] != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  final idx =
                      _tables.indexWhere((tt) => tt['id'] == t['id']);
                  if (idx >= 0) {
                    _tables[idx] = {
                      ..._tables[idx],
                      'pos_x': null,
                      'pos_y': null,
                    };
                    _hasChanges = true;
                  }
                });
              },
              child: const Text('นำออกจากผัง',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Grid painter for the canvas background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    const spacing = 40.0;

    // Vertical lines
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
