import 'package:flutter/material.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'ทั้งหมด';
  String _selectedShelf = 'ทั้งหมด';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFilter(),
          SizedBox(height: 16),
          _buildSummaryCards(),
          SizedBox(height: 16),
          _buildLowStockAlert(),
          SizedBox(height: 16),
          _buildExpiringItemsAlert(),
          SizedBox(height: 16),
          _buildMovementStatistics(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาสินค้า...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedWarehouse,
                    decoration: InputDecoration(
                      labelText: 'คลังสินค้า',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['ทั้งหมด', 'คลังหลัก', 'คลังสำรอง', 'คลังครัว'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) => setState(() => _selectedWarehouse = value!),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedShelf,
                    decoration: InputDecoration(
                      labelText: 'ชั้นวาง',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['ทั้งหมด', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'C3', 'D1', 'D2', 'E1'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) => setState(() => _selectedShelf = value!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📊 ภาพรวมคลังสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ทั้งหมด', '125', Colors.blue, Icons.inventory_2)),
            SizedBox(width: 8),
            Expanded(child: _buildSummaryCard('พร้อม', '98', Colors.green, Icons.check_circle)),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ใกล้หมด', '15', Colors.orange, Icons.warning)),
            SizedBox(width: 8),
            Expanded(child: _buildSummaryCard('หมด', '12', Colors.red, Icons.error)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            Text('รายการ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    final lowStockItems = [
      {'name': 'เค้กช็อกโกแลต', 'qty': '8', 'unit': 'ชิ้น', 'shelf': 'A1'},
      {'name': 'ไอศกรีมวานิลา', 'qty': '5', 'unit': 'ชิ้น', 'shelf': 'B2'},
      {'name': 'ขนมปังสด', 'qty': '3', 'unit': 'ถุง', 'shelf': 'C3'},
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('🚨 แจ้งเตือนสินค้าใกล้หมด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            ...lowStockItems.map((item) => Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('${item['name']} (${item['qty']} ${item['unit']}) ชั้น ${item['shelf']}')),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringItemsAlert() {
    final expiringItems = [
      {'name': 'นมสด', 'days': '2', 'qty': '10', 'unit': 'ขวด', 'status': 'รอเมนู'},
      {'name': 'เนื้อสด', 'days': '3', 'qty': '5', 'unit': 'กก.', 'status': 'กำลังปรุง'},
      {'name': 'ผักสด', 'days': '1', 'qty': '8', 'unit': 'กก.', 'status': 'วางขาย'},
      {'name': 'มะเขือเทศ', 'days': '2', 'qty': '15', 'unit': 'ผล', 'status': 'รอเมนู'},
      {'name': 'ไข่ไก่', 'days': '7', 'qty': '30', 'unit': 'ฟอง', 'status': 'วางขาย'},
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.red),
                SizedBox(width: 8),
                Text('⏰ แจ้งเตือนวัตถุดิบใกล้หมดอายุ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            ...expiringItems.map((item) => Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getExpiryColor(int.parse(item['days']!)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getExpiryColor(int.parse(item['days']!)).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  _getExpiryIcon(item['name']!),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['name']} หมดอายุ ${item['days']} วัน', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('(${item['qty']} ${item['unit']})', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildStatusChip(item['status']!),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Color _getExpiryColor(int days) {
    if (days <= 2) return Colors.red;
    if (days <= 4) return Colors.orange;
    return Colors.yellow[700]!;
  }

  Widget _getExpiryIcon(String name) {
    Map<String, IconData> icons = {
      'นมสด': Icons.local_drink,
      'เนื้อสด': Icons.restaurant,
      'ผักสด': Icons.eco,
      'มะเขือเทศ': Icons.circle,
      'ไข่ไก่': Icons.egg,
    };
    return Icon(icons[name] ?? Icons.inventory, color: Colors.grey[600], size: 20);
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'รอเมนู':
        color = Colors.blue;
        icon = Icons.hourglass_empty;
        break;
      case 'กำลังปรุง':
        color = Colors.orange;
        icon = Icons.local_fire_department;
        break;
      case 'วางขาย':
        color = Colors.green;
        icon = Icons.restaurant_menu;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMovementStatistics() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple),
                SizedBox(width: 8),
                Text('📋 สถิติการเคลื่อนไหวสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            _buildStatRow(Icons.download, 'รับเข้าวันนี้', '15 รายการ', Colors.green),
            _buildStatRow(Icons.upload, 'จ่ายออกวันนี้', '23 รายการ', Colors.red),
            _buildStatRow(Icons.sync, 'ปรับปรุงวันนี้', '5 รายการ', Colors.blue),
            _buildStatRow(Icons.attach_money, 'มูลค่าคลัง', '฿125,000', Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
