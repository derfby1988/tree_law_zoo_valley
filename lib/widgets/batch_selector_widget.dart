import 'package:flutter/material.dart';
import '../services/inventory_service.dart';
import '../utils/thai_date_utils.dart';

/// Widget สำหรับเลือก batch ในการผลิตหรือขาย
/// รองรับโหมด FEFO (auto) และ Manual Selection
class BatchSelectorWidget extends StatefulWidget {
  final String itemType; // 'product' | 'ingredient'
  final String itemId;
  final String itemName;
  final double quantityNeeded;
  final bool autoSelectFEFO;
  final Function(List<Map<String, dynamic>> selectedBatches)? onBatchesSelected;
  final VoidCallback? onError;

  const BatchSelectorWidget({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    required this.quantityNeeded,
    this.autoSelectFEFO = true,
    this.onBatchesSelected,
    this.onError,
  });

  @override
  State<BatchSelectorWidget> createState() => _BatchSelectorWidgetState();
}

class _BatchSelectorWidgetState extends State<BatchSelectorWidget> {
  List<Map<String, dynamic>> _availableBatches = [];
  List<Map<String, dynamic>> _selectedBatches = [];
  bool _isLoading = true;
  double _remainingNeeded = 0;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      // ดึง batch ที่ยังไม่หมดอายุ เรียงตาม FEFO
      final batches = await InventoryService.getBatchesForFEFO(
        itemType: widget.itemType,
        itemId: widget.itemId,
      );

