import 'package:flutter/material.dart';

import '../../../models/pos_discount_model.dart';
import '../../../models/pos_promotion_model.dart';
import '../../../models/user_group_model.dart';
import '../../../services/pos_promotion_service.dart';
import '../../../theme/app_design_system.dart';
import '../../../utils/date_picker_helper.dart';

class PromotionFormDialog extends StatefulWidget {
  const PromotionFormDialog({
    super.key,
    required this.title,
    this.existing,
    required this.coupons,
    required this.userGroups,
    required this.products,
    required this.onSubmit,
  });

  final String title;
  final PosPromotion? existing;
  final List<PosDiscount> coupons;
  final List<UserGroup> userGroups;
  final List<Map<String, dynamic>> products;
  final Future<void> Function(PromotionFormDialogResult result) onSubmit;

  @override
  State<PromotionFormDialog> createState() => _PromotionFormDialogState();
}

class PromotionFormDialogResult {
  const PromotionFormDialogResult({
    required this.name,
    required this.description,
    required this.promotionType,
    this.discountId,
    this.applicableUserGroupIds = const [],
    required this.isActive,
    this.startAt,
    this.endAt,
    this.items = const [],
  });

  final String name;
  final String description;
  final String promotionType;
  final String? discountId;
  final List<String> applicableUserGroupIds;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<Map<String, dynamic>> items;
}

