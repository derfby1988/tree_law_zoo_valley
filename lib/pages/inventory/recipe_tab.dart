import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/inventory_service.dart';

class RecipeTab extends StatefulWidget {
  const RecipeTab({super.key});

  @override
  State<RecipeTab> createState() => _RecipeTabState();
}

class _RecipeTabState extends State<RecipeTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ทั้งหมด';

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _recipeCategories = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        InventoryService.getRecipes(),
        InventoryService.getRecipeCategories(),
        InventoryService.getUnitsSortedByRecipeUsage(),
        InventoryService.getProducts(),
      ]);
      setState(() {
        _recipes = results[0];
        _recipeCategories = results[1];
        _units = results[2];
        _products = results[3];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e'; _isLoading = false; });
    }
  }

  // ดึงข้อมูลส่วนผสมจาก recipe ที่ได้จาก Supabase
  List<Map<String, dynamic>> _getIngredients(Map<String, dynamic> recipe) {
    final raw = recipe['ingredients'];
    if (raw == null || raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw);
  }

  String _getIngName(Map<String, dynamic> ing) => ing['product']?['name'] ?? '-';
  double _getIngQty(Map<String, dynamic> ing) => (ing['quantity'] as num?)?.toDouble() ?? 0;
  String _getIngUnit(Map<String, dynamic> ing) => ing['product']?['unit']?['abbreviation'] ?? '';
  double _getIngStock(Map<String, dynamic> ing) => (ing['product']?['quantity'] as num?)?.toDouble() ?? 0;
  String _getIngProductId(Map<String, dynamic> ing) => ing['product']?['id'] ?? '';

  String _getCategoryName(Map<String, dynamic> recipe) => recipe['category']?['name'] ?? '-';
  double _getYield(Map<String, dynamic> recipe) => (recipe['yield_quantity'] as num?)?.toDouble() ?? 1;
  String _getYieldUnit(Map<String, dynamic> recipe) => recipe['yield_unit'] ?? 'ชิ้น';
  double _getCost(Map<String, dynamic> recipe) => (recipe['cost'] as num?)?.toDouble() ?? 0;
  double _getPrice(Map<String, dynamic> recipe) => (recipe['price'] as num?)?.toDouble() ?? 0;

  bool _canProduceRecipe(Map<String, dynamic> recipe) {
    final ings = _getIngredients(recipe);
    if (ings.isEmpty) return false;
    return ings.every((ing) => _getIngStock(ing) >= _getIngQty(ing));
  }

  int _getMaxBatch(Map<String, dynamic> recipe) {
    final ings = _getIngredients(recipe);
    if (ings.isEmpty) return 0;
    int maxBatch = 999999;
    for (final ing in ings) {
      final qty = _getIngQty(ing);
      final stock = _getIngStock(ing);
      if (qty <= 0) continue;
      final batch = (stock / qty).floor();
      if (batch < maxBatch) maxBatch = batch;
    }
    return maxBatch == 999999 ? 0 : maxBatch;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red),
        SizedBox(height: 8),
        Text(_errorMessage!, style: TextStyle(color: Colors.red)),
        SizedBox(height: 12),
        ElevatedButton(onPressed: _loadData, child: Text('ลองใหม่')),
      ])));
    }

    var filtered = _selectedCategory == 'ทั้งหมด'
        ? _recipes
        : _recipes.where((r) => _getCategoryName(r) == _selectedCategory).toList();
    final search = _searchController.text.toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered.where((r) => (r['name'] as String).toLowerCase().contains(search)).toList();
    }

    final sortedCategoryNames = () {
      // นับจำนวนสูตรในแต่ละประเภท
      final counts = <String, int>{};
      for (final cat in _recipeCategories) {
        final catName = cat['name'] as String? ?? '';
        counts[catName] = _recipes.where((r) => r['recipe_category_id'] == cat['id']).length;
      }
      // กรองเฉพาะประเภทที่มีสูตรอาหาร และเรียงตามจำนวนสูตร (มากไปน้อย)
      final sorted = _recipeCategories
        .where((c) => counts[c['name'] as String? ?? ''] != null && counts[c['name'] as String? ?? '']! > 0)
        .map((c) => c['name'] as String)
        .toList();
      sorted.sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
      return ['ทั้งหมด', ...sorted];
    }();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndFilter(sortedCategoryNames),
            SizedBox(height: 16),
            _buildSummaryCards(),
            SizedBox(height: 16),
            _buildRecipeList(filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(List<String> categoryNames) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาสูตรอาหาร...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isNarrow ? constraints.maxWidth : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: categoryNames.contains(_selectedCategory) ? _selectedCategory : 'ทั้งหมด',
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'ประเภท',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: categoryNames.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (value) => setState(() => _selectedCategory = value!),
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showManageCategoriesDialog(),
                            icon: Icon(Icons.settings, size: 20),
                            tooltip: 'จัดการประเภท',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              padding: EdgeInsets.all(10),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (isNarrow)
                            IconButton(
                              onPressed: () => _showAddRecipeDialog(),
                              icon: Icon(Icons.add, color: Colors.white),
                              tooltip: 'เพิ่มสูตร',
                              style: IconButton.styleFrom(
                                backgroundColor: Color(0xFF2E7D32),
                                padding: EdgeInsets.all(10),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => _showAddRecipeDialog(),
                              icon: Icon(Icons.add, size: 18),
                              label: Text('เพิ่มสูตร'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalRecipes = _recipes.length;
    final canProduce = _recipes.where((r) => _canProduceRecipe(r)).length;
    double avgMargin = 0;
    if (_recipes.isNotEmpty) {
      final margins = _recipes.map((r) {
        final cost = _getCost(r);
        final price = _getPrice(r);
        final y = _getYield(r);
        final revenue = price * y;
        return revenue > 0 ? ((revenue - cost) / revenue) * 100 : 0.0;
      }).toList();
      avgMargin = margins.reduce((a, b) => a + b) / margins.length;
    }

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('สูตรทั้งหมด', '$totalRecipes', Colors.blue, Icons.menu_book)),
        SizedBox(width: 8),
        Expanded(child: _buildSummaryCard('ผลิตได้', '$canProduce', Colors.green, Icons.check_circle)),
        SizedBox(width: 8),
        Expanded(child: _buildSummaryCard('กำไรเฉลี่ย', '${avgMargin.toStringAsFixed(0)}%', Colors.orange, Icons.trending_up)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeList(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Column(children: [
            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text('ไม่พบสูตรอาหาร', style: TextStyle(color: Colors.grey[600])),
          ])),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('รายการสูตรอาหาร (${filtered.length} สูตร)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        ...filtered.map((recipe) => _buildRecipeCard(recipe)).toList(),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final ingredients = _getIngredients(recipe);
    final canProduce = _canProduceRecipe(recipe);
    final maxBatch = _getMaxBatch(recipe);
    final cost = _getCost(recipe);
    final price = _getPrice(recipe);
    final y = _getYield(recipe);
    final yieldUnit = _getYieldUnit(recipe);
    final profit = price * y - cost;
    final catName = _getCategoryName(recipe);

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: canProduce ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.restaurant_menu, color: canProduce ? Colors.green : Colors.red),
        ),
        title: Text(recipe['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildChip(catName, Colors.blue),
            _buildChip('ได้ ${y.toStringAsFixed(y == y.roundToDouble() ? 0 : 1)} $yieldUnit', Colors.purple),
            if (canProduce) _buildChip('ผลิตได้ $maxBatch ชุด', Colors.green)
            else _buildChip('วัตถุดิบไม่พอ', Colors.red),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCostInfo('ต้นทุน/ชุด', '${cost.toStringAsFixed(0)}', Colors.red),
                      _buildCostInfo('ราคาขาย/ชิ้น', '${price.toStringAsFixed(0)}', Colors.blue),
                      _buildCostInfo('กำไร/ชุด', '${profit.toStringAsFixed(0)}', Colors.green),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text('ส่วนผสม (${ingredients.length} รายการ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 8),
                ...ingredients.map((ing) {
                  final stock = _getIngStock(ing);
                  final qty = _getIngQty(ing);
                  final hasEnough = stock >= qty;
                  return Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasEnough ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: hasEnough ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(hasEnough ? Icons.check_circle_outline : Icons.warning_amber, size: 18, color: hasEnough ? Colors.green : Colors.red),
                        SizedBox(width: 8),
                        Expanded(child: Text(_getIngName(ing))),
                        Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} ${_getIngUnit(ing)}', style: TextStyle(fontWeight: FontWeight.w500)),
                        SizedBox(width: 12),
                        Text('(คลัง: ${stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 1)})', style: TextStyle(color: hasEnough ? Colors.grey[600] : Colors.red, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canProduce ? () => _showProduceDialog(recipe) : null,
                        icon: Icon(Icons.play_arrow),
                        label: Text('ผลิตสินค้า'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(onPressed: () => _showEditRecipeDialog(recipe), icon: Icon(Icons.edit, color: Colors.blue), tooltip: 'แก้ไขสูตร'),
                    IconButton(onPressed: () => _showDeleteConfirmDialog(recipe), icon: Icon(Icons.delete, color: Colors.red), tooltip: 'ลบสูตร'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildCostInfo(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  // === Dialogs ===

  void _showProduceDialog(Map<String, dynamic> recipe) {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController(text: '1');
    final maxBatch = _getMaxBatch(recipe);
    final ingredients = _getIngredients(recipe);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.play_arrow, color: Colors.green), SizedBox(width: 8), Expanded(child: Text('ผลิต: ${recipe['name']}'))]),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('ผลิตได้สูงสุด $maxBatch ชุด (ได้ ${(maxBatch * _getYield(recipe)).toStringAsFixed(0)} ${_getYieldUnit(recipe)})', style: TextStyle(fontSize: 13, color: Colors.blue[800]))),
                    ]),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: qtyController,
                    decoration: InputDecoration(labelText: 'จำนวนชุดที่ต้องการผลิต *', border: OutlineInputBorder(), suffixText: 'ชุด'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'กรุณากรอกจำนวน';
                      final n = int.tryParse(value);
                      if (n == null || n <= 0) return 'กรุณากรอกจำนวนที่ถูกต้อง';
                      if (n > maxBatch) return 'วัตถุดิบไม่เพียงพอ (สูงสุด $maxBatch ชุด)';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Text('วัตถุดิบที่จะถูกตัด:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ...ingredients.map((ing) {
                    final qty = _getIngQty(ing);
                    final batchQty = int.tryParse(qtyController.text) ?? 1;
                    final totalUse = qty * batchQty;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(child: Text(_getIngName(ing))),
                        Text('-${totalUse.toStringAsFixed(2)} ${_getIngUnit(ing)}', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                      ]),
                    );
                  }).toList(),
                  Divider(),
                  Row(children: [
                    Expanded(child: Text('สินค้าที่จะได้:', style: TextStyle(fontWeight: FontWeight.bold))),
                    Text('+${((int.tryParse(qtyController.text) ?? 1) * _getYield(recipe)).toStringAsFixed(0)} ${_getYieldUnit(recipe)}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton.icon(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState?.validate() != true) return;
                setDialogState(() => isLoading = true);
                final batchQty = int.tryParse(qtyController.text) ?? 1;
                final ingData = ingredients.map((ing) => {
                  'product_id': _getIngProductId(ing),
                  'quantity': _getIngQty(ing),
                  'current_stock': _getIngStock(ing),
                }).toList();
                final ok = await InventoryService.produceFromRecipe(
                  recipeId: recipe['id'],
                  batchQuantity: batchQty,
                  ingredients: ingData,
                  yieldQuantity: batchQty * _getYield(recipe),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ผลิต ${recipe['name']} $batchQty ชุด สำเร็จ'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red));
                  }
                }
              },
              icon: isLoading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.play_arrow),
              label: Text('ยืนยันผลิต'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRecipeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedCategoryId;
    String? selectedYieldUnit = 'จาน';  // Default หน่วยนับ
    bool isLoading = false;
    String? nameError;
    
    // Image state
    File? selectedImageFile;
    String? uploadedImageUrl;
    bool isUploadingImage = false;

    // Ingredients state - เปลี่ยนเป็น autocomplete
    List<Map<String, dynamic>> ingredients = [];
    List<Map<String, dynamic>> searchResults = [];
    final ingredientSearchController = TextEditingController();
    String? selectedProductId;
    String? selectedIngredientName;
    bool? selectedIngredientIsNew;
    String? selectedIngredientUnit;
    String? selectedIngredientCategoryId;  // หมวดหมู่ที่เลือก
    String? selectedIngredientCategoryName;  // ชื่อหมวดหมู่
    final quantityController = TextEditingController(text: '1');

    // เรียง categories ตามการใช้งานล่าสุดในสูตร
    List<Map<String, dynamic>> getSortedDialogCategories() {
      final sorted = List<Map<String, dynamic>>.from(_recipeCategories);
      final usageMap = <String, String>{};
      for (final r in _recipes) {
        final catId = r['recipe_category_id'] as String? ?? '';
        final updatedAt = r['updated_at']?.toString() ?? '';
        if (catId.isNotEmpty && (!usageMap.containsKey(catId) || updatedAt.compareTo(usageMap[catId]!) > 0)) {
          usageMap[catId] = updatedAt;
        }
      }
      sorted.sort((a, b) {
        final aUsage = usageMap[a['id']];
        final bUsage = usageMap[b['id']];
        if (aUsage != null && bUsage != null) return bUsage.compareTo(aUsage);
        if (aUsage != null) return -1;
        if (bUsage != null) return 1;
        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });
      return sorted;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sortedCategories = getSortedDialogCategories();

          // Initialize default unit to 'กรัม' on first build
          if (selectedIngredientUnit == null) {
            final gramUnit = _units.firstWhere(
              (u) => (u['name'] as String?) == 'กรัม',
              orElse: () => {},
            );
            if (gramUnit.isNotEmpty) {
              selectedIngredientUnit = gramUnit['id'] as String?;
            }
          }

          // เพิ่มวัตถุดิบในรายการ
          void addIngredient() {
            if ((selectedProductId != null || selectedIngredientIsNew == true) && quantityController.text.isNotEmpty && selectedIngredientUnit != null) {
              final quantity = double.tryParse(quantityController.text) ?? 0;

              if (quantity > 0) {
                final unit = _units.firstWhere((u) => u['id'] == selectedIngredientUnit);
                setDialogState(() {
                  ingredients.add({
                    'product_id': selectedProductId,
                    'product_name': selectedIngredientName ?? searchResults.firstWhere((p) => p['id'] == selectedProductId, orElse: () => {'name': ''})['name'],
                    'quantity': quantity,
                    'unit_id': selectedIngredientUnit,
                    'unit_name': unit['name'],
                    'unit_abbreviation': unit['abbreviation'],
                    'is_new': selectedIngredientIsNew ?? false,
                    'category_id': selectedIngredientCategoryId,
                    'category_name': selectedIngredientCategoryName ?? 'ไม่ระบุหมวดหมู่',
                  });
                  selectedProductId = null;
                  selectedIngredientName = null;
                  selectedIngredientIsNew = null;
                  selectedIngredientUnit = null;
                  selectedIngredientCategoryId = null;  // รีเซ็ตหมวดหมู่
                  selectedIngredientCategoryName = null;
                  quantityController.clear();
                  ingredientSearchController.clear();
                  searchResults = [];
                });
              }
            }
          }

          // ฟังก์ชันค้นหาวัตถุดิบ
          Future<void> searchProducts(String query) async {
            if (query.length >= 1) {
              final results = await InventoryService.searchProductsByName(query);
              setDialogState(() {
                searchResults = results;
              });
            } else {
              setDialogState(() {
                searchResults = [];
              });
            }
          }

          // เลือกวัตถุดิบจาก autocomplete
          void onSelectIngredient(Map<String, dynamic> product) {
            setDialogState(() {
              selectedProductId = product['id'] as String;
              selectedIngredientName = product['name'] as String;
              selectedIngredientIsNew = false;
              ingredientSearchController.text = product['name'] as String;
              searchResults = [];
              // Auto select unit if product has unit
              if (product['unit'] != null && product['unit']['id'] != null) {
                selectedIngredientUnit = product['unit']['id'] as String;
              }
              // Auto select category if product has category
              if (product['category'] != null) {
                selectedIngredientCategoryId = product['category']['id'] as String?;
                selectedIngredientCategoryName = product['category']['name'] as String?;
              }
            });
          }

          // ตรวจสอบว่าข้อความเป็นภาษาไทยเท่านั้น (อนุญาตตัวเลขและช่องว่าง)
          bool isThaiOnly(String text) {
            final thaiRegex = RegExp(r'^[\u0E00-\u0E7F0-9\s]+$');
            return text.isEmpty || thaiRegex.hasMatch(text);
          }

          // เลือกวัตถุดิบใหม่ (ยังไม่มีในระบบ)
          void onSelectNewIngredient(String name) {
            // ตรวจสอบภาษาไทยก่อน
            if (!isThaiOnly(name)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('กรุณาใช้ภาษาไทยเท่านั้น'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            setDialogState(() {
              selectedProductId = null;
              selectedIngredientName = name;
              selectedIngredientIsNew = true;
              ingredientSearchController.text = name;
              searchResults = [];
              // Auto select 'กรัม' as default unit for new ingredients
              final gramUnit = _units.firstWhere(
                (u) => (u['name'] as String?) == 'กรัม',
                orElse: () => _units.isNotEmpty ? _units.first : {},
              );
              if (gramUnit.isNotEmpty) {
                selectedIngredientUnit = gramUnit['id'] as String?;
              }
              // Default category for new ingredients
              selectedIngredientCategoryId = null;
              selectedIngredientCategoryName = 'วัตถุดิบใหม่';
            });
          }

          // ลบวัตถุดิบ
          void removeIngredient(int index) {
            setDialogState(() {
              ingredients.removeAt(index);
            });
          }

          // เลือกรูปภาพ
          Future<void> pickImage(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200);
              if (picked != null) {
                setDialogState(() {
                  selectedImageFile = File(picked.path);
                  isUploadingImage = true;
                });
                // อัปโหลดทันที
                final url = await InventoryService.uploadRecipeImageTemp(File(picked.path));
                setDialogState(() {
                  uploadedImageUrl = url;
                  isUploadingImage = false;
                });
              }
            } catch (e) {
              setDialogState(() => isUploadingImage = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกรูปภาพ: $e'), backgroundColor: Colors.red));
              }
            }
          }

          // ลบรูปภาพ
          void removeImage() {
            if (uploadedImageUrl != null) {
              // ลบจาก storage
              final uri = Uri.parse(uploadedImageUrl!);
              final pathSegments = uri.pathSegments;
              final bucketIndex = pathSegments.indexOf('recipe-images');
              if (bucketIndex >= 0 && bucketIndex + 1 < pathSegments.length) {
                final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
                Supabase.instance.client.storage.from('recipe-images').remove([storagePath]);
              }
            }
            setDialogState(() {
              selectedImageFile = null;
              uploadedImageUrl = null;
            });
          }

          return AlertDialog(
            title: Row(children: [Icon(Icons.add_circle, color: Colors.green), SizedBox(width: 8), Expanded(child: Text('เพิ่มสูตรอาหารใหม่'))]),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // รูปภาพสูตร
                      Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: isUploadingImage
                          ? Center(child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(height: 8),
                                Text('กำลังบีบอัดและอัปโหลด...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ))
                          : selectedImageFile != null || uploadedImageUrl != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: uploadedImageUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: uploadedImageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          errorWidget: (_, __, ___) => selectedImageFile != null
                                            ? Image.file(selectedImageFile!, fit: BoxFit.cover)
                                            : Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                        )
                                      : Image.file(selectedImageFile!, fit: BoxFit.cover),
                                  ),
                                  // ปุ่มแก้ไข/ลบ
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Row(
                                      children: [
                                        _buildImageActionButton(
                                          icon: Icons.edit,
                                          color: Colors.blue,
                                          tooltip: 'เปลี่ยนรูป',
                                          onTap: () => _showImageSourceDialog(context, pickImage),
                                        ),
                                        SizedBox(width: 4),
                                        _buildImageActionButton(
                                          icon: Icons.delete,
                                          color: Colors.red,
                                          tooltip: 'ลบรูป',
                                          onTap: removeImage,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : InkWell(
                                onTap: () => _showImageSourceDialog(context, pickImage),
                                borderRadius: BorderRadius.circular(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                                    SizedBox(height: 8),
                                    Text('เพิ่มรูปเมนูอาหาร', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                    Text('(บีบอัดอัตโนมัติ)', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                  ],
                                ),
                              ),
                      ),
                      SizedBox(height: 12),

                      // ชื่อสูตร
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'ชื่อเมนู *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: Icon(Icons.restaurant_menu),
                          errorText: nameError,
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'กรุณากรอกชื่อเมนู' : null,
                        onChanged: (_) {
                          if (nameError != null) setDialogState(() => nameError = null);
                        },
                      ),
                      SizedBox(height: 12),

                      // ประเภท (เรียงตามล่าสุด)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'ประเภท *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: selectedCategoryId,
                        isExpanded: true,
                        items: sortedCategories.map((c) {
                          final recipeCount = _recipes.where((r) => r['recipe_category_id'] == c['id']).length;
                          return DropdownMenuItem(
                            value: c['id'] as String,
                            child: Row(
                              children: [
                                Expanded(child: Text(c['name'] ?? '', overflow: TextOverflow.ellipsis)),
                                if (recipeCount > 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Text('$recipeCount', style: TextStyle(fontSize: 10, color: Colors.green[700])),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                        validator: (v) => v == null ? 'กรุณาเลือกประเภท' : null,
                      ),
                      SizedBox(height: 12),

                      // หน่วยนับ (เรียงตามล่าสุด) + ปุ่มเพิ่มหน่วยใหม่
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'หน่วยนับ *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: Icon(Icons.straighten),
                              ),
                              value: selectedYieldUnit,
                              isExpanded: true,
                              items: _units.map((u) => DropdownMenuItem(
                                value: u['name'] as String,
                                child: Text('${u['name']} ${u['abbreviation'] != u['name'] ? '(${u['abbreviation']})' : ''}', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) => setDialogState(() => selectedYieldUnit = v),
                              validator: (v) => v == null ? 'กรุณาเลือกหน่วย' : null,
                            ),
                          ),
                          SizedBox(width: 8),
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: IconButton(
                              onPressed: () => _showAddUnitDialog(setDialogState),
                              icon: Icon(Icons.add_circle, color: Colors.blue, size: 28),
                              tooltip: 'เพิ่มหน่วยใหม่',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.withOpacity(0.1),
                                padding: EdgeInsets.all(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // ส่วนผสม
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.inventory_2, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text('วัตถุดิบ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                Spacer(),
                                Text('${ingredients.length} ส่วนผสม', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                            SizedBox(height: 12),
                            
                            // เพิ่มวัตถุดิบใหม่ - autocomplete
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Autocomplete field + Add button
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: ingredientSearchController,
                                        decoration: InputDecoration(
                                          labelText: 'ค้นหา *',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          prefixIcon: Icon(Icons.search, size: 18),
                                          suffixIcon: ingredientSearchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: Icon(Icons.clear, size: 18),
                                                  onPressed: () {
                                                    ingredientSearchController.clear();
                                                    setDialogState(() {
                                                      searchResults = [];
                                                      selectedProductId = null;
                                                      selectedIngredientName = null;
                                                      selectedIngredientIsNew = null;
                                                      selectedIngredientCategoryId = null;
                                                      selectedIngredientCategoryName = null;
                                                    });
                                                  },
                                                )
                                              : null,
                                          hintText: 'พิมพ์ชื่อวัตถุดิบ...',
                                        ),
                                        onChanged: (value) => searchProducts(value),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    IconButton(
                                      onPressed: (selectedProductId != null || selectedIngredientIsNew == true) && quantityController.text.isNotEmpty && selectedIngredientUnit != null
                                          ? addIngredient
                                          : null,
                                      icon: Icon(
                                        Icons.add_circle,
                                        color: (selectedProductId != null || selectedIngredientIsNew == true) && quantityController.text.isNotEmpty && selectedIngredientUnit != null
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      tooltip: 'เพิ่มวัตถุดิบ',
                                    ),
                                  ],
                                ),
                                
                                // Search results dropdown
                                if (searchResults.isNotEmpty)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey[300]!),
                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                    constraints: BoxConstraints(maxHeight: 200),
                                    child: Scrollbar(
                                      thumbVisibility: searchResults.length > 3,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: searchResults.length,
                                        itemBuilder: (context, index) {
                                          final product = searchResults[index];
                                          final unitName = product['unit']?['name'] ?? '';
                                          return ListTile(
                                            dense: true,
                                            leading: Icon(Icons.inventory_2, size: 18, color: Colors.blue),
                                            title: Text(product['name'] ?? '', style: TextStyle(fontSize: 13)),
                                            subtitle: unitName.isNotEmpty ? Text(unitName, style: TextStyle(fontSize: 11, color: Colors.grey[600])) : null,
                                            onTap: () => onSelectIngredient(product),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                
                                // Option to add new ingredient if not found
                                if (ingredientSearchController.text.isNotEmpty && searchResults.isEmpty && selectedProductId == null)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isThaiOnly(ingredientSearchController.text) ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isThaiOnly(ingredientSearchController.text) ? Colors.orange.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isThaiOnly(ingredientSearchController.text) ? Icons.add_circle_outline : Icons.warning,
                                          color: isThaiOnly(ingredientSearchController.text) ? Colors.orange : Colors.red,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isThaiOnly(ingredientSearchController.text)
                                                ? 'ไม่เคยใช้ "${ingredientSearchController.text}"'
                                                : 'กรุณาใช้ภาษาไทยเท่านั้น',
                                            style: TextStyle(fontSize: 12, color: isThaiOnly(ingredientSearchController.text) ? Colors.orange[800] : Colors.red[800]),
                                          ),
                                        ),
                                        if (isThaiOnly(ingredientSearchController.text))
                                          TextButton.icon(
                                            onPressed: () => onSelectNewIngredient(ingredientSearchController.text),
                                            icon: Icon(Icons.add, size: 16),
                                            label: Text('ใช้ชื่อนี้', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.green,
                                              padding: EdgeInsets.symmetric(horizontal: 8),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                
                                // Selected ingredient indicator
                                if (selectedIngredientName != null)
                                  Container(
                                    margin: EdgeInsets.only(top: 8),
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: selectedIngredientIsNew == true ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: selectedIngredientIsNew == true ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          selectedIngredientIsNew == true ? Icons.new_releases : Icons.check_circle,
                                          size: 16,
                                          color: selectedIngredientIsNew == true ? Colors.orange : Colors.green,
                                        ),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                selectedIngredientName!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: selectedIngredientIsNew == true ? Colors.orange[800] : Colors.green[800],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (selectedIngredientIsNew == true)
                                                Text(
                                                  'วัตถุดิบใหม่',
                                                  style: TextStyle(fontSize: 11, color: Colors.orange[600]),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                SizedBox(height: 12),
                                
                                // Quantity and Unit row
                                Row(
                                  children: [
                                    // Stepper จำนวน
                                    Container(
                                      width: 120,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF0F4F8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // ปุ่มลบ
                                          Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                                            child: InkWell(
                                              onTap: () {
                                                final current = double.tryParse(quantityController.text) ?? 0;
                                                if (current > 0) {
                                                  setDialogState(() {
                                                    quantityController.text = (current - 1).toStringAsFixed(current == current.toInt() ? 0 : 1);
                                                  });
                                                }
                                              },
                                              borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                                              child: Container(
                                                width: 36,
                                                height: 40,
                                                alignment: Alignment.center,
                                                child: Icon(Icons.remove, size: 18, color: Colors.grey[700]),
                                              ),
                                            ),
                                          ),
                                          // ตัวเลข
                                          Expanded(
                                            child: TextFormField(
                                              controller: quantityController,
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                              onChanged: (value) {
                                                if (value.isEmpty) {
                                                  quantityController.text = '1';
                                                  quantityController.selection = TextSelection.fromPosition(
                                                    TextPosition(offset: quantityController.text.length),
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                          // ปุ่มบวก
                                          Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                                            child: InkWell(
                                              onTap: () {
                                                final current = double.tryParse(quantityController.text) ?? 0;
                                                setDialogState(() {
                                                  quantityController.text = (current + 1).toStringAsFixed(current == current.toInt() ? 0 : 1);
                                                });
                                              },
                                              borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                                              child: Container(
                                                width: 36,
                                                height: 40,
                                                alignment: Alignment.center,
                                                child: Icon(Icons.add, size: 18, color: Colors.grey[700]),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<String>(
                                        decoration: InputDecoration(
                                          labelText: 'หน่วย *',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        value: selectedIngredientUnit,
                                        isExpanded: true,
                                        items: _units.map((u) => DropdownMenuItem(
                                          value: u['id'] as String,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(u['name'] ?? '', overflow: TextOverflow.ellipsis),
                                          ),
                                        )).toList(),
                                        onChanged: (v) => setDialogState(() => selectedIngredientUnit = v),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Category dropdown - แก้ไขหมวดหมู่ได้
                                if (selectedIngredientName != null) ...[
                                  SizedBox(height: 8),
                                  DropdownButtonFormField<String?>(
                                    decoration: InputDecoration(
                                      labelText: 'หมวดหมู่วัตถุดิบ',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      prefixIcon: Icon(Icons.folder, size: 18, color: Colors.grey[600]),
                                    ),
                                    value: selectedIngredientCategoryId ?? (selectedIngredientIsNew == true ? '__new__' : null),
                                    isExpanded: true,
                                    items: () {
                                      // ดึงหมวดหมู่ที่ไม่ซ้ำจาก _products
                                      final categories = <String, String>{};
                                      for (final p in _products) {
                                        final cat = p['category'] as Map<String, dynamic>?;
                                        if (cat != null && cat['id'] != null) {
                                          categories[cat['id'] as String] = cat['name'] as String? ?? 'ไม่ระบุ';
                                        }
                                      }
                                      // เรียงตามชื่อ
                                      final sorted = categories.entries.toList()
                                        ..sort((a, b) => a.value.compareTo(b.value));
                                      
                                      final items = <DropdownMenuItem<String?>>[];
                                      
                                      // ถ้าเป็นวัตถุดิบใหม่ เพิ่ม option "วัตถุดิบใหม่" ก่อน
                                      if (selectedIngredientIsNew == true) {
                                        items.add(DropdownMenuItem<String?>(
                                          value: '__new__',
                                          child: Text('วัตถุดิบใหม่', style: TextStyle(color: Colors.orange[700])),
                                        ));
                                      }
                                      
                                      // เพิ่ม "ไม่ระบุหมวดหมู่" สำหรับวัตถุดิบที่มีอยู่แล้ว
                                      if (selectedIngredientIsNew != true) {
                                        items.add(DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('ไม่ระบุหมวดหมู่', style: TextStyle(color: Colors.grey[600])),
                                        ));
                                      }
                                      
                                      // เพิ่มหมวดหมู่จาก products
                                      items.addAll(sorted.map((e) => DropdownMenuItem<String?>(
                                        value: e.key,
                                        child: Text(e.value),
                                      )));
                                      
                                      return items;
                                    }(),
                                    onChanged: (v) => setDialogState(() {
                                      if (v == '__new__') {
                                        selectedIngredientCategoryId = null;
                                        selectedIngredientCategoryName = 'วัตถุดิบใหม่';
                                      } else {
                                        selectedIngredientCategoryId = v;
                                        // อัปเดตชื่อหมวดหมู่
                                        if (v == null) {
                                          selectedIngredientCategoryName = 'ไม่ระบุหมวดหมู่';
                                        } else {
                                          final cat = _products.firstWhere(
                                            (p) => (p['category']?['id'] as String?) == v,
                                            orElse: () => {},
                                          );
                                          selectedIngredientCategoryName = cat['category']?['name'] ?? 'ไม่ระบุ';
                                        }
                                      }
                                    }),
                                  ),
                                ],
                              ],
                            ),
                            
                            // รายการวัตถุดิบ - จัดกลุ่มตามหมวดหมู่
                            if (ingredients.isNotEmpty) ...[
                              SizedBox(height: 12),
                              Container(
                                constraints: BoxConstraints(maxHeight: 150),
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: () {
                                        // จัดกลุ่มตามหมวดหมู่
                                        final grouped = <String, List<MapEntry<int, dynamic>>>{};
                                        final entries = ingredients.asMap().entries.toList();
                                        
                                        for (final entry in entries) {
                                          final categoryName = entry.value['category_name'] ?? 'ไม่ระบุหมวดหมู่';
                                          grouped.putIfAbsent(categoryName, () => []).add(entry);
                                        }
                                        
                                        // สร้าง widgets ตามกลุ่ม
                                        final widgets = <Widget>[];
                                        for (final category in grouped.keys) {
                                          // Header หมวดหมู่
                                          widgets.add(
                                            Container(
                                              margin: EdgeInsets.only(top: 8, bottom: 4),
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                category,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue[800],
                                                ),
                                              ),
                                            ),
                                          );
                                          
                                          // รายการในหมวดหมู่
                                          for (final entry in grouped[category]!) {
                                            final index = entry.key;
                                            final ing = entry.value;
                                            widgets.add(
                                              Container(
                                                margin: EdgeInsets.only(bottom: 4),
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.grey[300]!),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(ing['product_name'] ?? '', style: TextStyle(fontSize: 13)),
                                                    ),
                                                    // ตัวเลขจำนวน - ชิดขวา เพื่อจัดตัวเลขตรงกัน
                                                    Container(
                                                      width: 60,
                                                      alignment: Alignment.centerRight,
                                                      child: Text(
                                                        '${ing['quantity']}',
                                                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    // หน่วย - ชิดขวา กว้างพอสำหรับหน่วยยาว
                                                    Container(
                                                      width: 70,
                                                      alignment: Alignment.centerRight,
                                                      child: Text(
                                                        ing['unit_name'] ?? '',
                                                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    IconButton(
                                                      onPressed: () => removeIngredient(index),
                                                      icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                                      tooltip: 'ลบ',
                                                      padding: EdgeInsets.zero,
                                                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        return widgets;
                                      }(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 12),

                      // คำอธิบาย
                      Container(
                        constraints: BoxConstraints(maxHeight: 120),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'คำอธิบาย / หมายเหตุ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: Icon(Icons.notes),
                              hintText: 'เช่น วิธีทำ, เคล็ดลับ...',
                              alignLabelWithHint: true,
                            ),
                            maxLines: null,
                            minLines: 3,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),

                      // Info box
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text('ต้นทุน, ราคาขาย สามารถเพิ่มได้ภายหลังจากหน้าแก้ไขสูตร', style: TextStyle(fontSize: 12, color: Colors.amber[800]))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () async {
                  if (formKey.currentState?.validate() != true) return;

                  // ตรวจสอบชื่อซ้ำ
                  setDialogState(() => isLoading = true);
                  final exists = await InventoryService.checkRecipeNameExists(nameController.text.trim());
                  if (exists) {
                    setDialogState(() {
                      isLoading = false;
                      nameError = 'ชื่อสูตร "${nameController.text.trim()}" มีอยู่แล้ว';
                    });
                    return;
                  }

                  // เตรียมข้อมูลวัตถุดิบสำหรับบันทึก
                  final existingIngredients = ingredients.where((ing) => ing['is_new'] != true).map((ing) => {
                    'product_id': ing['product_id'],
                    'quantity': ing['quantity'],
                    'unit_id': ing['unit_id'],
                  }).toList();
                  
                  final newIngredientsToCreate = ingredients.where((ing) => ing['is_new'] == true).map((ing) => {
                    'name': ing['product_name'],
                    'quantity': ing['quantity'],
                    'unit_id': ing['unit_id'],
                  }).toList();

                  final ok = await InventoryService.addRecipeWithIngredientsAndImage(
                    name: nameController.text.trim(),
                    categoryId: selectedCategoryId!,
                    yieldUnit: selectedYieldUnit!,
                    description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    imageUrl: uploadedImageUrl,
                    ingredients: existingIngredients,
                    newIngredientsToCreate: newIngredientsToCreate,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (ok) {
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มสูตร "${nameController.text}" พร้อมวัตถุดิบ ${ingredients.length} รายการ สำเร็จ'), backgroundColor: Colors.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red));
                    }
                  }
                },
                icon: isLoading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.save),
                label: Text('บันทึก'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context, Future<void> Function(ImageSource) pickImage) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('ถ่ายรูป'),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green),
              title: Text('เลือกจากคลังรูป'),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUnitDialog(void Function(void Function()) parentSetState) {
    final unitNameController = TextEditingController();
    final abbreviationController = TextEditingController();
    bool isUnitLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.straighten, color: Colors.blue), SizedBox(width: 8), Text('เพิ่มหน่วยนับใหม่')]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: unitNameController,
                decoration: InputDecoration(
                  labelText: 'พาชนะ (ชื่อหน่วยนับ) *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.label),
                  hintText: 'เช่น ถ้วย, จาน, ชาม',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: abbreviationController,
                decoration: InputDecoration(
                  labelText: 'ตัวย่อ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Icon(Icons.short_text),
                  hintText: 'เช่น กก., มล.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isUnitLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton.icon(
              onPressed: isUnitLoading ? null : () async {
                if (unitNameController.text.trim().isEmpty) return;
                setDialogState(() => isUnitLoading = true);
                final ok = await InventoryService.addUnit(
                  unitNameController.text.trim(),
                  abbreviation: abbreviationController.text.trim().isEmpty ? null : abbreviationController.text.trim(),
                );
                if (context.mounted) {
                  if (ok) {
                    // โหลด units ใหม่
                    final newUnits = await InventoryService.getUnitsSortedByRecipeUsage();
                    setState(() => _units = newUnits);
                    if (context.mounted) Navigator.pop(context);
                    parentSetState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มหน่วย "${unitNameController.text}" สำเร็จ'), backgroundColor: Colors.green));
                  } else {
                    setDialogState(() => isUnitLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด (อาจมีชื่อซ้ำ)'), backgroundColor: Colors.red));
                  }
                }
              },
              icon: isUnitLoading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.add),
              label: Text('เพิ่ม'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRecipeDialog(Map<String, dynamic> recipe) {
    final nameController = TextEditingController(text: recipe['name'] ?? '');
    final costController = TextEditingController(text: '${_getCost(recipe)}');
    final priceController = TextEditingController(text: '${_getPrice(recipe)}');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('แก้ไขสูตร')]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: nameController, decoration: InputDecoration(labelText: 'ชื่อสูตร', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextFormField(controller: costController, decoration: InputDecoration(labelText: 'ต้นทุน/ชุด', border: OutlineInputBorder(), prefixText: '฿'), keyboardType: TextInputType.number),
            SizedBox(height: 12),
            TextFormField(controller: priceController, decoration: InputDecoration(labelText: 'ราคาขาย/ชิ้น', border: OutlineInputBorder(), prefixText: '฿'), keyboardType: TextInputType.number),
          ])),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);
                final ok = await InventoryService.updateRecipe(recipe['id'], {
                  'name': nameController.text.trim(),
                  'cost': double.tryParse(costController.text) ?? 0,
                  'price': double.tryParse(priceController.text) ?? 0,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('แก้ไขสูตรสำเร็จ'), backgroundColor: Colors.green)); }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('ยืนยันการลบ')]),
        content: Text('ต้องการลบสูตร "${recipe['name']}" หรือไม่?\nการลบจะไม่สามารถกู้คืนได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await InventoryService.deleteRecipe(recipe['id']);
              if (mounted) {
                if (ok) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบสูตร ${recipe['name']} แล้ว'), backgroundColor: Colors.red)); }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('ลบ'),
          ),
        ],
      ),
    );
  }

  void _showManageCategoriesDialog() {
    final nameController = TextEditingController();
    bool isLoading = false;

    // นับจำนวนสูตรอาหารในแต่ละประเภท
    Map<String, int> getCategoryRecipeCounts() {
      final counts = <String, int>{};
      for (final cat in _recipeCategories) {
        final catId = cat['id'] as String?;
        if (catId != null) {
          counts[catId] = _recipes.where((r) => r['recipe_category_id'] == catId).length;
        }
      }
      return counts;
    }

    // เรียงประเภทตามจำนวนสูตร (มากไปน้อย)
    List<Map<String, dynamic>> getSortedCategories() {
      final counts = getCategoryRecipeCounts();
      final sorted = List<Map<String, dynamic>>.from(_recipeCategories);
      sorted.sort((a, b) {
        final countA = counts[a['id']] ?? 0;
        final countB = counts[b['id']] ?? 0;
        return countB.compareTo(countA); // มากไปน้อย
      });
      return sorted;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sortedCategories = getSortedCategories();
          final counts = getCategoryRecipeCounts();

          return AlertDialog(
            title: Row(children: [Icon(Icons.category, color: Colors.blue), SizedBox(width: 8), Text('จัดการประเภทสูตร')]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('เพิ่มประเภทใหม่', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อประเภท',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                  ),
                  Divider(height: 24),
                  Row(
                    children: [
                      Expanded(child: Text('ประเภททั้งหมด (${_recipeCategories.length} รายการ)', style: TextStyle(fontWeight: FontWeight.bold))),
                      Text('จำนวนสูตร', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_recipeCategories.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('ยังไม่มีประเภท', style: TextStyle(color: Colors.grey[600]))),
                    )
                  else
                    ...sortedCategories.map((c) {
                      final count = counts[c['id']] ?? 0;
                      return Container(
                        margin: EdgeInsets.only(bottom: 4),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: count > 0 ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: count > 0 ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.label, size: 16, color: count > 0 ? Colors.blue : Colors.grey),
                            SizedBox(width: 8),
                            Expanded(child: Text(c['name'] ?? '', style: TextStyle(fontWeight: count > 0 ? FontWeight.w500 : FontWeight.normal))),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: count > 0 ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$count สูตร',
                                style: TextStyle(fontSize: 11, color: count > 0 ? Colors.green[700] : Colors.grey[600], fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ปิด')),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () async {
                  if (nameController.text.trim().isEmpty) return;
                  setDialogState(() => isLoading = true);
                  final ok = await InventoryService.addRecipeCategory(name: nameController.text.trim());
                  if (context.mounted) {
                    if (ok) {
                      await _loadData();
                      setDialogState(() { isLoading = false; nameController.clear(); });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มประเภทสำเร็จ'), backgroundColor: Colors.green));
                    } else {
                      setDialogState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red));
                    }
                  }
                },
                icon: isLoading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.add),
                label: Text('เพิ่ม'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
}
