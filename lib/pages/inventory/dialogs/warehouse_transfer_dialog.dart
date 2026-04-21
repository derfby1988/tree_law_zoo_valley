import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_design_system.dart';

/// Dialog สำหรับโอนสินค้าระหว่างคลัง
class WarehouseTransferDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final double currentQuantity;
  final String fromWarehouseId;
  final String fromWarehouseName;
  final VoidCallback? onSuccess;

  const WarehouseTransferDialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.currentQuantity,
    required this.fromWarehouseId,
    required this.fromWarehouseName,
    this.onSuccess,
  });

  @override
  State<WarehouseTransferDialog> createState() => _WarehouseTransferDialogState();
}

class _WarehouseTransferDialogState extends State<WarehouseTransferDialog> {
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _toWarehouseId;
  String? _toWarehouseName;
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = false;
  bool _isLoadingWarehouses = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final warehouses = await InventoryService.getWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses
            .where((w) => w['id']?.toString() != widget.fromWarehouseId)
            .toList();
        _isLoadingWarehouses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingWarehouses = false);
    }
  }

  Future<void> _transfer() async {
    if (_toWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกคลังปลายทาง')),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุจำนวนที่ถูกต้อง')),
      );
      return;
    }

    if (quantity > widget.currentQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จำนวนเกินสต็อกที่มี')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = PermissionService.currentUserId;
      final success = await InventoryService.transferBetweenWarehouses(
        productId: widget.productId,
        quantity: quantity,
        fromWarehouseId: widget.fromWarehouseId,
        toWarehouseId: _toWarehouseId!,
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
        transferredBy: userId,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('โอนสินค้าสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSuccess?.call();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถโอนสินค้า')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'โอนสินค้าระหว่างคลัง',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.productName,
                style: TextStyle(
                  fontSize: 14,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // From warehouse
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignSystem.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คลังต้นทาง',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.fromWarehouseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'สต็อกที่มี: ${widget.currentQuantity.toStringAsFixed(2)} หน่วย',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // To warehouse
              Text(
                'คลังปลายทาง',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoadingWarehouses)
                const Center(child: CircularProgressIndicator())
              else if (_warehouses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ไม่มีคลังอื่นให้เลือก',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _toWarehouseId,
                  decoration: InputDecoration(
                    labelText: 'เลือกคลัง',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _warehouses.map((w) {
                    return DropdownMenuItem(
                      value: w['id']?.toString(),
                      child: Text(w['name']?.toString() ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _toWarehouseId = value;
                      _toWarehouseName = _warehouses
                          .firstWhere(
                            (w) => w['id']?.toString() == value,
                            orElse: () => {},
                          )['name']
                          ?.toString();
                    });
                  },
                ),
              const SizedBox(height: 16),

              // Quantity
              Text(
                'จำนวนที่โอน',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'จำนวน',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixText: 'หน่วย',
                ),
              ),
              const SizedBox(height: 16),

              // Reason
              Text(
                'เหตุผล (ไม่บังคับ)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'หมายเหตุ',
                  hintText: 'เช่น: ปรับสมดุลสต็อก',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _transfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('โอนสินค้า'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
