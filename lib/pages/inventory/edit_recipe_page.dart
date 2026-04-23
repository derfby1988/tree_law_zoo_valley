import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/inventory_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_product_page.dart' show AddProductPage, ItemType;

class EditRecipePage extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> shelves;
  final List<Map<String, dynamic>> warehouses;

  const EditRecipePage({
    super.key,
    required this.recipe,
    required this.categories,
    required this.units,
    required this.shelves,
    required this.warehouses,
  });

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  late final TextEditingController nameController;
  late final TextEditingController shortNameController;
  late final TextEditingController descriptionController;
  late final TextEditingController netWeightController;
  late final TextEditingController quantityController;
  late final TextEditingController ingredientSearchController;

  late String? selectedCategoryId;
  late String? selectedYieldUnit;
  late List<Map<String, dynamic>> ingredients;
  late List<Map<String, dynamic>> searchResults;
  late String? selectedProductId;
  late String? selectedIngredientName;
  late bool? selectedIngredientIsNew;
  late String? selectedIngredientUnit;
  late String? selectedIngredientCategoryId;
  late String? selectedIngredientCategoryName;

  File? selectedImageFile;
  String? uploadedImageUrl;
  bool isUploadingImage = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.recipe['name'] ?? '');
    shortNameController = TextEditingController(text: widget.recipe['short_name'] ?? '');
    descriptionController = TextEditingController(text: widget.recipe['description'] ?? '');
    // ✅ ตรวจสอบ net_weight จากข้อมูลจริง
    final netWeight = widget.recipe['net_weight'];
    netWeightController = TextEditingController(
      text: netWeight != null && netWeight != 0 ? netWeight.toString() : '',
    );
    quantityController = TextEditingController(text: '1');
    ingredientSearchController = TextEditingController();

    selectedCategoryId = widget.recipe['recipe_category_id'];
    selectedYieldUnit = widget.recipe['yield_unit'] ?? 'จาน';
    uploadedImageUrl = widget.recipe['image_url'];

    // ดึง ingredients จาก recipe
    final raw = widget.recipe['ingredients'];
    ingredients = raw is List ? List<Map<String, dynamic>>.from(raw) : [];
    
    // ✅ Debug: ตรวจสอบว่า unit data มีไหม
    for (final ing in ingredients) {
      debugPrint('📦 Ingredient: product_name=${ing['product_name']}, product=${ing['product']}, quantity=${ing['quantity']}, unit=${ing['unit']}, unit_id=${ing['unit_id']}');
      // ✅ ถ้า product_name เป็น null ให้ดึงจาก product.name
      if ((ing['product_name'] == null || ing['product_name'].toString().isEmpty) && ing['product'] is Map) {
        ing['product_name'] = (ing['product'] as Map)['name'];
        debugPrint('✅ Updated product_name from product object: ${ing['product_name']}');
      }
    }

    searchResults = [];
    selectedProductId = null;
    selectedIngredientName = null;
    selectedIngredientIsNew = null;
    selectedIngredientUnit = null;
    selectedIngredientCategoryId = null;
    selectedIngredientCategoryName = null;
  }

  @override
  void dispose() {
    nameController.dispose();
    shortNameController.dispose();
    descriptionController.dispose();
    netWeightController.dispose();
    quantityController.dispose();
    ingredientSearchController.dispose();
    super.dispose();
  }

  void addIngredient() {
    if ((selectedProductId != null || selectedIngredientIsNew == true) &&
        quantityController.text.isNotEmpty &&
        selectedIngredientUnit != null) {
      final quantity = double.tryParse(quantityController.text) ?? 0;

      if (quantity > 0) {
        final unit = widget.units.firstWhere((u) => u['id'] == selectedIngredientUnit);
        setState(() {
          ingredients.add({
            'product_id': selectedProductId,
            'product_name': selectedIngredientName ??
                searchResults
                    .firstWhere((p) => p['id'] == selectedProductId, orElse: () => {'name': ''})['name'],
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
          selectedIngredientCategoryId = null;
          selectedIngredientCategoryName = null;
          quantityController.clear();
          ingredientSearchController.clear();
          searchResults = [];
        });
      }
    }
  }

  Future<void> searchProducts(String query) async {
    if (query.length >= 1) {
      final results = await InventoryService.searchProductsByName(query);
      setState(() {
        searchResults = results;
      });
    } else {
      setState(() {
        searchResults = [];
      });
    }
  }

  void onSelectIngredient(Map<String, dynamic> product) {
    setState(() {
      selectedProductId = product['id'] as String;
      selectedIngredientName = product['name'] as String;
      selectedIngredientIsNew = false;
      ingredientSearchController.text = product['name'] as String;
      searchResults = [];
      if (product['unit'] != null && product['unit']['id'] != null) {
        selectedIngredientUnit = product['unit']['id'] as String;
      }
      if (product['category'] != null) {
        selectedIngredientCategoryId = product['category']['id'] as String?;
        selectedIngredientCategoryName = product['category']['name'] as String?;
      }
    });
  }

  void removeIngredient(int index) {
    setState(() {
      ingredients.removeAt(index);
    });
  }

  // ✅ คำนวน cost จากวัตถุดิบ
  double calculateCost() {
    double totalCost = 0;
    for (final ing in ingredients) {
      final productPrice = (ing['product']?['price'] as num?)?.toDouble() ?? 0;
      final quantity = (ing['quantity'] as num?)?.toDouble() ?? 0;
      totalCost += productPrice * quantity;
    }
    return totalCost;
  }

  // ✅ คำนวน price จาก cost / yield quantity
  double calculatePrice() {
    final cost = calculateCost();
    final yieldQty = double.tryParse(widget.recipe['yield_quantity']?.toString() ?? '1') ?? 1;
    return yieldQty > 0 ? cost / yieldQty : 0;
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200);
      if (picked != null) {
        setState(() {
          selectedImageFile = File(picked.path);
          isUploadingImage = true;
        });
        final url = await InventoryService.uploadRecipeImageTemp(File(picked.path));
        setState(() {
          uploadedImageUrl = url;
          isUploadingImage = false;
        });
      }
    } catch (e) {
      setState(() => isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเลือกรูปภาพ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> saveRecipe() async {
    // ✅ ตรวจสอบว่ามีวัตถุดิบอย่างน้อย 1 รายการ
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเพิ่มวัตถุดิบอย่างน้อย 1 รายการ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final existingIngredients = ingredients
          .where((ing) => ing['is_new'] != true)
          .map((ing) => {
                'product_id': ing['product_id'],
                'product_name': ing['product_name'],  // ✅ ส่งชื่อไปด้วย (เผื่อ resolve)
                'quantity': ing['quantity'],
                'unit_id': ing['unit_id'],
              })
          .toList();

      final newIngredientsToCreate = ingredients
          .where((ing) => ing['is_new'] == true)
          .map((ing) => {
                'name': ing['product_name'],
                'quantity': ing['quantity'],
                'unit_id': ing['unit_id'],
              })
          .toList();

      final ok = await InventoryService.updateRecipeWithIngredients(
        recipeId: widget.recipe['id'],
        name: nameController.text.trim(),
        shortName: shortNameController.text.trim().isEmpty ? null : shortNameController.text.trim(),
        netWeight: double.tryParse(netWeightController.text) ?? 0,  // ✅ น้ำหนักสุทธิ
        categoryId: selectedCategoryId!,
        yieldUnit: selectedYieldUnit!,
        description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
        cost: calculateCost(),  // ✅ คำนวนจากวัตถุดิบ
        price: calculatePrice(),  // ✅ คำนวนจาก cost / yield
        imageUrl: uploadedImageUrl,
        ingredients: existingIngredients,
        newIngredientsToCreate: newIngredientsToCreate,
      );

      if (mounted) {
        Navigator.pop(context, ok);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('แก้ไขสูตร "${nameController.text}" สำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขสูตร'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ชื่อสูตร
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อสูตร *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ชื่อย่อสูตร
            TextField(
              controller: shortNameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อย่อ / บนใบเสร็จ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // น้ำหนักสุทธิ
            TextField(
              controller: netWeightController,
              decoration: const InputDecoration(
                labelText: 'น้ำหนักสุทธิ (กรัม)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // หมวดหมู่
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'หมวดหมู่ *',
                border: OutlineInputBorder(),
              ),
              value: selectedCategoryId,
              items: widget.categories
                  .map((c) => DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['name'] ?? ''),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedCategoryId = v),
            ),
            const SizedBox(height: 16),

            // หน่วยนับ
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'หน่วยนับ *',
                border: OutlineInputBorder(),
              ),
              value: selectedYieldUnit,
              items: const [
                DropdownMenuItem(value: 'จาน', child: Text('จาน')),
                DropdownMenuItem(value: 'ชิ้น', child: Text('ชิ้น')),
                DropdownMenuItem(value: 'แก้ว', child: Text('แก้ว')),
                DropdownMenuItem(value: 'ชาม', child: Text('ชาม')),
              ],
              onChanged: (v) => setState(() => selectedYieldUnit = v),
            ),
            const SizedBox(height: 16),

            // คำอธิบาย
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // ✅ แสดง Cost & Price (คำนวนอัตโนมัติ)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ต้นทุนและราคา (คำนวนจากวัตถุดิบ)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ต้นทุน/ชุด:'),
                      Text(
                        '฿${calculateCost().toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ราคาขาย/หน่วย:'),
                      Text(
                        '฿${calculatePrice().toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // วัตถุดิบ
            Text('วัตถุดิบ *', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            // ค้นหาวัตถุดิบ
            TextField(
              controller: ingredientSearchController,
              decoration: InputDecoration(
                labelText: 'ค้นหาวัตถุดิบ',
                border: const OutlineInputBorder(),
                suffixIcon: searchResults.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          // ✅ กดปุ่ม X → ปิด dropdown
                          setState(() => searchResults = []);
                        },
                      )
                    : null,
              ),
              onChanged: searchProducts,
            ),
            // ✅ Dropdown ค้นหา
            if (searchResults.isNotEmpty)
              GestureDetector(
                onTap: () {
                  // ✅ กดพื้นที่ว่าง → ปิด dropdown
                  setState(() => searchResults = []);
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final item = searchResults[index];
                      return ListTile(
                        title: Text(item['name'] ?? ''),
                        onTap: () {
                          // ✅ กดรายการ → เลือกและปิด dropdown
                          onSelectIngredient(item);
                          setState(() => searchResults = []);
                        },
                      );
                    },
                  ),
                ),
              ),
            // ✅ ปุ่มเพิ่มสินค้า (เมื่อค้นหาไม่พบ)
            if (ingredientSearchController.text.isNotEmpty && searchResults.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ไม่พบ "${ingredientSearchController.text}"',
                      style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // ✅ Navigate ไป AddProductPage
                          final newProduct = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddProductPage(
                                categories: widget.categories,
                                units: widget.units,
                                recipes: [],
                                shelves: widget.shelves,
                                warehouses: widget.warehouses,
                                initialItemType: ItemType.ingredient,  // ✅ Set เป็น ingredient
                                initialProductName: ingredientSearchController.text.trim(),  // ✅ ส่งชื่อวัตถุดิบ
                              ),
                            ),
                          );

                          if (newProduct != null && mounted) {
                            // ✅ Auto-select สินค้าที่เพิ่งสร้าง
                            setState(() {
                              selectedProductId = newProduct['id'];
                              selectedIngredientName = newProduct['name'];
                              selectedIngredientIsNew = false;
                              // ✅ แสดงชื่อวัตถุดิบในช่องค้นหา
                              ingredientSearchController.text = newProduct['name'];
                              // ✅ ปิด dropdown ทันที
                              searchResults = [];
                              if (newProduct['unit'] != null && newProduct['unit']['id'] != null) {
                                selectedIngredientUnit = newProduct['unit']['id'];
                              }
                            });
                            // ✅ Focus ไปที่ช่องจำนวน เพื่อให้ผู้ใช้กรอกจำนวนได้เลย
                            FocusScope.of(context).nextFocus();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มวัตถุดิบใหม่'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // จำนวน + หน่วย
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'จำนวน',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                // ✅ แสดงหน่วยจากวัตถุดิบ (read-only)
                if (selectedIngredientUnit != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'หน่วย',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.units
                                .firstWhere(
                                  (u) => u['id'] == selectedIngredientUnit,
                                  orElse: () => {'name': '-'},
                                )['name'] ??
                                '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.orange.withOpacity(0.05),
                      ),
                      child: Text(
                        'เลือกวัตถุดิบ',
                        style: TextStyle(color: Colors.orange[800], fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ปุ่มเพิ่ม
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (selectedProductId != null || selectedIngredientName != null) {
                    addIngredient();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มวัตถุดิบ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // รายการวัตถุดิบ
            if (ingredients.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('รายการวัตถุดิบ (${ingredients.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  // ✅ Container พร้อม scrollbar (จำกัด 5 รายการ)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),  // ≈ 5 รายการ
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: ingredients.length,
                      itemBuilder: (context, index) {
                        final ing = ingredients[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            // ✅ ชื่อวัตถุดิบ (ตัวหนา)
                            title: Text(
                              ing['product_name'] ?? 'ไม่ระบุชื่อ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            // ✅ จำนวน + หน่วย
                            subtitle: Builder(
                              builder: (context) {
                                // ✅ ดึง unit abbreviation จากหลายแหล่ง (priority order)
                                String unitAbbr = '';
                                
                                // 1. ลองจาก unit object (จาก API)
                                if (ing['unit'] is Map) {
                                  unitAbbr = (ing['unit'] as Map)['abbreviation']?.toString() ?? '';
                                }
                                
                                // 2. ลองจาก unit_abbreviation (เก่า)
                                if (unitAbbr.isEmpty && ing['unit_abbreviation'] != null) {
                                  unitAbbr = ing['unit_abbreviation'].toString();
                                }
                                
                                // 3. ลองจาก product.unit (ถ้ามี)
                                if (unitAbbr.isEmpty && ing['product'] is Map) {
                                  final productUnit = (ing['product'] as Map)['unit'];
                                  if (productUnit is Map) {
                                    unitAbbr = productUnit['abbreviation']?.toString() ?? '';
                                  }
                                }
                                
                                debugPrint('🔍 Unit for ${ing['product_name']}: $unitAbbr (from ${ing['unit']})');
                                
                                // ✅ ลบทศนิยมที่ไม่จำเป็น (1.0 → 1)
                                final qty = ing['quantity'] as num?;
                                final qtyStr = qty != null
                                    ? (qty % 1 == 0 ? qty.toInt().toString() : qty.toString())
                                    : '0';
                                
                                return Text(
                                  'จำนวน: $qtyStr $unitAbbr',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ✅ ปุ่มแก้ไข
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    // เปิด dialog แก้ไขจำนวน
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        final quantityCtrl = TextEditingController(
                                          text: ing['quantity'].toString(),
                                        );
                                        return AlertDialog(
                                          title: Text('แก้ไข ${ing['product_name']}'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // ✅ แสดงชื่อวัตถุดิบ
                                              Text(
                                                'วัตถุดิบ: ${ing['product_name']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              // ✅ ช่องกรอกจำนวน
                                              TextField(
                                                controller: quantityCtrl,
                                                decoration: const InputDecoration(
                                                  labelText: 'จำนวน',
                                                  border: OutlineInputBorder(),
                                                ),
                                                keyboardType: TextInputType.number,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('ยกเลิก'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                final newQty = double.tryParse(quantityCtrl.text) ?? 0;
                                                if (newQty > 0) {
                                                  setState(() {
                                                    ingredients[index]['quantity'] = newQty;
                                                  });
                                                  Navigator.pop(context);
                                                }
                                              },
                                              child: const Text('บันทึก'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                                // ✅ ปุ่มลบ
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => removeIngredient(index),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
      // ✅ ปุ่มบันทึกอยู่นอก SingleChildScrollView
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : saveRecipe,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: const Text('บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}
