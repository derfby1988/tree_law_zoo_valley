import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryService {
  static final SupabaseClient _client = Supabase.instance.client;

  static const Map<String, dynamic> _productTaxFallback = {
    'is_tax_exempt': false,
    'tax_rate': 7.0,
    'tax_inclusion': 'included',
    'rule_name': 'ค่าเริ่มต้นสินค้า (VAT 7%)',
    'legal_reference': 'ประมวลรัษฎากร ภาษีมูลค่าเพิ่ม (กำหนดเป็นค่าเริ่มต้นระบบ)',
    'requires_manual_review': true,
    'source': 'fallback',
  };

  static const Map<String, dynamic> _ingredientTaxFallback = {
    'is_tax_exempt': true,
    'tax_rate': 0.0,
    'tax_inclusion': 'excluded',
    'rule_name': 'ค่าเริ่มต้นวัตถุดิบ (ยกเว้นภาษี)',
    'legal_reference': 'กำหนดโดยนโยบายเริ่มต้นระบบ (ต้องตรวจสอบธุรกรรมจริง)',
    'requires_manual_review': true,
    'source': 'fallback',
  };

  // =============================================
  // Products
  // =============================================

  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('''
            *,
            category:inventory_categories(id, name),
            unit:inventory_units(id, name, abbreviation),
            shelf:inventory_shelves(id, code, warehouse:inventory_warehouses(id, name))
          ''')
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading products: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getProductsByCategory(
    String categoryId, {
    int limit = 8,
  }) async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('''
            id,
            name,
            quantity,
            is_active,
            updated_at,
            unit:inventory_units(id, name, abbreviation)
          ''')
          .eq('category_id', categoryId)
          .order('updated_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading products by category: $e');
      return [];
    }
  }

  static Future<void> _createProductBarcode({
    required String productId,
    required String barcodeType,
    String? accountCode,
  }) async {
    final normalizedAccountCode = (accountCode ?? '').trim();
    final barcodeText = _buildGs1128BarcodeText(accountCode: normalizedAccountCode);

    await _client.from('inventory_product_barcodes').insert({
      'product_id': productId,
      'barcode_type': barcodeType,
      'barcode_text': barcodeText,
      'account_code': normalizedAccountCode,
      'barcode_scope': 'master',
      'is_primary': true,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static String _buildGs1128BarcodeText({
    required String accountCode,
  }) {
    final safeAccount = accountCode.isEmpty ? '0000000000' : accountCode;
    return '(240)$safeAccount';
  }

  static String _buildGs1128LotBarcodeText({
    required String accountCode,
    required double quantity,
    DateTime? productionDate,
    DateTime? expiryDate,
  }) {
    final safeAccount = accountCode.isEmpty ? '0000000000' : accountCode;
    final mfg = productionDate != null ? '(11)${_formatGs1Date(productionDate)}' : '';
    final exp = expiryDate != null ? '(17)${_formatGs1Date(expiryDate)}' : '';
    final qtyText = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return '(240)$safeAccount$mfg$exp(37)$qtyText';
  }

  static String _formatGs1Date(DateTime date) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yy$mm$dd';
  }

  static DateTime? _parseToDateOnly(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static Future<String> _resolveProductAccountCode(String productId) async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('''
            category:inventory_categories(
              inventory_account_code,
              revenue_account_code,
              cost_account_code
            )
          ''')
          .eq('id', productId)
          .maybeSingle();

      final category = (response?['category'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final inv = (category['inventory_account_code'] as String? ?? '').trim();
      if (inv.isNotEmpty) return inv;
      final rev = (category['revenue_account_code'] as String? ?? '').trim();
      if (rev.isNotEmpty) return rev;
      final cost = (category['cost_account_code'] as String? ?? '').trim();
      if (cost.isNotEmpty) return cost;
    } catch (e) {
      debugPrint('Error resolving product account code: $e');
    }
    return '0000000000';
  }

  static Future<void> _createLotBarcodesForReceiving({
    required String productId,
    required List<Map<String, dynamic>> lotBarcodeEntries,
  }) async {
    if (lotBarcodeEntries.isEmpty) return;
    final accountCode = await _resolveProductAccountCode(productId);
    final today = DateTime.now();

    for (final entry in lotBarcodeEntries) {
      final quantity = (entry['quantity'] as num?)?.toDouble() ?? 0;
      if (quantity <= 0) continue;

      final productionDate = _parseToDateOnly(entry['production_date']);
      final expiryDate = _parseToDateOnly(entry['expiry_date']);
      final barcodeText = _buildGs1128LotBarcodeText(
        accountCode: accountCode,
        quantity: quantity,
        productionDate: productionDate,
        expiryDate: expiryDate,
      );

      await _client.from('inventory_product_barcodes').insert({
        'product_id': productId,
        'barcode_type': 'GS1-128',
        'barcode_scope': 'lot',
        'barcode_text': barcodeText,
        'account_code': accountCode,
        'production_date': productionDate?.toIso8601String().split('T').first,
        'expiry_date': expiryDate?.toIso8601String().split('T').first,
        'received_date': today.toIso8601String().split('T').first,
        'lot_quantity': quantity,
        'is_primary': false,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// ดึงสูตรอาหารเรียงตามการใช้งานล่าสุด (updated_at ล่าสุดก่อน)
  static Future<List<Map<String, dynamic>>> getRecipesSortedByUsage() async {
    try {
      final response = await _client
          .from('inventory_recipes')
          .select('id, name, updated_at, yield_quantity, yield_unit')
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading recipes sorted by usage: $e');
      return getRecipes();
    }
  }

  /// Resolve กฎภาษีที่มีผลบังคับใช้ตามประเภทสินค้าและวันที่
  /// หมายเหตุ: เป็นระบบช่วยแนะนำ ต้องให้ผู้ใช้งานตรวจสอบความถูกต้องทางกฎหมายก่อนใช้งานจริง
  static Future<Map<String, dynamic>> resolveTaxRuleForCategory({
    required String categoryId,
    required String itemType,
    DateTime? effectiveDate,
  }) async {
    final date = effectiveDate ?? DateTime.now();
    final isoDate = date.toIso8601String().split('T').first;

    try {
      final response = await _client
          .from('inventory_tax_rules')
          .select('*')
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .or('item_type.eq.$itemType,item_type.eq.both')
          .lte('effective_from', isoDate)
          .or('effective_to.is.null,effective_to.gte.$isoDate')
          .order('priority', ascending: false)
          .order('effective_from', ascending: false)
          .limit(1);

      if ((response as List).isNotEmpty) {
        final row = Map<String, dynamic>.from(response.first);
        return {
          'is_tax_exempt': row['is_tax_exempt'] as bool? ?? false,
          'tax_rate': (row['tax_rate'] as num?)?.toDouble() ?? 0.0,
          'tax_inclusion': (row['tax_inclusion'] as String?) ?? 'excluded',
          'rule_name': (row['rule_name'] as String?) ?? 'กฎภาษีตามประเภทสินค้า',
          'legal_reference': (row['legal_reference'] as String?) ?? '',
          'requires_manual_review': row['requires_manual_review'] as bool? ?? false,
          'source': 'rule',
          'rule_id': row['id'],
          'effective_from': row['effective_from'],
          'effective_to': row['effective_to'],
        };
      }
    } catch (e) {
      debugPrint('Error resolving tax rule: $e');
    }

    return Map<String, dynamic>.from(
      itemType == 'ingredient' ? _ingredientTaxFallback : _productTaxFallback,
    );
  }

  static Future<List<Map<String, dynamic>>> getTaxRules({
    String? categoryId,
    bool includeInactive = true,
  }) async {
    try {
      var query = _client
          .from('inventory_tax_rules')
          .select('''
            *,
            category:inventory_categories(id, code, name)
          ''');

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (!includeInactive) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('is_active', ascending: false)
          .order('priority', ascending: false)
          .order('effective_from', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading tax rules: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addTaxRule({
    required String categoryId,
    required String itemType,
    required bool isTaxExempt,
    required double taxRate,
    required String taxInclusion,
    required String ruleName,
    String? legalReference,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    int priority = 1,
    bool requiresManualReview = true,
    bool isActive = true,
  }) async {
    try {
      final response = await _client.from('inventory_tax_rules').insert({
        'category_id': categoryId,
        'item_type': itemType,
        'is_tax_exempt': isTaxExempt,
        'tax_rate': taxRate,
        'tax_inclusion': taxInclusion,
        'rule_name': ruleName,
        'legal_reference': legalReference,
        'effective_from': effectiveFrom.toIso8601String().split('T').first,
        'effective_to': effectiveTo?.toIso8601String().split('T').first,
        'priority': priority,
        'requires_manual_review': requiresManualReview,
        'is_active': isActive,
      }).select().single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error adding tax rule: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateTaxRule(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      final response = await _client
          .from('inventory_tax_rules')
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error updating tax rule: $e');
      return null;
    }
  }

  static Future<bool> deactivateTaxRule(String id) async {
    try {
      await _client.from('inventory_tax_rules').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deactivating tax rule: $e');
      return false;
    }
  }

  static const String _productBucket = 'product-images';

  static Future<bool> addProduct({
    required String name,
    required String categoryId,
    required String unitId,
    String? shelfId,
    double quantity = 0,
    double minQuantity = 0,
    double price = 0,
    double cost = 0,
    DateTime? expiryDate,
    String itemType = 'product',
    bool isTaxExempt = true,
    double taxRate = 0,
    String taxInclusion = 'excluded',
    Uint8List? imageBytes,
    String? imageFileName,
    bool createGs1Barcode = false,
    String barcodeType = 'GS1-128',
    String? barcodeAccountCode,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'category_id': categoryId,
        'unit_id': unitId,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'price': price,
        'cost': cost,
        'item_type': itemType,
        'is_tax_exempt': isTaxExempt,
        'tax_rate': taxRate,
        'tax_inclusion': taxInclusion,
      };
      if (shelfId != null) data['shelf_id'] = shelfId;
      if (expiryDate != null) data['expiry_date'] = expiryDate.toIso8601String();

      debugPrint('📦 addProduct: $data');
      final response = await _client.from('inventory_products').insert(data).select('id').single();
      final productId = response['id'] as String;

      // อัปโหลดรูปภาพ (ถ้ามี)
      if (imageBytes != null && imageFileName != null) {
        await _uploadProductImage(productId, imageBytes, imageFileName);
      }

      // สร้างบาร์โค้ด GS1-128 อัตโนมัติ (ถ้าเปิดใช้งาน)
      if (createGs1Barcode) {
        await _createProductBarcode(
          productId: productId,
          barcodeType: barcodeType,
          accountCode: barcodeAccountCode,
        );
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error adding product: $e');
      return false;
    }
  }

  /// อัปโหลดรูปภาพสินค้า/วัตถุดิบไปยัง Supabase Storage
  static Future<String?> _uploadProductImage(String productId, Uint8List imageBytes, String fileName) async {
    try {
      // บีบอัดรูปภาพจาก bytes
      Uint8List uploadBytes = imageBytes;
      try {
        final original = img.decodeImage(imageBytes);
        if (original != null) {
          img.Image resized = original;
          if (original.width > 480 || original.height > 480) {
            resized = img.copyResize(
              original,
              width: original.width > original.height ? 480 : null,
              height: original.height >= original.width ? 480 : null,
            );
          }
          uploadBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 45));
          debugPrint('Product image compressed: ${imageBytes.length} -> ${uploadBytes.length} bytes');
        }
      } catch (e) {
        debugPrint('Warning: Could not compress product image, uploading original: $e');
      }

      final storageName = 'product_${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'products/$storageName';

      await _client.storage.from(_productBucket).uploadBinary(
        path,
        uploadBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = _client.storage.from(_productBucket).getPublicUrl(path);

      // อัปเดต image_url ในตาราง products
      await _client.from('inventory_products').update({
        'image_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);

      debugPrint('📸 Product image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error uploading product image: $e');
      return null;
    }
  }

  /// รวมรูปภาพหลายรูปเป็นรูปเดียว (Collage)
  static Future<Uint8List?> mergeImages(List<Uint8List> images) async {
    if (images.isEmpty) return null;
    if (images.length == 1) return images.first;

    return compute(_mergeImagesTask, images);
  }

  static Uint8List? _mergeImagesTask(List<Uint8List> images) {
    try {
      final List<img.Image> decoded = [];
      for (final bytes in images) {
        final d = img.decodeImage(bytes);
        if (d != null) decoded.add(d);
      }

      if (decoded.isEmpty) return null;
      if (decoded.length == 1) return img.encodeJpg(decoded.first, quality: 80);

      const int canvasWidth = 1200;
      const int gap = 10;
      const int rowHeight = 440; // 4:3 approx for half width
      
      // Determine Layout
      int rows = 1;
      if (decoded.length > 2) rows = 2; // 3, 4, 5 -> 2 rows

      final int totalHeight = (rows * rowHeight) + ((rows + 1) * gap);
      
      final canvas = img.Image(width: canvasWidth, height: totalHeight);
      // Fill white background
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

      // Function to draw a row
      void drawRow(List<img.Image> rowImages, int yPos) {
        int count = rowImages.length;
        if (count == 0) return;
        
        int itemWidth = (canvasWidth - (gap * (count + 1))) ~/ count;
        int x = gap;
        
        for (final src in rowImages) {
           // Helper to cover resize
           double srcAspect = src.width / src.height;
           double targetAspect = itemWidth / rowHeight;
           
           img.Image toDraw;
           if (srcAspect > targetAspect) {
             // Image is wider than target. Resize to match height, crop width.
             toDraw = img.copyResize(src, height: rowHeight);
             int cropX = (toDraw.width - itemWidth) ~/ 2;
             if (cropX < 0) cropX = 0;
             toDraw = img.copyCrop(toDraw, x: cropX, y: 0, width: itemWidth, height: rowHeight);
           } else {
             // Image is taller. Resize to match width, crop height.
             toDraw = img.copyResize(src, width: itemWidth);
             int cropY = (toDraw.height - rowHeight) ~/ 2;
             if (cropY < 0) cropY = 0;
             toDraw = img.copyCrop(toDraw, x: 0, y: cropY, width: itemWidth, height: rowHeight);
           }

          img.compositeImage(canvas, toDraw, dstX: x, dstY: yPos);
          x += itemWidth + gap;
        }
      }
      
      // Split images into rows
      List<img.Image> r1 = [];
      List<img.Image> r2 = [];
      
      if (decoded.length <= 2) {
        r1 = decoded;
      } else if (decoded.length == 3) {
        r1 = decoded.sublist(0, 2);
        r2 = decoded.sublist(2);
      } else if (decoded.length == 4) {
        r1 = decoded.sublist(0, 2);
        r2 = decoded.sublist(2);
      } else { // 5
        r1 = decoded.sublist(0, 2);
        r2 = decoded.sublist(2);
      }
      
      int y = gap;
      drawRow(r1, y);
      
      if (r2.isNotEmpty) {
        y += rowHeight + gap;
        drawRow(r2, y);
      }
      
      return Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
      
    } catch (e) {
      // Cannot print in isolate easily without custom setup, just return null on failure
      return null;
    }
  }

  static Future<bool> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('inventory_products').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  static Future<bool> deleteProduct(String id) async {
    try {
      await _client.from('inventory_products').update({'is_active': false}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  /// ย้ายสินค้าไปชั้นวางใหม่
  static Future<bool> updateProductShelf({
    required String productId,
    required String shelfId,
  }) async {
    try {
      // Update product with new shelf_id only
      // Note: warehouse_id is determined by shelf relationship, not stored directly
      await _client.from('inventory_products').update({
        'shelf_id': shelfId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);
      debugPrint('Product $productId moved to shelf $shelfId');
      return true;
    } catch (e) {
      debugPrint('Error updating product shelf: $e');
      return false;
    }
  }

  // =============================================
  // Recipe Categories (ประเภทสูตรอาหาร - แยกจากสินค้า)
  // =============================================

  static Future<List<Map<String, dynamic>>> getRecipeCategories() async {
    try {
      final response = await _client
          .from('inventory_recipe_categories')
          .select('*')
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading recipe categories: $e');
      return [];
    }
  }

  static Future<bool> addRecipeCategory({
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    try {
      await _client.from('inventory_recipe_categories').insert({
        'name': name,
        'description': description,
        'color': color ?? '#2196F3',
        'icon': icon ?? 'restaurant',
      });
      return true;
    } catch (e) {
      debugPrint('Error adding recipe category: $e');
      return false;
    }
  }

  static Future<bool> updateRecipeCategory(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('inventory_recipe_categories').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating recipe category: $e');
      return false;
    }
  }

  static Future<bool> deleteRecipeCategory(String id) async {
    try {
      await _client.from('inventory_recipe_categories').update({'is_active': false}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe category: $e');
      return false;
    }
  }

  /// ดึงประเภทสูตรอาหารเรียงตามการใช้งานล่าสุด
  static Future<List<Map<String, dynamic>>> getRecipeCategoriesSortedByUsage() async {
    try {
      final categories = await getRecipeCategories();
      final recipes = await _client
          .from('inventory_recipes')
          .select('recipe_category_id, updated_at')
          .eq('is_active', true)
          .order('updated_at', ascending: false);
      
      final usageMap = <String, String>{};
      for (final r in recipes) {
        final catId = r['recipe_category_id'] as String? ?? '';
        if (catId.isNotEmpty && !usageMap.containsKey(catId)) {
          usageMap[catId] = r['updated_at']?.toString() ?? '';
        }
      }
      
      categories.sort((a, b) {
        final aId = a['id'] as String? ?? '';
        final bId = b['id'] as String? ?? '';
        final aUsage = usageMap[aId];
        final bUsage = usageMap[bId];
        
        if (aUsage != null && bUsage != null) return bUsage.compareTo(aUsage);
        if (aUsage != null) return -1;
        if (bUsage != null) return 1;
        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });
      
      return categories;
    } catch (e) {
      debugPrint('Error loading recipe categories sorted by usage: $e');
      return [];
    }
  }

  // =============================================
  // Ingredients (วัตถุดิบ - ใช้กับสูตรอาหาร)
  // =============================================

  static Future<List<Map<String, dynamic>>> getIngredients() async {
    try {
      final response = await _client
          .from('inventory_ingredients')
          .select('*')
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading ingredients: $e');
      return [];
    }
  }

  static Future<bool> addIngredient({
    required String name,
    required String categoryId,
    required String unitId,
    String? shelfId,
    double quantity = 0,
    double minQuantity = 0,
    double cost = 0,
    String? supplierName,
    String? expiryDate,
    String? notes,
  }) async {
    try {
      await _client.from('inventory_ingredients').insert({
        'name': name,
        'category_id': categoryId,
        'unit_id': unitId,
        'shelf_id': shelfId,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'cost': cost,
        'supplier_name': supplierName,
        'expiry_date': expiryDate,
        'notes': notes,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding ingredient: $e');
      return false;
    }
  }

  static Future<bool> updateIngredient(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('inventory_ingredients').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating ingredient: $e');
      return false;
    }
  }

  static Future<bool> deleteIngredient(String id) async {
    try {
      await _client.from('inventory_ingredients').update({'is_active': false}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting ingredient: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> searchIngredients(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _client
          .from('inventory_ingredients')
          .select('id, name, unit:inventory_units(id, name, abbreviation), category:inventory_categories(id, name)')
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching ingredients: $e');
      return [];
    }
  }

  // =============================================
  // Categories (ประเภทสินค้า/วัตถุดิบ - ใช้กับทั้งสองตาราง)
  // =============================================

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _client
          .from('inventory_categories')
          .select('*')
          .order('sort_order')
          .order('code');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading categories: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addCategory(
    String name, {
    String? description,
    String? inventoryAccountCode,
    String? revenueAccountCode,
    String? costAccountCode,
    String? code,
    String? parentCode,
    int? level,
    int? sortOrder,
  }) async {
    try {
      final data = {
        'name': name,
        'description': description,
        'inventory_account_code': inventoryAccountCode,
        'revenue_account_code': revenueAccountCode,
        'cost_account_code': costAccountCode,
        if (code != null) 'code': code,
        if (parentCode != null) 'parent_code': parentCode,
        if (level != null) 'level': level,
        if (sortOrder != null) 'sort_order': sortOrder,
      };
      debugPrint('📦 addCategory insert data: $data');
      final response = await _client.from('inventory_categories').insert(data).select();
      debugPrint('📦 addCategory response: $response');
      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      debugPrint('❌ addCategory: insert returned empty response');
      return null;
    } catch (e) {
      debugPrint('❌ Error adding category: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateCategory(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      debugPrint('🔍 updateCategory: id=$id, data=$data');
      final response = await _client.from('inventory_categories').update(data).eq('id', id).select();
      debugPrint('🔍 updateCategory response: $response');
      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      debugPrint('❌ updateCategory: update returned empty response');
      return null;
    } catch (e) {
      debugPrint('❌ Error updating category: $e');
      return null;
    }
  }

  // =============================================
  // Units
  // =============================================

  static Future<List<Map<String, dynamic>>> getUnits() async {
    try {
      final response = await _client
          .from('inventory_units')
          .select('*')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading units: $e');
      return [];
    }
  }

  /// ดึงหน่วยนับเรียงตามจำนวนสินค้าที่ใช้งานจริง (มาก -> น้อย)
  static Future<List<Map<String, dynamic>>> getUnitsSortedByInventoryUsage() async {
    try {
      final units = await getUnits();
      final products = await _client
          .from('inventory_products')
          .select('unit_id')
          .eq('is_active', true);

      final usageCount = <String, int>{};
      for (final p in products) {
        final unitId = p['unit_id'] as String?;
        if (unitId == null) continue;
        usageCount[unitId] = (usageCount[unitId] ?? 0) + 1;
      }

      units.sort((a, b) {
        final aId = a['id'] as String? ?? '';
        final bId = b['id'] as String? ?? '';
        final aCount = usageCount[aId] ?? 0;
        final bCount = usageCount[bId] ?? 0;
        if (aCount != bCount) return bCount.compareTo(aCount);
        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });

      return units;
    } catch (e) {
      debugPrint('Error loading units sorted by inventory usage: $e');
      return getUnits();
    }
  }

  static Future<bool> addUnit(String name, {String? abbreviation}) async {
    try {
      await _client.from('inventory_units').insert({
        'name': name,
        'abbreviation': abbreviation ?? name,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding unit: $e');
      return false;
    }
  }

  // =============================================
  // Warehouses & Shelves
  // =============================================

  static Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final response = await _client
          .from('inventory_warehouses')
          .select('id, name, location, manager, is_active')
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading warehouses: $e');
      return [];
    }
  }

  /// ดึงคลังเรียงตามการใช้งานล่าสุด (จากการเพิ่ม/แก้ไขชั้นวาง)
  static Future<List<Map<String, dynamic>>> getWarehousesSortedByUsage() async {
    try {
      final warehouses = await getWarehouses();
      
      // ดึงชั้นวางเรียงตาม updated_at ล่าสุด
      final shelves = await _client
          .from('inventory_shelves')
          .select('warehouse_id, updated_at')
          .eq('is_active', true)
          .order('updated_at', ascending: false);
      
      // สร้าง map ของ warehouse_id -> latest usage timestamp
      final usageMap = <String, String>{};
      for (final s in shelves) {
        final whId = s['warehouse_id'] as String? ?? '';
        if (whId.isNotEmpty && !usageMap.containsKey(whId)) {
          usageMap[whId] = s['updated_at']?.toString() ?? '';
        }
      }
      
      // เรียง: คลังที่ใช้ล่าสุดก่อน, ที่ไม่เคยใช้ตามหลัง (เรียงตามชื่อ)
      warehouses.sort((a, b) {
        final aId = a['id'] as String? ?? '';
        final bId = b['id'] as String? ?? '';
        final aUsage = usageMap[aId];
        final bUsage = usageMap[bId];
        
        if (aUsage != null && bUsage != null) {
          return bUsage.compareTo(aUsage); // ล่าสุดก่อน
        } else if (aUsage != null) {
          return -1; // a ใช้แล้ว อยู่ก่อน
        } else if (bUsage != null) {
          return 1; // b ใช้แล้ว อยู่ก่อน
        }
        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });
      
      return warehouses;
    } catch (e) {
      debugPrint('Error loading warehouses sorted by usage: $e');
      return [];
    }
  }

  static Future<bool> addWarehouse({required String name, String? location, String? manager}) async {
    try {
      await _client.from('inventory_warehouses').insert({
        'name': name,
        'location': location,
        'manager': manager,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding warehouse: $e');
      return false;
    }
  }

  static Future<bool> updateWarehouse({required String id, required String name, String? location, String? manager}) async {
    try {
      await _client.from('inventory_warehouses').update({
        'name': name,
        'location': location,
        'manager': manager,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating warehouse: $e');
      return false;
    }
  }

  static Future<bool> deleteWarehouse(String id) async {
    try {
      // Check if warehouse has shelves
      final shelves = await _client
          .from('inventory_shelves')
          .select('id')
          .eq('warehouse_id', id)
          .eq('is_active', true)
          .limit(1);
      
      if ((shelves as List).isNotEmpty) {
        debugPrint('Cannot delete warehouse: has active shelves');
        return false;
      }

      await _client.from('inventory_warehouses').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting warehouse: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getShelves({String? warehouseId}) async {
    try {
      var query = _client
          .from('inventory_shelves')
          .select('*, warehouse:inventory_warehouses(id, name)')
          .eq('is_active', true);
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      final response = await query.order('code');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading shelves: $e');
      return [];
    }
  }

  static Future<bool> addShelf({required String warehouseId, required String code, int capacity = 0}) async {
    try {
      await _client.from('inventory_shelves').insert({
        'warehouse_id': warehouseId,
        'code': code,
        'capacity': capacity,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding shelf: $e');
      return false;
    }
  }

  static Future<bool> deleteShelf(String id) async {
    try {
      // Check if shelf has products
      final products = await _client
          .from('inventory_products')
          .select('id')
          .eq('shelf_id', id)
          .eq('is_active', true)
          .limit(1);
      
      if ((products as List).isNotEmpty) {
        debugPrint('Cannot delete shelf: has products');
        return false;
      }

      await _client.from('inventory_shelves').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting shelf: $e');
      return false;
    }
  }

  static Future<bool> updateShelf({
    required String id,
    String? warehouseId,
    String? code,
    int? capacity,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (warehouseId != null) data['warehouse_id'] = warehouseId;
      if (code != null) data['code'] = code;
      if (capacity != null) data['capacity'] = capacity;

      debugPrint('Updating shelf: id=$id, data=$data');

      final response = await _client.from('inventory_shelves').update(data).eq('id', id).select().single();
      
      debugPrint('Update response: $response');
      return true;
    } catch (e) {
      debugPrint('Error updating shelf: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return false;
    }
  }

  // =============================================
  // Recipes
  // =============================================

  static Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      final response = await _client
          .from('inventory_recipes')
          .select('''
            *,
            category:inventory_recipe_categories(id, name, color, icon),
            ingredients:inventory_recipe_ingredients(
              id,
              quantity,
              product:inventory_products(id, name, quantity, unit:inventory_units(id, name, abbreviation))
            )
          ''')
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading recipes: $e');
      return [];
    }
  }

  static Future<bool> addRecipe({
    required String name,
    required String recipeCategoryId,
    double yieldQuantity = 1,
    String yieldUnit = 'ชิ้น',
    double cost = 0,
    double price = 0,
    String? description,
  }) async {
    try {
      await _client.from('inventory_recipes').insert({
        'name': name,
        'recipe_category_id': recipeCategoryId,
        'yield_quantity': yieldQuantity,
        'yield_unit': yieldUnit,
        'cost': cost,
        'price': price,
        'description': description,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding recipe: $e');
      return false;
    }
  }

  /// เพิ่มสูตรพร้อมส่วนผสม
  static Future<bool> addRecipeWithIngredients({
    required String name,
    required String recipeCategoryId,
    double yieldQuantity = 1,
    String yieldUnit = 'ชิ้น',
    double cost = 0,
    double price = 0,
    String? description,
    required List<Map<String, dynamic>> ingredients, // [{product_id, quantity, unit_id}]
  }) async {
    try {
      // 1. เพิ่มสูตร
      final recipeResponse = await _client.from('inventory_recipes').insert({
        'name': name,
        'recipe_category_id': recipeCategoryId,
        'yield_quantity': yieldQuantity,
        'yield_unit': yieldUnit,
        'cost': cost,
        'price': price,
        'description': description,
      }).select('id').single();

      final recipeId = recipeResponse['id'] as String;

      // 2. เพิ่มส่วนผสม
      if (ingredients.isNotEmpty) {
        final ingredientsData = ingredients.map((ing) => {
          'recipe_id': recipeId,
          'product_id': ing['product_id'],
          'quantity': ing['quantity'],
          'unit_id': ing['unit_id'],
        }).toList();

        await _client.from('inventory_recipe_ingredients').insert(ingredientsData);
      }

      return true;
    } catch (e) {
      debugPrint('Error adding recipe with ingredients: $e');
      return false;
    }
  }

  /// ตรวจสอบชื่อสูตรซ้ำ
  static Future<bool> checkRecipeNameExists(String name) async {
    try {
      final response = await _client
          .from('inventory_recipes')
          .select('id')
          .eq('name', name)
          .eq('is_active', true)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking recipe name: $e');
      return false;
    }
  }

  /// ดึง units เรียงตามการใช้งานล่าสุดในสูตรอาหาร
  static Future<List<Map<String, dynamic>>> getUnitsSortedByRecipeUsage() async {
    try {
      final units = await getUnits();
      // ดึง recipes เพื่อดู yield_unit ที่ใช้ล่าสุด
      final recipes = await _client
          .from('inventory_recipes')
          .select('yield_unit, updated_at')
          .eq('is_active', true)
          .order('updated_at', ascending: false);
      
      // สร้าง map ของ unit name -> latest usage timestamp
      final usageMap = <String, String>{};
      for (final r in recipes) {
        final unitName = r['yield_unit'] as String? ?? '';
        if (unitName.isNotEmpty && !usageMap.containsKey(unitName)) {
          usageMap[unitName] = r['updated_at']?.toString() ?? '';
        }
      }
      
      // เรียง: units ที่ใช้ล่าสุดก่อน, ที่ไม่เคยใช้ตามหลัง (เรียงตามชื่อ)
      units.sort((a, b) {
        final aName = a['name'] as String? ?? '';
        final bName = b['name'] as String? ?? '';
        final aUsage = usageMap[aName];
        final bUsage = usageMap[bName];
        
        if (aUsage != null && bUsage != null) {
          return bUsage.compareTo(aUsage); // ล่าสุดก่อน
        } else if (aUsage != null) {
          return -1; // a ใช้แล้ว อยู่ก่อน
        } else if (bUsage != null) {
          return 1; // b ใช้แล้ว อยู่ก่อน
        }
        return aName.compareTo(bName); // ไม่เคยใช้ เรียงตามชื่อ
      });
      
      return units;
    } catch (e) {
      debugPrint('Error loading units sorted by recipe usage: $e');
      return [];
    }
  }

  /// ดึง categories เรียงตามการใช้งานล่าสุดในสูตรอาหาร
  static Future<List<Map<String, dynamic>>> getCategoriesSortedByRecipeUsage() async {
    try {
      final categories = await getCategories();
      final recipes = await _client
          .from('inventory_recipes')
          .select('category_id, updated_at')
          .eq('is_active', true)
          .order('updated_at', ascending: false);
      
      // สร้าง map ของ category_id -> latest usage timestamp
      final usageMap = <String, String>{};
      for (final r in recipes) {
        final catId = r['category_id'] as String? ?? '';
        if (catId.isNotEmpty && !usageMap.containsKey(catId)) {
          usageMap[catId] = r['updated_at']?.toString() ?? '';
        }
      }
      
      categories.sort((a, b) {
        final aId = a['id'] as String? ?? '';
        final bId = b['id'] as String? ?? '';
        final aUsage = usageMap[aId];
        final bUsage = usageMap[bId];
        
        if (aUsage != null && bUsage != null) {
          return bUsage.compareTo(aUsage);
        } else if (aUsage != null) {
          return -1;
        } else if (bUsage != null) {
          return 1;
        }
        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });
      
      return categories;
    } catch (e) {
      debugPrint('Error loading categories sorted by recipe usage: $e');
      return [];
    }
  }

  static Future<bool> updateRecipe(String id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('inventory_recipes').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      return false;
    }
  }

  static Future<bool> deleteRecipe(String id) async {
    try {
      await _client.from('inventory_recipe_ingredients').delete().eq('recipe_id', id);
      await _client.from('inventory_recipes').update({'is_active': false}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      return false;
    }
  }

  // =============================================
  // Production (ผลิตสินค้าจากสูตร)
  // =============================================

  static Future<bool> produceFromRecipe({
    required String recipeId,
    required int batchQuantity,
    required List<Map<String, dynamic>> ingredients,
    required double yieldQuantity,
    String? outputProductId,
    String? userName,
  }) async {
    try {
      // 1. ตัดสต็อกวัตถุดิบ
      for (final ing in ingredients) {
        final productId = ing['product_id'] as String;
        final qtyPerBatch = (ing['quantity'] as num).toDouble();
        final totalDeduct = qtyPerBatch * batchQuantity;
        final currentQty = (ing['current_stock'] as num).toDouble();
        final newQty = currentQty - totalDeduct;

        await _client.from('inventory_products').update({
          'quantity': newQty,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', productId);

        // บันทึก adjustment
        await _client.from('inventory_adjustments').insert({
          'product_id': productId,
          'type': 'produce',
          'quantity_before': currentQty,
          'quantity_after': newQty,
          'quantity_change': -totalDeduct,
          'reason': 'ผลิตจากสูตร (batch: $batchQuantity)',
          'reference_id': recipeId,
          'user_name': userName ?? 'ระบบ',
        });
      }

      // 2. เพิ่มสต็อกสินค้าที่ผลิตได้ (ถ้ามี output product)
      if (outputProductId != null) {
        final productResp = await _client
            .from('inventory_products')
            .select('quantity')
            .eq('id', outputProductId)
            .single();
        final currentQty = (productResp['quantity'] as num).toDouble();
        final newQty = currentQty + yieldQuantity;

        await _client.from('inventory_products').update({
          'quantity': newQty,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', outputProductId);

        await _client.from('inventory_adjustments').insert({
          'product_id': outputProductId,
          'type': 'produce',
          'quantity_before': currentQty,
          'quantity_after': newQty,
          'quantity_change': yieldQuantity,
          'reason': 'ผลิตจากสูตร (batch: $batchQuantity)',
          'reference_id': recipeId,
          'user_name': userName ?? 'ระบบ',
        });
      }

      // 3. บันทึก production log
      await _client.from('inventory_production_logs').insert({
        'recipe_id': recipeId,
        'batch_quantity': batchQuantity,
        'yield_quantity': yieldQuantity,
        'user_name': userName ?? 'ระบบ',
      });

      return true;
    } catch (e) {
      debugPrint('Error producing from recipe: $e');
      return false;
    }
  }

  // =============================================
  // Adjustments
  // =============================================

  static Future<List<Map<String, dynamic>>> getAdjustments({int limit = 20}) async {
    try {
      final response = await _client
          .from('inventory_adjustments')
          .select('''
            *,
            product:inventory_products(id, name, unit:inventory_units(id, name, abbreviation))
          ''')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading adjustments: $e');
      return [];
    }
  }

  static Future<bool> addAdjustment({
    required String productId,
    required String type,
    required double quantityBefore,
    required double quantityAfter,
    String? reason,
    String? userName,
    List<Map<String, dynamic>>? lotBarcodeEntries,
  }) async {
    try {
      final change = quantityAfter - quantityBefore;

      await _client.from('inventory_adjustments').insert({
        'product_id': productId,
        'type': type,
        'quantity_before': quantityBefore,
        'quantity_after': quantityAfter,
        'quantity_change': change,
        'reason': reason,
        'user_name': userName ?? 'ระบบ',
      });

      // อัปเดตจำนวนสินค้า
      await _client.from('inventory_products').update({
        'quantity': quantityAfter,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);

      if (type == 'purchase' && lotBarcodeEntries != null && lotBarcodeEntries.isNotEmpty) {
        await _createLotBarcodesForReceiving(
          productId: productId,
          lotBarcodeEntries: lotBarcodeEntries,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error adding adjustment: $e');
      return false;
    }
  }

  // =============================================
  // Overview / Statistics
  // =============================================

  static Future<Map<String, dynamic>> getOverviewStats() async {
    try {
      final products = await getProducts();
      final adjustments = await getAdjustments(limit: 50);

      final total = products.length;
      final ready = products.where((p) => (p['quantity'] as num) > (p['min_quantity'] as num)).length;
      final low = products.where((p) {
        final qty = (p['quantity'] as num).toDouble();
        final minQty = (p['min_quantity'] as num).toDouble();
        return qty > 0 && qty <= minQty;
      }).length;
      final outOfStock = products.where((p) => (p['quantity'] as num) <= 0).length;

      final now = DateTime.now();
      final expiringSoon = products.where((p) {
        if (p['expiry_date'] == null) return false;
        final expiry = DateTime.tryParse(p['expiry_date'].toString());
        if (expiry == null) return false;
        return expiry.difference(now).inDays <= 7 && expiry.isAfter(now);
      }).toList();

      final lowStockProducts = products.where((p) {
        final qty = (p['quantity'] as num).toDouble();
        final minQty = (p['min_quantity'] as num).toDouble();
        return qty > 0 && qty <= minQty;
      }).toList();

      final todayStart = DateTime(now.year, now.month, now.day);
      final todayAdjustments = adjustments.where((a) {
        final created = DateTime.tryParse(a['created_at'].toString());
        return created != null && created.isAfter(todayStart);
      }).toList();

      final inToday = todayAdjustments.where((a) => (a['quantity_change'] as num) > 0).length;
      final outToday = todayAdjustments.where((a) => (a['quantity_change'] as num) < 0).length;
      final adjustToday = todayAdjustments.length;

      final totalValue = products.fold<double>(0, (sum, p) {
        return sum + (p['quantity'] as num).toDouble() * (p['price'] as num).toDouble();
      });

      return {
        'total': total,
        'ready': ready,
        'low': low,
        'outOfStock': outOfStock,
        'expiringSoon': expiringSoon,
        'lowStockProducts': lowStockProducts,
        'inToday': inToday,
        'outToday': outToday,
        'adjustToday': adjustToday,
        'totalValue': totalValue,
        'products': products,
      };
    } catch (e) {
      debugPrint('Error loading overview stats: $e');
      return {};
    }
  }

  // =============================================
  // Recipe Images
  // =============================================

  static const String _recipeBucket = 'recipe-images';
  static const int _maxImageWidth = 800;
  static const int _maxImageHeight = 800;
  static const int _imageQuality = 70; // คุณภาพ 70% สมดุลระหว่างขนาดและความคมชัด

  /// บีบอัดรูปภาพก่อนอัปโหลด
  static Future<Uint8List?> compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return null;

      // Resize if larger than max dimensions
      img.Image resized = original;
      if (original.width > _maxImageWidth || original.height > _maxImageHeight) {
        resized = img.copyResize(
          original,
          width: original.width > original.height ? _maxImageWidth : null,
          height: original.height >= original.width ? _maxImageHeight : null,
        );
      }

      final result = Uint8List.fromList(img.encodeJpg(resized, quality: _imageQuality));
      debugPrint('Image compressed: ${bytes.length} -> ${result.length} bytes (${(result.length / bytes.length * 100).toStringAsFixed(0)}%)');
      return result;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// อัปโหลดรูปภาพสูตรอาหารไปยัง Supabase Storage
  static Future<String?> uploadRecipeImage(File imageFile, String recipeId) async {
    try {
      // บีบอัดรูปภาพ
      final compressed = await compressImage(imageFile);
      if (compressed == null) return null;

      final fileName = 'recipe_${recipeId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'recipes/$fileName';

      await _client.storage.from(_recipeBucket).uploadBinary(
        path,
        compressed,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      // สร้าง public URL
      final publicUrl = _client.storage.from(_recipeBucket).getPublicUrl(path);
      
      // อัปเดต image_url ในตาราง recipes
      await _client.from('inventory_recipes').update({
        'image_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', recipeId);

      debugPrint('Recipe image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading recipe image: $e');
      return null;
    }
  }

  /// ลบรูปภาพสูตรอาหารจาก Supabase Storage
  static Future<bool> deleteRecipeImage(String recipeId, String imageUrl) async {
    try {
      // ดึง path จาก URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // URL format: .../storage/v1/object/public/recipe-images/recipes/filename.jpg
      final bucketIndex = pathSegments.indexOf(_recipeBucket);
      if (bucketIndex >= 0 && bucketIndex + 1 < pathSegments.length) {
        final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _client.storage.from(_recipeBucket).remove([storagePath]);
      }

      // ลบ image_url ในตาราง recipes
      await _client.from('inventory_recipes').update({
        'image_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', recipeId);

      debugPrint('Recipe image deleted for recipe: $recipeId');
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe image: $e');
      return false;
    }
  }

  /// อัปโหลดรูปภาพสูตรใหม่ (ใช้ตอนสร้างสูตรใหม่ ยังไม่มี recipeId)
  static Future<String?> uploadRecipeImageTemp(File imageFile) async {
    try {
      final compressed = await compressImage(imageFile);
      if (compressed == null) return null;

      final fileName = 'recipe_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'recipes/$fileName';

      await _client.storage.from(_recipeBucket).uploadBinary(
        path,
        compressed,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = _client.storage.from(_recipeBucket).getPublicUrl(path);
      debugPrint('Temp recipe image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading temp recipe image: $e');
      return null;
    }
  }

  /// ค้นหาวัตถุดิบตามชื่อ (ใช้สำหรับ autocomplete)
  static Future<List<Map<String, dynamic>>> searchProductsByName(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _client
          .from('inventory_products')
          .select('id, name, unit:inventory_units(id, name, abbreviation), category:inventory_categories(id, name)')
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  /// ดึงวัตถุดิบตามชื่อ (สำหรับตรวจสอบว่ามีอยู่แล้วหรือไม่)
  static Future<Map<String, dynamic>?> getProductByName(String name) async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('*, unit:inventory_units(id, name, abbreviation)')
          .eq('name', name)
          .eq('is_active', true)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error getting product by name: $e');
      return null;
    }
  }

  /// เพิ่มวัตถุดิบใหม่แบบง่าย (ใช้สำหรับสร้างวัตถุดิบใหม่จาก dialog สูตร)
  static Future<Map<String, dynamic>?> addProductSimple({
    required String name,
    required String unitId,
    String? shelfId,
  }) async {
    try {
      // หา shelf แรกถ้าไม่ระบุ
      String? targetShelfId = shelfId;
      if (targetShelfId == null) {
        final shelfResp = await _client
            .from('inventory_shelves')
            .select('id')
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();
        if (shelfResp != null) {
          targetShelfId = shelfResp['id'] as String;
        }
      }

      // หาหมวดหมู่วัตถุดิบ
      var categoryResp = await _client
          .from('inventory_categories')
          .select('id')
          .eq('name', 'วัตถุดิบ')
          .maybeSingle();
      
      // ถ้าไม่มีหมวด "วัตถุดิบ" ให้หาหมวดแรก
      if (categoryResp == null) {
        categoryResp = await _client
            .from('inventory_categories')
            .select('id')
            .limit(1)
            .maybeSingle();
      }

      final response = await _client.from('inventory_products').insert({
        'name': name,
        'category_id': categoryResp?['id'],
        'unit_id': unitId,
        'shelf_id': targetShelfId,
        'quantity': 0,
        'min_quantity': 0,
        'price': 0,
        'cost': 0,
      }).select('id, name, unit:inventory_units(id, name, abbreviation)').single();

      debugPrint('New product created from recipe: $name');
      return response;
    } catch (e) {
      debugPrint('Error adding simple product: $e');
      return null;
    }
  }

  /// เพิ่มสูตรพร้อมส่วนผสม โดยจัดการวัตถุดิบใหม่ที่ยังไม่มีในระบบ
  static Future<bool> addRecipeWithIngredientsAndImage({
    required String name,
    required String categoryId,
    double yieldQuantity = 1,
    String yieldUnit = 'ชิ้น',
    double cost = 0,
    double price = 0,
    String? description,
    String? imageUrl,
    required List<Map<String, dynamic>> ingredients,
    required List<Map<String, dynamic>> newIngredientsToCreate,
  }) async {
    try {
      // สร้างวัตถุดิบใหม่ก่อนถ้ามี
      final List<Map<String, dynamic>> finalIngredients = [];
      for (final newIng in newIngredientsToCreate) {
        final created = await addProductSimple(
          name: newIng['name'],
          unitId: newIng['unit_id'],
        );
        if (created != null) {
          finalIngredients.add({
            'product_id': created['id'],
            'quantity': newIng['quantity'],
            'unit_id': newIng['unit_id'],
          });
        }
      }

      // รวมกับวัตถุดิบที่มีอยู่แล้ว
      finalIngredients.addAll(ingredients);

      final recipeResponse = await _client.from('inventory_recipes').insert({
        'name': name,
        'recipe_category_id': categoryId,
        'yield_quantity': yieldQuantity,
        'yield_unit': yieldUnit,
        'cost': cost,
        'price': price,
        'description': description,
        'image_url': imageUrl,
      }).select('id').single();

      final recipeId = recipeResponse['id'] as String;

      if (finalIngredients.isNotEmpty) {
        final ingredientsData = finalIngredients.map((ing) => {
          'recipe_id': recipeId,
          'product_id': ing['product_id'],
          'quantity': ing['quantity'],
          'unit_id': ing['unit_id'],
        }).toList();

        await _client.from('inventory_recipe_ingredients').insert(ingredientsData);
      }

      return true;
    } catch (e) {
      debugPrint('Error adding recipe with ingredients and image: $e');
      return false;
    }
  }
}
