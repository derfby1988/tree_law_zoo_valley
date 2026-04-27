import 'package:flutter/material.dart';
import '../services/inventory_service.dart';
import '../utils/thai_date_utils.dart';

/// Widget แสดงรายการ batch สำหรับสินค้าหรือวัตถุดิบ
/// รองรับการแสดงผล, แก้ไขวันหมดอายุ, mark as expired
class BatchListWidget extends StatefulWidget {
  final String itemType; // 'product' | 'ingredient'
  final String itemId;
  final String itemName;
  final String? warehouseId;
  final String? shelfId;
  final bool showActions;
  final bool allowExpiryEdit;
  final bool allowDispose;
  final VoidCallback? onBatchChanged;

  const BatchListWidget({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    this.warehouseId,
    this.shelfId,
    this.showActions = true,
    this.allowExpiryEdit = true,
    this.allowDispose = true,
    this.onBatchChanged,
  });

  @override
  State<BatchListWidget> createState() => _BatchListWidgetState();
}

class _BatchListWidgetState extends State<BatchListWidget> {
  List<Map<String, dynamic>> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final batches = await InventoryService.getBatches(
        productId: widget.itemType == 'product' ? widget.itemId : null,
        ingredientId: widget.itemType == 'ingredient' ? widget.itemId : null,
        itemType: widget.itemType,
        warehouseId: widget.warehouseId,
        shelfId: widget.shelfId,
        isActive: true,
      );
      if (mounted) {
        setState(() {
          _batches = batches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showExpiryEditDialog(Map<String, dynamic> batch) async {
    final batchId = batch['id'] as String;
    final currentExpiry = DateTime.parse(batch['expiry_date'] as String);
    final reasonController = TextEditingController();
    DateTime selectedDate = currentExpiry;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('แก้ไขวันหมดอายุ: ${batch['batch_number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'วันหมดอายุใหม่: ${ThaiDateUtils.formatBuddhistDate(selectedDate)}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await ThaiDateUtils.showThaiDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 1825)),
                );
                if (date != null) {
                  selectedDate = date;
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'เหตุผลการเปลี่ยนแปลง',
                border: OutlineInputBorder(),
                hintText: 'เช่น วันที่ผิดพลาดตอนรับสินค้า',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await InventoryService.updateBatchExpiry(
        batchId: batchId,
        newExpiryDate: selectedDate,
        reason: reasonController.text.isNotEmpty ? reasonController.text : null,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตวันหมดอายุสำเร็จ'), backgroundColor: Colors.green),
        );
        _loadBatches();
        widget.onBatchChanged?.call();
      }
    }
  }

  Future<void> _showDisposeDialog(Map<String, dynamic> batch) async {
    final batchId = batch['id'] as String;
    final batchNumber = batch['batch_number'] as String;
    final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ทิ้ง batch $batchNumber'),
        content: Text('ยืนยันการทิ้ง $quantity หน่วย ของ ${widget.itemName}?\n\nหมายเหตุ: รายการนี้จะถูกบันทึกว่าหมดอายุและถูกทิ้ง'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยันทิ้ง'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await InventoryService.markBatchAsExpired(
        batchId: batchId,
        disposed: true,
        notes: 'ทิ้ง batch หมดอายุ',
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทิ้งสำเร็จ'), backgroundColor: Colors.green),
        );
        _loadBatches();
        widget.onBatchChanged?.call();
      }
    }
  }

