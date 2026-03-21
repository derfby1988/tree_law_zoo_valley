import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_law_zoo_valley/pages/procurement/dialogs/send_po_dialog.dart';

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
                    builder: (_) => const SendPODialog(
                      purchaseOrder: {
                        'id': 'po-001',
                        'order_number': 'PO-001',
                        'supplier': {'name': 'Supplier A'},
                        'total_amount': 1250.0,
                      },
                      currentUserId: 'user-001',
                    ),
                  );
                },
                child: const Text('open-send'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-send'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows send dialog details and actions', (tester) async {
    await _openDialog(tester);

    expect(find.text('ส่งใบสั่งซื้อ'), findsOneWidget);
    expect(find.text('คุณต้องการส่ง PO นี้หรือไม่?'), findsOneWidget);
    expect(find.text('PO-001'), findsOneWidget);
    expect(find.text('Supplier A'), findsOneWidget);
    expect(find.text('1250.00 บาท'), findsOneWidget);
    expect(find.text('ส่ง PO'), findsOneWidget);
    expect(find.text('ยกเลิก'), findsOneWidget);
  });

  testWidgets('closes dialog when cancel tapped', (tester) async {
    await _openDialog(tester);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('ส่งใบสั่งซื้อ'), findsNothing);
  });
}
