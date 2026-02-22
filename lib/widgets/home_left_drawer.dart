import 'package:flutter/material.dart';

class HomeLeftDrawer extends StatelessWidget {
  const HomeLeftDrawer({
    super.key,
    required this.isGuestMode,
    required this.onHomeTap,
    required this.onTableBookingTap,
  });

  final bool isGuestMode;
  final VoidCallback onHomeTap;
  final VoidCallback onTableBookingTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait = screenHeight > screenWidth;
    final drawerWidth = isPortrait ? screenWidth * 0.75 : screenWidth * 0.25;

    return GestureDetector(
      onPanEnd: (details) {
        if (details.velocity.pixelsPerSecond.dx < -500) {
          Navigator.pop(context);
        }
      },
      child: Container(
        width: drawerWidth,
        color: const Color(0xFF79FFB6).withValues(alpha: 0.1),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF79FFB6).withValues(alpha: 0.5),
              ),
              child: const Text(
                'รายการ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _menuItem(
              context,
              title: 'หน้าแรก',
              icon: Icons.home,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: onHomeTap,
            ),
            _menuItem(context, title: 'สั่งอาหาร', icon: Icons.restaurant),
            _menuItem(
              context,
              title: 'จองโต๊ะ/ที่นั่ง',
              icon: Icons.table_restaurant,
              onTap: onTableBookingTap,
            ),
            _menuItem(context, title: 'จองที่พัก', icon: Icons.bed),
            _menuItem(context, title: 'คูปอง', icon: Icons.local_offer),
            _menuItem(context, title: 'เรียกพนักงาน / ให้ทิป', icon: Icons.people),
            _menuItem(context, title: 'ข้อมูลส่วนตัว', icon: Icons.person),
            _menuItem(context, title: 'ร่วมงานกับเรา', icon: Icons.work),
            _menuItem(context, title: 'รีวิว/ติดต่อสอบถาม', icon: Icons.contact_support),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    bool dense = false,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return ListTile(
      dense: dense,
      contentPadding: contentPadding,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ),
          Icon(icon, color: Colors.white),
        ],
      ),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }
}
