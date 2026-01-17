import 'package:flutter/material.dart';
import '../main.dart';

class RoomBookingPage extends StatelessWidget {
  const RoomBookingPage({super.key, required this.isGuestMode});

  final bool isGuestMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จองที่พัก'),
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
                      'คุณกำลังจองที่พักในโหมดผู้เยี่ยม สามารถเลือกห้องได้ แต่ต้องเข้าสู่ระบบก่อนยืนยันการจอง',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Room selection
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'เลือกประเภทห้องพัก',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildRoomCard(
                  'Standard Room',
                  'ห้องพักมาตรฐาน',
                  '1-2 คน',
                  800,
                  Icons.bed,
                  Colors.blue,
                ),
                
                _buildRoomCard(
                  'Deluxe Room',
                  'ห้องพักดีลักซ์',
                  '2-3 คน',
                  1200,
                  Icons.king_bed,
                  Colors.purple,
                ),
                
                _buildRoomCard(
                  'Suite Room',
                  'ห้องสวีท',
                  '3-4 คน',
                  2000,
                  Icons.weekend,
                  Colors.amber,
                ),
                
                _buildRoomCard(
                  'Family Room',
                  'ห้องพักครอบครัว',
                  '4-6 คน',
                  2500,
                  Icons.family_restroom,
                  Colors.green,
                ),
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
                  isGuestMode ? 'เข้าสู่ระบบเพื่อจองที่พัก' : 'จองที่พัก',
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

  Widget _buildRoomCard(
    String name,
    String description,
    String capacity,
    int price,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room image placeholder
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 48,
                color: color,
              ),
            ),
          ),
          
          // Room info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '฿$price/คืน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      capacity,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
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
          content: const Text('กรุณาเข้าสู่ระบบเพื่อยืนยันการจองที่พัก'),
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
                      returnToRoomBooking: true, // ✅ บอกว่าต้องกลับมาหน้าจองที่พัก
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
      // ✅ User - จองที่พักได้เลย
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('จองที่พักสำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
