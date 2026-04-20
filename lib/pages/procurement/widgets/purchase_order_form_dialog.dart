import 'package:flutter/material.dart';

/// Dialog helper สำหรับสร้าง/แก้ไขใบสั่งซื้อ สามารถใช้ซ้ำได้หลายแท็บ
Future<Map<String, dynamic>?> showPurchaseOrderFormDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> suppliers,
  required List<Map<String, dynamic>> products,
  required String title,
  required String submitLabel,
  String? initialSupplierId,
  String? initialNotes,
  String? initialExpectedDate,
  List<Map<String, dynamic>>? initialItems,
}) async {
  final formKey = GlobalKey<FormState>();
  final notesController = TextEditingController(text: initialNotes ?? '');
  String? supplierId = initialSupplierId;
  DateTime? expectedDate = initialExpectedDate != null ? DateTime.tryParse(initialExpectedDate) : null;
  final items = (initialItems ?? [])
      .map(
        (item) => {
          'product_id': item['product_id']?.toString(),
          'product_name': item['product_name']?.toString() ?? '',
          'quantity': (item['quantity'] as num?)?.toDouble() ?? 1,
          'unit_price': (item['unit_price'] as num?)?.toDouble() ?? 0,
        },
      )
      .toList();

  if (items.isEmpty) {
    items.add({'product_id': null, 'product_name': '', 'quantity': 1.0, 'unit_price': 0.0});
  }

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 620,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormSectionTitle('ข้อมูลหัวเอกสาร'),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: supplierId,
                                  decoration: const InputDecoration(
                                    labelText: 'ผู้ขาย *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: suppliers
                                      .map(
                                        (supplier) => DropdownMenuItem<String>(
                                          value: supplier['id']?.toString(),
                                          child: Text(supplier['name']?.toString() ?? '-'),
                                        ),
                                      )
                                      .toList(),
                                  validator: (value) => value == null || value.isEmpty ? 'กรุณาเลือกผู้ขาย' : null,
                                  onChanged: (value) => setDialogState(() => supplierId = value),
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: expectedDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() => expectedDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'วันที่คาดว่าจะรับ',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      expectedDate == null
                                          ? 'ไม่ระบุ'
                                          : '${expectedDate!.day}/${expectedDate!.month}/${expectedDate!.year + 543}',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: notesController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'หมายเหตุ',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFormSectionTitle('รายการสินค้า'),
                          ...items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final selectedProductId = item['product_id']?.toString();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            initialValue: selectedProductId,
                                            decoration: const InputDecoration(
                                              labelText: 'สินค้า',
                                              border: OutlineInputBorder(),
                                            ),
                                            isExpanded: true,
                                            items: products
                                                .map(
                                                  (product) => DropdownMenuItem<String>(
                                                    value: product['id']?.toString(),
                                                    child: Text(
                                                      product['name']?.toString() ?? '-',
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'เลือกสินค้า';
                                              }
                                              return null;
                                            },
                                            onChanged: (value) {
                                              final selectedProduct = products.firstWhere(
                                                (product) => product['id']?.toString() == value,
                                                orElse: () => <String, dynamic>{},
                                              );
                                              item['product_id'] = value;
                                              item['product_name'] = selectedProduct['name']?.toString() ?? '';
                                            },
                                          ),
                                        ),
                                        if (items.length > 1)
                                          IconButton(
                                            onPressed: () {
                                              setDialogState(() => items.removeAt(index));
                                            },
                                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                                            tooltip: 'ลบรายการ',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: (item['quantity'] as num?)?.toString() ?? '1',
                                            decoration: const InputDecoration(
                                              labelText: 'จำนวน',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            validator: (value) {
                                              final parsed = double.tryParse((value ?? '').trim());
                                              if (parsed == null || parsed <= 0) {
                                                return 'จำนวนต้องมากกว่า 0';
                                              }
                                              return null;
                                            },
                                            onChanged: (value) => item['quantity'] = double.tryParse(value) ?? 0,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: (item['unit_price'] as num?)?.toString() ?? '0',
                                            decoration: const InputDecoration(
                                              labelText: 'ราคาต่อหน่วย',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            validator: (value) {
                                              final parsed = double.tryParse((value ?? '').trim());
                                              if (parsed == null || parsed < 0) {
                                                return 'ราคาไม่ถูกต้อง';
                                              }
                                              return null;
                                            },
                                            onChanged: (value) => item['unit_price'] = double.tryParse(value) ?? 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                items.add({'product_id': null, 'product_name': '', 'quantity': 1.0, 'unit_price': 0.0});
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มรายการสินค้า'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Text(
                      'ตรวจสอบข้อมูลให้ครบก่อนกด $submitLabel',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                if (supplierId == null || supplierId!.isEmpty) {
                  return;
                }

                final sanitizedItems = items
                    .map((item) => {
                          'product_id': item['product_id']?.toString(),
                          'product_name': item['product_name']?.toString().trim() ?? '',
                          'quantity': (item['quantity'] as num?)?.toDouble() ?? 0,
                          'unit_price': (item['unit_price'] as num?)?.toDouble() ?? 0,
                        })
                    .toList();

                Navigator.of(context).pop({
                  'supplierId': supplierId,
                  'expectedDate': expectedDate,
                  'notes': notesController.text.trim(),
                  'items': sanitizedItems,
                });
              },
              child: Text(submitLabel),
            ),
          ],
        );
      },
    ),
  );

  notesController.dispose();
  return result;
}

Widget _buildFormSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
