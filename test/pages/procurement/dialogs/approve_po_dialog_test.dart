import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_law_zoo_valley/pages/procurement/dialogs/approve_po_dialog.dart';

void main() {
  Future<void> _openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    builder: (_) => const ApprovePODialog(
                      purchaseOrder: {
                        'id': 'po-001',
                        'order_number': 'PO-001',
                        'supplier': {'name': 'Supplier A'},
                        'total_amount': 4500.0,
                        'lines': [],
                      },
                      currentUserId: 'user-001',
                      userRole: 'store_manager',
                    ),
                  );
                },
                child: const Text('open-approve'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-approve'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows approve dialog key sections and actions', (tester) async {
    await _openDialog(tester);

    expect(find.text('อนุมัติใบสั่งซื้อ'), findsOneWidget);
    expect(find.text('PO-001'), findsOneWidget);
    expect(find.text('Supplier A'), findsOneWidget);
    expect(find.text('4500.00 บาท'), findsOneWidget);
    expect(find.text('วงเงินอนุมัติของคุณ: 5,000 บาท'), findsOneWidget);
    expect(find.text('ปฏิเสธ'), findsOneWidget);
    expect(find.text('อนุมัติ'), findsOneWidget);
  });

  testWidgets('shows rejection input area for approve flow', (tester) async {
    await _openDialog(tester);

    expect(find.text('หมายเหตุ (กรณีปฏิเสธ):'), findsOneWidget);
    expect(find.text('ระบุเหตุผล...'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
