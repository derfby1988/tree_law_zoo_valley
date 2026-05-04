# รายงานวิเคราะห์ Phase 0 และ Phase 1
## ระบบคูปองและโปรโมชัน - Tree Law Zoo Valley

**จัดทำ:** 4 พฤษภาคม 2568  
**ขอบเขต:** Phase 0 (Schema Baseline) และ Phase 1 (Coupon CRUD)

---

## สรุปผลการวิเคราะห์

| Phase | สถานะ | ความสมบูรณ์ | ปัญหาสำคัญ |
|-------|--------|------------|-----------------|
| Phase 0 | ✅ พร้อม | 95% | ต้องรัน SQL migration |
| Phase 1 | ⚠️ บางส่วน | 70% | Dialog UI มีปัญหา rendering |

---

## Phase 0: Schema และ Permission Baseline

### 1. วิเคราะห์ Database Schema

#### Fields ที่มีครบใน Model + Service + SQL Migration:

| Field | Model | Service | SQL Migration | สถานะ |
|-------|-------|---------|---------------|--------|
| `applicable_product_ids` | ✅ | ✅ | ✅ | พร้อม |
| `targeting_mode` | ✅ | ✅ | ✅ | พร้อม |
| `targeting_rule` | ✅ | ✅ | ✅ | พร้อม |
| `lifecycle_status` | ✅ | ✅ | ✅ | พร้อม |
| `usage_limit_per_customer` | ✅ | ✅ | ✅ | พร้อม |
| `usage_limit_per_day` | ✅ | ✅ | ✅ | พร้อม |
| `usage_limit_per_order` | ✅ | ✅ | ✅ | พร้อม |
| `applicable_channels` | ✅ | ✅ | ✅ | พร้อม |
| `require_in_stock` | ✅ | ✅ | ✅ | พร้อม |
| `require_sufficient_ingredients` | ✅ | ✅ | ✅ | พร้อม |
| `include_pending_procurement` | ✅ | ✅ | ✅ | พร้อม |
| ตาราง `pos_discount_codes` | N/A | ❌ | ✅ | บางส่วน |

#### สถานะ SQL Migration
- **ไฟล์:** `lib/database/coupon_promotion_phase0_schema_baseline.sql`
- **สถานะ:** สร้างแล้วแต่ยังไม่ได้รัน
- **ต้องทำ:** รัน migration บน Supabase

### 2. วิเคราะห์ระบบ Permission

| Permission Page | สถานะ | หมายเหตุ |
|-----------------|--------|-------|
| `coupon_promotion` page ID | ✅ | เพิ่มใน `_systemPages` แล้ว |
| `coupon_promotion_coupons` tab | ✅ | เพิ่มใน `_systemTabs` แล้ว |
| `coupon_promotion_promotions` tab | ✅ | เพิ่มใน `_systemTabs` แล้ว |
| `coupon_promotion_analytics` tab | ⚠️ | มีในระบบแต่ยังไม่มี UI |
| Actions (create/edit/delete) | ❌ | ยังไม่ได้กำหนดใน `_systemActions` |

**ข้อสังเกต:** โครงสร้าง permission กำหนดแล้วแต่ action-level permissions ยังไม่ถูก implement

---

## Phase 1: การ Implement Coupon CRUD

### 1. สถานะฟีเจอร์ใน Coupon Dialog

| ฟีเจอร์ | สถานะ | การ Implement | ปัญหา |
|---------|--------|----------------|-------|
| **ฟิลด์พื้นฐาน** | | | |
| ชื่อคูปอง | ✅ | TextField | ทำงานได้ |
| คำอธิบาย | ✅ | TextField | ทำงานได้ |
| ประเภทส่วนลด | ✅ | Dropdown | ทำงานได้ |
| มูลค่า | ✅ | TextField | ทำงานได้ |
| ส่วนลดสูงสุด | ✅ | TextField | ทำงานได้ |
| ยอดขั้นต่ำ | ✅ | TextField | ทำงานได้ |
| **Lifecycle** | | | |
| สถานะวงจรชีวิต | ✅ | Dropdown (ภาษาไทย) | ทำงานได้ |
| วันเริ่ม-สิ้นสุด | ✅ | DatePicker | ทำงานได้ |
| isActive sync | ✅ | Auto-sync กับ lifecycle | ทำงานได้ |
| **Usage Limits** | | | |
| จำกัดการใช้ทั้งหมด | ✅ | TextField | ทำงานได้ |
| จำกัดต่อลูกค้า | ✅ | TextField | ทำงานได้ |
| จำกัดต่อวัน | ✅ | TextField | ทำงานได้ |
| **Scope และ Targeting** | | | |
| Scope (order/category/item) | ✅ | Dropdown | ทำงานได้ |
| เลือกหมวดหมู่แบบ multi-select | ✅ | Dropdown + Chips | ทำงานได้ |
| เลือกสินค้าแบบ multi-select | ⚠️ | Dropdown + Chips | มีปัญหา layout ใน dialog |
| รหัสคูปอง | ✅ | TextField | ทำงานได้ |
| Stackable | ✅ | Switch | ทำงานได้ |
| **ขั้นสูง (Phase 0 fields)** | | | |
| Channel Targeting | ✅ | Multi-select | ทำงานได้ |
| ต้องมีสินค้าในสต็อก | ✅ | Switch | ทำงานได้ |
| ต้องมีวัตถุดิบเพียงพอ | ✅ | Switch | ทำงานได้ |
| รวมรายการจัดซื้อ | ✅ | Switch | ทำงานได้ |

