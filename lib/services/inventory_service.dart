import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
  // Categories (ประเภทสินค้า/วัตถุดิบ - ใช้กับ inventory_products เท่านั้น)
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
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: _maxImageWidth,
        minHeight: _maxImageHeight,
        quality: _imageQuality,
        format: CompressFormat.jpeg,
      );
      if (result != null) {
        debugPrint('Image compressed: ${file.lengthSync()} -> ${result.length} bytes (${(result.length / file.lengthSync() * 100).toStringAsFixed(0)}%)');
      }
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
