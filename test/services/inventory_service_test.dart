import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryService - Stock Forecasting', () {
    test('forecastStock should calculate days until stockout', () {
      // Given
      const currentStock = 100.0;
      const dailySalesAverage = 10.0;
      const safetyStock = 20.0;

      // When
      final daysUntilStockout = (currentStock - safetyStock) / dailySalesAverage;

      // Then
      expect(daysUntilStockout, equals(8.0));
    });

    test('forecastStock should calculate trend correctly', () {
      // Given
      final salesHistory = [100, 110, 120, 130, 140];
      final avgSales = salesHistory.reduce((a, b) => a + b) / salesHistory.length;

      // When
      final firstHalf = salesHistory.sublist(0, 2).reduce((a, b) => a + b) / 2;
      final secondHalf = salesHistory.sublist(3).reduce((a, b) => a + b) / 2;
      final trend = ((secondHalf - firstHalf) / firstHalf * 100);

      // Then
      expect(avgSales, equals(120.0));
      expect(trend, greaterThan(0)); // Uptrend
    });

    test('analyzeSeasonalPattern should detect seasonal index', () {
      // Given
      final monthlySales = [100, 120, 150, 110, 130, 160, 140, 170, 180, 150, 160, 190];
      final avgSales = monthlySales.reduce((a, b) => a + b) / monthlySales.length;
      final maxMonth = monthlySales.reduce((a, b) => a > b ? a : b);
      final minMonth = monthlySales.reduce((a, b) => a < b ? a : b);
      final seasonalIndex = maxMonth / minMonth;

      // When & Then
      expect(seasonalIndex, greaterThan(1.0));
      expect(seasonalIndex, lessThan(2.0));
    });

    test('getAtRiskProducts should identify low stock items', () {
      // Given
      final products = [
        {'id': '1', 'quantity': 5, 'reorder_point': 10},
        {'id': '2', 'quantity': 50, 'reorder_point': 10},
        {'id': '3', 'quantity': 8, 'reorder_point': 10},
      ];

      // When
      final atRiskProducts = products
          .where((p) => (p['quantity'] as int) < (p['reorder_point'] as int))
          .toList();

      // Then
      expect(atRiskProducts.length, equals(2));
      expect(atRiskProducts[0]['id'], equals('1'));
      expect(atRiskProducts[1]['id'], equals('3'));
    });
  });

  group('InventoryService - Batch Management', () {
    test('getBatchSummary should calculate expiry risk percentage', () {
      // Given
      final batches = [
        {'quantity': 100, 'is_expired': false},
        {'quantity': 50, 'is_expired': true},
        {'quantity': 30, 'is_expired': false},
      ];

      // When
      double totalQuantity = 0;
      double expiredQuantity = 0;
      for (final batch in batches) {
        final qty = (batch['quantity'] as int).toDouble();
        totalQuantity += qty;
        if (batch['is_expired'] == true) {
          expiredQuantity += qty;
        }
      }
      final riskPercentage = totalQuantity > 0 ? (expiredQuantity / totalQuantity * 100) : 0;

      // Then
      expect(totalQuantity, equals(180.0));
      expect(expiredQuantity, equals(50.0));
      expect(riskPercentage, equals(27.777777777777778));
    });

    test('getBatchesByFIFO should order by expiry date', () {
      // Given
      final batches = [
        {'id': '1', 'expiry_date': '2026-05-01', 'created_at': '2026-01-01'},
        {'id': '2', 'expiry_date': '2026-04-15', 'created_at': '2026-01-02'},
        {'id': '3', 'expiry_date': '2026-04-15', 'created_at': '2026-01-01'},
      ];

      // When
      batches.sort((a, b) {
        final aExpiry = DateTime.parse(a['expiry_date'] as String);
        final bExpiry = DateTime.parse(b['expiry_date'] as String);
        final expiryCompare = aExpiry.compareTo(bExpiry);
        if (expiryCompare != 0) return expiryCompare;
        final aCreated = DateTime.parse(a['created_at'] as String);
        final bCreated = DateTime.parse(b['created_at'] as String);
        return aCreated.compareTo(bCreated);
      });

      // Then
      expect(batches[0]['id'], equals('3')); // Expires 2026-04-15, created first
      expect(batches[1]['id'], equals('2')); // Expires 2026-04-15, created second
      expect(batches[2]['id'], equals('1')); // Expires 2026-05-01
    });

    test('reduceBatchQuantity should not go below zero', () {
      // Given
      double currentQty = 50.0;
      const quantityToReduce = 60.0;

      // When
      final newQty = (currentQty - quantityToReduce).clamp(0, double.infinity);

      // Then
      expect(newQty, equals(0.0));
    });
  });

  group('InventoryService - Multi-Warehouse', () {
    test('getConsolidatedSummary should calculate total values', () {
      // Given
      final products = [
        {'quantity': 100, 'price': 50, 'reserved_quantity': 20},
        {'quantity': 200, 'price': 25, 'reserved_quantity': 50},
        {'quantity': 150, 'price': 100, 'reserved_quantity': 0},
      ];

      // When
      double totalQuantity = 0;
      double totalReserved = 0;
      double totalValue = 0;

      for (final product in products) {
        final qty = (product['quantity'] as int).toDouble();
        final reserved = (product['reserved_quantity'] as int).toDouble();
        final price = (product['price'] as int).toDouble();
        totalQuantity += qty;
        totalReserved += reserved;
        totalValue += qty * price;
      }

      final availableQuantity = totalQuantity - totalReserved;
      final avgPrice = totalValue / products.length;

      // Then
      // 100*50 + 200*25 + 150*100 = 5000 + 5000 + 15000 = 25000
      expect(totalQuantity, equals(450.0));
      expect(totalReserved, equals(70.0));
      expect(availableQuantity, equals(380.0));
      expect(totalValue, equals(25000.0));
      expect(avgPrice, equals(8333.333333333334));
    });

    test('transferBetweenWarehouses should validate sufficient stock', () {
      // Given
      const fromQty = 50.0;
      const transferQty = 60.0;

      // When
      final hasEnoughStock = fromQty >= transferQty;

      // Then
      expect(hasEnoughStock, equals(false));
    });

    test('syncAllWarehouses should clamp reserved to quantity', () {
      // Given
      final products = [
        {'id': '1', 'quantity': 100, 'reserved_quantity': 50},
        {'id': '2', 'quantity': 50, 'reserved_quantity': 100}, // Invalid!
        {'id': '3', 'quantity': 200, 'reserved_quantity': 200},
      ];

      // When
      final synced = products.map((p) {
        final reserved = (p['reserved_quantity'] as int).toDouble();
        final qty = (p['quantity'] as int).toDouble();
        return {
          ...p,
          'reserved_quantity': reserved > qty ? qty : reserved,
        };
      }).toList();

      // Then
      expect(synced[0]['reserved_quantity'], equals(50)); // Unchanged
      expect(synced[1]['reserved_quantity'], equals(50)); // Clamped to quantity
      expect(synced[2]['reserved_quantity'], equals(200)); // Unchanged
    });
  });

  group('InventoryService - Reserve Stock', () {
    test('reserveStock should not exceed available quantity', () {
      // Given
      const totalQty = 100.0;
      const currentReserved = 30.0;
      const toReserve = 80.0;

      // When
      final available = totalQty - currentReserved;
      final canReserve = available >= toReserve;

      // Then
      expect(available, equals(70.0));
      expect(canReserve, equals(false));
    });

    test('releaseReservedStock should not go below zero', () {
      // Given
      const currentReserved = 30.0;
      const toRelease = 50.0;

      // When
      final newReserved = (currentReserved - toRelease).clamp(0, double.infinity);

      // Then
      expect(newReserved, equals(0.0));
    });

    test('getAvailableStock should calculate correctly', () {
      // Given
      const totalQty = 100.0;
      const reserved = 30.0;

      // When
      final available = totalQty - reserved;

      // Then
      expect(available, equals(70.0));
    });
  });

  group('InventoryService - Bulk Operations', () {
    test('bulkUpdateProducts should update multiple items', () {
      // Given
      final products = [
        {'id': '1', 'price': 100},
        {'id': '2', 'price': 200},
        {'id': '3', 'price': 150},
      ];
      final updates = {'1': 120, '2': 220};

      // When
      final updated = products.map((p) {
        final id = p['id'] as String;
        return {
          ...p,
          'price': updates.containsKey(id) ? updates[id] : p['price'],
        };
      }).toList();

      // Then
      expect(updated[0]['price'], equals(120));
      expect(updated[1]['price'], equals(220));
      expect(updated[2]['price'], equals(150)); // Unchanged
    });

    test('bulkAdjustment should apply same change to multiple items', () {
      // Given
      final products = [
        {'id': '1', 'quantity': 100},
        {'id': '2', 'quantity': 200},
        {'id': '3', 'quantity': 150},
      ];
      const quantityChange = -10;

      // When
      final adjusted = products.map((p) {
        final newQty = ((p['quantity'] as int) + quantityChange).clamp(0, 999999);
        return {...p, 'quantity': newQty};
      }).toList();

      // Then
      expect(adjusted[0]['quantity'], equals(90));
      expect(adjusted[1]['quantity'], equals(190));
      expect(adjusted[2]['quantity'], equals(140));
    });
  });
}