### 2. ปัญหาสำคัญที่พบ

#### ปัญหาที่ #1: Dialog Rendering Crash (ความสำคัญ: สูงมาก)

**อาการ:** Dialog ค้าง จอขาว แล้วขึ้นแดงเมื่อ:
- พิมพ์ในช่องค้นหาสินค้า
- เปลี่ยนค่า dropdown
- Layout ของ dialog พังด้วย error `IntrinsicWidth`

**สาเหตุ:**
- `DropdownButtonFormField` ใช้ `IntrinsicWidth` ภายใน
- `onChanged` callbacks เรียก `setState` ระหว่าง build cycle
- AlertDialog ไม่มี `ConstrainedBox` ทำให้ layout ซ้ำไม่สิ้นสุด

**แก้ไขที่ลองแล้ว:**
```dart
// 1. เพิ่ม ConstrainedBox ห่อ AlertDialog content
content: ConstrainedBox(
  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
  child: SingleChildScrollView(...)
)

// 2. ห่อ onChanged ด้วย Future.microtask
onChanged: (v) => Future.microtask(() => ds(() => ...))
```

**สถานะ:** แก้บางส่วนแล้ว ต้องทดสอบเพิ่ม

#### ปัญหาที่ #2: Product Selector ไม่ตาม Spec (ความสำคัญ: ปานกลาง)

**ปัญหา:** การเลือกสินค้าสำหรับ scope='item' ใช้ inline search ใน dialog
**Roadmap ต้องการ:** ควรใช้หน้าเต็มจอ `PromotionProductPickerPage`
**ปัจจุบัน:** ใช้ dropdown พื้นฐานพร้อม search (ไม่ตาม roadmap)

#### ปัญหาที่ #3: ไม่มีการเช็ค Permission (ความสำคัญ: ปานกลาง)

**ข้อสังเกต:** UI ไม่เช็ค permission ก่อนแสดง actions
**ควรจะเป็น:** ใช้ helper `checkPermissionAndExecute()`
**ปัจจุบัน:** ใช้ `onPressed` ตรงๆ โดยไม่เช็ค permission

### 3. ความสอดคล้อง Model-Service-UI

#### PosDiscount Model ✅
- มีทุก field ของ Phase 0
- `fromMap()` / `toMap()` ถูกต้อง
- `isValid` getter implement ตาม logic ของ lifecycle
- `calculateDiscount()` implement แล้ว

#### PosDiscountService ✅
- `addDiscount()` มีทุก field ของ Phase 0
- `updateDiscount()` มีทุก field ของ Phase 0
- ขาด: `getDiscountByCouponCode()` (ถูกลบออกตอน rollback)
- ขาด: Methods สำหรับ usage logging (recordDiscountUsage, incrementDiscountUsage)

#### Coupon Dialog UI ⚠️
- ใช้ทุก field ของ model ถูกต้อง
- Form validation มีแต่พื้นฐาน
- Save/Edit flow ทำงานได้
- **ปัญหา:** Product search มีปัญหา rendering

---

## Gap Analysis: Roadmap กับการ Implement

### ช่องโหว่ Phase 1

| ความต้องการ | Roadmap Spec | ปัจจุบัน | ช่องโหว่ |
|-------------|--------------|---------|-----|
| Product Picker | หน้าเต็มจอ | Inline dialog search | ❌ ไม่ตาม spec |
| Lifecycle Flow | draft→scheduled→active→expired→archived | UI แสดงทุก state | ⚠️ ไม่บังคับ flow |
| Validation | กฎครอบคลุม | เช็ค field พื้นฐาน | ⚠️ ไม่สมบูรณ์ |
| Permission | Action-level checks | ยังไม่ implement | ❌ ขาดหาย |
| Usage History | ดูต่อคูปอง | ถูกลบออกตอน rollback | ❌ ไม่มี |

### ช่องโหว่ Phase 2+

| ฟีเจอร์ | สถานะ | หมายเหตุ |
|---------|--------|-------|
| POS Coupon Application | ❌ ถูกลบออก | `_applyCouponCode()` ถูกลบจาก pos_page.dart |
| Usage Logging | ❌ ถูกลบออก | `recordDiscountUsage()` ถูกลบ |
| Discount Panel Validation | ⚠️ บางส่วน | Validation พื้นฐานเท่านั้น |
| Analytics Tab | ❌ ยังไม่เริ่ม | มี placeholder UI อย่างเดียว |

