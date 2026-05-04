# คู่มือแก้ไขปัญหา Dialog Rendering Crash (ฉบับเต็ม)

## สถานะปัญหาปัจจุบัน

**ไฟล์ที่มีปัญหา:** `@/Users/apisekpanyakong/ProjectFlutter/tree_law_zoo_valley/lib/pages/coupon_promotion_admin_page.dart`  
**ฟังก์ชั่น:** `_showPromotionDialog()` (บรรทัด ~1343)

### อาการที่เกิดขึ้น
1. พิมพ์ในช่องค้นหาสินค้า → Dialog ค้าง
2. เปลี่ยนค่า Dropdown → จอขาว
3. หลังจากนั้น Error: `RenderIntrinsicWidth` / `NEEDS-LAYOUT` / Red Screen

### แก้ไขที่ลองแล้ว (แต่ยังไม่หาย)
1. ✅ เพิ่ม `ConstrainedBox` ห่อ `SingleChildScrollView` (บรรทัด 1401-1403)
2. ✅ ใช้ `Future.microtask()` ครอบ `onChanged` (บรรทัด 1421, 1454, 1487, 1588)
3. ✅ เพิ่ม `if (!mounted) return;` (บรรทัด 1353)

**ผลลัพธ์:** ยังค้างอยู่

---

## วิเคราะห์สาเหตุลึก (Root Cause Analysis)

### สาเหตุหลัก 1: DropdownButtonFormField + IntrinsicWidth

```dart
// ปัญหาเกิดจากการผสมกันของ:
// 1. DropdownButtonFormField ใช้ IntrinsicWidth ภายใน
// 2. ListView.builder ใน search results (shrinkWrap: true)
// 3. Column + SingleChildScrollView + ConstrainedBox ที่ซ้อนกัน

DropdownButtonFormField<String>(
  isExpanded: true,  // <-- นี่ทำให้เกิดปัญหาเมื่ออยู่ใน IntrinsicWidth
  ...
)
```

**ทำไม Future.microtask ไม่พอ:**
- `Future.microtask` ช่วยให้ `setState` ไม่เรียกระหว่าง build
- แต่ปัญหาคือ Flutter layout engine ต้องคำนวณ `IntrinsicWidth` ซ้ำไปซ้ำมา
- เมื่อ search results เปลี่ยน → ListView height เปลี่ยน → IntrinsicWidth ต้องคำนวณใหม่

### สาเหตุหลัก 2: Search Results Container ไม่มีขนาดคงที่

```dart
// ปัญหาที่บรรทัด 1601-1627
if (searchResults.isNotEmpty)
  Container(
    constraints: const BoxConstraints(maxHeight: 160), // มี maxHeight แต่...
    child: ListView.builder(
      shrinkWrap: true,  // <-- นี่ทำให้ height เปลี่ยนตาม content
      ...
    ),
  )
```

---

## ทางเลือกการแก้ไข

### ทางเลือก A: แก้ไขภายใน Dialog (Conservative Fix)

**เป้าหมาย:** แก้ปัญหาโดยไม่เปลี่ยนโครงสร้างใหญ่

#### ขั้นตอนที่ 1: ลบ shrinkWrap จาก ListView

```dart
// แก้ไขที่บรรทัด 1611-1626 (ใน search results)
// จาก:
ListView.builder(
  shrinkWrap: true,  // <-- ลบบรรทัดนี้
  ...
)

// เป็น:
ListView.builder(
  // shrinkWrap: true,  // <-- ลบออก ให้ใช้ constraints จาก Container แทน
  ...
)
```

#### ขั้นตอนที่ 2: แทนที่ DropdownButtonFormField ด้วย custom widget

```dart
// สร้าง CustomDropdown ที่ไม่ใช้ IntrinsicWidth
class _CustomDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;

  const _CustomDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await showModalBottomSheet<T>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items.map((item) {
                final isSelected = item.value == value;
                return ListTile(
                  selected: isSelected,
                  title: item.child,
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, item.value),
                );
              }).toList(),
            ),
          ),
        );
        if (result != null) {
          onChanged(result);
        }
      },
      child: InputDecorator(
        decoration: decoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: items.firstWhere(
                (item) => item.value == value,
                orElse: () => items.first,
              ).child!,
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
```

#### ขั้นตอนที่ 3: ใช้ custom dropdown แทน DropdownButtonFormField

```dart
// แก้ไขที่บรรทัด 1412-1429
// จาก DropdownButtonFormField เป็น:
_CustomDropdown<String>(
  value: promotionType,
  decoration: const InputDecoration(labelText: 'ประเภทโปรโมชั่น', border: OutlineInputBorder()),
  items: const [
    DropdownMenuItem(value: 'bundle', child: Text('ชุดสินค้า (Bundle)')),
    DropdownMenuItem(value: 'seasonal', child: Text('ตามฤดูกาล (Seasonal)')),
    DropdownMenuItem(value: 'buy_x_get_y', child: Text('ซื้อ X แถม Y')),
  ],
  onChanged: (v) {
    final newType = v ?? 'bundle';
    ds(() {
      promotionType = newType;
      items.clear();
      searchResults = [];
    });
  },
),
```

**ข้อดี:**
- ไม่ต้องเปลี่ยนโครงสร้างใหญ่
- แก้ปัญหา IntrinsicWidth

**ข้อเสีย:**
- ต้องแก้ไขหลายจุด (มี 3 DropdownButtonFormField ใน dialog)
- UI อาจดูต่างจากเดิมเล็กน้อย

---

### ทางเลือก B: เปลี่ยนเป็น ModalBottomSheet (Recommended)

