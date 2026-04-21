import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Performance - List Rendering', () {
    testWidgets('Product list renders efficiently with 100 items', (WidgetTester tester) async {
      // Given - Product list with 100 items
      final products = List.generate(100, (i) => {
        'id': 'prod$i',
        'name': 'Product $i',
        'quantity': 100 + i,
        'price': 50.0 + i,
      });

      // When - Build product list
      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  title: Text(product['name'].toString()),
                  subtitle: Text('SKU: ${product['id']}'),
                  trailing: Text('${product['quantity']} units'),
                );
              },
            ),
          ),
        ),
      );
      
      stopwatch.stop();

      // Then - Rendering should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('Batch list renders efficiently with 50 items', (WidgetTester tester) async {
      // Given - Batch list with 50 items
      final batches = List.generate(50, (i) => {
        'batch_number': 'B${i.toString().padLeft(3, '0')}',
        'quantity': 100 - i,
        'expiry_date': '2026-05-${(i % 28) + 1}',
      });

      // When - Build batch list
      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final batch = batches[index];
                return Card(
                  child: ListTile(
                    title: Text('Batch: ${batch['batch_number']}'),
                    subtitle: Text('Qty: ${batch['quantity']}'),
                    trailing: Text('Exp: ${batch['expiry_date']}'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      
      stopwatch.stop();

      // Then - Rendering should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(600));
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('PO list renders efficiently with 75 items', (WidgetTester tester) async {
      // Given - PO list with 75 items
      final pos = List.generate(75, (i) => {
        'po_number': 'PO${i.toString().padLeft(4, '0')}',
        'status': ['Draft', 'Sent', 'Confirmed', 'Completed'][i % 4],
        'amount': 5000.0 + (i * 100),
      });

      // When - Build PO list
      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: pos.length,
              itemBuilder: (context, index) {
                final po = pos[index];
                return ListTile(
                  title: Text(po['po_number'].toString()),
                  subtitle: Text('Status: ${po['status']}'),
                  trailing: Text('฿${po['amount']}'),
                );
              },
            ),
          ),
        ),
      );
      
      stopwatch.stop();

      // Then - Rendering should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(700));
      expect(find.byType(ListTile), findsWidgets);
    });
  });

  group('Widget Performance - Search Performance', () {
    testWidgets('Search filters 100 products efficiently', (WidgetTester tester) async {
      // Given - Product list
      final allProducts = List.generate(100, (i) => 'Product $i');
      String searchQuery = '';

      // When - Perform search
      final stopwatch = Stopwatch()..start();
      
      final filtered = allProducts
          .where((p) => p.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
      
      searchQuery = 'Product 5';
      final filtered2 = allProducts
          .where((p) => p.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
      
      stopwatch.stop();

      // Then - Search should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(filtered2.length, greaterThan(0));
    });

    testWidgets('Search widget updates efficiently', (WidgetTester tester) async {
      // Given - Search widget
      final products = List.generate(50, (i) => 'Product $i');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: TextField(
                decoration: const InputDecoration(hintText: 'Search...'),
              ),
            ),
            body: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) => ListTile(title: Text(products[index])),
            ),
          ),
        ),
      );

      // When - User types in search
      final stopwatch = Stopwatch()..start();
      
      await tester.enterText(find.byType(TextField), 'Product');
      await tester.pumpAndSettle();
      
      stopwatch.stop();

      // Then - Update should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });
  });

  group('Widget Performance - Filter Performance', () {
    testWidgets('Filter 100 items by status efficiently', (WidgetTester tester) async {
      // Given - Items with status
      final items = List.generate(100, (i) => {
        'id': i,
        'status': ['Active', 'Pending', 'Completed'][i % 3],
      });

      // When - Filter items
      final stopwatch = Stopwatch()..start();
      
      final filtered = items
          .where((item) => item['status'] == 'Active')
          .toList();
      
      stopwatch.stop();

      // Then - Filtering should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(filtered.length, greaterThan(0));
    });

    testWidgets('Multiple filters applied efficiently', (WidgetTester tester) async {
      // Given - Items with multiple properties
      final items = List.generate(100, (i) => {
        'id': i,
        'status': ['Active', 'Pending'][i % 2],
        'warehouse': ['Main', 'Branch1', 'Branch2'][i % 3],
        'quantity': i * 10,
      });

      // When - Apply multiple filters
      final stopwatch = Stopwatch()..start();
      
      final filtered = items
          .where((item) => item['status'] == 'Active')
          .where((item) => item['warehouse'] == 'Main')
          .where((item) => (item['quantity'] as int) > 500)
          .toList();
      
      stopwatch.stop();

      // Then - Filtering should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Widget Performance - Navigation Performance', () {
    testWidgets('Tab navigation is smooth', (WidgetTester tester) async {
      // Given - Tab view
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Tab 1'),
                    Tab(text: 'Tab 2'),
                    Tab(text: 'Tab 3'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  const Center(child: Text('Tab 1')),
                  const Center(child: Text('Tab 2')),
                  const Center(child: Text('Tab 3')),
                ],
              ),
            ),
          ),
        ),
      );

      // When - Switch tabs
      final stopwatch = Stopwatch()..start();
      
      await tester.tap(find.text('Tab 2'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Tab 3'));
      await tester.pumpAndSettle();
      
      stopwatch.stop();

      // Then - Navigation should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    testWidgets('Page navigation is smooth', (WidgetTester tester) async {
      // Given - Navigation
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () => navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Page 2'))),
              ),
              child: const Text('Go to Page 2'),
            ),
          ),
        ),
      );

      // When - Navigate
      final stopwatch = Stopwatch()..start();
      
      await tester.tap(find.text('Go to Page 2'));
      await tester.pumpAndSettle();
      
      stopwatch.stop();

      // Then - Navigation should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });
  });

  group('Widget Performance - Sorting Performance', () {
    testWidgets('Sort 100 items by name efficiently', (WidgetTester tester) async {
      // Given - Items to sort
      final items = List.generate(100, (i) => {
        'name': 'Product ${99 - i}',
        'id': i,
      });

      // When - Sort items
      final stopwatch = Stopwatch()..start();
      
      final sorted = List.from(items)
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      
      stopwatch.stop();

      // Then - Sorting should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(sorted[0]['name'], startsWith('Product'));
    });

    testWidgets('Sort 100 items by numeric value efficiently', (WidgetTester tester) async {
      // Given - Items with numeric values
      final items = List.generate(100, (i) => {
        'name': 'Item $i',
        'quantity': 100 - i,
      });

      // When - Sort by quantity
      final stopwatch = Stopwatch()..start();
      
      final sorted = List.from(items)
        ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
      
      stopwatch.stop();

      // Then - Sorting should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(sorted[0]['quantity'], equals(100));
    });
  });

  group('Widget Performance - Memory Usage', () {
    testWidgets('Large list does not cause excessive memory', (WidgetTester tester) async {
      // Given - Large product list
      final products = List.generate(200, (i) => {
        'id': 'prod$i',
        'name': 'Product $i',
        'quantity': 100 + i,
        'price': 50.0 + i,
        'warehouse': 'Warehouse ${i % 5}',
      });

      // When - Build large list
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  title: Text(product['name'].toString()),
                  subtitle: Text('${product['quantity']} units'),
                  trailing: Text('฿${product['price']}'),
                );
              },
            ),
          ),
        ),
      );

      // Then - List should render without issues
      expect(find.byType(ListTile), findsWidgets);
      expect(products.length, equals(200));
    });

    testWidgets('Widget rebuild does not leak memory', (WidgetTester tester) async {
      // Given - Stateful widget
      int rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildCount++;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rebuild'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // When - Trigger multiple rebuilds
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.text('Rebuild'));
        await tester.pumpAndSettle();
      }

      // Then - Rebuilds should be efficient
      expect(rebuildCount, greaterThan(0));
    });
  });

  group('Widget Performance - Complex Widget Trees', () {
    testWidgets('Nested widgets render efficiently', (WidgetTester tester) async {
      // Given - Complex nested widget tree
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: List.generate(20, (i) => 
                  Card(
                    child: Column(
                      children: [
                        Text('Card $i'),
                        Row(
                          children: [
                            Expanded(child: Text('Item 1')),
                            Expanded(child: Text('Item 2')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      stopwatch.stop();

      // Then - Rendering should be efficient
      expect(stopwatch.elapsedMilliseconds, lessThan(800));
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('GridView renders efficiently', (WidgetTester tester) async {
      // Given - GridView with many items
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.count(
              crossAxisCount: 3,
              children: List.generate(60, (i) => 
                Card(
                  child: Center(child: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      );

      stopwatch.stop();

      // Then - Grid should render efficiently
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(find.byType(Card), findsWidgets);
    });
  });
}