class _PromotionFormDialogState extends State<PromotionFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _searchCtrl;
  late final TextEditingController _qtyCtrl;

  String _promotionType = 'bundle';
  String? _selectedDiscountId;
  List<String> _selectedUserGroupIds = [];
  bool _isActive = true;
  DateTime? _startAt;
  DateTime? _endAt;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSaving = false;
  String? _errorMsg;

  List<Map<String, dynamic>> get _products => widget.products;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _searchCtrl = TextEditingController();
    _qtyCtrl = TextEditingController(text: '1');
    _promotionType = existing?.promotionType ?? 'bundle';
    _selectedDiscountId = existing?.discountId;
    _selectedUserGroupIds = List<String>.from(existing?.applicableUserGroupIds ?? const []);
    _isActive = existing?.isActive ?? true;
    _startAt = existing?.startAt;
    _endAt = existing?.endAt;
    if (existing != null) {
      _loadExistingItems(existing);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingItems(PosPromotion existing) async {
    final loadedItems = await PosPromotionService.getPromotionItems(existing.id);
    if (!mounted) return;
    setState(() {
      _items = loadedItems.map((item) {
        final product = _products.firstWhere(
          (p) => p['id']?.toString() == item.productId,
          orElse: () => {},
        );
        return {
          'product_id': item.productId,
          'name': product['name']?.toString() ?? 'สินค้าเดิม',
          'quantity': item.quantityRequired,
        };
      }).toList();
    });
  }

  String _formatDate(DateTime date) {
    final months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showBuddhistDatePicker(
      context: context,
      initialDate: (isStart ? _startAt : _endAt) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  void _searchProducts(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _searchResults = _products
          .where((p) => ((p['name'] as String?) ?? '').toLowerCase().contains(q))
          .take(6)
          .toList();
    });
  }

  void _addItem(Map<String, dynamic> product) {
    final productId = product['id'].toString();
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    setState(() {
      final existingIndex = _items.indexWhere((i) => i['product_id'].toString() == productId);
      if (existingIndex >= 0) {
        final currentQty = (_items[existingIndex]['quantity'] as int?) ?? 1;
        _items[existingIndex]['quantity'] = currentQty + qty;
      } else {
        _items.add({'product_id': productId, 'name': product['name'], 'quantity': qty});
      }
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  Future<void> _handleSubmit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'กรุณากรอกชื่อโปรโมชั่น');
      return;
    }
    setState(() {
      _errorMsg = null;
      _isSaving = true;
    });

    final result = PromotionFormDialogResult(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      promotionType: _promotionType,
      discountId: _selectedDiscountId,
      applicableUserGroupIds: List<String>.from(_selectedUserGroupIds),
      isActive: _isActive,
      startAt: _startAt,
      endAt: _endAt,
      items: List<Map<String, dynamic>>.from(_items),
    );

    try {
      await widget.onSubmit(result);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupons = widget.coupons;
    final userGroups = widget.userGroups;
    final showItems = _promotionType == 'bundle' || _promotionType == 'buy_x_get_y';

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMsg != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                  ]),
                ),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อโปรโมชั่น *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _promotionType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'ประเภทโปรโมชั่น', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'bundle', child: Text('ชุดสินค้า (Bundle)')),
                  DropdownMenuItem(value: 'seasonal', child: Text('ตามฤดูกาล (Seasonal)')),
                  DropdownMenuItem(value: 'buy_x_get_y', child: Text('ซื้อ X แถม Y')),
                ],
                onChanged: (v) => setState(() {
                  _promotionType = v ?? 'bundle';
                  _items.clear();
                  _searchResults = [];
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _selectedDiscountId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'เชื่อมส่วนลด',
                  border: const OutlineInputBorder(),
                  helperText: coupons.isEmpty ? 'ยังไม่มีส่วนลด — สร้างที่แท็บ "คูปอง" ก่อน' : null,
                  prefixIcon: const Icon(Icons.local_offer, size: 18),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('ไม่มีส่วนลด')),
                  ...coupons.map((d) {
                    final tag = d.discountType == 'percentage' ? '${d.value.toStringAsFixed(0)}%' : '฿${d.value.toStringAsFixed(0)}';
                    final scopeLabel = {'order': 'ทั้งบิล', 'item': 'รายการ', 'category': 'หมวดหมู่'}[d.scope] ?? d.scope;
                    return DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text('${d.name} ($tag · $scopeLabel)', overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedDiscountId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'กลุ่มผู้ใช้ที่ใช้โปรโมชันได้',
                  border: const OutlineInputBorder(),
                  hintText: 'ไม่เลือก = ใช้ได้ทุกกลุ่ม',
                  suffixIcon: _selectedUserGroupIds.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('${_selectedUserGroupIds.length} กลุ่ม', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                      )
                    : null,
                ),
                items: [
                  const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                  const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ใช้ได้ทุกกลุ่ม')),
                  const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                  ...userGroups.map((group) {
                    final isSelected = _selectedUserGroupIds.contains(group.id);
                    return DropdownMenuItem<String>(
                      value: group.id,
                      child: Row(children: [
                        Checkbox(value: isSelected, onChanged: null),
                        const SizedBox(width: 8),
                        Expanded(child: Text(group.groupName)),
                      ]),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value == '__select_all__') {
                      _selectedUserGroupIds = userGroups.map((g) => g.id).toList();
                    } else if (value == '__clear_all__') {
                      _selectedUserGroupIds.clear();
                    } else if (value != null && value.isNotEmpty) {
                      if (_selectedUserGroupIds.contains(value)) {
                        _selectedUserGroupIds.remove(value);
                      } else {
                        _selectedUserGroupIds.add(value);
                      }
                    }
                  });
                },
              ),
              if (_selectedUserGroupIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedUserGroupIds.map((groupId) {
                    final group = userGroups.firstWhere(
                      (g) => g.id == groupId,
                      orElse: () => UserGroup(id: groupId, groupName: 'กลุ่มเดิม'),
                    );
                    return Chip(
                      label: Text(group.groupName, style: const TextStyle(fontSize: 10)),
                      onDeleted: () => setState(() => _selectedUserGroupIds.remove(groupId)),
                      backgroundColor: AppDesignSystem.primary.withOpacity(0.2),
                      deleteIcon: const Icon(Icons.close, size: 14),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Text('ช่วงเวลา', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(_startAt != null ? _formatDate(_startAt!) : 'วันเริ่มต้น', style: const TextStyle(fontSize: 11)),
                        onPressed: () => _pickDate(true),
                        style: OutlinedButton.styleFrom(foregroundColor: _startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                      ),
                    ),
                    if (_startAt != null)
                      InkWell(onTap: () => setState(() => _startAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                  ]),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 14),
                        label: Text(_endAt != null ? _formatDate(_endAt!) : 'วันสิ้นสุด', style: const TextStyle(fontSize: 11)),
                        onPressed: () => _pickDate(false),
                        style: OutlinedButton.styleFrom(foregroundColor: _endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                      ),
                    ),
                    if (_endAt != null)
                      InkWell(onTap: () => setState(() => _endAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                  ]),
                ),
              ]),
              if (showItems) ...[
                const SizedBox(height: 14),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2, size: 16, color: AppDesignSystem.secondary),
                      const SizedBox(width: 6),
                      Text(
                        _promotionType == 'bundle' ? 'สินค้าที่ร่วมโปรโมชั่น' : 'สินค้าที่ต้องซื้อ (X)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ]),
                    Text('${_items.length} รายการ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ค้นหาสินค้าจากคลัง',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: _searchProducts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder(), isDense: true),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppDesignSystem.border),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, i) {
                        final p = _searchResults[i];
                        final catName = p['category']?['name'] as String? ?? '';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.inventory_2, size: 16, color: AppDesignSystem.secondary),
                          title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13)),
                          subtitle: catName.isNotEmpty ? Text(catName, style: const TextStyle(fontSize: 11)) : null,
                          trailing: const Icon(Icons.add_circle_outline, size: 18, color: AppDesignSystem.primary),
                          onTap: () => _addItem(p),
                        );
                      },
                    ),
                  ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._items.asMap().entries.map((e) {
                    final item = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.selectedSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDesignSystem.primary.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.inventory_2, size: 14, color: AppDesignSystem.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item['name'] as String, style: const TextStyle(fontSize: 13))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text('×${item['quantity']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _items.removeAt(e.key)),
                          child: const Icon(Icons.close, size: 16, color: Colors.red),
                        ),
                      ]),
                    );
                  }),
                ],
                if (_products.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('ไม่พบสินค้าในคลัง — กรุณาเพิ่มสินค้าก่อน', style: TextStyle(fontSize: 12))),
                    ]),
                  ),
              ],
              SwitchListTile(
                title: Text('เปิดใช้งาน', style: TextStyle(fontSize: 13, color: _isActive ? AppDesignSystem.primary : Colors.grey)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppDesignSystem.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSubmit,
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.existing == null ? 'เพิ่ม' : 'บันทึก'),
        ),
      ],
    );
  }
}
