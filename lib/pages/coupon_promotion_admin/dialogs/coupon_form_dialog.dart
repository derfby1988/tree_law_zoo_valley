import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/pos_discount_model.dart';
import '../../../theme/app_design_system.dart';
import '../../../utils/date_picker_helper.dart';
import '../../../services/supabase_service.dart';

class CouponFormDialog extends StatefulWidget {
  const CouponFormDialog({
    super.key,
    required this.title,
    this.existing,
    required this.categories,
    required this.products,
    required this.onSubmit,
    this.defaultDailyMode = false,
  });

  final String title;
  final PosDiscount? existing;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> products;
  final Future<void> Function(CouponFormResult result) onSubmit;
  final bool defaultDailyMode;

  @override
  State<CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<CouponFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _couponCodeCtrl;
  late final TextEditingController _usageLimitCtrl;
  late final TextEditingController _usageLimitPerCustomerCtrl;
  late final TextEditingController _usageLimitPerDayCtrl;
  late final TextEditingController _entryAreaCtrl;
  late final TextEditingController _entryLimitCtrl;
  late final TextEditingController _discountLimitCtrl;
  late final TextEditingController _discountLimitPerCouponCtrl;
  late final TextEditingController _groupSizeCtrl;
  late final TextEditingController _idempotencyWindowCtrl;
  late final TextEditingController _qrReplayWindowCtrl;
  late final TextEditingController _keyVersionCtrl;

  String _discountType = 'fixed';
  String _scope = 'order';
  String _lifecycleStatus = 'active';
  List<String> _selectedCategoryIds = [];
  List<String> _selectedProductIds = [];
  List<String> _applicableChannels = [];
  bool _stackable = false;
  bool _isActive = true;
  bool _requireInStock = false;
  bool _requireSufficientIngredients = false;
  bool _includePendingProcurement = false;
  bool _showInCouponTab = false;
  bool _showInPosDiscountDialog = false;
  bool _isDailyCoupon = false;
  String _dailyAudience = 'individual';
  bool _entryRequiresSameDay = true;
  bool _allowEntryBeforeDiscount = true;
  bool _allowDiscountWithoutEntry = false;
  bool _resetAtLocalMidnight = true;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isCategoryLoading = false;
  bool _isSaving = false;
  String? _errorMsg;
  bool _hasPrefilledDailyDefaults = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _valueCtrl = TextEditingController(text: existing != null ? existing.value.toStringAsFixed(0) : '');
    _maxCtrl = TextEditingController(text: existing?.maxDiscount?.toStringAsFixed(0) ?? '');
    _minCtrl = TextEditingController(text: existing?.minAmount?.toStringAsFixed(0) ?? '');
    _couponCodeCtrl = TextEditingController(text: existing?.couponCode ?? '');
    _usageLimitCtrl = TextEditingController(text: existing?.usageLimit?.toString() ?? '');
    _usageLimitPerCustomerCtrl = TextEditingController(text: existing?.usageLimitPerCustomer?.toString() ?? '');
    _usageLimitPerDayCtrl = TextEditingController(text: existing?.usageLimitPerDay?.toString() ?? '');
    _discountType = existing?.discountType ?? 'fixed';
    _scope = existing?.scope ?? 'order';
    _lifecycleStatus = existing?.lifecycleStatus ?? 'active';
    _selectedCategoryIds = List<String>.from(existing?.applicableCategoryIds ?? const []);
    _selectedProductIds = List<String>.from(existing?.applicableProductIds ?? const []);
    _applicableChannels = List<String>.from(existing?.applicableChannels ?? const []);
    _stackable = existing?.stackable ?? false;
    _isActive = existing?.isActive ?? true;
    _requireInStock = existing?.requireInStock ?? false;
    _requireSufficientIngredients = existing?.requireSufficientIngredients ?? false;
    _includePendingProcurement = existing?.includePendingProcurement ?? false;
    _showInCouponTab = existing?.showInCouponTab ?? false;
    _showInPosDiscountDialog = existing?.showInPosDiscountDialog ?? false;
    _startAt = existing?.startAt;
    _endAt = existing?.endAt;