      if (mounted) {
        setState(() {
          _availableBatches = batches;
          _isLoading = false;
        });

        if (widget.autoSelectFEFO) {
          _calculateFEFOSelection();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onError?.call();
      }
    }
  }

  void _calculateFEFOSelection() {
    _selectedBatches = [];
    double remaining = widget.quantityNeeded;

    for (final batch in _availableBatches) {
      if (remaining <= 0) break;

      final batchQty = (batch['quantity'] as num).toDouble();
      final take = remaining < batchQty ? remaining : batchQty;

      _selectedBatches.add({
        ...batch,
        'take_quantity': take,
      });

      remaining -= take;
    }

    _remainingNeeded = remaining;

    // แจ้ง parent ถ้าเลือกครบแล้ว
    if (_remainingNeeded == 0 && widget.onBatchesSelected != null) {
      widget.onBatchesSelected!(_selectedBatches);
    }
  }

  void _toggleBatchSelection(Map<String, dynamic> batch, double quantity) {
    setState(() {
      final existingIndex = _selectedBatches.indexWhere(
        (b) => b['id'] == batch['id'],
      );

      if (existingIndex >= 0) {
        if (quantity <= 0) {
          _selectedBatches.removeAt(existingIndex);
        } else {
          _selectedBatches[existingIndex]['take_quantity'] = quantity;
        }
      } else if (quantity > 0) {
        _selectedBatches.add({
          ...batch,
          'take_quantity': quantity,
        });
      }

      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    double totalSelected = _selectedBatches.fold(
      0,
      (sum, b) => sum + ((b['take_quantity'] as num?)?.toDouble() ?? 0),
    );
    _remainingNeeded = widget.quantityNeeded - totalSelected;

    if (_remainingNeeded == 0 && widget.onBatchesSelected != null) {
      widget.onBatchesSelected!(_selectedBatches);
    }
  }

  Color _getExpiryColor(DateTime expiryDate) {
    final days = expiryDate.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red;
    if (days <= 3) return Colors.red.shade300;
    if (days <= 7) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_availableBatches.isEmpty) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ไม่มี batch ที่พร้อมใช้สำหรับ ${widget.itemName}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalAvailable = _availableBatches.fold<double>(
      0,
      (sum, b) => sum + ((b['quantity'] as num?)?.toDouble() ?? 0),
    );

    final isEnoughStock = totalAvailable >= widget.quantityNeeded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with summary
        Card(
          color: _remainingNeeded == 0
              ? Colors.green.shade50
              : isEnoughStock
                  ? Colors.orange.shade50
                  : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _remainingNeeded == 0
                          ? Icons.check_circle
                          : isEnoughStock
                              ? Icons.warning
                              : Icons.error,
                      color: _remainingNeeded == 0
                          ? Colors.green
                          : isEnoughStock
                              ? Colors.orange
                              : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.itemName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('ต้องการ', widget.quantityNeeded, Colors.blue),
                    _buildSummaryItem('มีในสต็อก', totalAvailable,
                        isEnoughStock ? Colors.green : Colors.red),
                    _buildSummaryItem(
                      _remainingNeeded == 0
                          ? 'เลือกครบ'
                          : 'ขาด',
                      _remainingNeeded == 0
                          ? 0
                          : _remainingNeeded.abs(),
                      _remainingNeeded == 0 ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Batch list
        Text(
          widget.autoSelectFEFO
              ? 'ระบบเลือก batch ตาม FEFO (หมดอายุก่อนใช้ก่อน)'
              : 'เลือก batch ที่ต้องการใช้',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),

        ..._availableBatches.map((batch) {
          final batchId = batch['id'] as String;
          final batchNumber = batch['batch_number'] as String? ?? '-';
          final expiryDate = DateTime.parse(batch['expiry_date'] as String);
          final batchQty = (batch['quantity'] as num).toDouble();
          final warehouseName = batch['warehouse']?['name'] as String? ?? '-';
          final shelfCode = batch['shelf']?['code'] as String? ?? '-';

          // หาจำนวนที่เลือกไว้
          final selectedBatch = _selectedBatches.firstWhere(
            (b) => b['id'] == batchId,
            orElse: () => {},
          );
          final selectedQty = selectedBatch.isNotEmpty
              ? (selectedBatch['take_quantity'] as num).toDouble()
              : 0.0;

          final expiryColor = _getExpiryColor(expiryDate);
          final daysUntil = expiryDate.difference(DateTime.now()).inDays;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Expiry indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: expiryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${expiryDate.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: expiryColor,
                              ),
                            ),
                            Text(
                              ThaiDateUtils.formatThaiMonthShort(expiryDate),
                              style: TextStyle(fontSize: 9, color: expiryColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batchNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$warehouseName / $shelfCode',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      // Selection controls (if not auto-select)
                      if (!widget.autoSelectFEFO) ...[
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: selectedQty > 0
                              ? () {
                                  final newQty = selectedQty - 1;
                                  if (newQty < 1) {
                                    _toggleBatchSelection(batch, 0);
                                  } else {
                                    _toggleBatchSelection(batch, newQty);
                                  }
                                }
                              : null,
                          iconSize: 20,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${selectedQty.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: selectedQty < batchQty
                              ? () => _toggleBatchSelection(batch, selectedQty + 1)
                              : null,
                          iconSize: 20,
                        ),
                      ] else ...[
                        // Auto-selected display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedQty > 0
                                ? Colors.green.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            selectedQty > 0
                                ? 'ใช้ ${selectedQty.toStringAsFixed(selectedQty == selectedQty.roundToDouble() ? 0 : 1)}'
                                : 'ไม่ใช้',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selectedQty > 0 ? Colors.green.shade800 : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.scale, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'เหลือ ${batchQty.toStringAsFixed(batchQty == batchQty.roundToDouble() ? 0 : 1)} หน่วย',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: expiryColor),
                      const SizedBox(width: 4),
                      Text(
                        daysUntil < 0
                            ? 'หมดอายุแล้ว'
                            : daysUntil == 0
                                ? 'หมดอายุวันนี้'
                                : 'เหลือ $daysUntil วัน',
                        style: TextStyle(fontSize: 12, color: expiryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        // Error message if not enough
        if (!isEnoughStock)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'สต็อกไม่พอ ขาด ${(widget.quantityNeeded - totalAvailable).toStringAsFixed(1)} หน่วย',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