---

## ข้อเสนอแนะการแก้ไข

### การดำเนินการทันที (ความสำคัญ: สูง)

1. **แก้ไข Dialog Rendering**
   - ทดสอบด้วย `flutter run` หลังแก้ไข microtask
   - ถ้ายังพัง ลองเปลี่ยน `DropdownButtonFormField` เป็น custom widget
   - ทางเลือก: ใช้ `showModalBottomSheet` แทน `AlertDialog` สำหรับ promotion dialog

2. **รัน SQL Migration**
   ```sql
   -- รันบน Supabase:
   \i lib/database/coupon_promotion_phase0_schema_baseline.sql
   ```

3. **เพิ่ม Action Permissions**
   - เพิ่มใน `user_permissions_page.dart`:
     ```dart
     {'id': 'coupon_promotion_coupons_create', 'name': 'สร้างคูปอง', 'tab_id': 'coupon_promotion_coupons', ...}
     {'id': 'coupon_promotion_coupons_edit', 'name': 'แก้ไขคูปอง', 'tab_id': 'coupon_promotion_coupons', ...}
     {'id': 'coupon_promotion_coupons_delete', 'name': 'ลบคูปอง', 'tab_id': 'coupon_promotion_coupons', ...}
     ```

### ระยะสั้น (ความสำคัญ: ปานกลาง)

4. **Implement Product Picker แบบเต็มจอ**
   - สร้าง `PromotionProductPickerPage` ตาม roadmap spec
   - รองรับ tabs: ทั้งหมด, ใกล้หมดอายุ, วัตถุดิบใกล้หมดอายุ, กำไรสูง, ตามฤดูกาล, เทศกาล, แนะนำ
   - แทนที่ inline product selector ด้วยการ navigate ไป picker

5. **คืนค่า Phase 2 Features (ถ้าต้องการ)**
   - ถ้าแก้ dialog ได้แล้ว พิจารณาคืนค่า:
     - `_applyCouponCode()` ใน POS
     - Usage history dialog
     - Discount panel validation

### ระยะยาว (ความสำคัญ: ต่ำ)

6. **Implement Analytics Tab**
   - Summary cards (usage count, total discount, sales after discount)
   - Line charts สำหรับ usage trends
   - Summary table พร้อม drill-down

---

## Checklist การทดสอบ

### การยืนยัน Phase 0
- [ ] SQL migration รันสำเร็จ
- [ ] ทุกคอลัมน์ใหม่มีใน `pos_discounts`
- [ ] Indexes ถูกสร้างแล้ว
- [ ] RLS policies active บน `pos_discount_codes`

### การยืนยัน Phase 1
- [ ] สร้างคูปองพร้อมทุก field type
- [ ] แก้ไขคูปองที่มีอยู่
- [ ] ลบคูปองพร้อม confirmation
- [ ] Lifecycle status เปลี่ยนถูกต้อง
- [ ] Category multi-select บันทึกค่า
- [ ] Product multi-select บันทึกค่า (หลังแก้ไข)
- [ ] Coupon code validation (unique check)
- [ ] Date validation (start < end)
- [ ] Scope validation (category ต้องมี 1+, item ต้องมี 1+)
- [ ] Permission checks ทำงาน

### Regression Testing
- [ ] POS page โหลดไม่มี error
- [ ] หน้าสินค้าไม่ได้รับผลกระทบ
- [ ] หน้า admin อื่นทำงานได้

---

## ไฟล์ที่แก้ไข/ตรวจสอบ

| ไฟล์ | บรรทัด | สถานะ |
|------|-------|--------|
| `lib/models/pos_discount_model.dart` | 177 | ✅ สมบูรณ์ |
| `lib/services/pos_discount_service.dart` | 307 | ⚠️ ขาดบาง methods |
| `lib/pages/coupon_promotion_admin_page.dart` | ~2000 | ⚠️ มีปัญหา rendering |
| `lib/database/coupon_promotion_phase0_schema_baseline.sql` | 201 | ✅ พร้อมรัน |

---

## สรุป

**Phase 0 (Schema):** 95% สมบูรณ์ - SQL migration พร้อม ต้องรัน
**Phase 1 (Coupon CRUD):** 70% สมบูรณ์ - Core functionality ทำงานได้แต่ dialog rendering ไม่เสถียร

**ข้อเสนอแนะ:**
1. แก้ไข dialog rendering ให้ได้ก่อน (ลำดับความสำคัญสูงสุด)
2. รัน SQL migration
3. ทดสอบ flow Phase 1 ให้ครบ
4. ค่อยไป Phase 2 (POS integration) หลัง Phase 1 เสถียรแล้ว

**ความเสี่ยง:** ปัญหา dialog rendering เกิดขึ้นหลายครั้งแม้แก้ไขแล้ว ควรพิจารณา redesign UI โดยใช้ `showModalBottomSheet` หรือหน้าใหม่แทน `AlertDialog`
