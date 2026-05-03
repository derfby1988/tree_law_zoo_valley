import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';
import '../services/pos_discount_service.dart';
import '../services/pos_promotion_service.dart';
import '../services/inventory_service.dart';
import '../services/user_group_service.dart';
import '../models/pos_discount_model.dart';
import '../models/pos_promotion_model.dart';
import '../models/user_group_model.dart';
import '../utils/date_picker_helper.dart';

class CouponPromotionAdminPage extends StatefulWidget {
  const CouponPromotionAdminPage({super.key});

  @override
  State<CouponPromotionAdminPage> createState() => _CouponPromotionAdminPageState();
}

class _CouponPromotionAdminPageState extends State<CouponPromotionAdminPage> {
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  List<PosDiscount> _coupons = [];
  List<PosPromotion> _promotions = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<UserGroup> _userGroups = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        PosDiscountService.getAllDiscounts(),
        PosPromotionService.getAllPromotions(),
        InventoryService.getProducts(),
        InventoryService.getCategories(),
        UserGroupService.getAllGroups(),
      ]);

      setState(() {
        _coupons = results[0] as List<PosDiscount>;
        _promotions = results[1] as List<PosPromotion>;
        _allProducts = results[2] as List<Map<String, dynamic>>;
        _categories = results[3] as List<Map<String, dynamic>>;
        _userGroups = results[4] as List<UserGroup>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการคูปอง & โปรโมชั่น'),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppDesignSystem.secondary,
                        AppDesignSystem.primary,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tab buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                label: 'คูปอง',
                                index: 0,
                                isSelected: _selectedTabIndex == 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTabButton(
                                label: 'โปรโมชั่น',
                                index: 1,
                                isSelected: _selectedTabIndex == 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: _buildTabContent(),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedTabIndex == 0) {
            _showAddCouponDialog();
          } else {
            _showAddPromotionDialog();
          }
        },
        backgroundColor: AppDesignSystem.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppDesignSystem.primary, width: 2)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppDesignSystem.primary : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildCouponsTab();
      case 1:
        return _buildPromotionsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCouponsTab() {
    if (_coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีคูปอง',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _coupons.map((coupon) {
        final discountText = coupon.discountType == 'percentage'
            ? '${coupon.value.toStringAsFixed(0)}%'
            : '${coupon.value.toStringAsFixed(0)} บาท';

        return Column(
          children: [
            _buildCouponAdminCard(
              coupon: coupon,
              discountText: discountText,
              onEdit: () => _showEditCouponDialog(coupon),
              onDelete: () => _showDeleteConfirmDialog(
                title: 'ลบคูปอง',
                message: 'คุณแน่ใจหรือว่าต้องการลบคูปอง "${coupon.name}"',
                onConfirm: () => _deleteCoupon(coupon.id),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPromotionsTab() {
    if (_promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีโปรโมชั่น',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _promotions.map((promotion) {
        return Column(
          children: [
            _buildPromotionAdminCard(
              promotion: promotion,
              onEdit: () => _showEditPromotionDialog(promotion),
              onDelete: () => _showDeleteConfirmDialog(
                title: 'ลบโปรโมชั่น',
                message: 'คุณแน่ใจหรือว่าต้องการลบโปรโมชั่น "${promotion.name}"',
                onConfirm: () => _deletePromotion(promotion.id),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCouponAdminCard({
    required PosDiscount coupon,
    required String discountText,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (coupon.description != null && coupon.description!.isNotEmpty)
                        Text(
                          coupon.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    discountText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: coupon.isActive ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        coupon.isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: coupon.isActive ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'หมดอายุ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coupon.endAt != null
                          ? _formatDate(coupon.endAt!)
                          : 'ไม่มีกำหนด',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('แก้ไข'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('ลบ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionAdminCard({
    required PosPromotion promotion,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promotion.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (promotion.description != null && promotion.description!.isNotEmpty)
                        Text(
                          promotion.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getPromotionTypeLabel(promotion.promotionType),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: promotion.isActive ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        promotion.isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: promotion.isActive ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'วันสิ้นสุด',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promotion.endAt != null
                          ? _formatDate(promotion.endAt!)
                          : 'ไม่มีกำหนด',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('แก้ไข'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('ลบ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCouponDialog() {
    _showCouponDialog(title: 'เพิ่มคูปองใหม่');
  }

  void _showEditCouponDialog(PosDiscount coupon) {
    _showCouponDialog(title: 'แก้ไขคูปอง', existing: coupon);
  }

  /// Validate coupon data before saving
  String? _validateCoupon({
    required String name,
    required String discountType,
    required String value,
    required String maxDiscount,
    required String scope,
    required DateTime? startAt,
    required DateTime? endAt,
  }) {
    if (name.trim().isEmpty) return 'ชื่อคูปองต้องไม่ว่าง';
    if (value.trim().isEmpty) return 'ค่าส่วนลดต้องไม่ว่าง';
    
    final val = double.tryParse(value);
    if (val == null || val <= 0) return 'ค่าส่วนลดต้องมากกว่า 0';
    
    if (discountType == 'percentage') {
      if (val > 100) return 'ส่วนลดเปอร์เซ็นต์ต้องไม่เกิน 100%';
      if (maxDiscount.isNotEmpty) {
        final max = double.tryParse(maxDiscount);
        if (max == null || max < 0) return 'ลดสูงสุดต้องเป็นตัวเลขบวก';
      }
    }
    
    if (startAt != null && endAt != null && startAt.isAfter(endAt)) {
      return 'วันเริ่มต้นต้องก่อนวันสิ้นสุด';
    }
    
    return null;
  }

  void _showCouponDialog({required String title, PosDiscount? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valueCtrl = TextEditingController(text: existing != null ? existing.value.toStringAsFixed(0) : '');
    final maxCtrl = TextEditingController(text: existing?.maxDiscount?.toStringAsFixed(0) ?? '');
    final minCtrl = TextEditingController(text: existing?.minAmount?.toStringAsFixed(0) ?? '');
    final couponCodeCtrl = TextEditingController(text: existing?.couponCode ?? '');
    final usageLimitCtrl = TextEditingController(text: existing?.usageLimit?.toString() ?? '');
    final usageLimitPerCustomerCtrl = TextEditingController(text: existing?.usageLimitPerCustomer?.toString() ?? '');
    final usageLimitPerDayCtrl = TextEditingController(text: existing?.usageLimitPerDay?.toString() ?? '');
    String discountType = existing?.discountType ?? 'fixed';
    String scope = existing?.scope ?? 'order';
    String lifecycleStatus = existing?.lifecycleStatus ?? 'active';
    List<String> selectedCategoryIds = List<String>.from(existing?.applicableCategoryIds ?? const []);
    List<String> selectedProductIds = List<String>.from(existing?.applicableProductIds ?? const []);
    List<String> applicableChannels = List<String>.from(existing?.applicableChannels ?? const []);
    bool isCategoryLoading = false;
    bool stackable = existing?.stackable ?? false;
    bool isActive = existing?.isActive ?? true;
    bool requireInStock = existing?.requireInStock ?? false;
    bool requireSufficientIngredients = existing?.requireSufficientIngredients ?? false;
    bool includePendingProcurement = existing?.includePendingProcurement ?? false;
    DateTime? startAt = existing?.startAt;
    DateTime? endAt = existing?.endAt;
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, ds) {
          Future<void> pickDate(bool isStart) async {
            final picked = await showBuddhistDatePicker(
              context: context,
              initialDate: (isStart ? startAt : endAt) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) ds(() => isStart ? startAt = picked : endAt = picked);
          }

          return AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      if (errorMsg != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                          ]),
                        ),
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อคูปอง *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: lifecycleStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'สถานะวงจรชีวิต', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('แบบร่าง')),
                        DropdownMenuItem(value: 'scheduled', child: Text('ตั้งเวลาไว้')),
                        DropdownMenuItem(value: 'active', child: Text('ใช้งานอยู่')),
                        DropdownMenuItem(value: 'paused', child: Text('หยุดชั่วคราว')),
                        DropdownMenuItem(value: 'expired', child: Text('หมดอายุ')),
                        DropdownMenuItem(value: 'archived', child: Text('เก็บถาวร')),
                      ],
                      onChanged: (v) => ds(() {
                        lifecycleStatus = v ?? 'active';
                        isActive = lifecycleStatus == 'active' || lifecycleStatus == 'scheduled';
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: couponCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'รหัสคูปอง',
                        border: OutlineInputBorder(),
                        hintText: 'ไม่กำหนด',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: discountType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ประเภทส่วนลด', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'fixed', child: Text('จำนวนเงิน (บาท)')),
                        DropdownMenuItem(value: 'percentage', child: Text('เปอร์เซ็นต์ (%)')),
                      ],
                      onChanged: (v) => ds(() => discountType = v ?? 'fixed'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueCtrl,
                      decoration: InputDecoration(
                        labelText: discountType == 'percentage' ? 'ส่วนลด (%)' : 'ส่วนลด (บาท)',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    if (discountType == 'percentage') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ลดสูงสุดไม่เกิน (บาท)',
                          border: OutlineInputBorder(),
                          hintText: 'ไม่กำหนด',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: scope,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ขอบเขต', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'order', child: Text('ทั้งบิล')),
                        DropdownMenuItem(value: 'item', child: Text('รายการสินค้า')),
                        DropdownMenuItem(value: 'category', child: Text('หมวดหมู่')),
                      ],
                      onChanged: (v) {
                        final newScope = v ?? 'order';
                        if (newScope == 'category' && scope != 'category') {
                          ds(() { scope = newScope; isCategoryLoading = true; });
                          Future.delayed(const Duration(milliseconds: 600), () {
                            ds(() => isCategoryLoading = false);
                          });
                        } else {
                          ds(() => scope = newScope);
                        }
                      },
                    ),
                    if (scope == 'category') ...[
                      const SizedBox(height: 12),
                      if (isCategoryLoading)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('กำลังโหลดหมวดหมู่...', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation(AppDesignSystem.primary),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'เลือกหมวดหมู่ *',
                            border: const OutlineInputBorder(),
                            hintText: 'แตะเพื่อเลือก',
                            suffixIcon: selectedCategoryIds.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('${selectedCategoryIds.length} รายการ', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                )
                              : null,
                          ),
                          items: _categories.isEmpty ? [] : [
                            const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                            const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ล้างการเลือก')),
                            const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                            ..._categories.map((cat) {
                              final catId = cat['id'].toString();
                              final isSelected = selectedCategoryIds.contains(catId);
                              final productCount = _allProducts.where((p) {
                                final c = p['category'];
                                return c is Map && c['id'].toString() == catId;
                              }).length;
                              return DropdownMenuItem<String>(
                                value: catId,
                                child: Row(children: [
                                  Checkbox(value: isSelected, onChanged: null),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(cat['name'] ?? 'ไม่ระบุชื่อ')),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: productCount > 0 ? AppDesignSystem.primary.withOpacity(0.15) : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$productCount',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: productCount > 0 ? AppDesignSystem.primary : Colors.grey[500],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            if (value == '__select_all__') {
                              ds(() => selectedCategoryIds = _categories.map((c) => c['id'].toString()).toList());
                            } else if (value == '__clear_all__') {
                              ds(() => selectedCategoryIds.clear());
                            } else if (value != null && value.isNotEmpty) {
                              ds(() {
                                if (selectedCategoryIds.contains(value)) {
                                  selectedCategoryIds.remove(value);
                                } else {
                                  selectedCategoryIds.add(value);
                                }
                              });
                            }
                          },
                        ),
                      if (selectedCategoryIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('หมวดหมู่ที่เลือก (${selectedCategoryIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedCategoryIds.map((catId) {
                                  final cat = _categories.firstWhere((c) => c['id'].toString() == catId, orElse: () => {});
                                  return Chip(
                                    label: Text(cat['name'] ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontSize: 10)),
                                    onDeleted: () => ds(() => selectedCategoryIds.remove(catId)),
                                    backgroundColor: AppDesignSystem.primary.withOpacity(0.2),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (scope == 'item') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'เลือกสินค้า *',
                          border: const OutlineInputBorder(),
                          hintText: 'แตะเพื่อเลือก',
                          suffixIcon: selectedProductIds.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('${selectedProductIds.length} รายการ', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                )
                              : null,
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                          const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ล้างการเลือก')),
                          const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                          ..._allProducts.map((product) {
                            final productId = product['id'].toString();
                            final isSelected = selectedProductIds.contains(productId);
                            final category = product['category'];
                            final categoryName = category is Map ? category['name']?.toString() ?? '' : '';
                            return DropdownMenuItem<String>(
                              value: productId,
                              child: Row(children: [
                                Checkbox(value: isSelected, onChanged: null),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(product['name']?.toString() ?? 'ไม่ระบุชื่อ'),
                                      if (categoryName.isNotEmpty)
                                        Text(categoryName, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                              ]),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value == '__select_all__') {
                            ds(() => selectedProductIds = _allProducts.map((p) => p['id'].toString()).toList());
                          } else if (value == '__clear_all__') {
                            ds(() => selectedProductIds.clear());
                          } else if (value != null && value.isNotEmpty) {
                            ds(() {
                              if (selectedProductIds.contains(value)) {
                                selectedProductIds.remove(value);
                              } else {
                                selectedProductIds.add(value);
                              }
                            });
                          }
                        },
                      ),
                      if (selectedProductIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('สินค้าที่เลือก (${selectedProductIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedProductIds.take(20).map((productId) {
                                  final product = _allProducts.firstWhere((p) => p['id'].toString() == productId, orElse: () => {});
                                  return Chip(
                                    label: Text(product['name']?.toString() ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontSize: 10)),
                                    onDeleted: () => ds(() => selectedProductIds.remove(productId)),
                                    backgroundColor: AppDesignSystem.primary.withOpacity(0.2),
                                    deleteIcon: const Icon(Icons.close, size: 14),
                                  );
                                }).toList(),
                              ),
                              if (selectedProductIds.length > 20)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('+ อีก ${selectedProductIds.length - 20} รายการ', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: minCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ยอดขั้นต่ำ (บาท)',
                        border: OutlineInputBorder(),
                        hintText: 'ไม่กำหนด',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: usageLimitCtrl,
                          decoration: const InputDecoration(labelText: 'จำกัดใช้ทั้งหมด', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: usageLimitPerCustomerCtrl,
                          decoration: const InputDecoration(labelText: 'ต่อคน', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usageLimitPerDayCtrl,
                      decoration: const InputDecoration(labelText: 'จำกัดใช้ต่อวัน', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Text('ช่องทางที่ใช้ได้', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    Wrap(
                      spacing: 6,
                      children: const [
                        ('pos', 'POS หน้าร้าน'),
                        ('qr_ordering', 'QR Ordering'),
                        ('delivery', 'Delivery'),
                        ('walk_in', 'Walk-in'),
                        ('table_service', 'Table service'),
                        ('group_booking', 'Group booking'),
                      ].map((channel) {
                        final selected = applicableChannels.contains(channel.$1);
                        return FilterChip(
                          label: Text(channel.$2, style: const TextStyle(fontSize: 11)),
                          selected: selected,
                          onSelected: (v) => ds(() {
                            if (v) {
                              applicableChannels.add(channel.$1);
                            } else {
                              applicableChannels.remove(channel.$1);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text('ช่วงเวลาใช้งาน', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 14),
                              label: Text(startAt != null ? _formatDate(startAt!) : 'วันเริ่มต้น', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(true),
                              style: OutlinedButton.styleFrom(foregroundColor: startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (startAt != null)
                            InkWell(onTap: () => ds(() => startAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event, size: 14),
                              label: Text(endAt != null ? _formatDate(endAt!) : 'วันสิ้นสุด', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(false),
                              style: OutlinedButton.styleFrom(foregroundColor: endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (endAt != null)
                            InkWell(onTap: () => ds(() => endAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 14),
                              label: Text(startAt != null ? '${startAt!.hour.toString().padLeft(2, '0')}:${startAt!.minute.toString().padLeft(2, '0')}' : 'เวลาเริ่มต้น', style: const TextStyle(fontSize: 11)),
                              onPressed: () async {
                                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startAt ?? DateTime.now()));
                                if (time != null && startAt != null) {
                                  ds(() => startAt = startAt!.copyWith(hour: time.hour, minute: time.minute));
                                }
                              },
                              style: OutlinedButton.styleFrom(foregroundColor: startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (startAt != null)
                            InkWell(onTap: () => ds(() => startAt = startAt!.copyWith(hour: 0, minute: 0)), child: const Icon(Icons.refresh, size: 14, color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 14),
                              label: Text(endAt != null ? '${endAt!.hour.toString().padLeft(2, '0')}:${endAt!.minute.toString().padLeft(2, '0')}' : 'เวลาสิ้นสุด', style: const TextStyle(fontSize: 11)),
                              onPressed: () async {
                                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(endAt ?? DateTime.now()));
                                if (time != null && endAt != null) {
                                  ds(() => endAt = endAt!.copyWith(hour: time.hour, minute: time.minute));
                                }
                              },
                              style: OutlinedButton.styleFrom(foregroundColor: endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (endAt != null)
                            InkWell(onTap: () => ds(() => endAt = endAt!.copyWith(hour: 23, minute: 59)), child: const Icon(Icons.refresh, size: 14, color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    CheckboxListTile(
                      title: const Text('ซ้อนส่วนลดอื่นได้', style: TextStyle(fontSize: 13)),
                      value: stackable,
                      onChanged: (v) => ds(() => stackable = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: Text('เปิดใช้งาน', style: TextStyle(fontSize: 13, color: isActive ? AppDesignSystem.primary : Colors.grey)),
                      value: isActive,
                      onChanged: (v) => ds(() => isActive = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('ต้องมีสินค้าในสต็อก', style: TextStyle(fontSize: 13)),
                      value: requireInStock,
                      onChanged: (v) => ds(() => requireInStock = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('สินค้าผลิตต้องมีวัตถุดิบเพียงพอ', style: TextStyle(fontSize: 13)),
                      value: requireSufficientIngredients,
                      onChanged: (v) => ds(() => requireSufficientIngredients = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('รวมรายการที่อยู่ในขั้นตอนจัดซื้อ', style: TextStyle(fontSize: 13)),
                      value: includePendingProcurement,
                      onChanged: (v) => ds(() => includePendingProcurement = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  final err = _validateCoupon(
                    name: nameCtrl.text,
                    discountType: discountType,
                    value: valueCtrl.text,
                    maxDiscount: maxCtrl.text,
                    scope: scope,
                    startAt: startAt,
                    endAt: endAt,
                  );
                  
                  if (err != null) {
                    ds(() => errorMsg = err);
                    return;
                  }
                  
                  if (scope == 'category' && selectedCategoryIds.isEmpty) {
                    ds(() => errorMsg = 'ต้องเลือกอย่างน้อย 1 หมวดหมู่');
                    return;
                  }

                  if (scope == 'item' && selectedProductIds.isEmpty) {
                    ds(() => errorMsg = 'ต้องเลือกอย่างน้อย 1 สินค้า');
                    return;
                  }
                  
                  ds(() => isSaving = true);
                  
                  try {
                    if (existing == null) {
                      await _addCoupon(
                        name: nameCtrl.text, description: descCtrl.text,
                        discountType: discountType, scope: scope,
                        value: double.tryParse(valueCtrl.text) ?? 0,
                        maxDiscount: maxCtrl.text.isNotEmpty ? double.tryParse(maxCtrl.text) : null,
                        minAmount: minCtrl.text.isNotEmpty ? double.tryParse(minCtrl.text) : null,
                        stackable: stackable,
                        isActive: isActive,
                        applicableCategoryIds: selectedCategoryIds,
                        applicableProductIds: selectedProductIds,
                        couponCode: couponCodeCtrl.text.trim().isEmpty ? null : couponCodeCtrl.text.trim(),
                        usageLimit: usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitCtrl.text),
                        usageLimitPerCustomer: usageLimitPerCustomerCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerCustomerCtrl.text),
                        usageLimitPerDay: usageLimitPerDayCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerDayCtrl.text),
                        lifecycleStatus: lifecycleStatus,
                        applicableChannels: applicableChannels,
                        requireInStock: requireInStock,
                        requireSufficientIngredients: requireSufficientIngredients,
                        includePendingProcurement: includePendingProcurement,
                        startAt: startAt,
                        endAt: endAt,
                      );
                    } else {
                      await _updateCoupon(
                        id: existing.id, name: nameCtrl.text, description: descCtrl.text,
                        discountType: discountType, scope: scope,
                        value: double.tryParse(valueCtrl.text) ?? 0,
                        maxDiscount: maxCtrl.text.isNotEmpty ? double.tryParse(maxCtrl.text) : null,
                        minAmount: minCtrl.text.isNotEmpty ? double.tryParse(minCtrl.text) : null,
                        stackable: stackable,
                        isActive: isActive,
                        applicableCategoryIds: selectedCategoryIds,
                        applicableProductIds: selectedProductIds,
                        couponCode: couponCodeCtrl.text.trim().isEmpty ? null : couponCodeCtrl.text.trim(),
                        usageLimit: usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitCtrl.text),
                        usageLimitPerCustomer: usageLimitPerCustomerCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerCustomerCtrl.text),
                        usageLimitPerDay: usageLimitPerDayCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitPerDayCtrl.text),
                        lifecycleStatus: lifecycleStatus,
                        applicableChannels: applicableChannels,
                        requireInStock: requireInStock,
                        requireSufficientIngredients: requireSufficientIngredients,
                        includePendingProcurement: includePendingProcurement,
                        startAt: startAt,
                        endAt: endAt,
                      );
                    }
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) ds(() => errorMsg = 'เกิดข้อผิดพลาด: $e');
                  } finally {
                    if (mounted) ds(() => isSaving = false);
                  }
                },
                child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(existing == null ? 'เพิ่ม' : 'บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPromotionDialog() {
    _showPromotionDialog(title: 'เพิ่มโปรโมชั่นใหม่');
  }

  void _showEditPromotionDialog(PosPromotion promotion) {
    _showPromotionDialog(title: 'แก้ไขโปรโมชั่น', existing: promotion);
  }

  Future<List<Map<String, dynamic>>> _loadPromotionItemsForDialog(String promotionId) async {
    final promotionItems = await PosPromotionService.getPromotionItems(promotionId);
    return promotionItems.map((item) {
      final product = _allProducts.firstWhere(
        (p) => p['id']?.toString() == item.productId,
        orElse: () => {},
      );
      return {
        'product_id': item.productId,
        'name': product['name']?.toString() ?? 'สินค้าเดิม',
        'quantity': item.quantityRequired,
      };
    }).toList();
  }

  void _showPromotionDialog({required String title, PosPromotion? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final searchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String promotionType = existing?.promotionType ?? 'bundle';
    String? selectedDiscountId = existing?.discountId;
    List<String> selectedUserGroupIds = List<String>.from(existing?.applicableUserGroupIds ?? const []);
    bool isActive = existing?.isActive ?? true;
    DateTime? startAt = existing?.startAt;
    DateTime? endAt = existing?.endAt;
    final List<Map<String, dynamic>> items = [];
    List<Map<String, dynamic>> searchResults = [];
    bool hasLoadedExistingItems = existing == null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, ds) {
          final showItems = promotionType == 'bundle' || promotionType == 'buy_x_get_y';

          if (!hasLoadedExistingItems && showItems) {
            hasLoadedExistingItems = true;
            final promotionId = existing!.id;
            _loadPromotionItemsForDialog(promotionId).then((loadedItems) {
              if (!mounted) return;
              ds(() {
                items
                  ..clear()
                  ..addAll(loadedItems);
              });
            });
          }

          void searchProducts(String query) {
            if (query.isEmpty) { ds(() => searchResults = []); return; }
            final q = query.toLowerCase();
            ds(() {
              searchResults = _allProducts
                  .where((p) => ((p['name'] as String?) ?? '').toLowerCase().contains(q))
                  .take(6)
                  .toList();
            });
          }

          void addItem(Map<String, dynamic> product) {
            final productId = product['id'].toString();
            final qty = int.tryParse(qtyCtrl.text) ?? 1;
            ds(() {
              final existingIndex = items.indexWhere((i) => i['product_id'].toString() == productId);
              if (existingIndex >= 0) {
                final currentQty = (items[existingIndex]['quantity'] as int?) ?? 1;
                items[existingIndex]['quantity'] = currentQty + qty;
              } else {
                items.add({'product_id': productId, 'name': product['name'], 'quantity': qty});
              }
              searchCtrl.clear();
              searchResults = [];
            });
          }

          Future<void> pickDate(bool isStart) async {
            final picked = await showBuddhistDatePicker(
              context: context,
              initialDate: (isStart ? startAt : endAt) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) ds(() => isStart ? startAt = picked : endAt = picked);
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อโปรโมชั่น *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: promotionType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ประเภทโปรโมชั่น', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'bundle', child: Text('ชุดสินค้า (Bundle)')),
                        DropdownMenuItem(value: 'seasonal', child: Text('ตามฤดูกาล (Seasonal)')),
                        DropdownMenuItem(value: 'buy_x_get_y', child: Text('ซื้อ X แถม Y')),
                      ],
                      onChanged: (v) => ds(() { promotionType = v ?? 'bundle'; items.clear(); searchResults = []; }),
                    ),
                    const SizedBox(height: 12),
                    // Discount linker
                    DropdownButtonFormField<String?>(
                      value: selectedDiscountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'เชื่อมส่วนลด',
                        border: const OutlineInputBorder(),
                        helperText: _coupons.isEmpty ? 'ยังไม่มีส่วนลด — สร้างที่แท็บ "คูปอง" ก่อน' : null,
                        prefixIcon: const Icon(Icons.local_offer, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('ไม่มีส่วนลด')),
                        ..._coupons.map((d) {
                          final tag = d.discountType == 'percentage'
                              ? '${d.value.toStringAsFixed(0)}%'
                              : '฿${d.value.toStringAsFixed(0)}';
                          final scopeLabel = {'order': 'ทั้งบิล', 'item': 'รายการ', 'category': 'หมวดหมู่'}[d.scope] ?? d.scope;
                          return DropdownMenuItem<String?>(
                            value: d.id,
                            child: Text('${d.name} ($tag · $scopeLabel)', overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => ds(() => selectedDiscountId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'กลุ่มผู้ใช้ที่ใช้โปรโมชันได้',
                        border: const OutlineInputBorder(),
                        hintText: 'ไม่เลือก = ใช้ได้ทุกกลุ่ม',
                        suffixIcon: selectedUserGroupIds.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text('${selectedUserGroupIds.length} กลุ่ม', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              )
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                        const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ใช้ได้ทุกกลุ่ม')),
                        const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                        ..._userGroups.map((group) {
                          final isSelected = selectedUserGroupIds.contains(group.id);
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
                        if (value == '__select_all__') {
                          ds(() => selectedUserGroupIds = _userGroups.map((g) => g.id).toList());
                        } else if (value == '__clear_all__') {
                          ds(() => selectedUserGroupIds.clear());
                        } else if (value != null && value.isNotEmpty) {
                          ds(() {
                            if (selectedUserGroupIds.contains(value)) {
                              selectedUserGroupIds.remove(value);
                            } else {
                              selectedUserGroupIds.add(value);
                            }
                          });
                        }
                      },
                    ),
                    if (selectedUserGroupIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selectedUserGroupIds.map((groupId) {
                          final group = _userGroups.firstWhere(
                            (g) => g.id == groupId,
                            orElse: () => UserGroup(id: groupId, groupName: 'กลุ่มเดิม'),
                          );
                          return Chip(
                            label: Text(group.groupName, style: const TextStyle(fontSize: 10)),
                            onDeleted: () => ds(() => selectedUserGroupIds.remove(groupId)),
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
                              label: Text(startAt != null ? _formatDate(startAt!) : 'วันเริ่มต้น', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(true),
                              style: OutlinedButton.styleFrom(foregroundColor: startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (startAt != null)
                            InkWell(onTap: () => ds(() => startAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event, size: 14),
                              label: Text(endAt != null ? _formatDate(endAt!) : 'วันสิ้นสุด', style: const TextStyle(fontSize: 11)),
                              onPressed: () => pickDate(false),
                              style: OutlinedButton.styleFrom(foregroundColor: endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                            ),
                          ),
                          if (endAt != null)
                            InkWell(onTap: () => ds(() => endAt = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    // Product items section for bundle / buy_x_get_y
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
                              promotionType == 'bundle' ? 'สินค้าที่ร่วมโปรโมชั่น' : 'สินค้าที่ต้องซื้อ (X)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ]),
                          Text('${items.length} รายการ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ค้นหาสินค้าจากคลัง',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.search, size: 18),
                            ),
                            onChanged: searchProducts,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: TextField(
                            controller: qtyCtrl,
                            decoration: const InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder(), isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ]),
                      if (searchResults.isNotEmpty)
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
                            itemCount: searchResults.length,
                            itemBuilder: (context, i) {
                              final p = searchResults[i];
                              final catName = p['category']?['name'] as String? ?? '';
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2, size: 16, color: AppDesignSystem.secondary),
                                title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13)),
                                subtitle: catName.isNotEmpty ? Text(catName, style: const TextStyle(fontSize: 11)) : null,
                                trailing: const Icon(Icons.add_circle_outline, size: 18, color: AppDesignSystem.primary),
                                onTap: () => addItem(p),
                              );
                            },
                          ),
                        ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...items.asMap().entries.map((e) {
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
                                onTap: () => ds(() => items.removeAt(e.key)),
                                child: const Icon(Icons.close, size: 16, color: Colors.red),
                              ),
                            ]),
                          );
                        }),
                      ],
                      if (_allProducts.isEmpty)
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
                      title: Text('เปิดใช้งาน', style: TextStyle(fontSize: 13, color: isActive ? AppDesignSystem.primary : Colors.grey)),
                      value: isActive,
                      onChanged: (v) => ds(() => isActive = v),
                      activeColor: AppDesignSystem.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
              ElevatedButton(
                onPressed: () {
                  if (existing == null) {
                    _addPromotion(
                      name: nameCtrl.text, description: descCtrl.text,
                      promotionType: promotionType, discountId: selectedDiscountId,
                      applicableUserGroupIds: selectedUserGroupIds,
                      isActive: isActive, startAt: startAt, endAt: endAt, items: items,
                    );
                  } else {
                    _updatePromotion(
                      id: existing.id, name: nameCtrl.text, description: descCtrl.text,
                      promotionType: promotionType, discountId: selectedDiscountId,
                      applicableUserGroupIds: selectedUserGroupIds,
                      isActive: isActive, startAt: startAt, endAt: endAt, items: items,
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(existing == null ? 'เพิ่ม' : 'บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'ลบ',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCoupon({
    required String name,
    required String description,
    required String discountType,
    required String scope,
    required double value,
    double? maxDiscount,
    double? minAmount,
    required bool stackable,
    required bool isActive,
    List<String> applicableCategoryIds = const [],
    List<String> applicableProductIds = const [],
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    String lifecycleStatus = 'active',
    List<String> applicableChannels = const [],
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อคูปอง')));
      return;
    }
    final result = await PosDiscountService.addDiscount(
      name: name, description: description,
      discountType: discountType, scope: scope, value: value,
      maxDiscount: maxDiscount, minAmount: minAmount,
      stackable: stackable,
      isActive: isActive,
      applicableCategoryIds: applicableCategoryIds,
      applicableProductIds: applicableProductIds,
      couponCode: couponCode,
      usageLimit: usageLimit,
      usageLimitPerCustomer: usageLimitPerCustomer,
      usageLimitPerDay: usageLimitPerDay,
      lifecycleStatus: lifecycleStatus,
      applicableChannels: applicableChannels,
      requireInStock: requireInStock,
      requireSufficientIngredients: requireSufficientIngredients,
      includePendingProcurement: includePendingProcurement,
      startAt: startAt,
      endAt: endAt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null ? 'เพิ่มคูปองสำเร็จ' : 'เพิ่มคูปองไม่สำเร็จ'),
      backgroundColor: result != null ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result != null) _loadData();
  }

  Future<void> _updateCoupon({
    required String id,
    required String name,
    required String description,
    required String discountType,
    required String scope,
    required double value,
    double? maxDiscount,
    double? minAmount,
    required bool stackable,
    required bool isActive,
    List<String> applicableCategoryIds = const [],
    List<String> applicableProductIds = const [],
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    String lifecycleStatus = 'active',
    List<String> applicableChannels = const [],
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อคูปอง')));
      return;
    }
    final result = await PosDiscountService.updateDiscount(
      id: id, name: name, description: description,
      discountType: discountType, value: value, isActive: isActive,
      scope: scope, maxDiscount: maxDiscount, minAmount: minAmount,
      stackable: stackable,
      applicableCategoryIds: applicableCategoryIds,
      applicableProductIds: applicableProductIds,
      couponCode: couponCode,
      usageLimit: usageLimit,
      usageLimitPerCustomer: usageLimitPerCustomer,
      usageLimitPerDay: usageLimitPerDay,
      lifecycleStatus: lifecycleStatus,
      applicableChannels: applicableChannels,
      requireInStock: requireInStock,
      requireSufficientIngredients: requireSufficientIngredients,
      includePendingProcurement: includePendingProcurement,
      startAt: startAt,
      endAt: endAt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null ? 'แก้ไขคูปองสำเร็จ' : 'แก้ไขคูปองไม่สำเร็จ'),
      backgroundColor: result != null ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result != null) _loadData();
  }

  Future<void> _deleteCoupon(String couponId) async {
    final result = await PosDiscountService.deleteDiscount(couponId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result ? 'ลบคูปองสำเร็จ' : 'ลบคูปองไม่สำเร็จ'),
      backgroundColor: result ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result) _loadData();
  }

  Future<void> _addPromotion({
    required String name,
    required String description,
    required String promotionType,
    String? discountId,
    List<String> applicableUserGroupIds = const [],
    required bool isActive,
    DateTime? startAt,
    DateTime? endAt,
    List<Map<String, dynamic>> items = const [],
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อโปรโมชั่น')));
      return;
    }
    final result = await PosPromotionService.addPromotion(
      name: name, description: description,
      promotionType: promotionType, discountId: discountId,
      applicableUserGroupIds: applicableUserGroupIds,
      isActive: isActive,
      startAt: startAt, endAt: endAt,
    );
    if (result != null) {
      for (final item in items) {
        await PosPromotionService.addPromotionItem(
          promotionId: result.id,
          productId: item['product_id'] as String,
          quantityRequired: (item['quantity'] as int?) ?? 1,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('เพิ่มโปรโมชั่นสำเร็จ${items.isNotEmpty ? " (${items.length} สินค้า)" : ""}'),
        backgroundColor: AppDesignSystem.primary,
      ));
      _loadData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('เพิ่มโปรโมชั่นไม่สำเร็จ'),
        backgroundColor: AppDesignSystem.danger,
      ));
    }
  }

  Future<void> _updatePromotion({
    required String id,
    required String name,
    required String description,
    required String promotionType,
    String? discountId,
    List<String> applicableUserGroupIds = const [],
    required bool isActive,
    DateTime? startAt,
    DateTime? endAt,
    List<Map<String, dynamic>> items = const [],
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อโปรโมชั่น')));
      return;
    }
    final result = await PosPromotionService.updatePromotion(
      id: id, name: name, description: description,
      promotionType: promotionType, discountId: discountId,
      applicableUserGroupIds: applicableUserGroupIds,
      isActive: isActive, startAt: startAt, endAt: endAt,
    );
    if (result != null) {
      await PosPromotionService.removePromotionItemsByPromotionId(id);
      for (final item in items) {
        await PosPromotionService.addPromotionItem(
          promotionId: id,
          productId: item['product_id'] as String,
          quantityRequired: (item['quantity'] as int?) ?? 1,
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null ? 'แก้ไขโปรโมชั่นสำเร็จ' : 'แก้ไขโปรโมชั่นไม่สำเร็จ'),
      backgroundColor: result != null ? AppDesignSystem.primary : AppDesignSystem.danger,
    ));
    if (result != null) _loadData();
  }

  Future<void> _deletePromotion(String promotionId) async {
    final result = await PosPromotionService.deletePromotion(promotionId);

    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโปรโมชั่นสำเร็จ')),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบโปรโมชั่นไม่สำเร็จ')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  String _getPromotionTypeLabel(String promotionType) {
    switch (promotionType) {
      case 'bundle':
        return 'ชุดสินค้า';
      case 'seasonal':
        return 'ตามฤดูกาล';
      case 'buy_x_get_y':
        return 'ซื้อ X แถม Y';
      default:
        return promotionType;
    }
  }
}
