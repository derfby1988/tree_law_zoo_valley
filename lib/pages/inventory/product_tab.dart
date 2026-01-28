import 'package:flutter/material.dart';

class ProductTab extends StatefulWidget {
  const ProductTab({super.key});

  @override
  State<ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'ทั้งหมด';
  String _selectedShelf = 'ทั้งหมด';

  final products = [
    {'name': 'แฮมเบอร์เกอร์', 'qty': '98', 'shelf': 'A1', 'status': 'พร้อม', 'unit': 'ชิ้น', 'price': '120'},
    {'name': 'โคคา-โคลา', 'qty': '45', 'shelf': 'B1', 'status': 'พร้อม', 'unit': 'ขวด', 'price': '45'},
    {'name': 'เค้กช็อกโกแลต', 'qty': '8', 'shelf': 'A2', 'status': 'ใกล้หมด', 'unit': 'ชิ้น', 'price': '85'},
    {'name': 'ไอศกรีมวานิลา', 'qty': '5', 'shelf': 'B2', 'status': 'ใกล้หมด', 'unit': 'ชิ้น', 'price': '60'},
    {'name': 'ขนมปังสด', 'qty': '0', 'shelf': 'C3', 'status': 'หมด', 'unit': 'ถุง', 'price': '25'},
    {'name': 'นมสด', 'qty': '10', 'shelf': 'D1', 'status': 'พร้อม', 'unit': 'ขวด', 'price': '35'},
    {'name': 'เนื้อสด', 'qty': '5', 'shelf': 'D2', 'status': 'ใกล้หมด', 'unit': 'กก.', 'price': '350'},
    {'name': 'ผักสด', 'qty': '8', 'shelf': 'E1', 'status': 'ใกล้หมด', 'unit': 'กก.', 'price': '80'},
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
          _buildProductList(),
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
            Text('🎯 จัดการข้อมูลสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton('📂 ประเภท', Colors.blue, () => _showCategoryDialog()),
                _buildActionButton('⚖️ หน่วยนับ', Colors.teal, () => _showUnitDialog()),
                _buildActionButton('💰 ราคาขาย', Colors.green, () => _showPriceDialog()),
                _buildActionButton('📋 รายงาน', Colors.purple, () => _showReportDialog()),
                _buildActionButton('➕ เพิ่มสินค้า', Colors.orange, () => _showAddProductDialog()),
                _buildActionButton('🧹 เคลียร์วัตถุดิบ', Colors.red, () => _showClearMaterialDialog()),
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

  Widget _buildProductList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋 รายการสินค้า (${products.length} รายการ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            ...products.map((product) => _buildProductItem(product)).toList(),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () {}, icon: Icon(Icons.chevron_left)),
                Text('หน้า 1 จาก 16'),
                IconButton(onPressed: () {}, icon: Icon(Icons.chevron_right)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(Map<String, String> product) {
    Color statusColor = product['status'] == 'พร้อม' ? Colors.green : product['status'] == 'ใกล้หมด' ? Colors.orange : Colors.red;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name']!, style: TextStyle(fontWeight: FontWeight.w500)),
                Text('฿${product['price']}/${product['unit']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Expanded(child: Text('${product['qty']}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(child: Text(product['shelf']!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center)),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          SizedBox(width: 8),
          IconButton(icon: Icon(Icons.edit, size: 20), onPressed: () => _showEditProductDialog(product), padding: EdgeInsets.zero, constraints: BoxConstraints()),
        ],
      ),
    );
  }

  // Dialogs
  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.folder, color: Colors.blue), SizedBox(width: 8), Text('📂 จัดการประเภท')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('🍔 อาหาร'), trailing: Text('45 รายการ')),
            ListTile(title: Text('🥤 เครื่องดื่ม'), trailing: Text('28 รายการ')),
            ListTile(title: Text('🍰 ของหวาน'), trailing: Text('18 รายการ')),
            Divider(),
            TextField(decoration: InputDecoration(labelText: 'เพิ่มประเภทใหม่', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ปิด')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showUnitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.scale, color: Colors.teal), SizedBox(width: 8), Text('⚖️ จัดการหน่วยนับ')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('📦 ชิ้น'), trailing: Text('45 รายการ')),
            ListTile(title: Text('🍾 ขวด'), trailing: Text('28 รายการ')),
            ListTile(title: Text('🥄 กิโลกรัม'), trailing: Text('12 รายการ')),
            Divider(),
            TextField(decoration: InputDecoration(labelText: 'เพิ่มหน่วยใหม่', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ปิด')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showPriceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.attach_money, color: Colors.green), SizedBox(width: 8), Text('💰 จัดการราคาขาย')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'เลือกสินค้า', border: OutlineInputBorder()),
              items: products.map((e) => DropdownMenuItem(value: e['name'], child: Text(e['name']!))).toList(),
              onChanged: (value) {},
            ),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'ราคาขาย (฿)', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'ต้นทุน (฿)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.analytics, color: Colors.purple), SizedBox(width: 8), Text('📋 รายงานสินค้า')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.list), title: Text('รายการสินค้า'), onTap: () {}),
            ListTile(leading: Icon(Icons.attach_money), title: Text('ราคาขาย'), onTap: () {}),
            ListTile(leading: Icon(Icons.trending_down), title: Text('สต็อกต่ำ'), onTap: () {}),
            ListTile(leading: Icon(Icons.error), title: Text('สินค้าหมด'), onTap: () {}),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('ปิด'))],
      ),
    );
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.add_circle, color: Colors.orange), SizedBox(width: 8), Text('➕ เพิ่มสินค้าใหม่')]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: 'ชื่อสินค้า', border: OutlineInputBorder())),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'ประเภท', border: OutlineInputBorder()),
                items: ['อาหาร', 'เครื่องดื่ม', 'ของหวาน'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) {},
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'ราคาขาย', border: OutlineInputBorder()))),
                  SizedBox(width: 12),
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'ชั้นวาง', border: OutlineInputBorder()))),
                ],
              ),
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

  void _showClearMaterialDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.cleaning_services, color: Colors.red), SizedBox(width: 8), Text('🧹 เคลียร์วัตถุดิบ')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('รายการวัตถุดิบที่ต้องเคลียร์'),
            ),
            SizedBox(height: 12),
            ListTile(title: Text('🥛 นมสด'), subtitle: Text('10 ขวด - หมดอายุใน 2 วัน')),
            ListTile(title: Text('🥩 เนื้อสด'), subtitle: Text('5 กก. - หมดอายุใน 3 วัน')),
            Divider(),
            TextField(decoration: InputDecoration(labelText: 'จำนวนที่เคลียร์', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('เคลียร์')),
        ],
      ),
    );
  }

  void _showEditProductDialog(Map<String, String> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('📝 แก้ไขสินค้า')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'ชื่อสินค้า', border: OutlineInputBorder()), controller: TextEditingController(text: product['name'])),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(decoration: InputDecoration(labelText: 'จำนวน', border: OutlineInputBorder()), controller: TextEditingController(text: product['qty']))),
                SizedBox(width: 12),
                Expanded(child: TextField(decoration: InputDecoration(labelText: 'ราคา', border: OutlineInputBorder()), controller: TextEditingController(text: product['price']))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('บันทึก')),
        ],
      ),
    );
  }
}
