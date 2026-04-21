import 'package:flutter/material.dart';
import '../../../theme/app_design_system.dart';

/// Widget สำหรับเลือกหลายรายการ (Multi-select)
class BulkSelectionWidget extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String itemLabelField; // field name for display (e.g., 'name')
  final ValueChanged<List<String>> onSelectionChanged;
  final bool showSelectAll;

  const BulkSelectionWidget({
    super.key,
    required this.items,
    required this.itemLabelField,
    required this.onSelectionChanged,
    this.showSelectAll = true,
  });

  @override
  State<BulkSelectionWidget> createState() => _BulkSelectionWidgetState();
}

class _BulkSelectionWidgetState extends State<BulkSelectionWidget> {
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    widget.onSelectionChanged(_selectedIds.toList());
  }

  void _selectAll() {
    setState(() {
      _selectedIds.clear();
      for (final item in widget.items) {
        final id = item['id']?.toString();
        if (id != null) {
          _selectedIds.add(id);
        }
      }
    });
    widget.onSelectionChanged(_selectedIds.toList());
  }

  void _deselectAll() {
    setState(() => _selectedIds.clear());
    widget.onSelectionChanged([]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with select/deselect buttons
        if (widget.showSelectAll)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'เลือก: ${_selectedIds.length}/${widget.items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('เลือกทั้งหมด'),
                    ),
                    TextButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('ยกเลิก'),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Items list
        Expanded(
          child: ListView.builder(
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final id = item['id']?.toString() ?? '';
              final label = item[widget.itemLabelField]?.toString() ?? 'Unknown';
              final isSelected = _selectedIds.contains(id);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: isSelected
                    ? AppDesignSystem.primary.withOpacity(0.1)
                    : null,
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(id),
                  title: Text(label),
                  subtitle: item['code'] != null
                      ? Text('รหัส: ${item['code']}')
                      : null,
                  secondary: item['quantity'] != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item['quantity']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
