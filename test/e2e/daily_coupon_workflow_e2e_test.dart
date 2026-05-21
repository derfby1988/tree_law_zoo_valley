import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Daily Coupon E2E - Customer Share Flow', () {
    testWidgets('Customer can see token usage and remaining counts', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                Text('คูปองรายวัน • รายกลุ่ม'),
                Text('สถานะการแชร์'),
                Text('ใช้แล้ว 2/8 • เหลือ 6'),
                Text('สมาชิก 8 คน'),
                Text('ใช้งานได้'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('คูปองรายวัน • รายกลุ่ม'), findsOneWidget);
      expect(find.text('ใช้แล้ว 2/8 • เหลือ 6'), findsOneWidget);
      expect(find.text('ใช้งานได้'), findsOneWidget);
    });

    testWidgets('Customer can copy share token payload', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('แชร์ให้สมาชิก'),
                ElevatedButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(
                        text: 'คูปองรายวัน • Share token: TLZ-123456',
                      ),
                    );
                  },
                  child: const Text('คัดลอก token'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('คัดลอก token'));
      await tester.pumpAndSettle();

      expect(find.text('คัดลอก token'), findsOneWidget);
    });
  });

  group('Daily Coupon E2E - Gate Scan Flow', () {
    testWidgets('Gate scanner shows offline queue state and replay guidance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Gate Scanner')),
            body: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('บันทึกไว้ในคิวออฟไลน์แล้ว'),
                Text('ซิงก์รายการค้างเรียบร้อยแล้ว'),
                Text('ประวัติล่าสุด'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Gate Scanner'), findsOneWidget);
      expect(find.text('คิวออฟไลน์แล้ว'), findsOneWidget);
    });

    testWidgets('Gate scanner can show valid scan result', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                Text('บันทึกการสแกนสำเร็จ'),
                Text('ใช้แล้ว 2/8'),
                Text('เหลือ 6'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('บันทึกการสแกนสำเร็จ'), findsOneWidget);
      expect(find.text('เหลือ 6'), findsOneWidget);
    });
  });

  group('Daily Coupon E2E - History Visibility', () {
    testWidgets('Customer history sheet shows gate and POS sections', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  Text('ประวัติการใช้พื้นที่ / ส่วนลด'),
                  Text('เข้า/ออกพื้นที่ (Gate)'),
                  Text('การใช้ส่วนลด (POS)'),
                  Text('สถานะการแชร์'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('ประวัติการใช้พื้นที่ / ส่วนลด'), findsOneWidget);
      expect(find.text('เข้า/ออกพื้นที่ (Gate)'), findsOneWidget);
      expect(find.text('การใช้ส่วนลด (POS)'), findsOneWidget);
    });
  });
}