    final rule = Map<String, dynamic>.from(existing?.targetingRule ?? const {});
    _isDailyCoupon = rule['daily_unified_enabled'] == true || (existing == null && widget.defaultDailyMode);
    _dailyAudience = (rule['coupon_audience'] ?? 'individual').toString();
    _entryRequiresSameDay = rule['entry_requires_same_day'] ?? true;
    _allowEntryBeforeDiscount = rule['allow_entry_before_discount'] ?? true;
    _allowDiscountWithoutEntry = rule['allow_discount_without_entry'] ?? false;
    _resetAtLocalMidnight = rule['reset_at_local_midnight'] ?? true;

    _entryAreaCtrl = TextEditingController(text: rule['entry_area_name']?.toString() ?? '');
    _entryLimitCtrl = TextEditingController(text: _intToString(rule['entry_limit_per_day']));
    _discountLimitCtrl = TextEditingController(text: _intToString(rule['discount_limit_per_day']));
    _discountLimitPerCouponCtrl = TextEditingController(text: _intToString(rule['discount_limit_per_coupon']));
    _groupSizeCtrl = TextEditingController(text: _intToString(rule['group_size']));
    _idempotencyWindowCtrl = TextEditingController(text: _intToString(rule['idempotency_window_seconds'] ?? 45));
    _qrReplayWindowCtrl = TextEditingController(text: _intToString(rule['qr_replay_window_seconds'] ?? 30));
    _keyVersionCtrl = TextEditingController(text: rule['key_version']?.toString() ?? '');

    if (existing == null && widget.defaultDailyMode) {
      _prefillDailyDefaults();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _maxCtrl.dispose();
    _minCtrl.dispose();
    _couponCodeCtrl.dispose();
    _usageLimitCtrl.dispose();
    _usageLimitPerCustomerCtrl.dispose();
    _usageLimitPerDayCtrl.dispose();
    _entryAreaCtrl.dispose();
    _entryLimitCtrl.dispose();
    _discountLimitCtrl.dispose();
    _discountLimitPerCouponCtrl.dispose();
    _groupSizeCtrl.dispose();
    _idempotencyWindowCtrl.dispose();
    _qrReplayWindowCtrl.dispose();
    _keyVersionCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _categories => widget.categories;
  List<Map<String, dynamic>> get _products => widget.products;

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

  void _prefillDailyDefaults() {
    if (_hasPrefilledDailyDefaults) return;
    _hasPrefilledDailyDefaults = true;

    if (_nameCtrl.text.trim().isEmpty) {
      _nameCtrl.text = 'คูปองเข้าพื้นที่ & แลกซื้อ';
    }

    _generateDailyCouponCode().then((code) {
      if (!mounted || code == null) return;
      if (_couponCodeCtrl.text.trim().isEmpty) {
        _couponCodeCtrl.text = code;
      }
    });
  }

  Future<String?> _generateDailyCouponCode() async {
    try {
      final datePart = _formatDateForCode(DateTime.now());
      final suffix = await _resolvePhoneSuffix();
      return 'TLZ$datePart$suffix';
    } catch (e) {
      debugPrint('Failed to generate daily coupon code: $e');
      return null;
    }
  }

  Future<String> _resolvePhoneSuffix() async {
    const fallback = '0000';
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return fallback;

      String? phone = user.phone;
      final metadataPhone = user.userMetadata?['phone'];
      if ((phone == null || phone.isEmpty) && metadataPhone != null) {
        phone = metadataPhone.toString();
      }

      if (phone == null || phone.isEmpty) {
        try {
          final response = await SupabaseService.client
              .from('users')
              .select('phone')
              .eq('id', user.id)
              .maybeSingle();
          if (response != null) {
            final row = Map<String, dynamic>.from(response as Map);
            phone = row['phone']?.toString();
          }
        } catch (e) {
          debugPrint('Failed to fetch phone from users table: $e');
        }
      }

      if (phone == null || phone.trim().isEmpty) return fallback;

      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return fallback;

      final normalized = digits.padLeft(4, '0');
      return normalized.substring(normalized.length - 4);
    } catch (e) {
      debugPrint('Failed to resolve phone suffix: $e');
      return fallback;
    }
  }

