import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_law_zoo_valley/pages/procurement/dialogs/cancel_po_dialog.dart';

void main() {
  Future<void> _openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    builder: (_) => const CancelPODialog(orderNumber: 'PO-001'),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows cancel button and validates empty reason', (tester) async {
    await _openDialog(tester);

    expect(find.text('ยกเลิกใบสั่งซื้อ'), findsOneWidget);
    expect(find.text('ปิด'), findsOneWidget);
    expect(find.text('ยืนยันยกเลิก'), findsOneWidget);

    await tester.tap(find.text('ยืนยันยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณาระบุเหตุผลการยกเลิก'), findsOneWidget);
  });

  testWidgets('accepts reason and closes dialog', (tester) async {
    await _openDialog(tester);

    await tester.enterText(find.byType(TextFormField), 'สินค้าผิดสเปค');
    await tester.tap(find.text('ยืนยันยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('ยกเลิกใบสั่งซื้อ'), findsNothing);
  });
}
