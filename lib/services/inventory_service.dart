import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'table_management_service.dart';

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

  static Future<List<Map<String, dynamic>>> getWarehouseUtilizationSummary() async {
    try {
      final shelves = await _client
          .from('inventory_shelves')
          .select('id, warehouse_id, capacity, is_active');
      final products = await _client
          .from('inventory_products')
          .select('id, shelf_id');

      final productCountByShelf = <String, int>{};
      for (final product in products) {
        final shelfId = product['shelf_id']?.toString();
        if (shelfId == null) continue;
        productCountByShelf[shelfId] = (productCountByShelf[shelfId] ?? 0) + 1;
      }

      final utilization = <String, Map<String, dynamic>>{};
      for (final shelf in shelves) {
        final warehouseId = shelf['warehouse_id']?.toString();
        if (warehouseId == null) continue;
        final shelfId = shelf['id']?.toString();
        final capacity = shelf['capacity'] is int
            ? shelf['capacity'] as int
            : int.tryParse(shelf['capacity']?.toString() ?? '0') ?? 0;

        final used = shelfId != null ? (productCountByShelf[shelfId] ?? 0) : 0;
        final entry = utilization.putIfAbsent(warehouseId, () => {
              'capacity': 0,
              'used': 0,
              'activeShelves': 0,
            });
        entry['capacity'] = (entry['capacity'] as int) + capacity;
        entry['used'] = (entry['used'] as int) + used;
        if (shelf['is_active'] != false) {
          entry['activeShelves'] = (entry['activeShelves'] as int) + 1;
        }
      }

      return utilization.entries
          .map((entry) => {
                'warehouse_id': entry.key,
                ...entry.value,
              })
          .toList();
    } catch (e) {
      debugPrint('Error computing warehouse utilization: $e');
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

  static Future<List<Map<String, dynamic>>> getWarehouses({bool includeInactive = false}) async {
    try {
      var query = _client
          .from('inventory_warehouses')
          .select('id, name, location, manager, capacity_limit, is_active, created_at, updated_at');
      if (!includeInactive) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('name');
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

  static Future<bool> addWarehouse({
    required String name,
    String? location,
    String? manager,
    bool isActive = true,
    int? capacityLimit,
  }) async {
    try {
      await _client.from('inventory_warehouses').insert({
        'name': name,
        'location': location,
        'manager': manager,
        'is_active': isActive,
        'capacity_limit': capacityLimit,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding warehouse: $e');
      return false;
    }
  }

  static Future<bool> updateWarehouse({
    required String id,
    required String name,
    String? location,
    String? manager,
    bool? isActive,
    int? capacityLimit,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (location != null) data['location'] = location;
      if (manager != null) data['manager'] = manager;
      if (isActive != null) data['is_active'] = isActive;
      if (capacityLimit != null) {
        data['capacity_limit'] = capacityLimit;
      }

      await _client.from('inventory_warehouses').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating warehouse: $e');
      return false;
    }
  }

  static Future<bool> updateWarehouseManager({
    required String id,
    String? managerId,
  }) async {
    try {
      await _client
          .from('inventory_warehouses')
          .update({
            'manager': managerId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating warehouse manager: $e');
      return false;
    }
  }

  static Future<bool> updateWarehouseCapacityLimit({
    required String id,
    int? capacityLimit,
  }) async {
    try {
      await _client
          .from('inventory_warehouses')
          .update({
            'capacity_limit': capacityLimit,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating warehouse capacity limit: $e');
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

  static Future<List<Map<String, dynamic>>> getWarehouseZones({
    String? warehouseId,
    bool includeInactive = false,
  }) async {
    try {
      var query = _client
          .from('inventory_zones')
          .select('*');
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      if (!includeInactive) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('display_order', ascending: true).order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading warehouse zones: $e');
      return [];
    }
  }

  static Future<bool> addWarehouseZone({
    required String warehouseId,
    required String name,
  }) async {
    try {
      await _client.from('inventory_zones').insert({
        'warehouse_id': warehouseId,
        'name': name,
        'display_order': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding warehouse zone: $e');
      return false;
    }
  }

  static Future<bool> updateWarehouseZone({
    required String id,
    String? name,
    int? displayOrder,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) data['name'] = name;
      if (displayOrder != null) data['display_order'] = displayOrder;
      if (isActive != null) data['is_active'] = isActive;

      await _client.from('inventory_zones').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating warehouse zone: $e');
      return false;
    }
  }

  static Future<bool> deleteWarehouseZone(String id) async {
    try {
      await _client.from('inventory_zones').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting warehouse zone: $e');
      return false;
    }
  }

  static Future<bool> updateZoneOrder(String warehouseId, List<String> orderedZoneIds) async {
    try {
      for (var i = 0; i < orderedZoneIds.length; i++) {
        await _client
            .from('inventory_zones')
            .update({'display_order': i, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', orderedZoneIds[i])
            .eq('warehouse_id', warehouseId);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating zone order: $e');
      return false;
    }
  }

  static Future<bool> updateShelfOrder(List<String> orderedShelfIds) async {
    try {
      for (var i = 0; i < orderedShelfIds.length; i++) {
        await _client
            .from('inventory_shelves')
            .update({'display_order': i, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', orderedShelfIds[i]);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating shelf order: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getShelves({
    String? warehouseId,
    bool includeInactive = false,
  }) async {
    try {
      var query = _client.from('inventory_shelves').select('''
            id,
            code,
            capacity,
            display_order,
            is_active,
            warehouse_id,
            zone_id,
            warehouse:inventory_warehouses(id, name),
            zone:inventory_zones(id, name, display_order, is_active)
          ''');
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      if (!includeInactive) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('display_order', ascending: true).order('code');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading shelves: $e');
      return [];
    }
  }

  static Future<bool> addShelf({
    required String warehouseId,
    required String code,
    int capacity = 0,
    String? zoneId,
    bool isActive = true,
  }) async {
    try {
      await _client.from('inventory_shelves').insert({
        'warehouse_id': warehouseId,
        'code': code,
        'capacity': capacity,
        'zone_id': zoneId,
        'display_order': DateTime.now().millisecondsSinceEpoch,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
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
    String? zoneId,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (warehouseId != null) data['warehouse_id'] = warehouseId;
      if (code != null) data['code'] = code;
      if (capacity != null) data['capacity'] = capacity;
      if (zoneId != null) data['zone_id'] = zoneId;
      if (isActive != null) data['is_active'] = isActive;

      data['updated_at'] = DateTime.now().toIso8601String();

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

  /// ✅ Validate if recipe can be produced with current stock
  static Future<Map<String, dynamic>> checkRecipeCanProduce({
    required String recipeId,
    required int batchQuantity,
  }) async {
    try {
      final response = await _client.rpc('check_recipe_can_produce', params: {
        'p_recipe_id': recipeId,
        'p_batch_quantity': batchQuantity,
      });
      
      final result = response as Map<String, dynamic>;
      return {
        'can_produce': result['can_produce'] ?? false,
        'missing_ingredients': result['missing_ingredients'] ?? [],
      };
    } catch (e) {
      debugPrint('Error checking recipe: $e');
      return {
        'can_produce': false,
        'missing_ingredients': [],
        'error': e.toString(),
      };
    }
  }

  /// ✅ Produce from recipe with validation & transaction
  static Future<Map<String, dynamic>> produceFromRecipe({
    required String recipeId,
    required int batchQuantity,
    required List<Map<String, dynamic>> ingredients,
    required double yieldQuantity,
    String? outputProductId,
    String? userName,
  }) async {
    try {
      // ✅ Step 1: Validate stock BEFORE production
      final validation = await checkRecipeCanProduce(
        recipeId: recipeId,
        batchQuantity: batchQuantity,
      );
      
      if (validation['can_produce'] != true) {
        final missingList = validation['missing_ingredients'] as List? ?? [];
        final missingStr = missingList.isEmpty 
          ? 'สต็อกไม่พอ'
          : missingList
              .map((m) => '${m['product_name']}: ต้อง ${m['needed']} แต่มี ${m['current']}')
              .join(', ');
        
        return {
          'success': false,
          'message': 'ไม่สามารถผลิตได้: $missingStr',
          'missing_ingredients': missingList,
        };
      }

      // ✅ Step 2: Use transaction function for production
      final response = await _client.rpc('produce_from_recipe', params: {
        'p_recipe_id': recipeId,
        'p_batch_quantity': batchQuantity,
        'p_ingredients': ingredients,
        'p_output_product_id': outputProductId,
        'p_user_name': userName ?? 'ระบบ',
      });

      final result = response as Map<String, dynamic>;
      
      return {
        'success': result['success'] ?? false,
        'message': result['message'] ?? 'เกิดข้อผิดพลาด',
        'production_log_id': result['production_log_id'],
      };
    } catch (e) {
      debugPrint('Error producing from recipe: $e');
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.toString()}',
      };
    }
  }

  /// ✅ Get production audit trail
  static Future<List<Map<String, dynamic>>> getProductionAuditTrail({
    required String recipeId,
  }) async {
    try {
      final response = await _client.rpc('get_production_audit_trail', params: {
        'p_recipe_id': recipeId,
      });
      
      return List<Map<String, dynamic>>.from(response as List? ?? []);
    } catch (e) {
      debugPrint('Error getting production audit trail: $e');
      return [];
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
    String? createdBy,
    bool applyImmediately = true,
    List<Map<String, dynamic>>? lotBarcodeEntries,
  }) async {
    try {
      final change = quantityAfter - quantityBefore;
      final now = DateTime.now().toIso8601String();

      await _client.from('inventory_adjustments').insert({
        'product_id': productId,
        'type': type,
        'quantity_before': quantityBefore,
        'quantity_after': quantityAfter,
        'quantity_change': change,
        'reason': reason,
        'user_name': userName ?? 'ระบบ',
        'created_by': createdBy,
        'status': applyImmediately ? 'completed' : 'pending',
        'created_at': now,
        'updated_at': now,
      });

      if (applyImmediately) {
        // อัปเดตจำนวนสินค้า
        await _client.from('inventory_products').update({
          'quantity': quantityAfter,
          'updated_at': now,
        }).eq('id', productId);

        if (type == 'purchase' && lotBarcodeEntries != null && lotBarcodeEntries.isNotEmpty) {
          await _createLotBarcodesForReceiving(
            productId: productId,
            lotBarcodeEntries: lotBarcodeEntries,
          );
        }
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

  static Future<Map<String, dynamic>> getInventoryReportsDashboard({
    int turnoverDays = 90,
    int slowDays = 60,
    int slowLimit = 10,
  }) async {
    try {
      final now = DateTime.now();
      final windowDays = math.max(turnoverDays, slowDays);
      final windowStart = now.subtract(Duration(days: windowDays));

      final results = await Future.wait([
        getProducts(),
        _client
            .from('inventory_adjustments')
            .select('product_id, quantity_change, type, created_at, status')
            .gte('created_at', windowStart.toIso8601String())
            .order('created_at', ascending: false),
      ]);

      final products = List<Map<String, dynamic>>.from(results[0] as List);
      final adjustmentsRaw = List<Map<String, dynamic>>.from(results[1] as List);

      final valuation = _computeValuationSummary(products);
      final turnover = _computeTurnoverMetrics(
        products: products,
        adjustments: adjustmentsRaw,
        turnoverDays: turnoverDays,
        windowStart: now.subtract(Duration(days: turnoverDays)),
      );
      final slowMovers = _computeSlowMovers(
        products: products,
        adjustments: adjustmentsRaw,
        slowDays: slowDays,
        slowLimit: slowLimit,
        now: now,
      );

      return {
        'valuation': valuation,
        'turnover': turnover,
        'slowMovers': slowMovers,
      };
    } catch (e) {
      debugPrint('Error loading inventory reports dashboard: $e');
      return {};
    }
  }

  static Map<String, dynamic> _computeValuationSummary(List<Map<String, dynamic>> products) {
    double totalQuantity = 0;
    double totalValue = 0;
    final categoryMap = <String, double>{};

    for (final product in products) {
      final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
      final cost = (product['cost'] as num?)?.toDouble() ?? 0;
      final value = qty * cost;
      final categoryName = product['category']?['name']?.toString() ?? 'ไม่ระบุหมวดหมู่';

      totalQuantity += qty;
      totalValue += value;
      categoryMap[categoryName] = (categoryMap[categoryName] ?? 0) + value;
    }

    final avgCost = totalQuantity > 0 ? totalValue / totalQuantity : 0;
    final breakdown = categoryMap.entries
        .map((entry) => {
              'label': entry.key,
              'value': entry.value,
              'percent': totalValue > 0 ? (entry.value / totalValue) : 0,
            })
        .toList()
      ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    return {
      'totalQuantity': totalQuantity,
      'totalValue': totalValue,
      'avgCost': avgCost,
      'categories': breakdown,
    };
  }

  static Map<String, dynamic> _computeTurnoverMetrics({
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> adjustments,
    required int turnoverDays,
    required DateTime windowStart,
    int buckets = 6,
  }) {
    final now = DateTime.now();
    final bucketLength = math.max(1, (turnoverDays / buckets).ceil());
    final bucketValues = List<double>.filled(buckets, 0);
    double totalOutQuantity = 0;

    for (final adj in adjustments) {
      final status = (adj['status'] ?? 'completed').toString();
      if (status == 'pending' || status == 'rejected') continue;

      final change = (adj['quantity_change'] as num?)?.toDouble() ?? 0;
      if (change >= 0) continue; // only count outflows

      final createdAtStr = adj['created_at']?.toString();
      if (createdAtStr == null) continue;
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt == null || createdAt.isBefore(windowStart)) continue;

      final diffDays = createdAt.difference(windowStart).inDays;
      var bucketIndex = (diffDays / bucketLength).floor();
      if (bucketIndex < 0) continue;
      if (bucketIndex >= buckets) bucketIndex = buckets - 1;

      final outQty = -change;
      bucketValues[bucketIndex] += outQty;
      totalOutQuantity += outQty;
    }

    final totalQuantity = products.fold<double>(0, (sum, product) => sum + ((product['quantity'] as num?)?.toDouble() ?? 0));
    final turnoverRatio = totalQuantity > 0 ? totalOutQuantity / totalQuantity : 0;

    final trend = List.generate(buckets, (index) {
      final start = windowStart.add(Duration(days: index * bucketLength));
      final end = start.add(Duration(days: bucketLength));
      final label = '${start.day}/${start.month} - ${end.day}/${end.month}';
      return {
        'label': label,
        'value': bucketValues[index],
      };
    });

    return {
      'totalOut': totalOutQuantity,
      'turnoverRatio': turnoverRatio,
      'trend': trend,
    };
  }

  static List<Map<String, dynamic>> _computeSlowMovers({
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> adjustments,
    required int slowDays,
    required int slowLimit,
    required DateTime now,
  }) {
    final lastMovementMap = <String, DateTime>{};
    for (final adj in adjustments) {
      final status = (adj['status'] ?? 'completed').toString();
      if (status == 'pending' || status == 'rejected') continue;

      final productId = adj['product_id']?.toString();
      if (productId == null) continue;
      final createdAtStr = adj['created_at']?.toString();
      if (createdAtStr == null) continue;
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt == null) continue;

      final prev = lastMovementMap[productId];
      if (prev == null || createdAt.isAfter(prev)) {
        lastMovementMap[productId] = createdAt;
      }
    }

    final slowList = <Map<String, dynamic>>[];
    for (final product in products) {
      final productId = product['id']?.toString();
      if (productId == null) continue;
      final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
      if (qty <= 0) continue;

      final cost = (product['cost'] as num?)?.toDouble() ?? 0;
      final lastMove = lastMovementMap[productId] ?? _parseDate(product['updated_at']) ?? _parseDate(product['created_at']);
      final daysSince = lastMove == null ? 9999 : now.difference(lastMove).inDays;

      if (daysSince >= slowDays) {
        slowList.add({
          'name': product['name'] ?? '-',
          'days': daysSince,
          'quantity': qty,
          'unit': product['unit']?['abbreviation'] ?? product['unit']?['name'] ?? '',
          'value': qty * cost,
        });
      }
    }

    slowList.sort((a, b) => (b['days'] as int).compareTo(a['days'] as int));
    if (slowList.length > slowLimit) {
      return slowList.sublist(0, slowLimit);
    }
    return slowList;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

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
      categoryResp ??= await _client
          .from('inventory_categories')
          .select('id')
          .limit(1)
          .maybeSingle();

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

  // =============================================
  // Stock Movement (enhanced queries)
  // =============================================

  /// ดึง stock movement พร้อม filter (type, product, date range)
  static Future<List<Map<String, dynamic>>> getStockMovements({
    int limit = 100,
    String? type,
    String? productId,
    String? warehouseId,
    String? shelfId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      var query = _client
          .from('inventory_adjustments')
          .select('''
            *,
            product:inventory_products(
              id,
              name,
              sku,
              unit:inventory_units(id, name, abbreviation),
              shelf:inventory_shelves(id, code, warehouse:inventory_warehouses(id, name))
            )
          ''');

      if (type != null && type.isNotEmpty && type != 'all') {
        query = query.eq('type', type);
      }
      if (productId != null && productId.isNotEmpty) {
        query = query.eq('product_id', productId);
      }
      if (shelfId != null && shelfId.isNotEmpty) {
        query = query.eq('product->shelf_id', shelfId);
      }
      if (warehouseId != null && warehouseId.isNotEmpty) {
        query = query.eq('product->shelf->warehouse_id', warehouseId);
      }
      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }
      if (dateTo != null) {
        final endOfDay = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading stock movements: $e');
      return [];
    }
  }

  /// สรุปยอด movement แยกตาม type
  static Future<Map<String, dynamic>> getMovementSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final movements = await getStockMovements(
        limit: 1000,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      double totalIn = 0;
      double totalOut = 0;
      int saleCount = 0;
      int purchaseCount = 0;
      int adjustCount = 0;

      for (final m in movements) {
        final change = (m['quantity_change'] as num?)?.toDouble() ?? 0;
        final type = m['type'] as String? ?? '';

        if (change > 0) totalIn += change;
        if (change < 0) totalOut += change.abs();

        switch (type) {
          case 'sale': saleCount++; break;
          case 'purchase': case 'receive': purchaseCount++; break;
          default: adjustCount++; break;
        }
      }

      return {
        'total_in': totalIn,
        'total_out': totalOut,
        'sale_count': saleCount,
        'purchase_count': purchaseCount,
        'adjust_count': adjustCount,
        'total_count': movements.length,
      };
    } catch (e) {
      debugPrint('Error getting movement summary: $e');
      return {};
    }
  }

  /// สร้างคำขอโอนสินค้า (draft)
  static Future<String?> createTransfer({
    required String productId,
    required double quantity,
    required String sourceWarehouseId,
    String? sourceShelfId,
    required String targetWarehouseId,
    String? targetShelfId,
    String? reason,
    String? note,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();
      final response = await _client.from('inventory_transfers').insert({
        'product_id': productId,
        'quantity': quantity,
        'source_warehouse_id': sourceWarehouseId,
        'source_shelf_id': sourceShelfId,
        'target_warehouse_id': targetWarehouseId,
        'target_shelf_id': targetShelfId,
        'reason': reason,
        'note': note,
        'created_by': userId,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      }).select('id').single();
      final insertedId = response['id']?.toString();
      return insertedId;
    } catch (e) {
      debugPrint('Error creating transfer: $e');
      return null;
    }
  }

  /// ส่งคำขอโอน (draft → pending)
  static Future<bool> submitTransfer({
    required String id,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _client
          .from('inventory_transfers')
          .update({'status': 'pending', 'updated_at': now})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error submitting transfer: $e');
      return false;
    }
  }

  /// รับรายการโอน (status filter optional)
  static Future<List<Map<String, dynamic>>> getTransfers({
    String? status,
    String? warehouseId,
    int limit = 100,
  }) async {
    try {
      var query = _client
          .from('inventory_transfers')
          .select('''
            *,
            product:inventory_products(id, name, sku, unit:inventory_units(id, name, abbreviation)),
            source_warehouse:inventory_warehouses(id, name),
            target_warehouse:inventory_warehouses(id, name)
          ''');
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (warehouseId != null && warehouseId.isNotEmpty) {
        query = query.or('source_warehouse_id.eq.$warehouseId,target_warehouse_id.eq.$warehouseId');
      }
      final response = await query.order('created_at', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading transfers: $e');
      return [];
    }
  }

  static Future<bool> _insertTransferAdjustment({
    required String productId,
    required String type,
    required double quantity,
    required String reason,
    required String? userId,
  }) async {
    try {
      final productResp = await _client
          .from('inventory_products')
          .select('id, quantity')
          .eq('id', productId)
          .single();
      final currentQty = (productResp['quantity'] as num?)?.toDouble() ?? 0.0;
      await _client.from('inventory_adjustments').insert({
        'product_id': productId,
        'type': type,
        'quantity_before': currentQty,
        'quantity_after': currentQty,
        'quantity_change': type == 'transfer_in' ? quantity : -quantity,
        'reason': reason,
        'user_id': userId,
        'user_name': null,
      });
      return true;
    } catch (e) {
      debugPrint('Error inserting transfer adjustment: $e');
      return false;
    }
  }

  static Future<bool> _updateProductShelf({
    required String productId,
    String? shelfId,
  }) async {
    try {
      await _client
          .from('inventory_products')
          .update({'shelf_id': shelfId, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', productId);
      return true;
    } catch (e) {
      debugPrint('Error updating product shelf: $e');
      return false;
    }
  }

  /// อนุมัติคำขอโอน (สร้าง adjustment + update status)
  static Future<bool> approveTransfer({
    required String id,
    required String approverId,
    String? note,
  }) async {
    try {
      final transfer = await _client
          .from('inventory_transfers')
          .select('id, product_id, quantity, target_shelf_id, status, reason, target_warehouse_id, source_warehouse_id')
          .eq('id', id)
          .single();
      if (transfer == null || transfer['status'] != 'pending') return false;
      final productId = transfer['product_id']?.toString();
      if (productId == null) return false;
      final qty = (transfer['quantity'] as num?)?.toDouble() ?? 0.0;
      final reason = transfer['reason']?.toString() ?? 'โอนคลัง';
      final warehouseLabel = transfer['target_warehouse_id'] ?? transfer['source_warehouse_id'];
      final reasonText = '$reason (โอนไปคลัง ${warehouseLabel ?? 'ไม่ระบุ'})';

      await Future.wait([
        _insertTransferAdjustment(
          productId: productId,
          type: 'transfer_out',
          quantity: qty,
          reason: 'ส่งออก $reasonText',
          userId: approverId,
        ),
        _insertTransferAdjustment(
          productId: productId,
          type: 'transfer_in',
          quantity: qty,
          reason: 'รับเข้า $reasonText',
          userId: approverId,
        ),
      ]);
      await _updateProductShelf(productId: productId, shelfId: transfer['target_shelf_id']?.toString());
      await _client
          .from('inventory_transfers')
          .update({
            'status': 'approved',
            'approved_by': approverId,
            'approved_at': DateTime.now().toIso8601String(),
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error approving transfer: $e');
      return false;
    }
  }

  /// ปฏิเสธคำขอโอน (status → rejected)
  static Future<bool> rejectTransfer({
    required String id,
    required String approverId,
    String? note,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _client
          .from('inventory_transfers')
          .update({
            'status': 'rejected',
            'approved_by': approverId,
            'approved_at': now,
            'note': note,
            'updated_at': now,
          })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error rejecting transfer: $e');
      return false;
    }
  }

  /// ดึง adjustments ที่รอการอนุมัติ
  static Future<List<Map<String, dynamic>>> getPendingAdjustments() async {
    try {
      final response = await _client
          .from('inventory_adjustments')
          .select('''
            *,
            product:inventory_products(id, name, sku, unit:inventory_units(id, name, abbreviation))
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting pending adjustments: $e');
      return [];
    }
  }

  /// อนุมัติ adjustment
  static Future<bool> approveAdjustment({
    required String adjustmentId,
    required String approverId,
    String? note,
  }) async {
    try {
      final adjustment = await _client
          .from('inventory_adjustments')
          .select('''
            *,
            product:inventory_products(id, quantity)
          ''')
          .eq('id', adjustmentId)
          .single();

      if (adjustment.isEmpty) return false;

      final productId = adjustment['product_id']?.toString();
      if (productId == null) return false;

      final currentQty = (adjustment['product']?['quantity'] as num?)?.toDouble() ?? 0;
      final change = (adjustment['quantity_change'] as num?)?.toDouble() ?? 0;
      final newQty = (currentQty + change).clamp(0, double.infinity);
      final now = DateTime.now().toIso8601String();

      await _client.from('inventory_products').update({
        'quantity': newQty,
        'updated_at': now,
      }).eq('id', productId);

      await _client
          .from('inventory_adjustments')
          .update({
            'status': 'approved',
            'quantity_before': currentQty,
            'quantity_after': newQty,
            'approved_by': approverId,
            'approved_at': now,
            'approval_note': note,
            'updated_at': now,
          })
          .eq('id', adjustmentId);
      return true;
    } catch (e) {
      debugPrint('Error approving adjustment: $e');
      return false;
    }
  }

  /// ปฏิเสธ adjustment
  static Future<bool> rejectAdjustment({
    required String adjustmentId,
    required String approverId,
    String? note,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _client
          .from('inventory_adjustments')
          .update({
            'status': 'rejected',
            'approved_by': approverId,
            'approved_at': now,
            'approval_note': note,
            'updated_at': now,
          })
          .eq('id', adjustmentId);
      return true;
    } catch (e) {
      debugPrint('Error rejecting adjustment: $e');
      return false;
    }
  }

  /// ดึงสินค้าที่คงเหลือต่ำกว่า min_quantity
  static Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final products = await getProducts();
      return products.where((p) {
        final qty = (p['quantity'] as num?)?.toDouble() ?? 0;
        final minQty = (p['min_quantity'] as num?)?.toDouble() ?? 0;
        return qty <= minQty && minQty > 0;
      }).toList();
    } catch (e) {
      debugPrint('Error getting low stock products: $e');
      return [];
    }
  }

  /// สร้าง PO อัตโนมัติสำหรับสินค้าต่ำสต็อก
  static Future<bool> createAutoPOForLowStock({
    required String productId,
    required String supplierId,
    required double quantity,
    DateTime? expectedDate,
    String? createdBy,
  }) async {
    try {
      final poData = {
        'order_number': '',
        'supplier_id': supplierId,
        'status': 'draft',
        'expected_date': expectedDate?.toIso8601String(),
        'subtotal': 0,
        'tax_amount': 0,
        'discount_amount': 0,
        'total_amount': 0,
        'notes': 'สร้างอัตโนมัติจากแจ้งเตือนสต็อกต่ำ',
        'created_by': createdBy,
      };

      final poResponse = await _client
          .from('procurement_purchase_orders')
          .insert(poData)
          .select()
          .single();

      final poId = poResponse['id']?.toString();
      if (poId == null) return false;

      await _client.from('procurement_purchase_order_lines').insert({
        'po_id': poId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': 0,
        'line_total': 0,
        'received_quantity': 0,
      });

      return true;
    } catch (e) {
      debugPrint('Error creating auto PO: $e');
      return false;
    }
  }

  /// สร้าง PO อัตโนมัติสำหรับสินค้าใกล้หมดอายุ
  static Future<bool> createAutoPOForExpiringStock({
    required String productId,
    required String supplierId,
    required double quantity,
    DateTime? expectedDate,
    String? createdBy,
  }) async {
    try {
      final poData = {
        'order_number': '',
        'supplier_id': supplierId,
        'status': 'draft',
        'expected_date': expectedDate?.toIso8601String(),
        'subtotal': 0,
        'tax_amount': 0,
        'discount_amount': 0,
        'total_amount': 0,
        'notes': 'สร้างอัตโนมัติจากแจ้งเตือนสินค้าใกล้หมดอายุ',
        'created_by': createdBy,
      };

      final poResponse = await _client
          .from('procurement_purchase_orders')
          .insert(poData)
          .select()
          .single();

      final poId = poResponse['id']?.toString();
      if (poId == null) return false;

      await _client.from('procurement_purchase_order_lines').insert({
        'po_id': poId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': 0,
        'line_total': 0,
        'received_quantity': 0,
      });

      return true;
    } catch (e) {
      debugPrint('Error creating auto PO for expiring stock: $e');
      return false;
    }
  }

  /// ดึงรายการ supplier ทั้งหมด
  static Future<List<Map<String, dynamic>>> getSuppliers({bool activeOnly = true}) async {
    try {
      final response = await _client
          .from('procurement_suppliers')
          .select('*')
          .order('name');
      
      if (activeOnly) {
        return List<Map<String, dynamic>>.from(response)
            .where((s) => s['is_active'] == true)
            .toList();
      }
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('InventoryService.getSuppliers error: $e');
      return [];
    }
  }

  /// Sync PO status กับ inventory adjustments
  /// เมื่อ PO completed ให้ approve adjustment ที่เกี่ยวข้อง
  static Future<bool> syncPOStatusToAdjustments(String poId) async {
    try {
      // ดึง PO detail
      final poResponse = await _client
          .from('procurement_purchase_orders')
          .select('*')
          .eq('id', poId)
          .single();

      final poStatus = poResponse['status']?.toString() ?? '';
      
      if (poStatus != 'completed') {
        return true; // ไม่ต้อง sync ถ้า PO ยังไม่ completed
      }

      // ดึง PO lines
      final linesResponse = await _client
          .from('procurement_purchase_order_lines')
          .select('*')
          .eq('po_id', poId);

      final lines = List<Map<String, dynamic>>.from(linesResponse);

      // ค้นหา adjustments ที่เกี่ยวข้องกับ PO นี้
      for (final line in lines) {
        final productId = line['product_id']?.toString();
        if (productId == null) continue;

        // ค้นหา pending adjustment สำหรับสินค้านี้
        final adjustmentResponse = await _client
            .from('inventory_adjustments')
            .select('*')
            .eq('product_id', productId)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(1);

        if (adjustmentResponse.isNotEmpty) {
          final adjustment = adjustmentResponse.first as Map<String, dynamic>;
          final adjustmentId = adjustment['id']?.toString();

          if (adjustmentId != null) {
            // Auto-approve adjustment
            await _client
                .from('inventory_adjustments')
                .update({
                  'status': 'approved',
                  'approved_by': 'system',
                  'approved_at': DateTime.now().toIso8601String(),
                  'approval_note': 'อนุมัติอัตโนมัติจากการรับสินค้า PO: $poId',
                })
                .eq('id', adjustmentId);
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('InventoryService.syncPOStatusToAdjustments error: $e');
      return false;
    }
  }

  // =============================================
  // Reserve Stock System
  // =============================================

  /// ดึงจำนวนสินค้าที่พร้อมใช้ (quantity - reserved_quantity)
  static Future<double> getAvailableStock(String productId) async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('quantity, reserved_quantity')
          .eq('id', productId)
          .single();

      final quantity = (response['quantity'] as num?)?.toDouble() ?? 0;
      final reserved = (response['reserved_quantity'] as num?)?.toDouble() ?? 0;
      
      return quantity - reserved;
    } catch (e) {
      debugPrint('InventoryService.getAvailableStock error: $e');
      return 0;
    }
  }

  /// สำรองสินค้า (เพิ่ม reserved_quantity)
  static Future<bool> reserveStock({
    required String productId,
    required double quantity,
    String? orderId,
    String? reservedBy,
  }) async {
    try {
      // ดึงจำนวนปัจจุบัน
      final response = await _client
          .from('inventory_products')
          .select('quantity, reserved_quantity')
          .eq('id', productId)
          .single();

      final currentQty = (response['quantity'] as num?)?.toDouble() ?? 0;
      final currentReserved = (response['reserved_quantity'] as num?)?.toDouble() ?? 0;
      final available = currentQty - currentReserved;

      // ตรวจสอบว่ามีสินค้าพอสำหรับสำรอง
      if (available < quantity) {
        debugPrint('InventoryService.reserveStock: Not enough available stock');
        return false;
      }

      // อัปเดต reserved_quantity
      final newReserved = currentReserved + quantity;
      await _client
          .from('inventory_products')
          .update({'reserved_quantity': newReserved})
          .eq('id', productId);

      // บันทึก reserve log
      await _client
          .from('inventory_reserve_logs')
          .insert({
            'product_id': productId,
            'quantity': quantity,
            'order_id': orderId,
            'action': 'reserve',
            'reserved_by': reservedBy,
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      debugPrint('InventoryService.reserveStock error: $e');
      return false;
    }
  }

  /// ปล่อยสำรองสินค้า (ลด reserved_quantity)
  static Future<bool> releaseReservedStock({
    required String productId,
    required double quantity,
    String? orderId,
    String? releasedBy,
  }) async {
    try {
      // ดึงจำนวนปัจจุบัน
      final response = await _client
          .from('inventory_products')
          .select('reserved_quantity')
          .eq('id', productId)
          .single();

      final currentReserved = (response['reserved_quantity'] as num?)?.toDouble() ?? 0;

      // ตรวจสอบว่ามีสำรองพอสำหรับปล่อย
      if (currentReserved < quantity) {
        debugPrint('InventoryService.releaseReservedStock: Not enough reserved stock');
        return false;
      }

      // อัปเดต reserved_quantity
      final newReserved = currentReserved - quantity;
      await _client
          .from('inventory_products')
          .update({'reserved_quantity': newReserved})
          .eq('id', productId);

      // บันทึก release log
      await _client
          .from('inventory_reserve_logs')
          .insert({
            'product_id': productId,
            'quantity': quantity,
            'order_id': orderId,
            'action': 'release',
            'released_by': releasedBy,
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      debugPrint('InventoryService.releaseReservedStock error: $e');
      return false;
    }
  }

  /// ดึงข้อมูลสต็อกแบบละเอียด (quantity, reserved, available)
  static Future<Map<String, dynamic>?> getStockDetails(String productId) async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('id, name, quantity, reserved_quantity')
          .eq('id', productId)
          .single();

      final quantity = (response['quantity'] as num?)?.toDouble() ?? 0;
      final reserved = (response['reserved_quantity'] as num?)?.toDouble() ?? 0;
      final available = quantity - reserved;

      return {
        'product_id': response['id'],
        'product_name': response['name'],
        'total_quantity': quantity,
        'reserved_quantity': reserved,
        'available_quantity': available,
        'reserved_percentage': quantity > 0 ? (reserved / quantity * 100) : 0,
      };
    } catch (e) {
      debugPrint('InventoryService.getStockDetails error: $e');
      return null;
    }
  }

  /// ดึง reserve logs สำหรับสินค้า
  static Future<List<Map<String, dynamic>>> getReserveLogs({
    String? productId,
    String? orderId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client
          .from('inventory_reserve_logs')
          .select('*');

      if (productId != null) {
        query = query.eq('product_id', productId);
      }
      if (orderId != null) {
        query = query.eq('order_id', orderId);
      }

      final response = await (query as dynamic).order('created_at', ascending: false);
      List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(response);

      // Filter by date range
      if (fromDate != null) {
        logs = logs.where((log) {
          final logDate = DateTime.tryParse(log['created_at']?.toString() ?? '');
          return logDate != null && logDate.isAfter(fromDate.subtract(const Duration(days: 1)));
        }).toList();
      }
      if (toDate != null) {
        logs = logs.where((log) {
          final logDate = DateTime.tryParse(log['created_at']?.toString() ?? '');
          return logDate != null && logDate.isBefore(toDate.add(const Duration(days: 1)));
        }).toList();
      }

      return logs;
    } catch (e) {
      debugPrint('InventoryService.getReserveLogs error: $e');
      return [];
    }
  }

  /// ดึงยอดขาย POS สรุปตามช่วงเวลา
  static Future<Map<String, dynamic>> getSalesReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      var query = _client.from('pos_orders').select('*');
      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }
      if (dateTo != null) {
        final endOfDay = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toIso8601String());
      }

      final orders = await query.order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(orders);

      double totalSales = 0;
      double totalTax = 0;
      double totalService = 0;
      double totalDiscount = 0;
      int orderCount = list.length;

      for (final o in list) {
        totalSales += (o['net_total'] as num?)?.toDouble() ?? 0;
        totalTax += (o['tax_amount'] as num?)?.toDouble() ?? 0;
        totalService += (o['service_amount'] as num?)?.toDouble() ?? 0;
        totalDiscount += (o['discount_amount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'orders': list,
        'order_count': orderCount,
        'total_sales': totalSales,
        'total_tax': totalTax,
        'total_service': totalService,
        'total_discount': totalDiscount,
      };
    } catch (e) {
      debugPrint('Error getting sales report: $e');
      return {'orders': [], 'order_count': 0, 'total_sales': 0.0};
    }
  }

  // =============================================
  // POS Orders
  // =============================================

  /// สร้างออเดอร์ POS พร้อมบันทึกรายการสินค้า ลดสต็อก และบันทึก adjustment
  static Future<Map<String, dynamic>?> createPosOrder({
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double discountAmount,
    String? discountNote,
    required double taxRate,
    required double taxAmount,
    required double serviceRate,
    required double serviceAmount,
    required double netTotal,
    required String paymentMethod,
    required String responsibleUserId,
    required String responsibleUserName,
    String? cashierUserId,
    String? cashierUserName,
    String orderType = 'walk_in',
    String? tableNumber,
    String? tableId,
    String? tableSessionId,
    String? customerUserId,
    String? customerName,
    String? userName,
    List<Map<String, dynamic>>? appliedDiscounts,
    double totalDiscountAmount = 0,
    String? customerId,
    double loyaltyPointsRedeemed = 0,
    double loyaltyDiscountAmount = 0,
    String? shiftId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;

      // 1. สร้าง order header
      final combinedDiscount = discountAmount + totalDiscountAmount + loyaltyDiscountAmount;
      final orderResp = await _client.from('pos_orders').insert({
        'order_number': '', // trigger จะ generate ให้
        'user_id': userId,
        'user_name': userName ?? 'พนักงาน',
        'order_type': orderType,
        'table_number': tableNumber,
        'table_id': tableId,
        'table_session_id': tableSessionId,
        'responsible_user_id': responsibleUserId,
        'responsible_user_name': responsibleUserName,
        'cashier_user_id': cashierUserId,
        'cashier_user_name': cashierUserName,
        'customer_user_id': customerUserId,
        'customer_name': customerName,
        'subtotal': subtotal,
        'discount_amount': combinedDiscount,
        'discount_note': discountNote,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'service_rate': serviceRate,
        'service_amount': serviceAmount,
        'net_total': netTotal,
        'paid_total': netTotal,
        'balance_due': 0,
        'payment_method': paymentMethod,
        'status': 'completed',
        'loyalty_points_redeemed': loyaltyPointsRedeemed,
        'loyalty_discount_amount': loyaltyDiscountAmount,
        if (shiftId != null) 'shift_id': shiftId,
      }).select().single();

      final orderId = orderResp['id'] as String;
      final orderNumber = orderResp['order_number'] as String;

      // 2. สร้าง order lines + ลดสต็อก + บันทึก adjustment
      for (final item in cartItems) {
        final product = item['product'] as Map<String, dynamic>;
        final qty = item['qty'] as int;
        final productId = product['id'] as String;
        final productName = product['name'] as String? ?? '';
        final unitPrice = (product['price'] ?? 0).toDouble();
        final lineTotal = unitPrice * qty;
        final unit = product['unit'];
        final unitName = (unit is Map) ? (unit['abbreviation'] ?? unit['name'] ?? '') : '';
        final isTaxExempt = product['is_tax_exempt'] == true;
        final productTaxRate = (product['tax_rate'] ?? 0).toDouble();

        // Insert order line
        await _client.from('pos_order_lines').insert({
          'order_id': orderId,
          'product_id': productId,
          'product_name': productName,
          'unit_name': unitName,
          'quantity': qty,
          'unit_price': unitPrice,
          'line_total': lineTotal,
          'tax_exempt': isTaxExempt,
          'tax_rate': productTaxRate,
          'note': item['note'] ?? '',
        });

        // ลดสต็อก
        final productResp = await _client
            .from('inventory_products')
            .select('quantity')
            .eq('id', productId)
            .single();
        final currentQty = (productResp['quantity'] as num).toDouble();
        final newQty = currentQty - qty;

        await _client.from('inventory_products').update({
          'quantity': newQty,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', productId);

        // บันทึก adjustment
        await _client.from('inventory_adjustments').insert({
          'product_id': productId,
          'type': 'sale',
          'quantity_before': currentQty,
          'quantity_after': newQty,
          'quantity_change': -qty.toDouble(),
          'reason': 'ขาย POS ($orderNumber)',
          'reference_id': orderId,
          'user_name': userName ?? 'พนักงาน',
        });
      }

      if (tableId != null && tableSessionId != null) {
        final attached = await TableManagementService.attachOrderToTableSession(
          tableId: tableId,
          sessionId: tableSessionId,
          orderId: orderId,
        );
        if (!attached) {
          debugPrint('⚠️ POS order created but failed to attach to table session: $orderNumber');
        }
      }

      // 3. บันทึก pos_order_discounts (Phase 2A — item #2)
      if (appliedDiscounts != null && appliedDiscounts.isNotEmpty) {
        for (final d in appliedDiscounts) {
          final discountInfo = d['pos_discounts'] as Map<String, dynamic>?;
          try {
            await _client.from('pos_order_discounts').insert({
              'order_id': orderId,
              'discount_id': d['discount_id'],
              'discount_name': discountInfo?['name'] ?? 'ส่วนลด',
              'discount_type': discountInfo?['discount_type'] ?? 'fixed',
              'discount_value': discountInfo?['value'] ?? 0,
              'discount_amount': (d['discount_amount'] ?? 0).toDouble(),
              'applied_by': userId,
            });
          } catch (e) {
            debugPrint('⚠️ Failed to save order discount: $e');
          }
        }
      }

      // 4. สะสม Loyalty Points อัตโนมัติ (Phase 2A — item #3)
      if (customerId != null && customerId.isNotEmpty) {
        try {
          final programs = await _client
              .from('pos_loyalty_programs')
              .select()
              .eq('is_active', true)
              .limit(1);

          if ((programs as List).isNotEmpty) {
            final program = programs[0];
            final programId = program['id'] as String;
            final pointsPerBaht = (program['points_per_baht'] ?? 1).toDouble();
            final expiryDays = program['points_expiry_days'] as int?;
            final earnedPoints = netTotal * pointsPerBaht;

            if (earnedPoints > 0) {
              // หา/สร้าง wallet
              var walletResp = await _client
                  .from('pos_customer_loyalty_wallets')
                  .select()
                  .eq('customer_id', customerId)
                  .eq('loyalty_program_id', programId)
                  .maybeSingle();

              if (walletResp == null) {
                walletResp = await _client
                    .from('pos_customer_loyalty_wallets')
                    .insert({
                      'customer_id': customerId,
                      'loyalty_program_id': programId,
                      'total_points': 0,
                      'redeemed_points': 0,
                      'available_points': 0,
                    })
                    .select()
                    .single();
              }

              final walletId = walletResp['id'] as String;
              final currentTotal = (walletResp['total_points'] ?? 0).toDouble();
              final currentAvailable = (walletResp['available_points'] ?? 0).toDouble();
              final newTotal = currentTotal + earnedPoints;
              final newAvailable = currentAvailable + earnedPoints;

              final expiresAt = expiryDays != null
                  ? DateTime.now().add(Duration(days: expiryDays)).toIso8601String()
                  : null;

              await _client.from('pos_loyalty_transactions').insert({
                'wallet_id': walletId,
                'order_id': orderId,
                'transaction_type': 'earn',
                'points': earnedPoints,
                'balance_after': newAvailable,
                'reason': 'สะสมแต้มจากบิล $orderNumber',
                'expires_at': expiresAt,
                'created_by': userId,
              });

              await _client
                  .from('pos_customer_loyalty_wallets')
                  .update({
                    'total_points': newTotal,
                    'available_points': newAvailable,
                    'last_transaction_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', walletId);

              // อัปเดต loyalty_points_earned บน order
              await _client
                  .from('pos_orders')
                  .update({'loyalty_points_earned': earnedPoints})
                  .eq('id', orderId);

              debugPrint('🎯 Loyalty earned: $earnedPoints pts for order $orderNumber');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to earn loyalty points: $e');
        }
      }

      // 5. บันทึก Order Status Log (Phase 2A — item #4)
      try {
        await _client.from('pos_order_status_log').insert({
          'order_id': orderId,
          'from_status': null,
          'to_status': 'completed',
          'changed_by': userId,
          'changed_by_name': userName ?? 'พนักงาน',
          'reason': 'ชำระเงินด้วย $paymentMethod',
        });
      } catch (e) {
        debugPrint('⚠️ Failed to log order status: $e');
      }

      debugPrint('✅ POS Order created: $orderNumber, total: $netTotal');
      return Map<String, dynamic>.from(orderResp);
    } catch (e) {
      debugPrint('❌ Error creating POS order: $e');
      return null;
    }
  }

  /// ดึงออเดอร์ POS ล่าสุด
  static Future<List<Map<String, dynamic>>> getRecentPosOrders({int limit = 20}) async {
    try {
      final response = await _client
          .from('pos_orders')
          .select('''
            *,
            lines:pos_order_lines(*)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading POS orders: $e');
      return [];
    }
  }

  // =============================================
  // Bulk Operations
  // =============================================

  /// ปรับปรุงสต็อกหลายรายการพร้อมกัน (Bulk Adjustment)
  static Future<bool> bulkAdjustment({
    required List<Map<String, dynamic>> adjustments, // [{productId, quantity, reason}, ...]
    String? warehouseId,
    String? adjustedBy,
  }) async {
    try {
      final adjustmentRecords = <Map<String, dynamic>>[];

      for (final adj in adjustments) {
        final productId = adj['product_id']?.toString();
        final quantity = (adj['quantity'] as num?)?.toDouble() ?? 0;
        final reason = adj['reason']?.toString() ?? 'Bulk adjustment';

        if (productId == null || quantity == 0) continue;

        adjustmentRecords.add({
          'product_id': productId,
          'adjustment_type': 'manual',
          'quantity_change': quantity,
          'reason': reason,
          'warehouse_id': warehouseId,
          'status': 'pending',
          'created_by': adjustedBy,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (adjustmentRecords.isEmpty) return false;

      // Insert all adjustments
      await _client
          .from('inventory_adjustments')
          .insert(adjustmentRecords);

      return true;
    } catch (e) {
      debugPrint('InventoryService.bulkAdjustment error: $e');
      return false;
    }
  }

  /// อัปเดตราคาหลายรายการพร้อมกัน (Bulk Price Update)
  static Future<bool> bulkUpdatePrice({
    required List<Map<String, dynamic>> updates, // [{productId, newPrice}, ...]
    String? updatedBy,
  }) async {
    try {
      for (final update in updates) {
        final productId = update['product_id']?.toString();
        final newPrice = (update['new_price'] as num?)?.toDouble();

        if (productId == null || newPrice == null) continue;

        await _client
            .from('inventory_products')
            .update({
              'price': newPrice,
              'updated_at': DateTime.now().toIso8601String(),
              'updated_by': updatedBy,
            })
            .eq('id', productId);
      }

      return true;
    } catch (e) {
      debugPrint('InventoryService.bulkUpdatePrice error: $e');
      return false;
    }
  }

  /// อัปเดตตำแหน่งเก็บหลายรายการพร้อมกัน (Bulk Location Update)
  static Future<bool> bulkUpdateLocation({
    required List<String> productIds,
    required String newWarehouseId,
    required String newShelfId,
    String? updatedBy,
  }) async {
    try {
      await _client
          .from('inventory_products')
          .update({
            'warehouse_id': newWarehouseId,
            'shelf_id': newShelfId,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': updatedBy,
          })
          .inFilter('id', productIds);

      return true;
    } catch (e) {
      debugPrint('InventoryService.bulkUpdateLocation error: $e');
      return false;
    }
  }

  /// อนุมัติหลายการปรับปรุงพร้อมกัน (Bulk Approve Adjustments)
  static Future<bool> bulkApproveAdjustments({
    required List<String> adjustmentIds,
    String? approvedBy,
    String? approvalNote,
  }) async {
    try {
      await _client
          .from('inventory_adjustments')
          .update({
            'status': 'approved',
            'approved_by': approvedBy,
            'approved_at': DateTime.now().toIso8601String(),
            'approval_note': approvalNote,
          })
          .inFilter('id', adjustmentIds);

      return true;
    } catch (e) {
      debugPrint('InventoryService.bulkApproveAdjustments error: $e');
      return false;
    }
  }

  /// ปฏิเสธหลายการปรับปรุงพร้อมกัน (Bulk Reject Adjustments)
  static Future<bool> bulkRejectAdjustments({
    required List<String> adjustmentIds,
    String? rejectedBy,
    String? rejectionReason,
  }) async {
    try {
      await _client
          .from('inventory_adjustments')
          .update({
            'status': 'rejected',
            'rejected_by': rejectedBy,
            'rejected_at': DateTime.now().toIso8601String(),
            'rejection_reason': rejectionReason,
          })
          .inFilter('id', adjustmentIds);

      return true;
    } catch (e) {
      debugPrint('InventoryService.bulkRejectAdjustments error: $e');
      return false;
    }
  }

  /// สำรองสินค้าหลายรายการพร้อมกัน (Bulk Reserve)
  static Future<bool> bulkReserveStock({
    required List<Map<String, dynamic>> reserves, // [{productId, quantity, orderId}, ...]
    String? reservedBy,
  }) async {
    try {
      for (final reserve in reserves) {
        final productId = reserve['product_id']?.toString();
        final quantity = (reserve['quantity'] as num?)?.toDouble() ?? 0;
        final orderId = reserve['order_id']?.toString();

        if (productId == null || quantity == 0) continue;

        await reserveStock(
          productId: productId,
          quantity: quantity,
          orderId: orderId,
          reservedBy: reservedBy,
        );
      }

      return true;
    } catch (e) {
      debugPrint('InventoryService.bulkReserveStock error: $e');
      return false;
    }
  }

  /// ปล่อยสำรองหลายรายการพร้อมกัน (Bulk Release)
  static Future<bool> bulkReleaseStock({
    required List<Map<String, dynamic>> releases, // [{productId, quantity, orderId}, ...]
    String? releasedBy,
  }) async {
    try {
      for (final release in releases) {
        final productId = release['product_id']?.toString();
        final quantity = (release['quantity'] as num?)?.toDouble() ?? 0;
        final orderId = release['order_id']?.toString();

        if (productId == null || quantity == 0) continue;

        await releaseReservedStock(
          productId: productId,
          quantity: quantity,
          orderId: orderId,
          releasedBy: releasedBy,
        );
      }

      return true;
    } catch (e) {
      debugPrint('InventoryService.bulkReleaseStock error: $e');
      return false;
    }
  }

  // =============================================
  // Stock Forecasting
  // =============================================

  /// ดึงข้อมูลการขายสินค้า (historical sales)
  static Future<List<Map<String, dynamic>>> getSalesHistory({
    required String productId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await _client
          .from('pos_order_lines')
          .select('''
            *,
            order:pos_orders(created_at)
          ''')
          .eq('product_id', productId)
          .gte('created_at', fromDate.toIso8601String())
          .lte('created_at', toDate.toIso8601String())
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('InventoryService.getSalesHistory error: $e');
      return [];
    }
  }

  /// คำนวณพยากรณ์สต็อก (Simple Moving Average)
  /// ใช้ข้อมูลขาย 30 วันที่ผ่านมา เพื่อพยากรณ์ 7 วันข้างหน้า
  static Future<Map<String, dynamic>?> forecastStock({
    required String productId,
    int historyDays = 30,
    int forecastDays = 7,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = now.subtract(Duration(days: historyDays));
      
      // ดึงข้อมูลการขายในอดีต
      final salesHistory = await getSalesHistory(
        productId: productId,
        fromDate: fromDate,
        toDate: now,
      );

      if (salesHistory.isEmpty) {
        return null;
      }

      // จัดกลุ่มการขายตามวัน
      final dailySales = <String, double>{};
      for (final sale in salesHistory) {
        final orderDate = sale['order']?['created_at']?.toString() ?? '';
        final quantity = (sale['quantity'] as num?)?.toDouble() ?? 0;
        
        if (orderDate.isNotEmpty) {
          final date = DateTime.parse(orderDate);
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          dailySales[dateKey] = (dailySales[dateKey] ?? 0) + quantity;
        }
      }

      // คำนวณค่าเฉลี่ยรายวัน (Simple Moving Average)
      final avgDailySales = dailySales.values.isEmpty 
          ? 0.0 
          : dailySales.values.reduce((a, b) => a + b) / dailySales.length;

      // คำนวณ trend (เพิ่มขึ้น/ลดลง)
      final recentSales = dailySales.values.toList().reversed.take(7).toList();
      final olderSales = dailySales.values.toList().reversed.skip(7).take(7).toList();
      
      final recentAvg = recentSales.isEmpty ? 0.0 : recentSales.reduce((a, b) => a + b) / recentSales.length;
      final olderAvg = olderSales.isEmpty ? 0.0 : olderSales.reduce((a, b) => a + b) / olderSales.length;
      
      final trendPercentage = olderAvg > 0 ? ((recentAvg - olderAvg) / olderAvg * 100) : 0.0;

      // พยากรณ์สต็อกในอนาคต
      final forecastedDemand = avgDailySales * forecastDays;
      
      // ดึงสต็อกปัจจุบัน
      final productResponse = await _client
          .from('inventory_products')
          .select('quantity, reorder_point')
          .eq('id', productId)
          .single();

      final currentStock = (productResponse['quantity'] as num?)?.toDouble() ?? 0;
      final reorderPoint = (productResponse['reorder_point'] as num?)?.toDouble() ?? 0;
      final projectedStock = currentStock - forecastedDemand;

      return {
        'product_id': productId,
        'current_stock': currentStock,
        'avg_daily_sales': avgDailySales,
        'trend_percentage': trendPercentage,
        'trend_direction': trendPercentage > 5 ? 'up' : trendPercentage < -5 ? 'down' : 'stable',
        'forecast_days': forecastDays,
        'forecasted_demand': forecastedDemand,
        'projected_stock': projectedStock,
        'will_stockout': projectedStock < 0,
        'days_until_stockout': avgDailySales > 0 ? (currentStock / avgDailySales).ceil() : 999,
        'reorder_point': reorderPoint,
        'needs_reorder': projectedStock < reorderPoint,
        'confidence': dailySales.length >= 14 ? 'high' : dailySales.length >= 7 ? 'medium' : 'low',
      };
    } catch (e) {
      debugPrint('InventoryService.forecastStock error: $e');
      return null;
    }
  }

  /// พยากรณ์สต็อกหลายสินค้า
  static Future<List<Map<String, dynamic>>> forecastMultipleProducts({
    required List<String> productIds,
    int historyDays = 30,
    int forecastDays = 7,
  }) async {
    try {
      final forecasts = <Map<String, dynamic>>[];

      for (final productId in productIds) {
        final forecast = await forecastStock(
          productId: productId,
          historyDays: historyDays,
          forecastDays: forecastDays,
        );

        if (forecast != null) {
          forecasts.add(forecast);
        }
      }

      // เรียงตามความเสี่ยง (high risk first)
      forecasts.sort((a, b) {
        final aRisk = a['will_stockout'] == true ? 0 : 1;
        final bRisk = b['will_stockout'] == true ? 0 : 1;
        return aRisk.compareTo(bRisk);
      });

      return forecasts;
    } catch (e) {
      debugPrint('InventoryService.forecastMultipleProducts error: $e');
      return [];
    }
  }

  /// ดึงสินค้าที่มีความเสี่ยงสต็อกหมด (At-risk products)
  static Future<List<Map<String, dynamic>>> getAtRiskProducts({
    int historyDays = 30,
    int forecastDays = 7,
  }) async {
    try {
      // ดึงสินค้าทั้งหมด
      final products = await getProducts();
      final productIds = products
          .map((p) => p['id']?.toString())
          .whereType<String>()
          .toList();

      if (productIds.isEmpty) return [];

      // พยากรณ์สต็อก
      final forecasts = await forecastMultipleProducts(
        productIds: productIds,
        historyDays: historyDays,
        forecastDays: forecastDays,
      );

      // กรองเฉพาะสินค้าที่มีความเสี่ยง
      return forecasts.where((f) {
        final willStockout = f['will_stockout'] == true;
        final needsReorder = f['needs_reorder'] == true;
        return willStockout || needsReorder;
      }).toList();
    } catch (e) {
      debugPrint('InventoryService.getAtRiskProducts error: $e');
      return [];
    }
  }

  /// คำนวณ seasonal pattern (รูปแบบตามฤดูกาล)
  static Future<Map<String, dynamic>?> analyzeSeasonalPattern({
    required String productId,
    int monthsBack = 12,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = DateTime(now.year - (monthsBack ~/ 12), now.month - (monthsBack % 12), 1);
      
      final salesHistory = await getSalesHistory(
        productId: productId,
        fromDate: fromDate,
        toDate: now,
      );

      if (salesHistory.isEmpty) return null;

      // จัดกลุ่มตามเดือน
      final monthlySales = <String, double>{};
      for (final sale in salesHistory) {
        final orderDate = sale['order']?['created_at']?.toString() ?? '';
        final quantity = (sale['quantity'] as num?)?.toDouble() ?? 0;
        
        if (orderDate.isNotEmpty) {
          final date = DateTime.parse(orderDate);
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlySales[monthKey] = (monthlySales[monthKey] ?? 0) + quantity;
        }
      }

      if (monthlySales.length < 3) return null;

      final avgMonthlySales = monthlySales.values.reduce((a, b) => a + b) / monthlySales.length;
      final maxMonth = monthlySales.values.reduce((a, b) => a > b ? a : b);
      final minMonth = monthlySales.values.reduce((a, b) => a < b ? a : b);
      final seasonalIndex = maxMonth / avgMonthlySales;

      return {
        'product_id': productId,
        'avg_monthly_sales': avgMonthlySales,
        'peak_sales': maxMonth,
        'low_sales': minMonth,
        'seasonal_index': seasonalIndex,
        'is_seasonal': seasonalIndex > 1.3,
        'months_analyzed': monthlySales.length,
      };
    } catch (e) {
      debugPrint('InventoryService.analyzeSeasonalPattern error: $e');
      return null;
    }
  }

  // =============================================
  // Batch Expiry Tracking
  // =============================================

  /// ดึงข้อมูลล็อตสินค้า (batches)
  static Future<List<Map<String, dynamic>>> getBatches({
    String? productId,
    String? warehouseId,
    bool? expiredOnly,
  }) async {
    try {
      var query = _client
          .from('inventory_batches')
          .select('*');

      if (productId != null) {
        query = query.eq('product_id', productId);
      }
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final response = await (query as dynamic).order('expiry_date', ascending: true);
      var batches = List<Map<String, dynamic>>.from(response);

      // Filter expired if requested
      if (expiredOnly == true) {
        final now = DateTime.now();
        batches = batches.where((b) {
          final expiryDate = b['expiry_date']?.toString();
          if (expiryDate == null) return false;
          return DateTime.parse(expiryDate).isBefore(now);
        }).toList();
      }

      return batches;
    } catch (e) {
      debugPrint('InventoryService.getBatches error: $e');
      return [];
    }
  }

  /// สร้างล็อตสินค้าใหม่
  static Future<bool> createBatch({
    required String productId,
    required String batchNumber,
    required double quantity,
    required DateTime expiryDate,
    String? warehouseId,
    String? shelfId,
    String? notes,
    String? createdBy,
  }) async {
    try {
      await _client
          .from('inventory_batches')
          .insert({
            'product_id': productId,
            'batch_number': batchNumber,
            'quantity': quantity,
            'expiry_date': expiryDate.toIso8601String(),
            'warehouse_id': warehouseId,
            'shelf_id': shelfId,
            'notes': notes,
            'created_by': createdBy,
            'created_at': DateTime.now().toIso8601String(),
            'is_expired': false,
          });

      return true;
    } catch (e) {
      debugPrint('InventoryService.createBatch error: $e');
      return false;
    }
  }

  /// ดึงล็อตที่ใกล้หมดอายุ (Expiring soon)
  static Future<List<Map<String, dynamic>>> getExpiringBatches({
    int daysUntilExpiry = 7,
  }) async {
    try {
      final now = DateTime.now();
      final expiryThreshold = now.add(Duration(days: daysUntilExpiry));

      final response = await _client
          .from('inventory_batches')
          .select('*, product:inventory_products(name, code)')
          .gte('expiry_date', now.toIso8601String())
          .lte('expiry_date', expiryThreshold.toIso8601String())
          .eq('is_expired', false)
          .order('expiry_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('InventoryService.getExpiringBatches error: $e');
      return [];
    }
  }

  /// ดึงล็อตที่หมดอายุแล้ว
  static Future<List<Map<String, dynamic>>> getExpiredBatches() async {
    try {
      final now = DateTime.now();

      final response = await _client
          .from('inventory_batches')
          .select('*, product:inventory_products(name, code)')
          .lt('expiry_date', now.toIso8601String())
          .eq('is_expired', false)
          .order('expiry_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('InventoryService.getExpiredBatches error: $e');
      return [];
    }
  }

  /// อัปเดตสถานะหมดอายุของล็อต
  static Future<bool> markBatchAsExpired({
    required String batchId,
    String? disposedBy,
    String? disposalNotes,
  }) async {
    try {
      await _client
          .from('inventory_batches')
          .update({
            'is_expired': true,
            'disposed_by': disposedBy,
            'disposal_notes': disposalNotes,
            'disposed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', batchId);

      return true;
    } catch (e) {
      debugPrint('InventoryService.markBatchAsExpired error: $e');
      return false;
    }
  }

  /// ดึงล็อตตามลำดับ FIFO (First In First Out)
  static Future<List<Map<String, dynamic>>> getBatchesByFIFO({
    required String productId,
    String? warehouseId,
  }) async {
    try {
      var query = _client
          .from('inventory_batches')
          .select('*')
          .eq('product_id', productId)
          .eq('is_expired', false)
          .gt('quantity', 0);

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final response = await (query as dynamic)
          .order('expiry_date', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('InventoryService.getBatchesByFIFO error: $e');
      return [];
    }
  }

  /// ลดจำนวนล็อต (เมื่อขายหรือใช้)
  static Future<bool> reduceBatchQuantity({
    required String batchId,
    required double quantityToReduce,
    String? reason,
    String? usedBy,
  }) async {
    try {
      // ดึงจำนวนปัจจุบัน
      final response = await _client
          .from('inventory_batches')
          .select('quantity')
          .eq('id', batchId)
          .single();

      final currentQty = (response['quantity'] as num?)?.toDouble() ?? 0;
      final newQty = (currentQty - quantityToReduce).clamp(0, double.infinity);

      // อัปเดต
      await _client
          .from('inventory_batches')
          .update({
            'quantity': newQty,
            'last_used_at': DateTime.now().toIso8601String(),
            'last_used_by': usedBy,
          })
          .eq('id', batchId);

      // บันทึก log
      await _client
          .from('inventory_batch_logs')
          .insert({
            'batch_id': batchId,
            'action': 'reduce',
            'quantity_change': -quantityToReduce,
            'reason': reason,
            'performed_by': usedBy,
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      debugPrint('InventoryService.reduceBatchQuantity error: $e');
      return false;
    }
  }

  /// ดึงประวัติล็อต (batch history)
  static Future<List<Map<String, dynamic>>> getBatchHistory({
    required String batchId,
  }) async {
    try {
      final response = await _client
          .from('inventory_batch_logs')
          .select('*')
          .eq('batch_id', batchId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('InventoryService.getBatchHistory error: $e');
      return [];
    }
  }

  /// ดึงสรุปล็อตสินค้า (Batch summary)
  static Future<Map<String, dynamic>?> getBatchSummary({
    required String productId,
  }) async {
    try {
      final batches = await getBatches(productId: productId);
      if (batches.isEmpty) return null;

      final now = DateTime.now();
      int totalBatches = batches.length;
      int expiredBatches = 0;
      int expiringBatches = 0;
      double totalQuantity = 0;
      double expiredQuantity = 0;

      DateTime? oldestExpiry;
      DateTime? newestExpiry;

      for (final batch in batches) {
        final qty = (batch['quantity'] as num?)?.toDouble() ?? 0;
        final isExpired = batch['is_expired'] == true;
        final expiryDate = batch['expiry_date']?.toString();

        totalQuantity += qty;

        if (isExpired) {
          expiredBatches++;
          expiredQuantity += qty;
        } else if (expiryDate != null) {
          final expiry = DateTime.parse(expiryDate);
          if (expiry.isBefore(now.add(const Duration(days: 7)))) {
            expiringBatches++;
          }

          if (oldestExpiry == null || expiry.isBefore(oldestExpiry)) {
            oldestExpiry = expiry;
          }
          if (newestExpiry == null || expiry.isAfter(newestExpiry)) {
            newestExpiry = expiry;
          }
        }
      }

      return {
        'product_id': productId,
        'total_batches': totalBatches,
        'expired_batches': expiredBatches,
        'expiring_soon_batches': expiringBatches,
        'total_quantity': totalQuantity,
        'expired_quantity': expiredQuantity,
        'available_quantity': totalQuantity - expiredQuantity,
        'oldest_expiry_date': oldestExpiry?.toIso8601String(),
        'newest_expiry_date': newestExpiry?.toIso8601String(),
        'expiry_risk_percentage': totalQuantity > 0 ? (expiredQuantity / totalQuantity * 100) : 0,
      };
    } catch (e) {
      debugPrint('InventoryService.getBatchSummary error: $e');
      return null;
    }
  }

  // =============================================
  // Multi-Warehouse Sync
  // =============================================

  /// ดึงข้อมูลสต็อกรวมทั้งหมด (Consolidated inventory)
  static Future<List<Map<String, dynamic>>> getConsolidatedInventory() async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('*, warehouse:inventory_store_locations(name, code)')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('InventoryService.getConsolidatedInventory error: $e');
      return [];
    }
  }

  /// ดึงข้อมูลสต็อกแยกตามคลัง
  static Future<Map<String, dynamic>> getInventoryByWarehouse({
    required String warehouseId,
  }) async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('*')
          .eq('warehouse_id', warehouseId);

      final products = List<Map<String, dynamic>>.from(response);
      double totalQuantity = 0;
      double totalValue = 0;

      for (final product in products) {
        final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
        final price = (product['price'] as num?)?.toDouble() ?? 0;
        totalQuantity += qty;
        totalValue += qty * price;
      }

      return {
        'warehouse_id': warehouseId,
        'product_count': products.length,
        'total_quantity': totalQuantity,
        'total_value': totalValue,
        'products': products,
      };
    } catch (e) {
      debugPrint('InventoryService.getInventoryByWarehouse error: $e');
      return {};
    }
  }

  /// ดึงสรุปสต็อกทั้งหมด (Consolidated summary)
  static Future<Map<String, dynamic>?> getConsolidatedSummary() async {
    try {
      final response = await _client
          .from('inventory_products')
          .select('quantity, price, reserved_quantity');

      final products = List<Map<String, dynamic>>.from(response);
      if (products.isEmpty) return null;

      double totalQuantity = 0;
      double totalReserved = 0;
      double totalValue = 0;
      int productCount = products.length;

      for (final product in products) {
        final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
        final reserved = (product['reserved_quantity'] as num?)?.toDouble() ?? 0;
        final price = (product['price'] as num?)?.toDouble() ?? 0;
        totalQuantity += qty;
        totalReserved += reserved;
        totalValue += qty * price;
      }

      return {
        'product_count': productCount,
        'total_quantity': totalQuantity,
        'available_quantity': totalQuantity - totalReserved,
        'reserved_quantity': totalReserved,
        'total_value': totalValue,
        'average_price': totalValue / productCount,
      };
    } catch (e) {
      debugPrint('InventoryService.getConsolidatedSummary error: $e');
      return null;
    }
  }

  /// โอนสินค้าระหว่างคลัง (Warehouse transfer)
  static Future<bool> transferBetweenWarehouses({
    required String productId,
    required double quantity,
    required String fromWarehouseId,
    required String toWarehouseId,
    String? reason,
    String? transferredBy,
  }) async {
    try {
      // ตรวจสอบว่ามีสินค้าพอ
      final fromResponse = await _client
          .from('inventory_products')
          .select('quantity')
          .eq('id', productId)
          .eq('warehouse_id', fromWarehouseId)
          .single();

      final fromQty = (fromResponse['quantity'] as num?)?.toDouble() ?? 0;
      if (fromQty < quantity) {
        debugPrint('InventoryService.transferBetweenWarehouses: Not enough stock');
        return false;
      }

      // ลดสต็อกจากคลังต้นทาง
      await _client
          .from('inventory_products')
          .update({'quantity': fromQty - quantity})
          .eq('id', productId)
          .eq('warehouse_id', fromWarehouseId);

      // เพิ่มสต็อกไปยังคลังปลายทาง
      final toResponse = await _client
          .from('inventory_products')
          .select('quantity')
          .eq('id', productId)
          .eq('warehouse_id', toWarehouseId)
          .single();

      final toQty = (toResponse['quantity'] as num?)?.toDouble() ?? 0;
      await _client
          .from('inventory_products')
          .update({'quantity': toQty + quantity})
          .eq('id', productId)
          .eq('warehouse_id', toWarehouseId);

      // บันทึก transfer log
      await _client
          .from('inventory_warehouse_transfers')
          .insert({
            'product_id': productId,
            'quantity': quantity,
            'from_warehouse_id': fromWarehouseId,
            'to_warehouse_id': toWarehouseId,
            'reason': reason,
            'transferred_by': transferredBy,
            'created_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      debugPrint('InventoryService.transferBetweenWarehouses error: $e');
      return false;
    }
  }

  /// ดึงประวัติการโอนสินค้า
  static Future<List<Map<String, dynamic>>> getTransferHistory({
    String? productId,
    String? fromWarehouseId,
    String? toWarehouseId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client
          .from('inventory_warehouse_transfers')
          .select('*');

      if (productId != null) {
        query = query.eq('product_id', productId);
      }
      if (fromWarehouseId != null) {
        query = query.eq('from_warehouse_id', fromWarehouseId);
      }
      if (toWarehouseId != null) {
        query = query.eq('to_warehouse_id', toWarehouseId);
      }

      final response = await (query as dynamic).order('created_at', ascending: false);
      var transfers = List<Map<String, dynamic>>.from(response);

      // Filter by date range
      if (fromDate != null) {
        transfers = transfers.where((t) {
          final date = DateTime.tryParse(t['created_at']?.toString() ?? '');
          return date != null && date.isAfter(fromDate);
        }).toList();
      }
      if (toDate != null) {
        transfers = transfers.where((t) {
          final date = DateTime.tryParse(t['created_at']?.toString() ?? '');
          return date != null && date.isBefore(toDate);
        }).toList();
      }

      return transfers;
    } catch (e) {
      debugPrint('InventoryService.getTransferHistory error: $e');
      return [];
    }
  }

  /// ดึงรายงานการใช้สินค้าแยกตามคลัง
  static Future<Map<String, dynamic>> getWarehouseUsageReport({
    required String warehouseId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final now = DateTime.now();
      final from = fromDate ?? DateTime(now.year, now.month - 1, 1);
      final to = toDate ?? now;

      // ดึงข้อมูลสินค้า
      final inventoryResponse = await _client
          .from('inventory_products')
          .select('*')
          .eq('warehouse_id', warehouseId);

      final products = List<Map<String, dynamic>>.from(inventoryResponse);

      // ดึงข้อมูลการปรับปรุง
      final adjustmentsResponse = await _client
          .from('inventory_adjustments')
          .select('*')
          .eq('warehouse_id', warehouseId)
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());

      final adjustments = List<Map<String, dynamic>>.from(adjustmentsResponse);

      double totalQuantity = 0;
      double totalValue = 0;
      double totalAdjustments = 0;

      for (final product in products) {
        final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
        final price = (product['price'] as num?)?.toDouble() ?? 0;
        totalQuantity += qty;
        totalValue += qty * price;
      }

      for (final adj in adjustments) {
        final change = (adj['quantity_change'] as num?)?.toDouble() ?? 0;
        totalAdjustments += change.abs();
      }

      return {
        'warehouse_id': warehouseId,
        'period_from': from.toIso8601String(),
        'period_to': to.toIso8601String(),
        'product_count': products.length,
        'total_quantity': totalQuantity,
        'total_value': totalValue,
        'total_adjustments': totalAdjustments,
        'adjustment_count': adjustments.length,
      };
    } catch (e) {
      debugPrint('InventoryService.getWarehouseUsageReport error: $e');
      return {};
    }
  }

  /// ซิงค์สต็อกทั้งหมด (Auto-sync all warehouses)
  static Future<bool> syncAllWarehouses() async {
    try {
      // ดึงข้อมูลทั้งหมด
      final response = await _client
          .from('inventory_products')
          .select('*');

      final products = List<Map<String, dynamic>>.from(response);

      // ตรวจสอบและอัปเดต
      for (final product in products) {
        final id = product['id']?.toString() ?? '';
        final qty = (product['quantity'] as num?)?.toDouble() ?? 0;
        final reserved = (product['reserved_quantity'] as num?)?.toDouble() ?? 0;

        // ตรวจสอบว่า reserved ไม่เกิน quantity
        if (reserved > qty && id.isNotEmpty) {
          await _client
              .from('inventory_products')
              .update({'reserved_quantity': qty})
              .eq('id', id);
        }
      }

      return true;
    } catch (e) {
      debugPrint('InventoryService.syncAllWarehouses error: $e');
      return false;
    }
  }
}