  String _formatDateForCode(DateTime date) {
    const monthAbbr = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final year = (date.year % 100).toString().padLeft(2, '0');
    final month = monthAbbr[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

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

  String? _validateDailyCouponFields() {
    if (!_isDailyCoupon) return null;
    if (_entryAreaCtrl.text.trim().isEmpty) {
      return 'คูปองรายวันต้องระบุชื่อพื้นที่ที่ใช้สิทธิ์';
    }

    final entryLimit = int.tryParse(_entryLimitCtrl.text.trim());
    if (entryLimit == null || entryLimit <= 0) {
      return 'จำนวนเข้าได้ต่อวันต้องมากกว่า 0';
    }

    final discountLimit = int.tryParse(_discountLimitCtrl.text.trim());
    if (discountLimit == null || discountLimit < 0) {
      return 'จำนวนใช้ส่วนลดต่อวันต้องเป็นตัวเลข 0 ขึ้นไป';
    }

    if (_dailyAudience == 'group') {
      final size = int.tryParse(_groupSizeCtrl.text.trim());
      if (size == null || size < 2) {
        return 'คูปองรายกลุ่มต้องกำหนดจำนวนสมาชิกอย่างน้อย 2 คน';
      }
    }

    if (_discountLimitPerCouponCtrl.text.trim().isNotEmpty) {
      final perCoupon = int.tryParse(_discountLimitPerCouponCtrl.text.trim());
      if (perCoupon == null || perCoupon < 0) {
        return 'จำนวนใช้ต่อคูปองต้องเป็นตัวเลข 0 ขึ้นไป';
      }
    }

    final idempotency = int.tryParse(_idempotencyWindowCtrl.text.trim());
    if (idempotency == null || idempotency <= 0) {
      return 'Idempotency window (วินาที) ต้องมากกว่า 0';
    }

    final replay = int.tryParse(_qrReplayWindowCtrl.text.trim());
    if (replay == null || replay <= 0) {
      return 'Replay window (วินาที) ต้องมากกว่า 0';
    }

    return null;
  }

  Future<void> _handleSubmit() async {
    final err = _validateCoupon(
      name: _nameCtrl.text,
      discountType: _discountType,
      value: _valueCtrl.text,
      maxDiscount: _maxCtrl.text,
      scope: _scope,
      startAt: _startAt,
      endAt: _endAt,
    );

    if (err != null) {
      setState(() => _errorMsg = err);
      return;
    }

    final dailyErr = _validateDailyCouponFields();
    if (dailyErr != null) {
      setState(() => _errorMsg = dailyErr);
      return;
    }

    if (_scope == 'category' && _selectedCategoryIds.isEmpty) {
      setState(() => _errorMsg = 'ต้องเลือกอย่างน้อย 1 หมวดหมู่');
      return;
    }

    if (_scope == 'item' && _selectedProductIds.isEmpty) {
      setState(() => _errorMsg = 'ต้องเลือกอย่างน้อย 1 สินค้า');
      return;
    }

    setState(() {
      _errorMsg = null;
      _isSaving = true;
    });

    final targetingRule = _buildTargetingRule();

    final data = CouponFormResult(
      name: _nameCtrl.text,
      description: _descCtrl.text,
      discountType: _discountType,
      scope: _scope,
      value: double.tryParse(_valueCtrl.text) ?? 0,
      maxDiscount: _maxCtrl.text.isNotEmpty ? double.tryParse(_maxCtrl.text) : null,
      minAmount: _minCtrl.text.isNotEmpty ? double.tryParse(_minCtrl.text) : null,
      stackable: _stackable,
      isActive: _isActive,
      applicableCategoryIds: _selectedCategoryIds,
      applicableProductIds: _selectedProductIds,
      couponCode: _couponCodeCtrl.text.trim().isEmpty ? null : _couponCodeCtrl.text.trim(),
      usageLimit: _usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(_usageLimitCtrl.text),
      usageLimitPerCustomer: _usageLimitPerCustomerCtrl.text.trim().isEmpty ? null : int.tryParse(_usageLimitPerCustomerCtrl.text),
      usageLimitPerDay: _usageLimitPerDayCtrl.text.trim().isEmpty ? null : int.tryParse(_usageLimitPerDayCtrl.text),
      lifecycleStatus: _lifecycleStatus,
      applicableChannels: _applicableChannels,
      requireInStock: _requireInStock,
      requireSufficientIngredients: _requireSufficientIngredients,
      includePendingProcurement: _includePendingProcurement,
      showInCouponTab: _showInCouponTab,
      showInPosDiscountDialog: _showInPosDiscountDialog,
      startAt: _startAt,
      endAt: _endAt,
      targetingRule: targetingRule,
    );

    try {
      await widget.onSubmit(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อคูปอง *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder()), maxLines: 2),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _lifecycleStatus,
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
                onChanged: (v) => setState(() {
                  _lifecycleStatus = v ?? 'active';
                  _isActive = _lifecycleStatus == 'active' || _lifecycleStatus == 'scheduled';
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _couponCodeCtrl,
                decoration: const InputDecoration(labelText: 'รหัสคูปอง', border: OutlineInputBorder(), hintText: 'ไม่กำหนด'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _discountType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'ประเภทส่วนลด', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'fixed', child: Text('จำนวนเงิน (บาท)')),
                  DropdownMenuItem(value: 'percentage', child: Text('เปอร์เซ็นต์ (%)')),
                ],
                onChanged: (v) => setState(() => _discountType = v ?? 'fixed'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueCtrl,
                decoration: InputDecoration(
                  labelText: _discountType == 'percentage' ? 'ส่วนลด (%)' : 'ส่วนลด (บาท)',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              if (_discountType == 'percentage') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _maxCtrl,
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
                value: _scope,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'ขอบเขต', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'order', child: Text('ทั้งบิล')),
                  DropdownMenuItem(value: 'item', child: Text('รายการสินค้า')),
                  DropdownMenuItem(value: 'category', child: Text('หมวดหมู่')),
                ],
                onChanged: (v) {
                  final newScope = v ?? 'order';
                  if (newScope == 'category' && _scope != 'category') {
                    setState(() {
                      _scope = newScope;
                      _isCategoryLoading = true;
                    });
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) setState(() => _isCategoryLoading = false);
                    });
                  } else {
                    setState(() => _scope = newScope);
                  }
                },
              ),
              if (_scope == 'category') ...[
                const SizedBox(height: 12),
                if (_isCategoryLoading)
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
                          valueColor: const AlwaysStoppedAnimation(AppDesignSystem.primary),
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
                      suffixIcon: _selectedCategoryIds.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('${_selectedCategoryIds.length} รายการ', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                            )
                          : null,
                    ),
                    items: _categories.isEmpty
                        ? []
                        : [
                            const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                            const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ล้างการเลือก')),
                            const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                            ..._categories.map((cat) {
                              final catId = cat['id'].toString();
                              final isSelected = _selectedCategoryIds.contains(catId);
                              final productCount = _products.where((p) {
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
                        setState(() => _selectedCategoryIds = _categories.map((c) => c['id'].toString()).toList());
                      } else if (value == '__clear_all__') {
                        setState(() => _selectedCategoryIds.clear());
                      } else if (value != null && value.isNotEmpty) {
                        setState(() {
                          if (_selectedCategoryIds.contains(value)) {
                            _selectedCategoryIds.remove(value);
                          } else {
                            _selectedCategoryIds.add(value);
                          }
                        });
                      }
                    },
                  ),
                if (_selectedCategoryIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('หมวดหมู่ที่เลือก (${_selectedCategoryIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedCategoryIds.map((catId) {
                            final cat = _categories.firstWhere((c) => c['id'].toString() == catId, orElse: () => {});
                            return Chip(
                              label: Text(cat['name'] ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontSize: 10)),
                              onDeleted: () => setState(() => _selectedCategoryIds.remove(catId)),
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
              if (_scope == 'item') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'เลือกสินค้า *',
                    border: const OutlineInputBorder(),
                    hintText: 'แตะเพื่อเลือก',
                    suffixIcon: _selectedProductIds.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('${_selectedProductIds.length} รายการ', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                          )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: '__select_all__', child: Text('✓ เลือกทั้งหมด')),
                    const DropdownMenuItem<String>(value: '__clear_all__', child: Text('✕ ล้างการเลือก')),
                    const DropdownMenuItem<String>(enabled: false, value: '', child: Divider()),
                    ..._products.map((product) {
                      final productId = product['id'].toString();
                      final isSelected = _selectedProductIds.contains(productId);
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
                      setState(() => _selectedProductIds = _products.map((p) => p['id'].toString()).toList());
                    } else if (value == '__clear_all__') {
                      setState(() => _selectedProductIds.clear());
                    } else if (value != null && value.isNotEmpty) {
                      setState(() {
                        if (_selectedProductIds.contains(value)) {
                          _selectedProductIds.remove(value);
                        } else {
                          _selectedProductIds.add(value);
                        }
                      });
                    }
                  },
                ),
                if (_selectedProductIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('สินค้าที่เลือก (${_selectedProductIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedProductIds.take(20).map((productId) {
                            final product = _products.firstWhere((p) => p['id'].toString() == productId, orElse: () => {});
                            return Chip(
                              label: Text(product['name']?.toString() ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontSize: 10)),
                              onDeleted: () => setState(() => _selectedProductIds.remove(productId)),
                              backgroundColor: AppDesignSystem.primary.withOpacity(0.2),
                              deleteIcon: const Icon(Icons.close, size: 14),
                            );
                          }).toList(),
                        ),
                        if (_selectedProductIds.length > 20)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('+ อีก ${_selectedProductIds.length - 20} รายการ', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _minCtrl,
                decoration: const InputDecoration(labelText: 'ยอดขั้นต่ำ (บาท)', border: OutlineInputBorder(), hintText: 'ไม่กำหนด'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _usageLimitCtrl,
                    decoration: const InputDecoration(labelText: 'จำกัดใช้ทั้งหมด', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _usageLimitPerCustomerCtrl,
                    decoration: const InputDecoration(labelText: 'ต่อคน', border: OutlineInputBorder(), hintText: 'ไม่จำกัด'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _usageLimitPerDayCtrl,
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
                  return _ChannelChip(value: channel.$1, label: channel.$2);
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
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule, size: 14),
                        label: Text(_startAt != null ? '${_startAt!.hour.toString().padLeft(2, '0')}:${_startAt!.minute.toString().padLeft(2, '0')}' : 'เวลาเริ่มต้น', style: const TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startAt ?? DateTime.now()));
                          if (time != null && _startAt != null) {
                            setState(() => _startAt = _startAt!.copyWith(hour: time.hour, minute: time.minute));
                          }
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: _startAt != null ? AppDesignSystem.primary : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                      ),
                    ),
                    if (_startAt != null)
                      InkWell(onTap: () => setState(() => _startAt = _startAt!.copyWith(hour: 0, minute: 0)), child: const Icon(Icons.refresh, size: 14, color: Colors.grey)),
                  ]),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule, size: 14),
                        label: Text(_endAt != null ? '${_endAt!.hour.toString().padLeft(2, '0')}:${_endAt!.minute.toString().padLeft(2, '0')}' : 'เวลาสิ้นสุด', style: const TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endAt ?? DateTime.now()));
                          if (time != null && _endAt != null) {
                            setState(() => _endAt = _endAt!.copyWith(hour: time.hour, minute: time.minute));
                          }
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: _endAt != null ? AppDesignSystem.danger : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                      ),
                    ),
                    if (_endAt != null)
                      InkWell(onTap: () => setState(() => _endAt = _endAt!.copyWith(hour: 23, minute: 59)), child: const Icon(Icons.refresh, size: 14, color: Colors.grey)),
                  ]),
                ),
              ]),
              CheckboxListTile(
                title: const Text('ซ้อนส่วนลดอื่นได้', style: TextStyle(fontSize: 13)),
                value: _stackable,
                onChanged: (v) => setState(() => _stackable = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SwitchListTile(
                title: Text('เปิดใช้งาน', style: TextStyle(fontSize: 13, color: _isActive ? AppDesignSystem.primary : Colors.grey)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppDesignSystem.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SwitchListTile(
                title: const Text('ต้องมีสินค้าในสต็อก', style: TextStyle(fontSize: 13)),
                value: _requireInStock,
                onChanged: (v) => setState(() => _requireInStock = v),
                activeColor: AppDesignSystem.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SwitchListTile(
                title: const Text('สินค้าผลิตต้องมีวัตถุดิบเพียงพอ', style: TextStyle(fontSize: 13)),
                value: _requireSufficientIngredients,
                onChanged: (v) => setState(() => _requireSufficientIngredients = v),
                activeColor: AppDesignSystem.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SwitchListTile(
                title: const Text('รวมรายการที่อยู่ในขั้นตอนจัดซื้อ', style: TextStyle(fontSize: 13)),
                value: _includePendingProcurement,
                onChanged: (v) => setState(() => _includePendingProcurement = v),
                activeColor: AppDesignSystem.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text('แสดงในแถบคูปอง (หน้าคูปอง & โปรโมชัน)', style: TextStyle(fontSize: 13)),
                subtitle: const Text('ลูกค้าจะเห็นคูปองนี้ในหน้าคูปอง', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _showInCouponTab,
                onChanged: (v) => setState(() => _showInCouponTab = v),
                activeColor: Colors.orange,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SwitchListTile(
                title: const Text('แสดงใน POS (หน้าขาย)', style: TextStyle(fontSize: 13)),
                subtitle: const Text('พนักงานจะเห็นคูปองนี้ใน dialog เลือกส่วนลด', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _showInPosDiscountDialog,
                onChanged: (v) => setState(() => _showInPosDiscountDialog = v),
                activeColor: Colors.blue,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text('เปิดใช้โหมดคูปองรายวัน (ส่วนลด + สิทธิ์เข้าพื้นที่)', style: TextStyle(fontSize: 13)),
                subtitle: const Text('กำหนด quota ส่วนลดและการเข้าพื้นที่ในใบเดียวตามมาตรฐาน Phase 13'),
                value: _isDailyCoupon,
                onChanged: (v) => setState(() => _isDailyCoupon = v),
                activeColor: AppDesignSystem.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              if (_isDailyCoupon) _buildDailyCouponSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSubmit,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existing == null ? 'เพิ่ม' : 'บันทึก'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
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

  String _intToString(dynamic value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    if (value is String) return value;
    return '';
  }

  Map<String, dynamic> _buildTargetingRule() {
    if (!_isDailyCoupon) {
      return const {};
    }

    final entryLimit = int.tryParse(_entryLimitCtrl.text.trim());
    final discountLimit = int.tryParse(_discountLimitCtrl.text.trim());
    final discountPerCoupon = int.tryParse(_discountLimitPerCouponCtrl.text.trim());
    final groupSize = int.tryParse(_groupSizeCtrl.text.trim());
    final idempotency = int.tryParse(_idempotencyWindowCtrl.text.trim());
    final replay = int.tryParse(_qrReplayWindowCtrl.text.trim());

    final map = <String, dynamic>{
      'daily_unified_enabled': true,
      'event_types': const ['discount', 'entry'],
      'coupon_audience': _dailyAudience,
      'entry_zone_mode': 'single',
      'entry_area_name': _entryAreaCtrl.text.trim(),
      'entry_limit_per_day': entryLimit,
      'discount_limit_per_day': discountLimit,
      'discount_limit_per_coupon': discountPerCoupon,
      'entry_requires_same_day': _entryRequiresSameDay,
      'allow_entry_before_discount': _allowEntryBeforeDiscount,
      'allow_discount_without_entry': _allowDiscountWithoutEntry,
      'reset_at_local_midnight': _resetAtLocalMidnight,
      'idempotency_window_seconds': idempotency,
      'qr_replay_window_seconds': replay,
      'key_version': _keyVersionCtrl.text.trim().isEmpty ? null : _keyVersionCtrl.text.trim(),
    };

    if (_dailyAudience == 'group' && groupSize != null) {
      map['group_size'] = groupSize;
    }

    map.removeWhere((key, value) => value == null);
    return map;
  }

  Widget _buildDailyCouponSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppDesignSystem.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'กำหนด quota และความปลอดภัยของคูปองรายวัน พร้อมให้สิทธิ์ส่วนลดและการเข้า-ออกพื้นที่ในคูปองใบเดียว',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _dailyAudience,
          decoration: const InputDecoration(labelText: 'ประเภทผู้ใช้คูปอง', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'individual', child: Text('รายบุคคล')),
            DropdownMenuItem(value: 'group', child: Text('รายกลุ่ม')),
          ],
          onChanged: (value) => setState(() => _dailyAudience = value ?? 'individual'),
        ),
        if (_dailyAudience == 'group') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _groupSizeCtrl,
            decoration: const InputDecoration(labelText: 'จำนวนสมาชิกในกลุ่ม (คน) *', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _entryAreaCtrl,
          decoration: const InputDecoration(labelText: 'ชื่อพื้นที่ (สำหรับสิทธิ์เข้าพื้นที่) *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _entryLimitCtrl,
                decoration: const InputDecoration(labelText: 'เข้าได้ต่อวัน (ครั้ง) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _discountLimitCtrl,
                decoration: const InputDecoration(labelText: 'ใช้ส่วนลดต่อวัน (ครั้ง) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _discountLimitPerCouponCtrl,
          decoration: const InputDecoration(labelText: 'จำกัดจำนวนใช้ต่อคูปอง (ทั้งหมด)', border: OutlineInputBorder(), hintText: 'ปล่อยว่าง = ไม่จำกัด'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _idempotencyWindowCtrl,
                decoration: const InputDecoration(labelText: 'Idempotency Window (วินาที) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _qrReplayWindowCtrl,
                decoration: const InputDecoration(labelText: 'QR Replay Window (วินาที) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _keyVersionCtrl,
          decoration: const InputDecoration(labelText: 'Key Version (optional)', border: OutlineInputBorder(), hintText: 'เช่น v3'),
        ),
        SwitchListTile(
          title: const Text('ต้องใช้สิทธิ์ภายในวันเดียวกัน'),
          value: _entryRequiresSameDay,
          onChanged: (v) => setState(() => _entryRequiresSameDay = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          title: const Text('อนุญาตให้สแกนเข้าพื้นที่ก่อนใช้ส่วนลด'),
          value: _allowEntryBeforeDiscount,
          onChanged: (v) => setState(() => _allowEntryBeforeDiscount = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          title: const Text('อนุญาตใช้ส่วนลดโดยไม่ต้องเข้าเขตก่อน'),
          value: _allowDiscountWithoutEntry,
          onChanged: (v) => setState(() => _allowDiscountWithoutEntry = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          title: const Text('รีเซ็ตโควตาตามเที่ยงคืนของพื้นที่ (timezone tenant)'),
          value: _resetAtLocalMidnight,
          onChanged: (v) => setState(() => _resetAtLocalMidnight = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }
}

class CouponFormResult {
  const CouponFormResult({
    required this.name,
    required this.description,
    required this.discountType,
    required this.scope,
    required this.value,
    this.maxDiscount,
    this.minAmount,
    required this.stackable,
    required this.isActive,
    required this.applicableCategoryIds,
    required this.applicableProductIds,
    this.couponCode,
    this.usageLimit,
    this.usageLimitPerCustomer,
    this.usageLimitPerDay,
    required this.lifecycleStatus,
    required this.applicableChannels,
    required this.requireInStock,
    required this.requireSufficientIngredients,
    required this.includePendingProcurement,
    required this.showInCouponTab,
    required this.showInPosDiscountDialog,
    this.startAt,
    this.endAt,
    this.targetingRule = const {},
  });

  final String name;
  final String description;
  final String discountType;
  final String scope;
  final double value;
  final double? maxDiscount;
  final double? minAmount;
  final bool stackable;
  final bool isActive;
  final List<String> applicableCategoryIds;
  final List<String> applicableProductIds;
  final String? couponCode;
  final int? usageLimit;
  final int? usageLimitPerCustomer;
  final int? usageLimitPerDay;
  final String lifecycleStatus;
  final List<String> applicableChannels;
  final bool requireInStock;
  final bool requireSufficientIngredients;
  final bool includePendingProcurement;
  final bool showInCouponTab;
  final bool showInPosDiscountDialog;
  final DateTime? startAt;
  final DateTime? endAt;
  final Map<String, dynamic> targetingRule;
}

class _ChannelChip extends StatefulWidget {
  const _ChannelChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  State<_ChannelChip> createState() => _ChannelChipState();
}

class _ChannelChipState extends State<_ChannelChip> {
  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_CouponFormDialogState>();
    final selected = state!._applicableChannels.contains(widget.value);
    return FilterChip(
      label: Text(widget.label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (v) {
        state.setState(() {
          if (v) {
            state._applicableChannels.add(widget.value);
          } else {
            state._applicableChannels.remove(widget.value);
          }
        });
      },
    );
  }
}
