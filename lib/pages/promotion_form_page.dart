import 'package:flutter/material.dart';
import '../models/pos_discount_model.dart';
import '../models/pos_promotion_model.dart';
import '../models/user_group_model.dart';
import '../services/pos_discount_service.dart';
import '../services/pos_promotion_service.dart';
import '../services/user_group_service.dart';
// import '../utils/buddhist_date_converter.dart';  // TODO: สร้างไฟล์นี้หรือใช้ date_picker_helper แทน
import '../theme/app_design_system.dart';
import 'promotion_product_picker_page.dart';
import '../services/inventory_service.dart';

class PromotionFormPage extends StatefulWidget {
  final String? promotionId;
  final String? initialName;
  final String? initialDescription;
  final double? initialDiscountPercent;
  final List<String>? initialSelectedProducts;

  const PromotionFormPage({
    super.key, 
    this.promotionId,
    this.initialName,
    this.initialDescription,
    this.initialDiscountPercent,
    this.initialSelectedProducts,
  });

  @override
  State<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends State<PromotionFormPage> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  // State
  String _promotionType = 'bundle';
  String? _selectedDiscountId;
  DateTime? _startAt;
  DateTime? _endAt;
  List<String> _selectedUserGroupIds = [];
  List<Map<String, dynamic>> _selectedProducts = [];
  bool _isActive = true;
  bool _isLoading = false;
  bool _isSaving = false;
  // Phase 4: Availability & Procurement Rules
  bool _requireInStock = false;
  bool _requireSufficientIngredients = false;
  bool _includePendingProcurement = false;

  // Data
  List<PosDiscount> _coupons = [];
  List<UserGroup> _userGroups = [];
  PosPromotion? _existingPromotion;

