import 'package:flutter/material.dart';

import '../../services/inventory_service.dart';

class TaxRulesAdminPage extends StatefulWidget {
  const TaxRulesAdminPage({super.key});

  @override
  State<TaxRulesAdminPage> createState() => _TaxRulesAdminPageState();
}

class _TaxRulesAdminPageState extends State<TaxRulesAdminPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _includeInactive = true;
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        InventoryService.getCategories(),
        InventoryService.getTaxRules(includeInactive: _includeInactive),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(results[0]);
        _rules = List<Map<String, dynamic>>.from(results[1]);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โหลดข้อมูลกฎภาษีไม่สำเร็จ'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRules {
    final query = _searchController.text.trim().toLowerCase();
    return _rules.where((rule) {
      if (_selectedCategoryId != null && rule['category_id'] != _selectedCategoryId) {
        return false;
      }

      if (query.isEmpty) return true;
      final ruleName = (rule['rule_name'] as String? ?? '').toLowerCase();
      final legalRef = (rule['legal_reference'] as String? ?? '').toLowerCase();
      final cat = rule['category'] as Map<String, dynamic>?;
      final catName = (cat?['name'] as String? ?? '').toLowerCase();
      final catCode = (cat?['code'] as String? ?? '').toLowerCase();
      return ruleName.contains(query) ||
          legalRef.contains(query) ||
          catName.contains(query) ||
          catCode.contains(query);
    }).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final text = value.toString();
    if (text.length >= 10) return text.substring(0, 10);
    return text;
  }

  String _itemTypeLabel(String type) {
    switch (type) {
      case 'product':
        return 'สินค้า';
      case 'ingredient':
        return 'วัตถุดิบ';
      default:
        return 'ทั้งสองประเภท';
    }
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ปิดใช้งานกฎภาษี'),
        content: Text('ต้องการปิดใช้งานกฎ "${rule['rule_name']}" หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ปิดใช้งาน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final success = await InventoryService.deactivateTaxRule(rule['id'] as String);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ปิดใช้งานกฎภาษีแล้ว'), backgroundColor: Colors.green),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ปิดใช้งานไม่สำเร็จ'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showRuleDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    String? categoryId = existing?['category_id'] as String?;
    String itemType = (existing?['item_type'] as String?) ?? 'both';
    bool isTaxExempt = existing?['is_tax_exempt'] as bool? ?? false;
    String taxInclusion = (existing?['tax_inclusion'] as String?) ?? 'included';
    final taxRateController = TextEditingController(
      text: ((existing?['tax_rate'] as num?)?.toDouble() ?? 7).toStringAsFixed(0),
    );
    final ruleNameController = TextEditingController(
      text: existing?['rule_name'] as String? ?? '',
    );
    final legalReferenceController = TextEditingController(
      text: existing?['legal_reference'] as String? ?? '',
    );
    final priorityController = TextEditingController(
      text: ((existing?['priority'] as num?)?.toInt() ?? 1).toString(),
    );
    bool requiresManualReview = existing?['requires_manual_review'] as bool? ?? true;
    bool isActive = existing?['is_active'] as bool? ?? true;

    DateTime effectiveFrom = DateTime.tryParse(existing?['effective_from']?.toString() ?? '') ?? DateTime.now();
    DateTime? effectiveTo =
        DateTime.tryParse(existing?['effective_to']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'แก้ไขกฎภาษี' : 'เพิ่มกฎภาษี'),
          content: SizedBox(
            width: 540,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'ประเภทสินค้า *',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'] as String,
                              child: Text('${c['code']} - ${c['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => categoryId = v),
                      validator: (v) => v == null ? 'กรุณาเลือกประเภทสินค้า' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: itemType,
                      decoration: const InputDecoration(
                        labelText: 'ใช้กับ *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'product', child: Text('สินค้า')),
                        DropdownMenuItem(value: 'ingredient', child: Text('วัตถุดิบ')),
                        DropdownMenuItem(value: 'both', child: Text('ทั้งสองประเภท')),
                      ],
                      onChanged: (v) => setDialogState(() => itemType = v ?? 'both'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('ยกเว้นภาษี'),
                      value: isTaxExempt,
                      onChanged: (v) => setDialogState(() {
                        isTaxExempt = v;
                        if (v) {
                          taxRateController.text = '0';
                          taxInclusion = 'excluded';
                        }
                      }),
                    ),
                    if (!isTaxExempt) ...[
                      TextFormField(
                        controller: taxRateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'อัตราภาษี (%) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final rate = double.tryParse((v ?? '').trim());
                          if (rate == null) return 'กรุณากรอกอัตราภาษี';
                          if (rate < 0 || rate > 100) return 'ต้องอยู่ระหว่าง 0-100';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: taxInclusion,
                        decoration: const InputDecoration(
                          labelText: 'รูปแบบราคา *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'included', child: Text('รวมภาษีแล้ว')),
                          DropdownMenuItem(value: 'excluded', child: Text('ยังไม่รวมภาษี')),
                        ],
                        onChanged: (v) => setDialogState(() => taxInclusion = v ?? 'included'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: ruleNameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อกฎ *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อกฎ' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: legalReferenceController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'อ้างอิงกฎหมาย',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priorityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ลำดับความสำคัญ (มากกว่า = ใช้ก่อน)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final p = int.tryParse((v ?? '').trim());
                        if (p == null || p < 1) return 'ต้องเป็นจำนวนเต็มตั้งแต่ 1';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('มีผลตั้งแต่: ${_formatDate(effectiveFrom)}'),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: effectiveFrom,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => effectiveFrom = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('สิ้นสุด (ถ้ามี): ${effectiveTo != null ? _formatDate(effectiveTo) : '-'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (effectiveTo != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setDialogState(() => effectiveTo = null),
                            ),
                          const Icon(Icons.event_busy),
                        ],
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: effectiveTo ?? effectiveFrom,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => effectiveTo = picked);
                        }
                      },
                    ),
                    if (effectiveTo != null && effectiveTo!.isBefore(effectiveFrom))
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'วันที่สิ้นสุดต้องไม่น้อยกว่าวันเริ่มต้น',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('ต้องตรวจสอบโดยผู้เชี่ยวชาญก่อนใช้งานจริง'),
                      value: requiresManualReview,
                      onChanged: (v) => setDialogState(() => requiresManualReview = v),
                    ),
                    if (isEdit)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('เปิดใช้งานกฎนี้'),
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (effectiveTo != null && effectiveTo!.isBefore(effectiveFrom)) return;

                final taxRate = isTaxExempt ? 0.0 : (double.tryParse(taxRateController.text.trim()) ?? 0.0);
                final priority = int.tryParse(priorityController.text.trim()) ?? 1;

                if (isEdit) {
                  final updated = await InventoryService.updateTaxRule(existing['id'] as String, {
                    'category_id': categoryId,
                    'item_type': itemType,
                    'is_tax_exempt': isTaxExempt,
                    'tax_rate': taxRate,
                    'tax_inclusion': taxInclusion,
                    'rule_name': ruleNameController.text.trim(),
                    'legal_reference': legalReferenceController.text.trim().isEmpty
                        ? null
                        : legalReferenceController.text.trim(),
                    'effective_from': effectiveFrom.toIso8601String().split('T').first,
                    'effective_to': effectiveTo?.toIso8601String().split('T').first,
                    'priority': priority,
                    'requires_manual_review': requiresManualReview,
                    'is_active': isActive,
                  });
                  if (updated != null && mounted) {
                    Navigator.pop(ctx, true);
                  }
                  return;
                }

                final created = await InventoryService.addTaxRule(
                  categoryId: categoryId!,
                  itemType: itemType,
                  isTaxExempt: isTaxExempt,
                  taxRate: taxRate,
                  taxInclusion: taxInclusion,
                  ruleName: ruleNameController.text.trim(),
                  legalReference: legalReferenceController.text.trim().isEmpty
                      ? null
                      : legalReferenceController.text.trim(),
                  effectiveFrom: effectiveFrom,
                  effectiveTo: effectiveTo,
                  priority: priority,
                  requiresManualReview: requiresManualReview,
                );
                if (created != null && mounted) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(isEdit ? 'บันทึกการแก้ไข' : 'สร้างกฎ'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'แก้ไขกฎภาษีสำเร็จ' : 'เพิ่มกฎภาษีสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = _filteredRules;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: จัดการกฎภาษี'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: const Text(
                          'คำเตือน: ระบบนี้เป็นตัวช่วยแนะนำภาษีตามกฎที่ตั้งไว้เท่านั้น ควรตรวจสอบเอกสารภาษีและข้อเท็จจริงธุรกรรมก่อนใช้งานจริง',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'ค้นหากฎ / ประเภท / อ้างอิง',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: _selectedCategoryId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'กรองตามประเภทสินค้า',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('ทั้งหมด'),
                                ),
                                ..._categories.map(
                                  (c) => DropdownMenuItem<String?>(
                                    value: c['id'] as String,
                                    child: Text('${c['code']} - ${c['name']}'),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _selectedCategoryId = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('รวมที่ปิดใช้งาน'),
                            selected: _includeInactive,
                            onSelected: (v) async {
                              setState(() => _includeInactive = v);
                              await _loadData();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: rules.isEmpty
                      ? const Center(child: Text('ไม่พบกฎภาษี'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: rules.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final rule = rules[index];
                            final category = rule['category'] as Map<String, dynamic>?;
                            final isActive = rule['is_active'] as bool? ?? false;
                            final isTaxExempt = rule['is_tax_exempt'] as bool? ?? false;
                            final taxRate = (rule['tax_rate'] as num?)?.toDouble() ?? 0.0;

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            rule['rule_name'] as String? ?? '-',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (!isActive)
                                          const Chip(
                                            label: Text('ปิดใช้งาน'),
                                            backgroundColor: Color(0xFFFFE0E0),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        Chip(label: Text('ประเภท: ${category?['code'] ?? '-'} ${category?['name'] ?? ''}')),
                                        Chip(label: Text('ใช้กับ: ${_itemTypeLabel(rule['item_type'] as String? ?? 'both')}')),
                                        Chip(
                                          label: Text(
                                            isTaxExempt
                                                ? 'ยกเว้นภาษี'
                                                : 'VAT ${taxRate.toStringAsFixed(taxRate == taxRate.roundToDouble() ? 0 : 2)}%',
                                          ),
                                        ),
                                        Chip(label: Text('ราคา: ${rule['tax_inclusion'] == 'included' ? 'รวมภาษีแล้ว' : 'ยังไม่รวมภาษี'}')),
                                        Chip(label: Text('Priority: ${rule['priority'] ?? 1}')),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('มีผล: ${_formatDate(rule['effective_from'])} ถึง ${_formatDate(rule['effective_to'])}'),
                                    if ((rule['legal_reference'] as String?)?.isNotEmpty == true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'อ้างอิง: ${rule['legal_reference']}',
                                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _showRuleDialog(existing: rule),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('แก้ไข'),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isActive)
                                          TextButton.icon(
                                            onPressed: () => _confirmDeactivate(rule),
                                            icon: const Icon(Icons.block, color: Colors.red),
                                            label: const Text('ปิดใช้งาน', style: TextStyle(color: Colors.red)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRuleDialog(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มกฎภาษี'),
      ),
    );
  }
}
