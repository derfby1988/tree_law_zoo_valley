import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryService {
  static final SupabaseClient _client = Supabase.instance.client;

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

  static Future<bool> addProduct({
    required String name,
    required String categoryId,
    required String unitId,
    String? shelfId,
    double quantity = 0,
    double minQuantity = 0,
    double price = 0,
    double cost = 0,
    String? expiryDate,
  }) async {
    try {
      await _client.from('inventory_products').insert({
        'name': name,
        'category_id': categoryId,
        'unit_id': unitId,
        'shelf_id': shelfId,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'price': price,
        'cost': cost,
        'expiry_date': expiryDate,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding product: $e');
      return false;
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

  // =============================================
  // Categories
  // =============================================

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _client
          .from('inventory_categories')
          .select('*')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading categories: $e');
      return [];
    }
  }

  static Future<bool> addCategory(String name, {String? description}) async {
    try {
      await _client.from('inventory_categories').insert({
        'name': name,
        'description': description,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding category: $e');
      return false;
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
          .select('*')
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading warehouses: $e');
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

  // =============================================
  // Recipes
  // =============================================

  static Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      final response = await _client
          .from('inventory_recipes')
          .select('''
            *,
            category:inventory_categories(id, name),
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
    required String categoryId,
    double yieldQuantity = 1,
    String yieldUnit = 'ชิ้น',
    double cost = 0,
    double price = 0,
    String? description,
  }) async {
    try {
      await _client.from('inventory_recipes').insert({
        'name': name,
        'category_id': categoryId,
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
    required String categoryId,
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
        'category_id': categoryId,
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
}