**เป้าหมาย:** ใช้ BottomSheet แทน AlertDialog ทั้งหมด

#### ขั้นตอนที่ 1: สร้างโครงสร้างใหม่

```dart
void _showPromotionDialog({required String title, PosDiscount? existing}) {
  // ... state variables เหมือนเดิม ...

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,  // สำคัญ: ให้ใช้พื้นที่เต็ม
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,  // เริ่มที่ 90% ของหน้าจอ
      minChildSize: 0.5,      // ลงได้ต่ำสุด 50%
      maxChildSize: 0.95,     // ขึ้นได้สูงสุด 95%
      expand: false,
      builder: (context, scrollController) {
        return StatefulBuilder(
          builder: (context, ds) {
            // ... เนื้อหาเดิมทั้งหมด ...
            
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Content (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ... เนื้อหาเดิมทั้งหมด ...
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Footer (actions)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ยกเลิก'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // ... save logic ...
                            },
                            child: Text(existing == null ? 'เพิ่ม' : 'บันทึก'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
```

**ข้อดี:**
- ไม่มีปัญหา AlertDialog + IntrinsicWidth
- UX ที่ดีกว่าบน mobile/tablet (เลื่อนลงปิดได้)
- มีพื้นที่ใช้งานมากขึ้น

**ข้อเสีย:**
- ต้องแก้ไขโครงสร้างใหญ่
- ต้อง test ใหม่ทั้งหมด

---

### ทางเลือก C: แยกเป็นหน้าใหม่ (Best Practice ตาม Roadmap)

**เป้าหมาย:** ตาม roadmap ต้นฉบับที่ออกแบบไว้

#### ขั้นตอนที่ 1: สร้างไฟล์ใหม่ `lib/pages/promotion_form_page.dart`

```dart
import 'package:flutter/material.dart';
import '../models/pos_discount_model.dart';
import '../services/pos_discount_service.dart';

class PromotionFormPage extends StatefulWidget {
  final String? promotionId; // null = create, มีค่า = edit

  const PromotionFormPage({super.key, this.promotionId});

  @override
  State<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends State<PromotionFormPage> {
  // ... state variables เหมือนใน dialog ...
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    // โหลด promotion ถ้าเป็น edit mode
    // โหลด products, discounts, user groups
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promotionId == null ? 'เพิ่มโปรโมชั่น' : 'แก้ไขโปรโมชั่น'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('บันทึก'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... เนื้อหาเดิมทั้งหมด ...
          ],
        ),
      ),
    );
  }
  
  Future<void> _save() async {
    // ... save logic ...
  }
}
```

#### ขั้นตอนที่ 2: แก้ไข `_showPromotionDialog` ให้ navigate แทน

```dart
void _showPromotionDialog({required String title, PosDiscount? existing}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PromotionFormPage(
        promotionId: existing?.id,
      ),
    ),
  ).then((result) {
    if (result == true) {
      _loadData(); // reload หลังจากบันทึกสำเร็จ
    }
  });
}
```

**ข้อดี:**
- ตาม roadmap ต้นฉบับ
- มีพื้นที่ใช้งานเต็มที่
- ไม่มีปัญหา dialog rendering
- รองรับการเพิ่มฟีเจอร์ในอนาคตได้ดี

**ข้อเสีย:**
- ต้องสร้างไฟล์ใหม่
- ต้องย้ายโค้ดเยอะ

---

## แนวทางการตัดสินใจ

### ถ้าต้องการแก้เร็วที่สุด (Quick Fix)
**เลือก ทางเลือก A** - แก้ shrinkWrap + Custom Dropdown
- เวลา: ~30 นาที
- ความเสี่ยง: ต่ำ

### ถ้าต้องการ UX ที่ดีกว่า (Recommended)
**เลือก ทางเลือก B** - ModalBottomSheet
- เวลา: ~1-2 ชั่วโมง
- ความเสี่ยง: ปานกลาง

### ถ้าต้องการตาม Roadmap เป๊ะ (Best Practice)
**เลือก ทางเลือก C** - แยกหน้าใหม่
- เวลา: ~2-3 ชั่วโมง
- ความเสี่ยง: ต้อง test ใหม่ทั้งหมด

---

## Code Reference สำหรับการแก้ไข

### จุดที่ต้องแก้ในไฟล์ปัจจุบัน

| บรรทัด | โค้ดปัจจุบัน | สถานะ |
|--------|-------------|-------|
| 1412-1429 | DropdownButtonFormField (promotionType) | ต้องแก้ |
| 1432-1454 | DropdownButtonFormField (discount) | ต้องแก้ |
| 1457-1503 | DropdownButtonFormField (user groups) | ต้องแก้ |
| 1580-1589 | TextField search (onChanged) | อาจไม่ต้องแก้ |
| 1611 | ListView.builder shrinkWrap | ควรลบ |

---

## ขั้นตอนทดสอบหลังแก้ไข

1. เปิดหน้า Coupon & Promotion
2. กด "เพิ่มโปรโมชั่น"
3. พิมพ์ในช่อง "ค้นหาสินค้าจากคลัง" อย่างรวดเร็ว 5-10 ตัวอักษร
4. เปลี่ยนค่า "ประเภทโปรโมชั่น" หลายครั้ง
5. เลือกสินค้าจากผลการค้นหา
6. กด "เพิ่ม" เพื่อบันทึก

**ผลที่คาดหวัง:**
- ไม่มีจอขาว/แดง
- ไม่มี error ใน console
- บันทึกข้อมูลได้ปกติ
