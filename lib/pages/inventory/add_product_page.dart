import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/inventory_service.dart';

enum ItemType { product, ingredient }

class AddProductPage extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> recipes;
  final List<Map<String, dynamic>> shelves;
  final List<Map<String, dynamic>> warehouses;

  const AddProductPage({
    super.key,
    required this.categories,
    required this.units,
    required this.recipes,
    required this.shelves,
    required this.warehouses,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _productInfoCardKey = GlobalKey();
  final _nameFocusNode = FocusNode();
  final _nameController = TextEditingController();
  final _productionQtyController = TextEditingController(text: '1');
  final _qtyController = TextEditingController(text: '0');
  final _minQtyController = TextEditingController(text: '0');
  final _taxRateController = TextEditingController(text: '7');

  // Toggle: สินค้า / วัตถุดิบ
  ItemType _itemType = ItemType.product;

  String? _selectedCategoryId;
  String? _selectedUnitId;
  String? _selectedShelfId;
  String? _selectedWarehouseId;
  bool _isSaving = false;
  bool _showAdditionalFields = false;
  bool _showCategoryError = false;

  // Tax
  bool _isTaxExempt = false; // true = ยกเว้นภาษี
  String _taxInclusion = 'included'; // 'included' = รวมภาษี, 'excluded' = ยังไม่รวมภาษี

  // Production from recipe
  String? _selectedRecipeId;
  String _manualProductNameBeforeRecipe = '';

  // Image
  static const int _maxImageSlots = 5;
  final List<Uint8List?> _imageSlots = List<Uint8List?>.filled(_maxImageSlots, null);
  final List<String?> _imageFileNames = List<String?>.filled(_maxImageSlots, null);

  // Category auto-suggest
  List<Map<String, dynamic>> _suggestedCategories = [];

  // Accounting info from selected category
  String? _categoryInvAccount;
  String? _categoryRevAccount;
  String? _categoryCostAccount;

  // Tax rule engine state
  bool _isTaxAutoMode = true;
  bool _isResolvingTaxRule = false;
  Map<String, dynamic>? _resolvedTaxRule;

  static const _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  // Dynamic labels
  String get _typeLabel => _itemType == ItemType.product ? 'สินค้า' : 'วัตถุดิบ';
  String get _itemTypeValue => _itemType == ItemType.product ? 'product' : 'ingredient';
  bool get _isProducedFromRecipe => _itemType == ItemType.product && _selectedRecipeId != null;

  int? get _primaryImageIndex {
    for (var i = 0; i < _imageSlots.length; i++) {
      if (_imageSlots[i] != null) return i;
    }
    return null;
  }

  Uint8List? get _primaryImageBytes {
    final index = _primaryImageIndex;
    return index == null ? null : _imageSlots[index];
  }

  String? get _primaryImageFileName {
    final index = _primaryImageIndex;
    return index == null ? null : _imageFileNames[index];
  }

  List<Map<String, dynamic>> get _recipesSortedByUsage {
    final recipes = List<Map<String, dynamic>>.from(widget.recipes);
    recipes.sort((a, b) {
      final aUpdated = a['updated_at']?.toString() ?? '';
      final bUpdated = b['updated_at']?.toString() ?? '';
      final cmp = bUpdated.compareTo(aUpdated);
      if (cmp != 0) return cmp;
      return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
    });
    return recipes;
  }

  bool get _hasUnsavedChanges {
    return _nameController.text.trim().isNotEmpty ||
        _selectedCategoryId != null ||
        _selectedUnitId != null ||
        _selectedShelfId != null ||
        _selectedWarehouseId != null ||
        (_qtyController.text.trim().isNotEmpty && _qtyController.text.trim() != '0') ||
        (_minQtyController.text.trim().isNotEmpty && _minQtyController.text.trim() != '0') ||
        _itemType != ItemType.product ||
        _selectedRecipeId != null ||
        _productionQtyController.text.trim() != '1' ||
        !_isTaxAutoMode ||
        _isTaxExempt ||
        _taxInclusion != 'included' ||
        _taxRateController.text.trim() != '7' ||
        _imageSlots.any((img) => img != null);
  }

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _scrollProductInfoToTop();
      }
    });
  }

  void _scrollProductInfoToTop() {
    final context = _productInfoCardKey.currentContext;
    if (context == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleRecipeChanged(String? recipeId) {
    if (recipeId == null) {
      setState(() {
        _selectedRecipeId = null;
        _nameController.text = _manualProductNameBeforeRecipe;
        _productionQtyController.text = '1';
      });
      _updateCategorySuggestions(_manualProductNameBeforeRecipe);
      return;
    }

    if (_selectedRecipeId == null) {
      _manualProductNameBeforeRecipe = _nameController.text.trim();
    }

    final recipe = widget.recipes.firstWhere(
      (r) => r['id'] == recipeId,
      orElse: () => <String, dynamic>{},
    );
    final recipeName = recipe['name'] as String? ?? '';
    final recipeUnit = (recipe['yield_unit'] as String? ?? '').trim();
    final matchedUnitId = _findUnitIdByRecipeUnit(recipeUnit);
    setState(() {
      _selectedRecipeId = recipeId;
      _nameController.text = recipeName;
      if (matchedUnitId != null) {
        _selectedUnitId = matchedUnitId;
      }
    });
    _updateCategorySuggestions(recipeName);
  }

  String? _findUnitIdByRecipeUnit(String recipeUnit) {
    if (recipeUnit.isEmpty) return null;
    final normalized = recipeUnit.toLowerCase();
    for (final unit in widget.units) {
      final name = (unit['name'] as String? ?? '').trim().toLowerCase();
      final abbreviation = (unit['abbreviation'] as String? ?? '').trim().toLowerCase();
      if (normalized == name || normalized == abbreviation) {
        return unit['id'] as String?;
      }
    }
    return null;
  }

  void _applyItemTypeTaxFallback(ItemType type) {
    if (type == ItemType.ingredient) {
      _isTaxExempt = true;
      _taxRateController.text = '0';
      _taxInclusion = 'excluded';
      return;
    }
    _isTaxExempt = false;
    _taxRateController.text = '7';
    _taxInclusion = 'included';
  }

  void _applyResolvedTaxRule(Map<String, dynamic> rule) {
    _isTaxExempt = rule['is_tax_exempt'] as bool? ?? false;
    final taxRate = (rule['tax_rate'] as num?)?.toDouble() ?? 0.0;
    _taxRateController.text =
        taxRate == taxRate.roundToDouble() ? taxRate.toStringAsFixed(0) : taxRate.toStringAsFixed(2);
    _taxInclusion = (rule['tax_inclusion'] as String?) ?? 'excluded';
  }

  Future<void> _resolveTaxRuleForSelection({bool forceApply = false}) async {
    if (_selectedCategoryId == null) return;

    setState(() => _isResolvingTaxRule = true);
    final resolved = await InventoryService.resolveTaxRuleForCategory(
      categoryId: _selectedCategoryId!,
      itemType: _itemTypeValue,
      effectiveDate: DateTime.now(),
    );
    if (!mounted) return;

    setState(() {
      _resolvedTaxRule = resolved;
      if (_isTaxAutoMode || forceApply) {
        _applyResolvedTaxRule(resolved);
      }
      _isResolvingTaxRule = false;
    });
  }

  Future<void> _handleItemTypeChanged(ItemType type) async {
    if (_itemType == type) return;
    setState(() {
      _itemType = type;
      _resolvedTaxRule = null;
      if (type == ItemType.ingredient) {
        _selectedRecipeId = null;
        _productionQtyController.text = '1';
      }
      if (_isTaxAutoMode && _selectedCategoryId == null) {
        _applyItemTypeTaxFallback(type);
      }
    });

    if (_isTaxAutoMode && _selectedCategoryId != null) {
      await _resolveTaxRuleForSelection(forceApply: true);
    }
  }

  Future<void> _handleCategorySelected(Map<String, dynamic> cat) async {
    setState(() {
      _selectedCategoryId = cat['id'] as String?;
      _categoryInvAccount = cat['inventory_account_code'] as String?;
      _categoryRevAccount = cat['revenue_account_code'] as String?;
      _categoryCostAccount = cat['cost_account_code'] as String?;
      _showCategoryError = false;
      _suggestedCategories = [];
    });

    if (_isTaxAutoMode) {
      await _resolveTaxRuleForSelection(forceApply: true);
    }
  }

  String? _validateNonNegativeNumber(String? value, String fieldName) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return 'กรุณากรอก$fieldNameเป็นตัวเลข';
    if (parsed < 0) return '$fieldNameต้องมากกว่าหรือเท่ากับ 0';
    return null;
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันออกจากหน้านี้'),
        content: Text('มีข้อมูลที่ยังไม่ได้บันทึก ต้องการออกจากหน้านี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('กลับไปแก้ไข'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ออกจากหน้า', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _handleCancel() async {
    final shouldDiscard = await _confirmDiscardChanges();
    if (!mounted || !shouldDiscard) return;
    Navigator.pop(context, false);
  }

  /// ค้นหาประเภทสินค้าที่ตรงกับชื่อที่พิมพ์
  void _updateCategorySuggestions(String productName) {
    if (productName.trim().isEmpty) {
      setState(() => _suggestedCategories = []);
      return;
    }

    if (productName.trim().length < 2) {
      setState(() => _suggestedCategories = []);
      return;
    }

    final input = productName.trim().toLowerCase();
    // แยกคำจากชื่อสินค้า
    final words = input.split(RegExp(r'[\s,./\-]+'))
        .where((w) => w.length >= 2)
        .toList();

    if (words.isEmpty) {
      setState(() => _suggestedCategories = []);
      return;
    }

    // คะแนนแต่ละ category
    final scored = <Map<String, dynamic>, int>{};
    for (final cat in widget.categories) {
      final catName = (cat['name'] as String? ?? '').toLowerCase();
      int score = 0;

      // ตรวจสอบชื่อ category ตรงกับคำค้นหา
      for (final word in words) {
        if (catName.contains(word) || word.contains(catName)) {
          score += 10;
        }
      }

      // ตรวจสอบชื่อสินค้าทั้งหมดตรงกับชื่อ category
      if (catName.length >= 2 && input.contains(catName)) {
        score += 15;
      }

      // ให้คะแนนเพิ่มสำหรับ category ระดับลึก (เฉพาะเจาะจงกว่า)
      if (score > 0) {
        final level = (cat['level'] as int?) ?? 1;
        score += level * 2;
      }

      if (score > 0) scored[cat] = score;
    }

    // เรียงตามคะแนนสูงสุด เอา top 3
    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _suggestedCategories = sorted
          .take(3)
          .map((e) => e.key)
          .toList();
    });
  }

  /// สร้าง breadcrumb path ของ category (เช่น สินค้า > การเกษตร > ข้าว)
  String _getCategoryPath(Map<String, dynamic> category) {
    final parentCode = category['parent_code'] as String?;
    if (parentCode == null) return category['name'] as String? ?? '';

    final parent = widget.categories.firstWhere(
      (c) => c['code'] == parentCode,
      orElse: () => <String, dynamic>{},
    );
    if (parent.isEmpty) return category['name'] as String? ?? '';

    final parentName = parent['name'] as String? ?? '';
    return '$parentName > ${category['name']}';
  }

  Widget _buildCategorySuggestions() {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: Colors.amber[700]),
              SizedBox(width: 4),
              Text(
                'ประเภทที่แนะนำ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _suggestedCategories.map((cat) {
              final name = cat['name'] as String? ?? '';
              final path = _getCategoryPath(cat);
              final hasAccounts = cat['inventory_account_code'] != null;

              return InkWell(
                onTap: () => _handleCategorySelected(cat),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label, size: 14, color: Colors.blue[600]),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          path != name ? path : name,
                          style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!hasAccounts) ...[
                        SizedBox(width: 4),
                        Icon(Icons.warning_amber, size: 12, color: Colors.orange[400]),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _productionQtyController.dispose();
    _qtyController.dispose();
    _minQtyController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('เพิ่มรายการสินค้าและวัตถุดิบ', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle: สินค้า / วัตถุดิบ
                _buildItemTypeToggle(),
                SizedBox(height: 12),
                // Card 1: ข้อมูลสินค้า/วัตถุดิบ
                _buildProductInfoCard(),
                SizedBox(height: 12),
                // Card 2: รูปภาพ
                _buildImageCard(),
                SizedBox(height: 12),
                // Quick mode / Additional details
                _buildAdditionalInfoToggle(),
                SizedBox(height: 12),
                AnimatedCrossFade(
                  firstChild: SizedBox.shrink(),
                  secondChild: Column(
                    children: [
                      _buildTaxCard(),
                      SizedBox(height: 12),
                      _buildStockLocationCard(),
                      SizedBox(height: 12),
                      _buildAccountInfoCard(),
                    ],
                  ),
                  crossFadeState: _showAdditionalFields ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: Duration(milliseconds: 200),
                ),
                SizedBox(height: 16),
                // ปุ่มบันทึก
                _buildActionButtons(),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoToggle() {
    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _showAdditionalFields = !_showAdditionalFields),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _showAdditionalFields ? Icons.expand_less : Icons.expand_more,
                color: Colors.blue[700],
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showAdditionalFields
                      ? 'ซ่อนข้อมูลเพิ่มเติม (ภาษี, สต็อก, บัญชี)'
                      : 'แสดงข้อมูลเพิ่มเติม (ไม่บังคับ)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Toggle: สินค้า / วัตถุดิบ =====
  Widget _buildItemTypeToggle() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ประเภทรายการ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    label: 'สินค้า',
                    icon: Icons.shopping_bag,
                    isSelected: _itemType == ItemType.product,
                    color: Colors.blue,
                    onTap: () => _handleItemTypeChanged(ItemType.product),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton(
                    label: 'วัตถุดิบ',
                    icon: Icons.eco,
                    isSelected: _itemType == ItemType.ingredient,
                    color: Colors.teal,
                    onTap: () => _handleItemTypeChanged(ItemType.ingredient),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey[600]),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Card 1: รูปภาพ =====
  Widget _buildImageCard() {
    final imageCount = _imageSlots.where((img) => img != null).length;
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รูปภาพ$_typeLabel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              'ไม่สามารถอัปโหลดรูปภาพ/วิดีโอที่ไม่ชัดเจนได้ กรุณาอัปโหลดรูปภาพ/วิดีโอที่เห็นตัวสินค้าอย่างชัดเจน',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[400],
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final slotSize = ((constraints.maxWidth - (spacing * (_maxImageSlots - 1))) / _maxImageSlots)
                    .clamp(40.0, 96.0);

                return Row(
                  children: List.generate(_maxImageSlots, (index) {
                    final hasImage = _imageSlots[index] != null;
                    return Padding(
                      padding: EdgeInsets.only(right: index == _maxImageSlots - 1 ? 0 : spacing),
                      child: GestureDetector(
                        onTap: () => _showImagePickerOptions(index),
                        child: Container(
                          width: slotSize,
                          height: slotSize,
                          decoration: BoxDecoration(
                            color: hasImage ? Colors.white : Colors.grey[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: hasImage ? Colors.red[400]! : Colors.grey[400]!,
                              width: 1.6,
                            ),
                          ),
                          child: hasImage
                              ? Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.memory(
                                        _imageSlots[index]!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => setState(() {
                                          _imageSlots[index] = null;
                                          _imageFileNames[index] = null;
                                        }),
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          child: Icon(Icons.close, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 18, color: Colors.grey[500]),
                                    SizedBox(height: 4),
                                    Text(
                                      '${index + 1}',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            SizedBox(height: 10),
            Text(
              'เพิ่มรูปได้สูงสุด $_maxImageSlots รูปต่อ 1 บทความ (เลือกแล้ว $imageCount/$_maxImageSlots)',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerOptions(int slotIndex) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Text('เลือกรูปภาพ$_typeLabel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.camera_alt, color: Colors.blue),
                  ),
                  title: Text('ถ่ายรูป'),
                  subtitle: Text('ใช้กล้องถ่ายรูป$_typeLabel'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera, slotIndex);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.photo_library, color: Colors.green),
                  ),
                  title: Text('เลือกจากแกลเลอรี'),
                  subtitle: Text('เลือกรูปภาพจากอัลบั้ม'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery, slotIndex);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, int slotIndex) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 45,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageSlots[slotIndex] = bytes;
          _imageFileNames[slotIndex] = pickedFile.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเลือกรูปภาพได้: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ===== Card 2: ข้อมูลสินค้า/วัตถุดิบ =====
  Widget _buildProductInfoCard() {
    return Card(
      key: _productInfoCardKey,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ข้อมูล$_typeLabel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // ชื่อ
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              readOnly: _itemType == ItemType.product && _isProducedFromRecipe,
              decoration: InputDecoration(
                labelText: 'ชื่อ$_typeLabel *',
                hintText: _itemType == ItemType.product
                    ? 'เช่น ข้าวหอมมะลิ ตราบัวเงิน 5 กก.'
                    : 'เช่น แป้งสาลี, น้ำตาลทราย',
                border: _inputBorder,
                filled: _itemType == ItemType.product && _isProducedFromRecipe,
                fillColor: _itemType == ItemType.product && _isProducedFromRecipe ? Colors.grey[100] : null,
                suffixIcon: _itemType == ItemType.product && _isProducedFromRecipe
                    ? Icon(Icons.lock_outline, size: 18, color: Colors.grey[600])
                    : null,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'กรุณากรอกชื่อ$_typeLabel';
                if (v.trim().length < 2) return 'ชื่อ$_typeLabelต้องมีอย่างน้อย 2 ตัวอักษร';
                return null;
              },
              textInputAction: TextInputAction.next,
              onTap: _scrollProductInfoToTop,
              onChanged: (value) {
                _updateCategorySuggestions(value);
                _scrollProductInfoToTop();
              },
            ),
            if (_itemType == ItemType.product && _isProducedFromRecipe) ...[
              SizedBox(height: 12),
              TextFormField(
                controller: _productionQtyController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                decoration: InputDecoration(
                  labelText: 'จำนวนการผลิต *',
                  hintText: 'เช่น 1, 10, 25.5',
                  border: _inputBorder,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                validator: (v) {
                  if (!_isProducedFromRecipe) return null;
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return 'กรุณากรอกจำนวนการผลิต';
                  final qty = double.tryParse(text);
                  if (qty == null) return 'จำนวนการผลิตต้องเป็นตัวเลข';
                  if (qty <= 0) return 'จำนวนการผลิตต้องมากกว่า 0';
                  return null;
                },
              ),
            ],
            // แนะนำประเภทอัตโนมัติ
            if (_suggestedCategories.isNotEmpty)
              _buildCategorySuggestions(),
            SizedBox(height: 12),
            // หน่วยนับ
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'หน่วยนับ *',
                border: _inputBorder,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              value: _selectedUnitId,
              items: widget.units.map((u) => DropdownMenuItem<String>(
                value: u['id'] as String?,
                child: Text('${u['name']} (${u['abbreviation']})'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedUnitId = v),
              validator: (v) => v == null ? 'กรุณาเลือกหน่วยนับ' : null,
            ),
            SizedBox(height: 12),
            // ประเภท
            _buildCategoryField(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryField() {
    final categories = widget.categories;
    final selectedCat = _selectedCategoryId != null
        ? categories.firstWhere((c) => c['id'] == _selectedCategoryId, orElse: () => <String, dynamic>{})
        : null;

    final displayText = selectedCat != null && selectedCat.isNotEmpty
        ? '${selectedCat['code']} \u00BB ${selectedCat['name']}'
        : null;

    return InkWell(
      onTap: () => _showCategoryBottomSheet(),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'ประเภท$_typeLabel *',
          border: _inputBorder,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedCategoryId != null)
                IconButton(
                  icon: Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() {
                    _selectedCategoryId = null;
                    _categoryInvAccount = null;
                    _categoryRevAccount = null;
                    _categoryCostAccount = null;
                    _resolvedTaxRule = null;
                    if (_isTaxAutoMode) {
                      _applyItemTypeTaxFallback(_itemType);
                    }
                  }),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_drop_down),
              ),
            ],
          ),
          errorText: _showCategoryError && _selectedCategoryId == null ? 'กรุณาเลือกประเภท$_typeLabel' : null,
        ),
        child: Text(
          displayText ?? 'เลือกประเภท$_typeLabel',
          style: TextStyle(
            color: displayText != null ? null : Colors.grey[600],
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ===== Card 3: ภาษี =====
  Widget _buildTaxCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ข้อมูลภาษี', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isTaxAutoMode,
              title: Text('คำนวณอัตโนมัติตามกฎภาษี', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                _isTaxAutoMode
                    ? 'ใช้ประเภทสินค้า + วันที่ปัจจุบันเพื่อแนะนำภาษีตามกฎที่ตั้งไว้'
                    : 'โหมดกำหนดเอง: ผู้ใช้งานแก้ภาษีด้วยตนเอง',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (enabled) async {
                setState(() => _isTaxAutoMode = enabled);
                if (!enabled) return;
                if (_selectedCategoryId != null) {
                  await _resolveTaxRuleForSelection(forceApply: true);
                } else {
                  setState(() => _applyItemTypeTaxFallback(_itemType));
                }
              },
            ),
            if (_isResolvingTaxRule)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('กำลังตรวจสอบกฎภาษี...', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              ),
            if (_resolvedTaxRule != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'กฎที่ใช้: ${_resolvedTaxRule!['rule_name'] ?? '-'}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue[900]),
                    ),
                    if ((_resolvedTaxRule!['legal_reference'] as String?)?.isNotEmpty == true)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'อ้างอิง: ${_resolvedTaxRule!['legal_reference']}',
                          style: TextStyle(fontSize: 11, color: Colors.blue[800]),
                        ),
                      ),
                    if (_resolvedTaxRule!['requires_manual_review'] == true)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'คำเตือน: กฎนี้เป็นคำแนะนำเบื้องต้น ควรตรวจสอบเอกสารภาษีจริงก่อนใช้งาน',
                          style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                        ),
                      ),
                  ],
                ),
              ),
            // Toggle ยกเว้นภาษี / มีภาษี
            Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    label: 'ยกเว้นภาษี',
                    icon: Icons.money_off,
                    isSelected: _isTaxExempt,
                    color: Colors.green,
                    onTap: _isTaxAutoMode ? () {} : () => setState(() => _isTaxExempt = true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton(
                    label: 'มีภาษี',
                    icon: Icons.receipt_long,
                    isSelected: !_isTaxExempt,
                    color: Colors.orange,
                    onTap: _isTaxAutoMode ? () {} : () => setState(() => _isTaxExempt = false),
                  ),
                ),
              ],
            ),
            // แสดงช่องกรอกภาษีเมื่อเลือก "มีภาษี"
            if (!_isTaxExempt) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _taxRateController,
                      decoration: InputDecoration(
                        labelText: 'อัตราภาษีขาย',
                        border: _inputBorder,
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      validator: (v) {
                        if (_isTaxExempt) return null;
                        final err = _validateNonNegativeNumber(v, 'อัตราภาษี');
                        if (err != null) return err;
                        final rate = double.tryParse(v?.trim() ?? '') ?? 0;
                        if (rate > 100) return 'อัตราภาษีต้องไม่เกิน 100%';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                      enabled: !_isTaxAutoMode,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'ราคาขาย',
                        border: _inputBorder,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      value: _taxInclusion,
                      items: [
                        DropdownMenuItem(value: 'excluded', child: Text('ยังไม่รวมภาษี')),
                        DropdownMenuItem(value: 'included', child: Text('รวมภาษีแล้ว')),
                      ],
                      onChanged: _isTaxAutoMode ? null : (v) => setState(() => _taxInclusion = v ?? 'excluded'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _taxInclusion == 'included'
                            ? 'ราคาขายที่ตั้งไว้จะรวมภาษี ${_taxRateController.text}% แล้ว'
                            : 'ราคาขายที่ตั้งไว้ยังไม่รวมภาษี ${_taxRateController.text}% ระบบจะคำนวณเพิ่มเมื่อขาย',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== Card 4: สต็อกและตำแหน่ง =====
  Widget _buildStockLocationCard() {
    // Filter shelves by selected warehouse
    final filteredShelves = _selectedWarehouseId != null
        ? widget.shelves.where((s) {
            final warehouse = s['warehouse'] as Map<String, dynamic>?;
            return warehouse != null && warehouse['id'] == _selectedWarehouseId;
          }).toList()
        : widget.shelves;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สต็อกและตำแหน่งจัดเก็บ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: InputDecoration(
                      labelText: 'จำนวนเริ่มต้น',
                      helperText: 'สต็อกเปิด',
                      border: _inputBorder,
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    validator: (v) => _validateNonNegativeNumber(v, 'จำนวนเริ่มต้น'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minQtyController,
                    decoration: InputDecoration(
                      labelText: 'จุดสั่งซื้อ',
                      helperText: 'แจ้งเตือนเมื่อต่ำกว่า',
                      border: _inputBorder,
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    validator: (v) => _validateNonNegativeNumber(v, 'จุดสั่งซื้อ'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // คลังสินค้า
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'คลังสินค้า',
                border: _inputBorder,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              value: _selectedWarehouseId,
              items: [
                DropdownMenuItem<String>(value: null, child: Text('— ไม่ระบุ', style: TextStyle(color: Colors.grey[600]))),
                ...widget.warehouses.map((w) => DropdownMenuItem<String>(
                  value: w['id'] as String?,
                  child: Text(w['name'] as String? ?? ''),
                )),
              ],
              onChanged: (v) => setState(() {
                _selectedWarehouseId = v;
                _selectedShelfId = null;
              }),
            ),
            SizedBox(height: 12),
            // ชั้นวางสินค้า
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'ชั้นวางสินค้า',
                border: _inputBorder,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              value: _selectedShelfId,
              items: [
                DropdownMenuItem<String>(value: null, child: Text('— ไม่ระบุ', style: TextStyle(color: Colors.grey[600]))),
                ...filteredShelves.map((s) {
                  final warehouse = s['warehouse'] as Map<String, dynamic>?;
                  final warehouseName = warehouse?['name'] as String? ?? '';
                  return DropdownMenuItem<String>(
                    value: s['id'] as String?,
                    child: Text('${s['code']} ($warehouseName)'),
                  );
                }),
              ],
              onChanged: filteredShelves.isEmpty ? null : (v) => setState(() => _selectedShelfId = v),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Card 5: ข้อมูลบัญชี =====
  Widget _buildAccountInfoCard() {
    final hasCat = _selectedCategoryId != null;
    final hasAccounts = _categoryInvAccount != null;

    return Card(
      elevation: 2,
      color: hasAccounts ? Colors.green[50] : (hasCat ? Colors.orange[50] : null),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, size: 20, color: hasAccounts ? Colors.green[700] : Colors.grey[600]),
                SizedBox(width: 8),
                Text('ข้อมูลบัญชี', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            if (!hasCat)
              _buildInfoRow('เลือกประเภท$_typeLabelเพื่อดูบัญชีที่ผูกไว้', Icons.info_outline, Colors.grey)
            else if (!hasAccounts)
              _buildInfoRow('ประเภทนี้ยังไม่ได้กำหนดบัญชี — ตั้งค่าภายหลังในหน้าจัดการประเภท', Icons.warning_amber, Colors.orange)
            else ...[
              _buildAccountTableRow(_itemType == ItemType.product ? 'สินค้าคงเหลือ' : 'วัตถุดิบคงเหลือ', _categoryInvAccount!, 'Dr.'),
              Divider(height: 1),
              _buildAccountTableRow('รายได้ขาย', _categoryRevAccount ?? '-', 'Cr.'),
              Divider(height: 1),
              _buildAccountTableRow('ต้นทุนขาย', _categoryCostAccount ?? '-', 'Dr.'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'เมื่อขาย$_typeLabel ระบบจะบันทึกบัญชีอัตโนมัติ:\n'
                        'Dr. ลูกหนี้/เงินสด  |  Cr. $_categoryRevAccount\n'
                        'Dr. $_categoryCostAccount  |  Cr. $_categoryInvAccount',
                        style: TextStyle(fontSize: 11, color: Colors.blue[800], height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
      ],
    );
  }

  Widget _buildAccountTableRow(String label, String code, String side) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(side, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: side == 'Dr.' ? Colors.blue[700] : Colors.green[700]))),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13))),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(code, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  // ===== ปุ่มบันทึก =====
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleCancel,
            icon: Icon(Icons.close),
            label: Text('ยกเลิก'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.save),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก$_typeLabel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ===== Category Dialog (Top) =====
  void _showCategoryBottomSheet() {
    final categories = widget.categories;
    final searchController = TextEditingController();
    bool didAutoScrollToSelected = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchController.text.toLowerCase();
            final filtered = (query.isEmpty
                ? categories
                : categories.where((c) {
                    final name = (c['name'] as String? ?? '').toLowerCase();
                    final code = (c['code'] as String? ?? '').toLowerCase();
                    return name.contains(query) || code.contains(query);
                  }).toList())
              ..sort((a, b) {
                final aAccount = (a['inventory_account_code'] as String? ??
                        a['revenue_account_code'] as String? ??
                        a['cost_account_code'] as String? ??
                        '')
                    .trim();
                final bAccount = (b['inventory_account_code'] as String? ??
                        b['revenue_account_code'] as String? ??
                        b['cost_account_code'] as String? ??
                        '')
                    .trim();

                final aHasAccount = aAccount.isNotEmpty;
                final bHasAccount = bAccount.isNotEmpty;
                if (aHasAccount != bHasAccount) return aHasAccount ? -1 : 1;

                final accountCompare = aAccount.compareTo(bAccount);
                if (accountCompare != 0) return accountCompare;

                final aCode = (a['code'] as String? ?? '').trim();
                final bCode = (b['code'] as String? ?? '').trim();
                final codeCompare = aCode.compareTo(bCode);
                if (codeCompare != 0) return codeCompare;

                final aName = (a['name'] as String? ?? '').trim();
                final bName = (b['name'] as String? ?? '').trim();
                return aName.compareTo(bName);
              });
            final selectedTileKey = GlobalKey();
            final screenHeight = MediaQuery.of(ctx).size.height;
            final topInset = MediaQuery.of(ctx).padding.top;
            final bottomInset = MediaQuery.of(ctx).padding.bottom;

            final hasSelectedInFiltered = _selectedCategoryId != null &&
                filtered.any((c) => c['id'] == _selectedCategoryId);
            if (!didAutoScrollToSelected && hasSelectedInFiltered) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final selectedContext = selectedTileKey.currentContext;
                if (selectedContext != null) {
                  Scrollable.ensureVisible(
                    selectedContext,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: 0.5,
                  );
                }
              });
              didAutoScrollToSelected = true;
            }

            return SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: EdgeInsets.fromLTRB(12, topInset > 0 ? 8 : 12, 12, 12 + bottomInset),
                    height: screenHeight * 0.82,
                    constraints: BoxConstraints(maxHeight: screenHeight - (topInset + bottomInset + 24)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 14, 8, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('เลือกประเภท$_typeLabel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'ค้นหาประเภท...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final cat = filtered[i];
                              final level = (cat['level'] as int?) ?? 1;
                              final indent = (level - 1) * 16.0;
                              final code = cat['code'] as String? ?? '';
                              final name = cat['name'] as String? ?? '';
                              final isSelected = cat['id'] == _selectedCategoryId;
                              final hasAccounts = cat['inventory_account_code'] != null;

                              return InkWell(
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await _handleCategorySelected(cat);
                                },
                                child: Container(
                                  key: isSelected ? selectedTileKey : null,
                                  padding: EdgeInsets.only(left: 16 + indent, right: 16, top: 10, bottom: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue[50] : null,
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        level <= 2 ? Icons.folder : (level <= 4 ? Icons.folder_open : Icons.label_outline),
                                        size: 18,
                                        color: level <= 2 ? Colors.blue : (level <= 3 ? Colors.teal : Colors.grey[600]),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$code  $name',
                                          style: TextStyle(
                                            fontSize: level <= 2 ? 14.0 : 13.0,
                                            fontWeight: level <= 3 ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (!hasAccounts)
                                        Tooltip(
                                          message: 'ยังไม่ได้กำหนดบัญชี',
                                          child: Icon(Icons.warning_amber, size: 16, color: Colors.orange[400]),
                                        ),
                                      if (isSelected)
                                        Icon(Icons.check_circle, size: 20, color: Colors.blue),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===== Save =====
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      setState(() => _showCategoryError = true);
      return;
    }

    setState(() {
      _showCategoryError = false;
    });

    setState(() => _isSaving = true);

    try {
      final taxRate = _isTaxExempt ? 0.0 : (double.tryParse(_taxRateController.text) ?? 0);

      final ok = await InventoryService.addProduct(
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        unitId: _selectedUnitId!,
        shelfId: _selectedShelfId,
        quantity: double.tryParse(_qtyController.text) ?? 0,
        minQuantity: double.tryParse(_minQtyController.text) ?? 0,
        price: 0,
        cost: 0,
        itemType: _itemType == ItemType.product ? 'product' : 'ingredient',
        isTaxExempt: _isTaxExempt,
        taxRate: taxRate,
        taxInclusion: _taxInclusion,
        imageBytes: _primaryImageBytes,
        imageFileName: _primaryImageFileName,
      );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เพิ่ม$_typeLabel "${_nameController.text.trim()}" สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่ม$_typeLabelไม่สำเร็จ กรุณาลองใหม่'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
