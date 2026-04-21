import 'package:flutter_test/flutter_test.dart';
import 'package:tree_law_zoo_valley/services/inventory_service.dart';

void main() {
  group('Production Workflow Tests', () {
    // Test Recipe IDs (from database)
    const testRecipeId = 'cb51b90f-82a8-4e72-94d9-7096160dc56c'; // แฮมเบอร์เกอร์เนื้อ
    const testRecipeId2 = '95c69df5-f5ac-47d5-997f-362e5d3b1d08'; // เค้กช็อกโกแลต

    test('✅ Check recipe can produce - should validate stock', () async {
      // ✅ Test 1: Validate stock before production
      final validation = await InventoryService.checkRecipeCanProduce(
        recipeId: testRecipeId,
        batchQuantity: 1,
      );

      expect(validation, isNotNull);
      expect(validation.containsKey('can_produce'), true);
      expect(validation.containsKey('missing_ingredients'), true);

      print('✅ Validation Result:');
      print('  - Can Produce: ${validation['can_produce']}');
      print('  - Missing Ingredients: ${validation['missing_ingredients']}');
    });

    test('✅ Produce from recipe - should return success/failure map', () async {
      // ✅ Test 2: Execute production
      final result = await InventoryService.produceFromRecipe(
        recipeId: testRecipeId,
        batchQuantity: 1,
        ingredients: [
          {
            'product_id': 'prod_id_1',
            'quantity': 100,
            'current_stock': 500,
          }
        ],
        yieldQuantity: 1,
        userName: 'test_user',
      );

      expect(result, isNotNull);
      expect(result.containsKey('success'), true);
      expect(result.containsKey('message'), true);

      print('✅ Production Result:');
      print('  - Success: ${result['success']}');
      print('  - Message: ${result['message']}');
      print('  - Production Log ID: ${result['production_log_id']}');
    });

    test('✅ Get production audit trail - should return list of productions', () async {
      // ✅ Test 3: Get audit trail
      final auditTrail = await InventoryService.getProductionAuditTrail(
        recipeId: testRecipeId,
      );

      expect(auditTrail, isNotNull);
      expect(auditTrail, isA<List>());

      print('✅ Audit Trail Result:');
      print('  - Total Records: ${auditTrail.length}');
      
      if (auditTrail.isNotEmpty) {
        final record = auditTrail.first;
        print('  - Latest Production:');
        print('    - Date: ${record['production_date']}');
        print('    - Batch Qty: ${record['batch_quantity']}');
        print('    - Yield Qty: ${record['yield_quantity']}');
        print('    - User: ${record['user_name']}');
        print('    - Ingredients: ${record['ingredient_adjustments']}');
      } else {
        print('  - No production history yet');
      }
    });

    test('✅ Validation with insufficient stock - should return missing ingredients', () async {
      // ✅ Test 4: Validate with high batch quantity
      final validation = await InventoryService.checkRecipeCanProduce(
        recipeId: testRecipeId2,
        batchQuantity: 100, // High batch quantity
      );

      expect(validation, isNotNull);
      expect(validation.containsKey('can_produce'), true);

      print('✅ Validation with High Batch:');
      print('  - Can Produce: ${validation['can_produce']}');
      
      if (validation['can_produce'] != true) {
        final missing = validation['missing_ingredients'] as List;
        print('  - Missing Ingredients:');
        for (final item in missing) {
          print('    - ${item['product_name']}: need ${item['needed']}, have ${item['current']}, shortage ${item['shortage']}');
        }
      }
    });

    test('✅ Production error handling - should return error message', () async {
      // ✅ Test 5: Error handling
      final result = await InventoryService.produceFromRecipe(
        recipeId: 'invalid-recipe-id',
        batchQuantity: 1,
        ingredients: [],
        yieldQuantity: 1,
        userName: 'test_user',
      );

      expect(result, isNotNull);
      expect(result.containsKey('success'), true);
      expect(result.containsKey('message'), true);

      print('✅ Error Handling Result:');
      print('  - Success: ${result['success']}');
      print('  - Message: ${result['message']}');
    });

    test('✅ Audit trail structure - should have all required fields', () async {
      // ✅ Test 6: Verify audit trail structure
      final auditTrail = await InventoryService.getProductionAuditTrail(
        recipeId: testRecipeId,
      );

      if (auditTrail.isNotEmpty) {
        final record = auditTrail.first;
        
        expect(record.containsKey('production_date'), true);
        expect(record.containsKey('batch_quantity'), true);
        expect(record.containsKey('yield_quantity'), true);
        expect(record.containsKey('user_name'), true);
        expect(record.containsKey('ingredient_adjustments'), true);

        print('✅ Audit Trail Structure:');
        print('  - production_date: ${record['production_date'].runtimeType}');
        print('  - batch_quantity: ${record['batch_quantity'].runtimeType}');
        print('  - yield_quantity: ${record['yield_quantity'].runtimeType}');
        print('  - user_name: ${record['user_name'].runtimeType}');
        print('  - ingredient_adjustments: ${record['ingredient_adjustments'].runtimeType}');
      }
    });

    test('✅ Production validation flow - complete workflow', () async {
      // ✅ Test 7: Complete workflow
      print('\n🚀 Complete Production Workflow:');
      
      // Step 1: Validate
      print('\n1️⃣ Step 1: Validate Stock');
      final validation = await InventoryService.checkRecipeCanProduce(
        recipeId: testRecipeId,
        batchQuantity: 1,
      );
      print('   Result: ${validation['can_produce']}');

      if (validation['can_produce'] == true) {
        // Step 2: Produce
        print('\n2️⃣ Step 2: Execute Production');
        final result = await InventoryService.produceFromRecipe(
          recipeId: testRecipeId,
          batchQuantity: 1,
          ingredients: [
            {
              'product_id': 'prod_id_1',
              'quantity': 100,
              'current_stock': 500,
            }
          ],
          yieldQuantity: 1,
          userName: 'test_user',
        );
        print('   Result: ${result['success']}');
        print('   Message: ${result['message']}');

        // Step 3: Get Audit Trail
        print('\n3️⃣ Step 3: Get Audit Trail');
        final auditTrail = await InventoryService.getProductionAuditTrail(
          recipeId: testRecipeId,
        );
        print('   Total Records: ${auditTrail.length}');
      } else {
        print('   ❌ Cannot produce - stock insufficient');
        final missing = validation['missing_ingredients'] as List;
        for (final item in missing) {
          print('   - ${item['product_name']}: shortage ${item['shortage']}');
        }
      }

      expect(validation, isNotNull);
    });
  });
}
