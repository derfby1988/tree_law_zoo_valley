import 'package:flutter/material.dart';
import '../main.dart';

class TableBookingPage extends StatelessWidget {
  const TableBookingPage({super.key, required this.isGuestMode});

  final bool isGuestMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จองโต๊ะ'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ✅ Guest Mode Banner
          if (isGuestMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'คุณกำลังจองโต๊ะในโหมดผู้เยี่ยม สามารถเลือกโต๊ะได้ แต่ต้องเข้าสู่ระบบก่อนยืนยันการจอง',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Table selection
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16),
              children: [
                _buildTable('โต๊ะ 1', true),
                _buildTable('โต๊ะ 2', false),
                _buildTable('โต๊ะ 3', true),
                _buildTable('โต๊ะ 4', true),
                _buildTable('โต๊ะ 5', false),
                _buildTable('โต๊ะ 6', true),
                _buildTable('โต๊ะ 7', true),
                _buildTable('โต๊ะ 8', false),
                _buildTable('โต๊ะ 9', true),
              ],
            ),
          ),
          
          // ✅ Booking button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _handleBooking(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isGuestMode ? 'เข้าสู่ระบบเพื่อจองโต๊ะ' : 'จองโต๊ะ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(String name, bool available) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: available ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: available ? Colors.green[300]! : Colors.red[300]!,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_restaurant,
            size: 32,
            color: available ? Colors.green[600] : Colors.red[600],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: available ? Colors.green[700] : Colors.red[700],
            ),
          ),
          Text(
            available ? 'ว่าง' : 'ไม่ว่าง',
            style: TextStyle(
              fontSize: 10,
              color: available ? Colors.green[600] : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }

  void _handleBooking(BuildContext context) {
    if (isGuestMode) {
      // ✅ Guest - ต้อง login ก่อน
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ต้องการเข้าสู่ระบบ'),
          content: const Text('กรุณาเข้าสู่ระบบเพื่อยืนยันการจองโต๊ะ'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LoginPage(
                      returnToBooking: true, // ✅ บอกว่าต้องกลับมาหน้าจองโต๊ะ
                    ),
                  ),
                );
              },
              child: const Text('เข้าสู่ระบบ'),
            ),
          ],
        ),
      );
    } else {
      // ✅ User - จองโต๊ะได้เลย
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('จองโต๊ะสำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