  Future<void> _showBatchLogs(Map<String, dynamic> batch) async {
    final batchId = batch['id'] as String;
    final logs = await InventoryService.getBatchLogs(batchId: batchId);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ประวัติ: ${batch['batch_number']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: logs.isEmpty
              ? const Text('ไม่มีประวัติ')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final actionType = log['action_type'] as String?;
                    final qtyBefore = (log['quantity_before'] as num?)?.toDouble() ?? 0;
                    final qtyAfter = (log['quantity_after'] as num?)?.toDouble() ?? 0;
                    final performedAt = log['performed_at'] as String?;
                    final notes = log['notes'] as String?;

                    Color actionColor;
                    IconData actionIcon;
                    String actionLabel;

                    switch (actionType) {
                      case 'receive':
                        actionColor = Colors.green;
                        actionIcon = Icons.download;
                        actionLabel = 'รับเข้า';
                        break;
                      case 'consume':
                        actionColor = Colors.orange;
                        actionIcon = Icons.remove_circle;
                        actionLabel = 'ใช้ไป';
                        break;
                      case 'adjust_count':
                        actionColor = Colors.blue;
                        actionIcon = Icons.edit;
                        actionLabel = 'ปรับนับ';
                        break;
                      case 'expiry_change':
                        actionColor = Colors.purple;
                        actionIcon = Icons.date_range;
                        actionLabel = 'เปลี่ยนวันหมด';
                        break;
                      case 'dispose':
                        actionColor = Colors.red;
                        actionIcon = Icons.delete;
                        actionLabel = 'ทิ้ง';
                        break;
                      default:
                        actionColor = Colors.grey;
                        actionIcon = Icons.info;
                        actionLabel = actionType ?? 'อื่นๆ';
                    }

                    return ListTile(
                      leading: Icon(actionIcon, color: actionColor),
                      title: Text(actionLabel),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (qtyBefore != 0 || qtyAfter != 0)
                            Text('$qtyBefore → $qtyAfter'),
                          if (notes != null && notes.isNotEmpty)
                            Text(notes, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      trailing: performedAt != null
                          ? Text(
                              ThaiDateUtils.formatThaiDateTimeShort(DateTime.parse(performedAt)),
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Color _getExpiryColor(DateTime expiryDate) {
    final days = expiryDate.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red;
    if (days <= 3) return Colors.red.shade300;
    if (days <= 7) return Colors.orange;
    return Colors.green;
  }

  String _getExpiryText(DateTime expiryDate) {
    final days = expiryDate.difference(DateTime.now()).inDays;
    final dateStr = ThaiDateUtils.formatBuddhistDate(expiryDate);
    
    if (days < 0) return 'หมดอายุแล้ว ($dateStr)';
    if (days == 0) return 'หมดอายุวันนี้ ($dateStr)';
    if (days <= 3) return 'เหลือ $days วัน ($dateStr)';
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_batches.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'ไม่มี batch',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'รายการ batch (${_batches.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: _loadBatches,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('รีเฟรช', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._batches.map((batch) {
          final batchNumber = batch['batch_number'] as String? ?? '-';
          final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0;
          final expiryDate = DateTime.parse(batch['expiry_date'] as String);
          final warehouseName = batch['warehouse']?['name'] as String? ?? '-';
          final shelfCode = batch['shelf']?['code'] as String? ?? '-';
          final unitCost = (batch['unit_cost'] as num?)?.toDouble();
          final supplierName = batch['supplier_name'] as String?;
          final isExpired = batch['is_expired'] == true;
          final isDisposed = batch['is_disposed'] == true;

          final expiryColor = _getExpiryColor(expiryDate);
          final expiryText = _getExpiryText(expiryDate);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: expiryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: expiryColor.withOpacity(0.3)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${expiryDate.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: expiryColor,
                        ),
                      ),
                      Text(
                        ThaiDateUtils.formatThaiMonthShort(expiryDate),
                        style: TextStyle(fontSize: 10, color: expiryColor),
                      ),
                    ],
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      batchNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('หมดอายุ', style: TextStyle(fontSize: 10, color: Colors.red)),
                    ),
                  if (isDisposed)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ทิ้งแล้ว', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.scale, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1)} หน่วย',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      if (unitCost != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.attach_money, size: 14, color: Colors.grey.shade600),
                        Text(
                          '${unitCost.toStringAsFixed(2)}/หน่วย',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '$warehouseName / $shelfCode',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiryText,
                    style: TextStyle(
                      fontSize: 12,
                      color: expiryColor,
                      fontWeight: daysUntilExpiry(expiryDate) <= 7 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (supplierName != null && supplierName.isNotEmpty)
                    Text(
                      'ผู้จำหน่าย: $supplierName',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                ],
              ),
              trailing: widget.showActions
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        switch (value) {
                          case 'logs':
                            await _showBatchLogs(batch);
                            break;
                          case 'edit_expiry':
                            if (widget.allowExpiryEdit) {
                              await _showExpiryEditDialog(batch);
                            }
                            break;
                          case 'dispose':
                            if (widget.allowDispose && !isDisposed) {
                              await _showDisposeDialog(batch);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'logs',
                          child: ListTile(
                            leading: Icon(Icons.history),
                            title: Text('ประวัติ'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (widget.allowExpiryEdit && !isDisposed)
                          const PopupMenuItem(
                            value: 'edit_expiry',
                            child: ListTile(
                              leading: Icon(Icons.edit_calendar, color: Colors.blue),
                              title: Text('แก้ไขวันหมดอายุ'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (widget.allowDispose && !isDisposed)
                          const PopupMenuItem(
                            value: 'dispose',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red),
                              title: Text('ทิ้ง'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    )
                  : null,
            ),
          );
        }).toList(),
      ],
    );
  }

  int daysUntilExpiry(DateTime expiryDate) {
    return expiryDate.difference(DateTime.now()).inDays;
  }
}
