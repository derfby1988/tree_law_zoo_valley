import 'package:flutter/material.dart';
import '../main.dart';

class RestaurantMenuPage extends StatelessWidget {
  const RestaurantMenuPage({super.key, required this.isGuestMode});

  final bool isGuestMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สั่งอาหาร'),
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
                      'คุณกำลังดูเมนูในโหมดผู้เยี่ยม สามารถสั่งอาหารได้ แต่ต้องเข้าสู่ระบบก่อนชำระเงิน',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMenuItem('ข้าวผัด', 120),
                _buildMenuItem('ผัดไทย', 100),
                _buildMenuItem('ต้มยำ', 150),
                _buildMenuItem('ข้าวมันไก่', 80),
                _buildMenuItem('ก๋วยเตี๋ยว', 90),
                _buildMenuItem('แกงเขียวหวาน', 140),
              ],
            ),
          ),
          
          // ✅ Checkout button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _handleCheckout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isGuestMode ? 'เข้าสู่ระบบเพื่อสั่งอาหาร' : 'สั่งอาหาร',
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

  Widget _buildMenuItem(String name, int price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '฿$price',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[600],
            ),
          ),
        ],
      ),
    );
  }

  void _handleCheckout(BuildContext context) {
    if (isGuestMode) {
      // ✅ Guest - ต้อง login ก่อน
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ต้องการเข้าสู่ระบบ'),
          content: const Text('กรุณาเข้าสู่ระบบเพื่อสั่งอาหาร'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด dialog
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LoginPage(
                      returnToMenu: true, // ✅ บอกว่าต้องกลับมาหน้าเมนู
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
      // ✅ User - สั่งอาหารได้เลย
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กำลังดำเนินการสั่งอาหาร...'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
