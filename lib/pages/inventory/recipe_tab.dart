import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _categories = [];
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
        InventoryService.getCategories(),
      ]);
      setState(() {
        _recipes = results[0];
        _categories = results[1];
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

    final categoryNames = ['ทั้งหมด', ..._categories.map((c) => c['name'] as String)];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndFilter(categoryNames),
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: categoryNames.contains(_selectedCategory) ? _selectedCategory : 'ทั้งหมด',
                    decoration: InputDecoration(
                      labelText: 'ประเภท',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: categoryNames.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddRecipeDialog(),
                  icon: Icon(Icons.add),
                  label: Text('เพิ่มสูตร'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
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
    final yieldController = TextEditingController(text: '1');
    final costController = TextEditingController();
    final priceController = TextEditingController();
    String? selectedCategoryId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [Icon(Icons.add_circle, color: Colors.green), SizedBox(width: 8), Text('เพิ่มสูตรอาหารใหม่')]),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: nameController, decoration: InputDecoration(labelText: 'ชื่อสูตร *', border: OutlineInputBorder()), validator: (v) => v?.trim().isEmpty == true ? 'กรุณากรอกชื่อสูตร' : null),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'ประเภท *', border: OutlineInputBorder()),
                    value: selectedCategoryId,
                    items: _categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? ''))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                    validator: (v) => v == null ? 'กรุณาเลือกประเภท' : null,
                  ),
                  SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: yieldController, decoration: InputDecoration(labelText: 'จำนวนที่ได้ *', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => v?.trim().isEmpty == true ? 'กรุณากรอก' : null)),
                    SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: costController, decoration: InputDecoration(labelText: 'ต้นทุน/ชุด *', border: OutlineInputBorder(), prefixText: '฿'), keyboardType: TextInputType.number, validator: (v) => v?.trim().isEmpty == true ? 'กรุณากรอก' : null)),
                  ]),
                  SizedBox(height: 12),
                  TextFormField(controller: priceController, decoration: InputDecoration(labelText: 'ราคาขาย/ชิ้น *', border: OutlineInputBorder(), prefixText: '฿'), keyboardType: TextInputType.number, validator: (v) => v?.trim().isEmpty == true ? 'กรุณากรอก' : null),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('ส่วนผสมสามารถเพิ่มได้ภายหลังจากหน้าแก้ไขสูตร', style: TextStyle(fontSize: 12, color: Colors.amber[800]))),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: Text('ยกเลิก')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState?.validate() != true) return;
                setDialogState(() => isLoading = true);
                final ok = await InventoryService.addRecipe(
                  name: nameController.text.trim(),
                  categoryId: selectedCategoryId!,
                  yieldQuantity: double.tryParse(yieldController.text) ?? 1,
                  cost: double.tryParse(costController.text) ?? 0,
                  price: double.tryParse(priceController.text) ?? 0,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (ok) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มสูตร ${nameController.text} สำเร็จ'), backgroundColor: Colors.green)); }
                  else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red)); }
                }
              },
              child: isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('บันทึก'),
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
}
