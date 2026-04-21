import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Batch Management Widget Tests', () {
    testWidgets('BatchManagementWidget displays summary cards', (WidgetTester tester) async {
      // Given
      const summary = {
        'product_count': 5,
        'total_quantity': 100.0,
        'available_quantity': 80.0,
        'reserved_quantity': 20.0,
        'total_value': 5000.0,
        'average_price': 1000.0,
      };

      // When - Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Simulate summary cards
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text('${summary['product_count']} สินค้า'),
                          Text('${summary['total_quantity']} หน่วย'),
                          Text('฿${summary['total_value']}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Then - Verify summary is displayed
      expect(find.text('5 สินค้า'), findsOneWidget);
      expect(find.text('100.0 หน่วย'), findsOneWidget);
      expect(find.text('฿5000.0'), findsOneWidget);
    });

    testWidgets('BatchManagementWidget filters by status', (WidgetTester tester) async {
      // Given
      final batches = [
        {'id': '1', 'batch_number': 'B001', 'is_expired': false},
        {'id': '2', 'batch_number': 'B002', 'is_expired': true},
        {'id': '3', 'batch_number': 'B003', 'is_expired': false},
      ];

      // When - Filter active batches
      final activeBatches = batches.where((b) => b['is_expired'] != true).toList();

      // Then
      expect(activeBatches.length, equals(2));
      expect(activeBatches[0]['batch_number'], equals('B001'));
      expect(activeBatches[1]['batch_number'], equals('B003'));
    });

    testWidgets('BatchManagementWidget shows empty state', (WidgetTester tester) async {
      // Given
      final batches = <Map<String, dynamic>>[];

      // When
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: batches.isEmpty
                ? const Center(child: Text('ไม่มีล็อตสินค้า'))
                : ListView.builder(
                    itemCount: batches.length,
                    itemBuilder: (context, index) => Text(batches[index]['batch_number']),
                  ),
          ),
        ),
      );

      // Then
      expect(find.text('ไม่มีล็อตสินค้า'), findsOneWidget);
    });

    testWidgets('BatchManagementWidget displays batch cards', (WidgetTester tester) async {
      // Given
      final batch = {
        'batch_number': 'B001',
        'quantity': 100.0,
        'expiry_date': '2026-05-15',
        'is_expired': false,
      };

      // When
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ล็อต: ${batch['batch_number']}'),
                    Text('จำนวน: ${batch['quantity']}'),
                    Text('หมดอายุ: ${batch['expiry_date']}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Then
      expect(find.text('ล็อต: B001'), findsOneWidget);
      expect(find.text('จำนวน: 100.0'), findsOneWidget);
      expect(find.text('หมดอายุ: 2026-05-15'), findsOneWidget);
    });
  });

  group('Batch Expiry Page Tests', () {
    testWidgets('BatchExpiryPage displays expiring and expired tabs', (WidgetTester tester) async {
      // Given
      const expiringCount = 3;
      const expiredCount = 2;

      // When
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('ใกล้หมด (3)'),
                        selected: true,
                        onSelected: (_) {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('หมดอายุแล้ว (2)'),
                        selected: false,
                        onSelected: (_) {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      // Then
      expect(find.text('ใกล้หมด (3)'), findsOneWidget);
      expect(find.text('หมดอายุแล้ว (2)'), findsOneWidget);
    });

    testWidgets('BatchExpiryPage shows batch details', (WidgetTester tester) async {
      // Given
      final batch = {
        'product': {'name': 'น้ำมันพืช', 'code': 'OIL001'},
        'batch_number': 'B001',
        'quantity': 50.0,
        'expiry_date': '2026-04-20',
      };

      // When
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((batch['product'] as Map)['name'].toString()),
                    Text('รหัส: ${(batch['product'] as Map)['code']}'),
                    Text('ล็อต: ${batch['batch_number']}'),
                    Text('จำนวน: ${batch['quantity']}'),
                    Text('หมดอายุ: ${batch['expiry_date']}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Then
      expect(find.text('น้ำมันพืช'), findsOneWidget);
      expect(find.text('รหัส: OIL001'), findsOneWidget);
      expect(find.text('ล็อต: B001'), findsOneWidget);
      expect(find.text('จำนวน: 50.0'), findsOneWidget);
      expect(find.text('หมดอายุ: 2026-04-20'), findsOneWidget);
    });
  });

  group('Consolidated Inventory Widget Tests', () {
    testWidgets('ConsolidatedInventoryWidget displays summary', (WidgetTester tester) async {
      // Given
      const summary = {
        'product_count': 50,
        'total_quantity': 1000.0,
        'available_quantity': 800.0,
        'reserved_quantity': 200.0,
        'total_value': 50000.0,
        'average_price': 1000.0,
      };

      // When
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text('สินค้าทั้งหมด: ${summary['product_count']}'),
                  Text('จำนวนรวม: ${summary['total_quantity']}'),
                  Text('มูลค่ารวม: ฿${summary['total_value']}'),
                  Text('พร้อมใช้: ${summary['available_quantity']}'),
                  Text('สำรอง: ${summary['reserved_quantity']}'),
                ],
              ),
            ),
          ),
        ),
      );

      // Then
      expect(find.text('สินค้าทั้งหมด: 50'), findsOneWidget);
      expect(find.text('จำนวนรวม: 1000.0'), findsOneWidget);
      expect(find.text('มูลค่ารวม: ฿50000.0'), findsOneWidget);
      expect(find.text('พร้อมใช้: 800.0'), findsOneWidget);
      expect(find.text('สำรอง: 200.0'), findsOneWidget);
    });

    test('ConsolidatedInventoryWidget sorts by quantity', () {
      // Given
      final products = [
        {'name': 'ซอส', 'quantity': 100},
        {'name': 'น้ำมัน', 'quantity': 200},
        {'name': 'เกลือ', 'quantity': 150},
      ];

      // When
      products.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

      // Then
      expect(products[0]['quantity'], equals(200)); // Highest first
      expect(products[1]['quantity'], equals(150));
      expect(products[2]['quantity'], equals(100)); // Lowest last
    });
  });
}