  @override
  void initState() {
    super.initState();
    // Initialize with initial values if provided
    if (widget.initialName != null) {
      _nameCtrl.text = widget.initialName!;
    }
    if (widget.initialDescription != null) {
      _descCtrl.text = widget.initialDescription!;
    }
    if (widget.initialSelectedProducts != null) {
      _selectedProducts = widget.initialSelectedProducts!.map((id) => {
        'id': id,
        'product_id': id,
        'quantity': 1,
      }).toList();
    }
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load coupons for discount linker
      _coupons = await PosDiscountService.getAllDiscounts();
      
      // Load user groups
      _userGroups = await UserGroupService.getAllGroups();

      // Load existing promotion if editing
      if (widget.promotionId != null) {
        await _loadExistingPromotion();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExistingPromotion() async {
    try {
      _existingPromotion = await PosPromotionService.getPromotionById(widget.promotionId!);
      
      if (_existingPromotion == null) {
        throw Exception('Promotion not found');
      }

      // Populate fields
      _nameCtrl.text = _existingPromotion!.name;
      _descCtrl.text = _existingPromotion!.description ?? '';
      _promotionType = _existingPromotion!.promotionType;
      _selectedDiscountId = _existingPromotion!.discountId;
      _startAt = _existingPromotion!.startAt;
      _endAt = _existingPromotion!.endAt;
      _isActive = _existingPromotion!.isActive;
      _selectedUserGroupIds = _existingPromotion!.applicableUserGroupIds;
      // Phase 4: Load availability rules
      _requireInStock = _existingPromotion!.requireInStock;
      _requireSufficientIngredients = _existingPromotion!.requireSufficientIngredients;
      _includePendingProcurement = _existingPromotion!.includePendingProcurement;
      
      // Load promotion items (selected products)
      final promotionItems = await PosPromotionService.getPromotionItems(widget.promotionId!);
      
      // Fetch product details to get actual names
      final productIds = promotionItems.map((item) => item.productId).toList();
      final productDetails = await InventoryService.getProducts();
      final productMap = <String, Map<String, dynamic>>{};
      for (final product in productDetails) {
        final id = product['id']?.toString();
        if (id != null) {
          productMap[id] = product;
        }
      }
      
      _selectedProducts = promotionItems.map((item) {
        final product = productMap[item.productId];
        return {
          'id': item.productId,
          'name': product?['name'] ?? 'สินค้า ID: ${item.productId}',
          'quantity': item.quantityRequired,
        };
      }).toList();
      
      // Update date controllers
      if (_startAt != null) {
        _startDateCtrl.text = _formatDate(_startAt!);
      }
      if (_endAt != null) {
        _endDateCtrl.text = _formatDate(_endAt!);
      }
    } catch (e) {
      debugPrint('Error loading existing promotion: $e');
    }
  }

  String _formatDate(DateTime date) {
    final buddhistYear = date.year + 543;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$buddhistYear';
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startAt : _endAt) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startAt = picked;
          _startDateCtrl.text = _formatDate(picked);
        } else {
          _endAt = picked;
          _endDateCtrl.text = _formatDate(picked);
        }
      });
    }
  }

  Future<void> _navigateToProductPicker() async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => PromotionProductPickerPage(
          initiallySelectedProducts: _selectedProducts,
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedProducts = result);
    }
  }

  Future<void> _save() async {
    // Validation: ชื่อต้องไม่ว่าง
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('กรุณากรอกชื่อโปรโมชั่น');
      return;
    }

    // Validation: วันเริ่มต้นต้องไม่เกินวันสิ้นสุด
    if (_startAt != null && _endAt != null && _startAt!.isAfter(_endAt!)) {
      _showError('วันเริ่มต้นต้องไม่เกินวันสิ้นสุด');
      return;
    }

    // Validation: ถ้าเป็น bundle หรือ buy_x_get_y ต้องมีสินค้าอย่างน้อย 1 รายการ
    if ((_promotionType == 'bundle' || _promotionType == 'buy_x_get_y') && _selectedProducts.isEmpty) {
      _showError('กรุณาเลือกสินค้าอย่างน้อย 1 รายการ');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final promotionData = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'promotion_type': _promotionType,
        'discount_id': _selectedDiscountId,
        'applicable_user_group_ids': _selectedUserGroupIds.isEmpty ? null : _selectedUserGroupIds,
        'start_at': _startAt?.toIso8601String(),
        'end_at': _endAt?.toIso8601String(),
        'is_active': _isActive,
        'lifecycle_status': _isActive ? 'active' : 'paused',
        'targeting_mode': 'manual',
        'applicable_channels': const <String>[],
      };

      if (widget.promotionId == null) {
        // Create new promotion
        final result = await PosPromotionService.addPromotion(
          name: promotionData['name'] as String,
          description: promotionData['description'] as String?,
          promotionType: _promotionType,
          discountId: _selectedDiscountId,
          applicableUserGroupIds: _selectedUserGroupIds,
          isActive: _isActive,
          startAt: _startAt,
          endAt: _endAt,
          // Phase 4: Availability fields
          requireInStock: _requireInStock,
          requireSufficientIngredients: _requireSufficientIngredients,
          includePendingProcurement: _includePendingProcurement,
        );

        if (result == null) {
          throw Exception('ไม่สามารถสร้างโปรโมชั่นได้');
        }

        // Add promotion items (selected products)
        for (final product in _selectedProducts) {
          final productId = product['id']?.toString() ?? '';
          if (productId.isNotEmpty) {
            await PosPromotionService.addPromotionItem(
              promotionId: result.id,
              productId: productId,
              quantityRequired: 1,
            );
          }
        }
      } else {
        // Update existing promotion
        final result = await PosPromotionService.updatePromotion(
          id: widget.promotionId!,
          name: promotionData['name'] as String,
          description: promotionData['description'] as String?,
          promotionType: _promotionType,
          discountId: _selectedDiscountId,
          applicableUserGroupIds: _selectedUserGroupIds,
          isActive: _isActive,
          startAt: _startAt,
          endAt: _endAt,
          // Phase 4: Availability fields
          requireInStock: _requireInStock,
          requireSufficientIngredients: _requireSufficientIngredients,
          includePendingProcurement: _includePendingProcurement,
        );

        if (result == null) {
          throw Exception('ไม่สามารถอัปเดตโปรโมชั่นได้');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.promotionId == null ? 'เพิ่มโปรโมชั่นสำเร็จ' : 'บันทึกโปรโมชั่นสำเร็จ'),
            backgroundColor: AppDesignSystem.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showError('เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppDesignSystem.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppDesignSystem.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.promotionId == null ? 'เพิ่มโปรโมชั่น' : 'แก้ไขโปรโมชั่น',
          style: const TextStyle(
            color: AppDesignSystem.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info Card
                  _buildCard(
                    title: 'ข้อมูลพื้นฐาน',
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อโปรโมชั่น *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_offer_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'คำอธิบาย',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Promotion Type Card
                  _buildCard(
                    title: 'ประเภทโปรโมชั่น',
                    children: [
                      _buildRadioTile(
                        title: 'ชุดสินค้า (Bundle)',
                        subtitle: 'รวมสินค้าหลายรายการในโปรเดียว',
                        value: 'bundle',
                        groupValue: _promotionType,
                        onChanged: (v) => setState(() => _promotionType = v!),
                        icon: Icons.inventory_2_outlined,
                      ),
                      _buildRadioTile(
                        title: 'ตามฤดูกาล (Seasonal)',
                        subtitle: 'โปรโมชั่นช่วงเวลาพิเศษ',
                        value: 'seasonal',
                        groupValue: _promotionType,
                        onChanged: (v) => setState(() => _promotionType = v!),
                        icon: Icons.calendar_today_outlined,
                      ),
                      _buildRadioTile(
                        title: 'ซื้อ X แถม Y',
                        subtitle: 'ซื้อสินค้าครบจำนวน แถมสินค้าฟรี',
                        value: 'buy_x_get_y',
                        groupValue: _promotionType,
                        onChanged: (v) => setState(() => _promotionType = v!),
                        icon: Icons.card_giftcard_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Linked Discount Card
                  _buildCard(
                    title: 'เชื่อมกับส่วนลด',
                    children: [
                      if (_coupons.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ยังไม่มีส่วนลด - สร้างที่แท็บ "คูปอง" ก่อน',
                                  style: TextStyle(color: Colors.orange[800], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String?>(
                          value: _selectedDiscountId,
                          decoration: const InputDecoration(
                            labelText: 'เลือกส่วนลด',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_offer, size: 18),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('ไม่เชื่อมกับส่วนลด'),
                            ),
                            ..._coupons.map((d) {
                              final tag = d.discountType == 'percentage'
                                  ? '${d.value.toStringAsFixed(0)}%'
                                  : '฿${d.value.toStringAsFixed(0)}';
                              return DropdownMenuItem<String?>(
                                value: d.id,
                                child: Text('${d.name} ($tag)', overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() => _selectedDiscountId = v),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // User Groups Card
                  _buildCard(
                    title: 'กลุ่มผู้ใช้ที่ใช้ได้',
                    subtitle: 'ไม่เลือก = ใช้ได้ทุกกลุ่ม',
                    children: [
                      _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _userGroups.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'ไม่พบกลุ่มผู้ใช้ในระบบ กรุณาตรวจสอบตาราง user_groups',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.orange[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ..._userGroups.map((group) {
                                      final isSelected = _selectedUserGroupIds.contains(group.id);
                                      return FilterChip(
                                        selected: isSelected,
                                        label: Text(group.groupName),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedUserGroupIds.add(group.id);
                                            } else {
                                              _selectedUserGroupIds.remove(group.id);
                                            }
                                          });
                                        },
                                        selectedColor: AppDesignSystem.primary.withOpacity(0.2),
                                        checkmarkColor: AppDesignSystem.primary,
                                      );
                                    }),
                                  ],
                                ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Date Range Card
                  _buildCard(
                    title: 'ช่วงเวลา',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startDateCtrl,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'วันเริ่มต้น',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                suffixIcon: _startAt != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() {
                                          _startAt = null;
                                          _startDateCtrl.clear();
                                        }),
                                      )
                                    : null,
                              ),
                              onTap: () => _pickDate(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _endDateCtrl,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'วันสิ้นสุด',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                suffixIcon: _endAt != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() {
                                          _endAt = null;
                                          _endDateCtrl.clear();
                                        }),
                                      )
                                    : null,
                              ),
                              onTap: () => _pickDate(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Products Card (for bundle/buy_x_get_y)
                  if (_promotionType == 'bundle' || _promotionType == 'buy_x_get_y')
                    _buildCard(
                      title: 'สินค้าในโปรโมชั่น',
                      subtitle: '${_selectedProducts.length} รายการ',
                      children: [
                        // Product Selection Card
                        InkWell(
                          onTap: _navigateToProductPicker,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppDesignSystem.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedProducts.isEmpty
                                      ? Icons.add_circle_outline
                                      : Icons.edit,
                                  color: AppDesignSystem.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedProducts.isEmpty
                                            ? 'เลือกสินค้า'
                                            : '${_selectedProducts.length} รายการที่เลือก',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppDesignSystem.primary,
                                        ),
                                      ),
                                      if (_selectedProducts.isNotEmpty)
                                        Text(
                                          'แตะเพื่อแก้ไข',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppDesignSystem.primary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Selected Products List
                        if (_selectedProducts.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._selectedProducts.asMap().entries.map((e) {
                            final product = e.value;
                            return _buildProductItem(product);
                          }),
                        ],
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Status Card
                  _buildCard(
                    title: 'สถานะ',
                    children: [
                      SwitchListTile(
                        title: const Text('เปิดใช้งาน'),
                        subtitle: Text(
                          _isActive ? 'โปรโมชั่นจะแสดงในระบบ' : 'โปรโมชั่นจะถูกซ่อน',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeColor: AppDesignSystem.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Phase 4: Availability & Procurement Rules Card
                  _buildCard(
                    title: 'กฎการตรวจสอบสินค้าพร้อมขาย',
                    subtitle: 'Phase 4',
                    children: [
                      // Require In Stock
                      SwitchListTile(
                        title: const Text('ต้องมีสต็อกพร้อมขาย'),
                        subtitle: Text(
                          _requireInStock
                              ? 'สินค้าต้องมี stock > 0 จึงจะขายได้'
                              : 'ไม่ตรวจสอบสต็อก (ขายได้แม้ stock หมด)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: _requireInStock,
                        onChanged: (v) => setState(() => _requireInStock = v),
                        activeColor: AppDesignSystem.primary,
                      ),
                      const Divider(height: 1),
                      // Require Sufficient Ingredients
                      SwitchListTile(
                        title: const Text('ต้องมีวัตถุดิบพอผลิต'),
                        subtitle: Text(
                          _requireSufficientIngredients
                              ? 'ตรวจสอบวัตถุดิบพอผลิต > 1 ชิ้น'
                              : 'ไม่ตรวจสอบวัตถุดิบ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: _requireSufficientIngredients,
                        onChanged: (v) => setState(() => _requireSufficientIngredients = v),
                        activeColor: AppDesignSystem.primary,
                      ),
                      const Divider(height: 1),
                      // Include Pending Procurement
                      SwitchListTile(
                        title: const Text('นับรวมการจัดซื้อที่รอรับ'),
                        subtitle: Text(
                          _includePendingProcurement
                              ? 'นับ PO ที่รอรับ (ยกเว้น completed/cancelled)'
                              : 'ไม่นับรวมการจัดซื้อ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: _includePendingProcurement,
                        onChanged: (v) => setState(() => _includePendingProcurement = v),
                        activeColor: AppDesignSystem.primary,
                      ),
                      // Summary
                      if (_requireInStock || _requireSufficientIngredients || _includePendingProcurement)
                        Container(
                          margin: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'สรุปการตรวจสอบ:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (_requireInStock) '• ต้องมี stock > 0',
                                  if (_requireSufficientIngredients) '• วัตถุดิบพอผลิต > 1 ชิ้น',
                                  if (_includePendingProcurement) '• นับรวม PO รอรับ',
                                ].join('\n'),
                                style: const TextStyle(fontSize: 11, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    final isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppDesignSystem.primary.withOpacity(0.05) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppDesignSystem.primary : Colors.grey[300]!,
        ),
      ),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppDesignSystem.primary : Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: AppDesignSystem.primary,
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignSystem.selectedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignSystem.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, size: 16, color: AppDesignSystem.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              product['name'] ?? 'ไม่มีชื่อ',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '×${product['quantity'] ?? 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              setState(() {
                _selectedProducts.remove(product);
              });
            },
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
