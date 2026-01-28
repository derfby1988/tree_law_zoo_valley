import 'package:flutter/material.dart';

class AdjustmentTab extends StatefulWidget {
  const AdjustmentTab({super.key});

  @override
  State<AdjustmentTab> createState() => _AdjustmentTabState();
}

class _AdjustmentTabState extends State<AdjustmentTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'ทั้งหมด';
  String _selectedShelf = 'ทั้งหมด';

  final adjustments = [
    {'product': 'แฮมเบอร์เกอร์', 'from': '98', 'to': '100', 'user': 'สมชาย', 'time': '10:30'},
    {'product': 'โคคา-โคลา', 'from': '45', 'to': '50', 'user': 'มานี', 'time': '09:15'},
    {'product': 'เค้กช็อกโกแลต', 'from': '5', 'to': '8', 'user': 'วิรัติ', 'time': '08:45'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchAndFilter(),
          SizedBox(height: 16),
          _buildActionButtons(),
          SizedBox(height: 16),
          _buildAdjustmentForm(),
          SizedBox(height: 16),
          _buildRecentAdjustments(),
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
                    items: ['ทั้งหมด', 'คลังหลัก', 'คลังสำรอง'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                    items: ['ทั้งหมด', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'C3'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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

  Widget _buildActionButtons() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎯 ดำเนินการคลังสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton('🏗️ กำหนดคลัง', Colors.indigo, () => _showWarehouseDialog()),
                _buildActionButton('📋 ชั้นวาง', Colors.teal, () => _showShelfDialog()),
                _buildActionButton('🛒 ซื้อสินค้า', Colors.green, () => _showPurchaseDialog()),
                _buildActionButton('📤 ส่งคืน', Colors.orange, () => _showReturnDialog()),
                _buildActionButton('🔢 ตรวจนับ', Colors.blue, () => _showCountDialog()),
                _buildActionButton('🔄 โอนคลัง', Colors.purple, () => _showTransferDialog()),
                _buildActionButton('📤 เบิกใช้', Colors.cyan, () => _showWithdrawDialog()),
                _buildActionButton('❌ ตัดสินค้าเสีย', Colors.red, () => _showDamageDialog()),
                _buildActionButton('📊 รายงาน', Colors.brown, () => _showReportDialog()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _buildAdjustmentForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📝 ฟอร์มปรับปรุงคลังสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: '📦 เลือกสินค้า', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              items: ['แฮมเบอร์เกอร์', 'โคคา-โคลา', 'เค้กช็อกโกแลต'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(decoration: InputDecoration(labelText: '📍 ชั้นวาง', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), initialValue: 'A1')),
                SizedBox(width: 12),
                Expanded(child: TextFormField(decoration: InputDecoration(labelText: '📊 ปัจจุบัน', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), initialValue: '98', enabled: false)),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(decoration: InputDecoration(labelText: '📈 ปรับเป็น', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), keyboardType: TextInputType.number)),
                SizedBox(width: 12),
                Expanded(child: TextFormField(decoration: InputDecoration(labelText: '📝 เหตุผล', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(decoration: InputDecoration(labelText: '📅 วันที่', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), initialValue: '28/01/2026', enabled: false)),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: '👤 ผู้ดำเนินการ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: ['คุณสมชาย', 'คุณมานี', 'คุณวิรัติ'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(onPressed: () {}, icon: Icon(Icons.refresh), label: Text('รีเซ็ต')),
                SizedBox(width: 12),
                ElevatedButton.icon(onPressed: () {}, icon: Icon(Icons.save), label: Text('บันทึก'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAdjustments() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋 ประวัติการปรับปรุงล่าสุด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            ...adjustments.map((adj) => Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('${adj['product']} ${adj['from']}→${adj['to']}')),
                  Text('${adj['user']}', style: TextStyle(color: Colors.grey[600])),
                  SizedBox(width: 8),
                  Text('${adj['time']}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // Dialogs
  void _showWarehouseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.warehouse, color: Colors.indigo), SizedBox(width: 8), Text('🏗️ กำหนดคลัง')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'ชื่อคลัง', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'ที่ตั้ง', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'ผู้รับผิดชอบ', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showShelfDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.shelves, color: Colors.teal), SizedBox(width: 8), Text('📋 จัดการชั้นวาง')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกคลัง', border: OutlineInputBorder()),
              items: ['คลังหลัก', 'คลังสำรอง'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'รหัสชั้น', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'ความจุ', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.shopping_cart, color: Colors.green), SizedBox(width: 8), Text('🛒 ซื้อสินค้า')]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
                items: ['แฮมเบอร์เกอร์', 'โคคา-โคลา'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) {},
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()))),
                  SizedBox(width: 12),
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'ราคา/หน่วย', border: OutlineInputBorder()))),
                ],
              ),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'ผู้ขาย', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showReturnDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.assignment_return, color: Colors.orange), SizedBox(width: 8), Text('📤 ส่งคืนสินค้า')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
              items: ['แฮมเบอร์เกอร์', 'โคคา-โคลา'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'เหตุผล', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showCountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.calculate, color: Colors.blue), SizedBox(width: 8), Text('🔢 ตรวจนับสินค้า')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
              items: ['แฮมเบอร์เกอร์', 'โคคา-โคลา'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(decoration: InputDecoration(labelText: 'ในระบบ', border: OutlineInputBorder()), enabled: false, controller: TextEditingController(text: '98'))),
                SizedBox(width: 12),
                Expanded(child: TextField(decoration: InputDecoration(labelText: 'จำนวนจริง', border: OutlineInputBorder()))),
              ],
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showTransferDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.swap_horiz, color: Colors.purple), SizedBox(width: 8), Text('🔄 โอนคลัง')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
              items: ['แฮมเบอร์เกอร์', 'โคคา-โคลา'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'จากคลัง', border: OutlineInputBorder()), items: ['คลังหลัก', 'คลังสำรอง'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) {})),
                SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'ไปคลัง', border: OutlineInputBorder()), items: ['คลังหลัก', 'คลังสำรอง'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) {})),
              ],
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.outbox, color: Colors.cyan), SizedBox(width: 8), Text('📤 เบิกใช้สินค้า')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
              items: ['แฮมเบอร์เกอร์', 'โคคา-โคลา'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'แผนก', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'วัตถุประสงค์', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showDamageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('❌ ตัดสินค้าเสีย')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
              items: ['แฮมเบอร์เกอร์', 'โคคา-โคลา'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder())),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'สาเหตุ', border: OutlineInputBorder()),
              items: ['หมดอายุ', 'ชำรุด', 'สูญหาย', 'อื่นๆ'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'หมายเหตุ', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('ตัดสินค้า')),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.analytics, color: Colors.brown), SizedBox(width: 8), Text('📊 รายงาน')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.summarize), title: Text('สรุปประจำวัน'), onTap: () {}),
            ListTile(leading: Icon(Icons.swap_horiz), title: Text('การเคลื่อนไหว'), onTap: () {}),
            ListTile(leading: Icon(Icons.assignment_return), title: Text('การส่งคืน'), onTap: () {}),
            ListTile(leading: Icon(Icons.delete), title: Text('สินค้าเสียหาย'), onTap: () {}),
            ListTile(leading: Icon(Icons.account_balance_wallet), title: Text('มูลค่าคลัง'), onTap: () {}),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('ปิด'))],
      ),
    );
  }
}
