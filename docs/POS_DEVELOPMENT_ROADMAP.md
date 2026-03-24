# POS Development Roadmap for Tree Law Zoo Valley

เอกสารนี้ใช้เป็นทั้ง **แผนพัฒนา**, **checklist การออกแบบ UX/UI**, และ **แนวทางออกแบบฐานข้อมูล** สำหรับระบบ POS ของ Tree Law Zoo Valley

## 1) เป้าหมายของระบบ

ระบบ POS ที่เหมาะกับแพลตฟอร์มนี้ควรตอบโจทย์ 5 เรื่องพร้อมกัน:

- **เร็ว** - ค้นหาและเพิ่มสินค้าได้ในไม่กี่คลิก
- **ชัด** - เห็นยอด, ภาษี, ค่าบริการ, ส่วนลด และยอดสุทธิแบบไม่ต้องเดา
- **ยืดหยุ่น** - รองรับขายหน้าร้าน, ฝากโต๊ะ, takeaway, delivery, และ split payment
- **ตรวจสอบได้** - มีประวัติออเดอร์, void/refund, audit log, และสต็อกที่ตามรอยได้
- **เหมาะกับบริบทสวนสัตว์/คาเฟ่** - ลูกค้าอาจสั่งอาหาร, เครื่องดื่ม, ของที่ระลึก, และมีหลายจุดขาย

## 2) วิเคราะห์ UX/UI Flow ปัจจุบัน

### จุดแข็ง

- **Layout แบ่งโซนชัดเจน**
  - ซ้ายเป็นหมวดหมู่
  - กลางเป็นสินค้า
  - ล่างเป็นตะกร้า
  - ขวาเป็นการชำระเงิน
- **เหมาะกับหน้าจอ POS ขนาดใหญ่**
  - ดูข้อมูลพร้อมกันได้หลายส่วน
  - ใช้สี accent เดียวช่วยย้ำจุดสำคัญ
- **การคำนวณอัตโนมัติ**
  - subtotal, tax, service, net total พร้อมแยกแสดง

### ช่องว่าง UX/UI ที่ควรปรับ

- **ยังไม่มีสถานะคำสั่งซื้อชัดเจน**
  - ไม่เห็นว่าออเดอร์เป็น draft, holding, paid, voided, refunded
- **ยังไม่รองรับ workflow คีย์สำคัญของ POS จริง**
  - เปิดบิลค้างไว้
  - ย้ายโต๊ะ
  - แยกบิล
  - ลดราคาเฉพาะรายการ
  - เลือก order type ตั้งแต่ต้น
- **ตะกร้ายังดูเป็นรายการเชิงเทคนิคมากกว่าเป็น flow การขาย**
  - ยังขาด subtotal by category/discount summary
  - ยังขาด note ระดับรายการและระดับบิล
- **การชำระเงินยังเป็นปุ่ม method-based**
  - เหมาะสำหรับ flow ง่าย แต่ยังไม่พอสำหรับ split payment, partial payment, mixed payment
- **ยังขาดฟีดแบ็กเชิงสถานะ**
  - สินค้าหมด
  - ตะกร้าเกิน stock
  - ออเดอร์ถูกยืนยันสำเร็จแล้ว
  - การพิมพ์ใบเสร็จล้มเหลว

## 3) UX/UI Flow ที่ควรมีสำหรับ Tree Law Zoo Valley

### 3.1 Flow หลัก: ขายหน้าร้าน

1. เลือก **ประเภทการขาย**
   - ทานที่ร้าน
   - กลับบ้าน
   - เดลิเวอรี
   - บริจาค/สวัสดิการพนักงาน (ถ้ามีใช้จริง)

2. เลือก **ลูกค้า/โต๊ะ/บิล**
   - เดินเข้ามาใหม่ = สร้างบิลใหม่
   - มีโต๊ะ = ผูกโต๊ะ
   - มีลูกค้าสมาชิก = ผูกโปรไฟล์ลูกค้า

3. เลือกสินค้า
   - หมวดหมู่ด้านซ้าย
   - ค้นหาด้วยชื่อ/บาร์โค้ด
   - มี quick add สำหรับสินค้าขายดี

4. ตรวจสอบตะกร้า
   - เพิ่ม/ลดจำนวน
   - ใส่ note รายการ
   - แก้ไขส่วนลดเฉพาะบิลหรือเฉพาะรายการ

5. ชำระเงิน
   - cash / card / transfer / QR / split payment
   - ตรวจยอดค้างชำระก่อนยืนยัน

6. ปิดงาน
   - พิมพ์ใบเสร็จ
   - บันทึกสต็อก
   - บันทึก audit log

### 3.2 Flow ที่ควรเพิ่ม

- **Hold order** - ฝากบิลไว้ก่อน
- **Resume order** - กลับมาเปิดบิลเดิม
- **Void / Refund** - ต้องมีเหตุผลและสิทธิ์กำกับ
- **Move table** - เปลี่ยนโต๊ะโดยไม่ต้องสร้างออเดอร์ใหม่
- **Split item / split bill** - แบ่งรายการหรือแบ่งยอดออกเป็นหลายส่วน

## 4) ข้อเสนอ UX/UI ที่เหมาะกับ Tree Law Zoo Valley

### 4.1 หน้าจอควรเปลี่ยนจาก 5 โซนเป็น 6 บล็อกเชิงการทำงาน

- **Context Bar**
  - ประเภทการขาย
  - โต๊ะ
  - ลูกค้า
  - พนักงาน
  - สถานะบิล

- **Category Rail**
  - หมวดสินค้า
  - รายการโปรด
  - สินค้าขายดี

- **Product Browser**
  - ค้นหา
  - สแกนบาร์โค้ด
  - quick add
  - badge แจ้ง stock/หมด

- **Cart & Adjustments**
  - รายการสินค้า
  - note
  - ส่วนลด
  - ภาษี
  - ค่าบริการ

- **Payment Panel**
  - เลือกวิธีจ่าย
  - split payment
  - refund/void actions

- **Action Footer**
  - hold order
  - save draft
  - print receipt
  - finalize order

### 4.2 UX Pattern ที่ควรเพิ่ม

- **Quick Search ที่เด่นกว่าเดิม**
  - รองรับพิมพ์ชื่อสินค้า, barcode, SKU

- **สินค้าแนะนำตามสถานการณ์**
  - เช้า: เครื่องดื่ม/เบเกอรี่
  - เที่ยง: อาหารหลัก
  - เด็ก/ครอบครัว: combo/เมนูยอดนิยม

- **สถานะสีที่สอดคล้องกัน**
  - เขียว = พร้อมขาย/ชำระแล้ว
  - เหลือง = ต้องตรวจสอบ
  - แดง = หมด/ผิดพลาด/void

- **Empty state ที่มีการนำทางต่อ**
  - ไม่มีสินค้า -> แนะนำค้นหา/เลือกหมวด
  - ตะกร้าว่าง -> call to action ที่ชัด

## 5) โครงสร้างข้อมูลที่ควรมีจริง

### 5.1 ตารางหลักสำหรับ POS

#### `pos_orders`
เก็บหัวบิลทุกใบ

ควรมีฟิลด์สำคัญ:
- `order_number`
- `order_type` (`dine_in`, `takeaway`, `delivery`)
- `status` (`draft`, `held`, `pending_payment`, `paid`, `voided`, `refunded`, `partially_refunded`)
- `table_id`
- `customer_id`
- `cashier_id`
- `subtotal`
- `discount_total`
- `tax_total`
- `service_total`
- `grand_total`
- `paid_total`
- `balance_due`
- `notes`
- `opened_at`, `closed_at`

#### `pos_order_items`
เก็บรายการสินค้าแต่ละบิล

ควรมีฟิลด์สำคัญ:
- `order_id`
- `product_id`
- `product_name_snapshot`
- `unit_price_snapshot`
- `quantity`
- `line_discount`
- `tax_rate_snapshot`
- `service_rate_snapshot`
- `tax_exempt`
- `item_note`
- `line_total`

#### `pos_payments`
เก็บการจ่ายเงินจริงทุกครั้ง

ควรมีฟิลด์สำคัญ:
- `order_id`
- `payment_method`
- `amount`
- `reference_number`
- `paid_at`
- `status`
- `received_by`

#### `pos_discounts`
ส่วนลดระดับบิล/รายการ

ควรมีฟิลด์สำคัญ:
- `discount_type`
- `scope` (`order`, `item`, `category`)
- `value`
- `max_discount`
- `min_amount`
- `stackable`
- `start_at`, `end_at`
- `is_active`

#### `pos_order_discounts`
เชื่อมว่าบิลนี้ใช้ส่วนลดอะไรบ้าง

#### `pos_taxes`
เก็บนโยบายภาษีที่ระบบใช้จริง

ควรมีฟิลด์สำคัญ:
- `name`
- `rate`
- `is_inclusive`
- `applies_to`
- `is_exempt`
- `jurisdiction`

#### `pos_service_charges`
เก็บ service charge และกติกาการคิด

#### `pos_tables`
ถ้ามีโต๊ะ ต้องแยกตารางนี้ออกมา

ควรมีฟิลด์สำคัญ:
- `table_code`
- `zone`
- `status`
- `capacity`
- `current_order_id`

#### `pos_customers`
โปรไฟล์ลูกค้าและสมาชิก

#### `pos_order_status_logs`
audit trail ของสถานะบิล

#### `pos_void_refunds`
บันทึกการ void/refund พร้อมเหตุผลและผู้อนุมัติ

#### `pos_shift_sessions`
รอบกะของแคชเชียร์

#### `pos_register_cash_drawers`
เงินสดเข้าออกของเครื่องแคชเชียร์แต่ละเครื่อง

#### `pos_printer_profiles`
การตั้งค่าเครื่องพิมพ์ต่อจุดขาย

#### `pos_audit_logs`
บันทึกการเปลี่ยนแปลงทุก action สำคัญ

### 5.2 ตารางเสริมสำหรับแพลตฟอร์ม Tree Law Zoo Valley

- **`pos_menu_groups`** - แบ่งเมนูตามช่วงเวลา/ธีม
- **`pos_bundle_promotions`** - ชุดโปรโมชั่น เช่น เมนูคู่, เซ็ตครอบครัว
- **`pos_loyalty_wallets`** - สะสมแต้ม/เครดิตสมาชิก
- **`pos_store_settings`** - ค่าระบบระดับสาขา
- **`pos_device_sessions`** - เครื่อง POS เครื่องไหนเปิดใช้
- **`pos_inventory_reservations`** - กันสต็อกเมื่อเปิดบิลค้างไว้

## 6) Schema ที่แนะนำให้ปรับจากของเดิม

### ของเดิมที่ควรขยาย

- `pos_orders`
  - ตอนนี้ควรรองรับหลายสถานะ ไม่ใช่แค่ completed
- `pos_order_lines`
  - ควรเก็บ snapshot ของราคา, ภาษี, หน่วย, note
- `inventory_products`
  - ควรแยก quantity ที่ขายได้จริงกับ quantity ที่ reserve ไว้
- `inventory_adjustments`
  - ควรมี reference type ที่ชัดว่ามาจาก sale, refund, void, transfer

### ความสัมพันธ์ที่ควรมี

- 1 order -> หลาย items
- 1 order -> หลาย payments
- 1 order -> หลาย discounts
- 1 order -> หลาย status logs
- 1 shift -> หลาย orders
- 1 customer -> หลาย orders
- 1 table -> 1 current active order ได้ในช่วงเวลาเดียว

## 7) สิ่งที่ขาดใน code flow ปัจจุบัน

### ฝั่ง UI

- **ไม่มี order drawer / order summary ที่เป็น stateful จริง**
- **ยังไม่มีปุ่ม Hold / Resume**
- **ยังไม่มี customer picker**
- **ยังไม่มี split payment modal**
- **ยังไม่มี receipt preview**
- **ยังไม่มี low-stock badge บนสินค้า**

### ฝั่ง logic

- **ยังคำนวณ tax/service แบบรวม**
  - ควรคำนวณระดับ line item เพื่อ audit ได้
- **ยังไม่มี payment state machine**
  - pending -> partial -> paid
- **ยังไม่มี refund flow**
  - refund ควรเป็น transaction ใหม่ ไม่ใช่แค่ลบรายการ
- **ยังไม่มี shift control**
  - POS จริงต้องรู้ว่าใครเปิดเครื่องกะไหน

## 8) Roadmap ใหม่ที่แนะนำสำหรับ Tree Law Zoo Valley

### Phase 1 - Core POS Stability

1. **Order Context Layer**
   - order type
   - table
   - customer
   - cashier

2. **Cart & Pricing Engine**
   - line-item tax
   - line-item discount
   - service charge
   - grand total

3. **Payment State Flow**
   - full payment
   - partial payment
   - split payment
   - payment validation

4. **Hold / Resume Order**
   - ฝากบิล
   - เรียกบิลกลับ

### Phase 2 - Business Completeness

5. **Customer & Loyalty**
   - สมาชิก
   - แต้ม
   - ประวัติการซื้อ

6. **Discount & Promotion Engine**
   - ส่วนลดระดับบิล
   - ส่วนลดระดับรายการ
   - โปรโมชั่น bundle/seasonal

7. **Receipt & Printing**
   - preview
   - printer profile
   - reprint

### Phase 3 - Operation Control

8. **Shift / Cash Drawer**
   - เปิดกะ
   - ปิดกะ
   - เงินสดยกมา
   - เงินสดออก

9. **Void / Refund / Audit**
   - เหตุผล
   - ผู้อนุมัติ
   - log ทุก action

10. **Inventory Sync**
    - reserve stock
    - decrement on paid
    - return on refund

### Phase 4 - Growth & Insights

11. **Reports & Analytics**
    - ยอดขายตามช่วงเวลา
    - เมนูขายดี
    - ช่องทางชำระ
    - performance พนักงาน

12. **Multi-device / Multi-store Ready**
    - session ต่อ device
    - config ต่อสาขา
    - sync และ conflict handling

## 9) สิ่งที่ควรลงมือทำก่อนที่สุด

1. **เพิ่ม order context และสถานะบิล**
2. **แยก order item / payment / discount ออกจาก order header**
3. **เพิ่ม hold/resume และ partial payment**
4. **เพิ่ม customer/table integration**
5. **เพิ่ม shift session และ audit log**
6. **เพิ่ม refund/void ที่ตรวจสอบได้**

## 10) วิธีใช้เอกสารนี้ต่อ

- ใช้เป็น **checklist ออกแบบ UX/UI** ก่อนลงมือเขียนโค้ด
- ใช้เป็น **checklist ฐานข้อมูล** ก่อนเพิ่ม migration
- ใช้เป็น **ลำดับการพัฒนา** เพื่อไม่ให้ POS โตแบบไร้โครงสร้าง
- ใช้เป็น **บันทึกความจำ** ว่าระบบนี้ต้องพร้อมใช้งานจริงสำหรับ Tree Law Zoo Valley

## 11) วิเคราะห์ `lib/pages/pos_page.dart` แบบลงลึกทีละฟังก์ชัน

เอกสารส่วนนี้จับคู่ฟังก์ชันจริงใน `pos_page.dart` กับ roadmap เพื่อใช้เป็นแนวทาง refactor ทีละขั้น โดยเรียงจากฟังก์ชันพื้นฐาน → ฟังก์ชันคำนวณ → ฟังก์ชัน UX → ฟังก์ชัน checkout

### 11.1 โครงสร้าง state และ lifecycle

- `initState()`
  - หน้าที่ปัจจุบัน: ผูก focus listener และเริ่มโหลดข้อมูล
  - สิ่งที่ดี: ทำให้หน้า POS พร้อมใช้งานทันทีเมื่อเปิดหน้า
  - สิ่งที่ยังขาด: state ของ error, retry, empty state, staged loading
  - roadmap ที่เกี่ยวข้อง: Phase 1 - Product Browser, Order Context Layer
  - refactor path: ย้ายการโหลดข้อมูลออกจากหน้าไปยัง controller/repository และเพิ่ม state model แบบ `loading / loaded / empty / error`

- `dispose()`
  - หน้าที่ปัจจุบัน: ปล่อย controller และ focus node
  - สิ่งที่ดี: cleanup ถูกต้อง
  - สิ่งที่ยังขาด: ถ้าเพิ่ม payment/customer/table controller ต้องรวม cleanup ให้ครบ
  - roadmap ที่เกี่ยวข้อง: ทุก phase ที่มี controller เพิ่ม
  - refactor path: สร้าง lifecycle เดียวสำหรับ POS state ทั้งหมด

### 11.2 Helper ด้าน UI

- `_gradientIcon()` และ `_gradientText()`
  - หน้าที่ปัจจุบัน: สร้าง visual identity แบบ gradient
  - สิ่งที่ดี: ทำให้ POS ดูเป็นระบบเดียวกัน
  - สิ่งที่ยังขาด: ยังเป็น helper ภายในไฟล์ ไม่สามารถ reuse ได้ง่าย
  - roadmap ที่เกี่ยวข้อง: UX/UI consistency, design system
  - refactor path: ย้ายเป็น shared widgets เช่น `AppGradientIcon`, `AppGradientText`

- `_focusSearchField()`
  - หน้าที่ปัจจุบัน: request focus ไปที่ช่องค้นหา
  - สิ่งที่ดี: ลด friction สำหรับแคชเชียร์
  - สิ่งที่ยังขาด: ยังไม่รองรับ barcode/SKU scan flow
  - roadmap ที่เกี่ยวข้อง: Product Browser, Barcode flow
  - refactor path: ให้ controller เดียวดูแล search modes หลายแบบ

### 11.3 Data loading และ catalog flow

- `_loadData()`
  - หน้าที่ปัจจุบัน: โหลด products และ categories พร้อมกันจาก `InventoryService`
  - สิ่งที่ดี: เรียบง่ายและตรงจุด
  - สิ่งที่ยังขาด: error handling, retry, cache, pagination, skeleton loading
  - roadmap ที่เกี่ยวข้อง: Product Browser, Performance Optimization, Inventory Sync
  - refactor path: แยกเป็น `PosCatalogRepository` + staged loading (`categories` → `products` → `tax rules`)

- `_filteredProducts`
  - หน้าที่ปัจจุบัน: filter ตาม category และ search query
  - สิ่งที่ดี: เป็นแกนของ browsing flow
  - สิ่งที่ยังขาด: barcode, quick filter, favorites, hot items, low-stock badges
  - roadmap ที่เกี่ยวข้อง: Product Browser, Quick Search, Barcode flow
  - refactor path: ย้าย logic ไป view model / provider เพื่อรองรับ filter mode หลายแบบ

- `_getCategoryIcon(name)`
  - หน้าที่ปัจจุบัน: map ชื่อหมวดเป็น icon
  - สิ่งที่ดี: ช่วยให้ category rail อ่านง่าย
  - สิ่งที่ยังขาด: hardcoded text matching ทำให้เปลี่ยนชื่อหมวดแล้ว icon เพี้ยน
  - roadmap ที่เกี่ยวข้อง: Category UX, Menu grouping
  - refactor path: เก็บ icon metadata ใน database หรือ config ของ category

### 11.4 Cart และ pricing engine

- `_addToCart(product)`
  - หน้าที่ปัจจุบัน: resolve tax rule, cache rule ต่อหมวด, เพิ่มสินค้าเข้า cart หรือเพิ่ม qty
  - สิ่งที่ดี: มี tax rule cache และรองรับ repeat item
  - สิ่งที่ยังขาด: line snapshot, stock validation, discount per item, note per item, order context, immutability
  - roadmap ที่เกี่ยวข้อง: Cart & Pricing Engine, Tax Policy, Discount Management, Inventory Reservation
  - refactor path: สร้าง `PosCartItem` model แยกจาก product, เก็บ snapshot ของ name/price/tax/unit/category, และอย่า mutate `product` ตรง ๆ

- `_removeFromCart(index)`
  - หน้าที่ปัจจุบัน: ลบรายการด้วย index
  - สิ่งที่ดี: เข้าใจง่าย
  - สิ่งที่ยังขาด: ใช้ index ทำให้ brittle เมื่อรายการเปลี่ยนลำดับ
  - roadmap ที่เกี่ยวข้อง: Cart Management, Hold/Resume support
  - refactor path: ลบด้วย `cartLineId` แทน index และเตรียม undo ได้ในอนาคต

- `_updateQty(index, delta)`
  - หน้าที่ปัจจุบัน: เพิ่ม/ลดจำนวน และลบถ้า qty <= 0
  - สิ่งที่ดี: เหมาะกับ POS ที่ต้องเร็ว
  - สิ่งที่ยังขาด: max/min rule, stock guard, split item support
  - roadmap ที่เกี่ยวข้อง: Cart & Pricing Engine, Inventory Sync, Split bill
  - refactor path: validate ก่อนเปลี่ยน qty และให้รู้ source ของข้อจำกัดจาก inventory

- `_subtotal`, `_discount`, `_preTaxTotal`, `_taxAmount`, `_avgTaxRate`, `_serviceAmount`, `_netTotal`
  - หน้าที่ปัจจุบัน: รวมยอดเงินและภาษีแบบภาพรวม
  - สิ่งที่ดี: แยกยอดสำคัญได้ชัดเจน
  - สิ่งที่ยังขาด: line-level discount, inclusive/exclusive tax model, paid/balance due, service policy ตามสาขา
  - roadmap ที่เกี่ยวข้อง: Cart & Pricing Engine, Discount Engine, Tax Policy, Service Charge Engine, Payment State Flow
  - refactor path: ย้ายการคำนวณไป `PosPricingService` และสร้าง `PosOrderSummary` ที่มี `subtotal`, `discountTotal`, `taxTotal`, `serviceTotal`, `grandTotal`, `paidTotal`, `balanceDue`

### 11.5 Layout และ navigation

- `build(context)`
  - หน้าที่ปัจจุบัน: สร้าง scaffold หลัก แบ่งพื้นที่เป็น sidebar + main panels
  - สิ่งที่ดี: เหมาะกับหน้าจอ POS ขนาดใหญ่
  - สิ่งที่ยังขาด: error state, order context bar, responsive breakpoints, action footer
  - roadmap ที่เกี่ยวข้อง: Whole POS layout refactor, Order Context Layer
  - refactor path: แตก UI เป็น panel ย่อยตามงานจริง แล้วให้แต่ละ panel รับ state ที่จำเป็นเท่านั้น

- `_buildLeftIconBar()` และ `_buildSidebarIcon()`
  - หน้าที่ปัจจุบัน: สร้างหมวดหมู่ด้านซ้ายและปุ่มเลือก
  - สิ่งที่ดี: compact, touch-friendly, มี tooltip
  - สิ่งที่ยังขาด: badge จำนวนสินค้า, favorites, pinned categories, แยกหมวดสำหรับขายกับหมวด admin
  - roadmap ที่เกี่ยวข้อง: Category Rail, Menu grouping
  - refactor path: เพิ่ม metadata ต่อหมวดและแยก data source ระหว่าง sellable categories กับ all categories

- `_buildHeader()` และ `_headerChip()`
  - หน้าที่ปัจจุบัน: แสดง store, โต๊ะ placeholder, user, date, time, back button
  - สิ่งที่ดี: เป็น context bar ขั้นต้น
  - สิ่งที่ยังขาด: order type, customer, actual table, order status, shift status
  - roadmap ที่เกี่ยวข้อง: Order Context Layer
  - refactor path: เปลี่ยน header ให้เป็น stateful context bar ที่สะท้อนสภาพบิลจริง

- `_buildTopAndMiddleRow()`
  - หน้าที่ปัจจุบัน: จัด layout zone 1–4 แบบ 7:3
  - สิ่งที่ดี: โครงสร้างชัดสำหรับ POS จอใหญ่
  - สิ่งที่ยังขาด: ยัง rigid เมื่อจะเพิ่ม hold queue, order drawer, customer panel
  - roadmap ที่เกี่ยวข้อง: Layout redesign
  - refactor path: แตกเป็น panel widgets และทำ breakpoint-based layout

### 11.6 Summary cards และ payment zone

- `_buildZone1()`
  - หน้าที่ปัจจุบัน: แสดง pre-tax total, discount row, subtotal
  - สิ่งที่ดี: สื่อยอดหลักก่อนคิดภาษีชัดเจน
  - สิ่งที่ยังขาด: discount จริง, breakdown ระดับรายการ
  - roadmap ที่เกี่ยวข้อง: Discount Management, Order Summary
  - refactor path: เปลี่ยนเป็น `OrderSummaryCard` ที่ดึงข้อมูลจาก pricing engine

- `_discountRow()` และ `_infoRow()`
  - หน้าที่ปัจจุบัน: helper สำหรับแสดงบรรทัดยอดเงิน
  - refactor path: รวมกับ money formatter และ summary component กลาง

- `_buildZone2()`
  - หน้าที่ปัจจุบัน: แสดง net total, tax, service
  - สิ่งที่ดี: ยอดสุทธิเด่นและอ่านง่าย
  - สิ่งที่ยังขาด: paid total และ balance due
  - roadmap ที่เกี่ยวข้อง: Payment State Flow, Settlement UI
  - refactor path: แสดงยอดที่ต้องชำระจริงและยอดคงเหลือร่วมด้วย

- `_buildZone3()` และ `_paymentButton()`
  - หน้าที่ปัจจุบัน: แสดงวิธีชำระเงินและเปิด dialog ยืนยัน
  - สิ่งที่ดี: เข้าใจง่ายสำหรับ flow ง่าย
  - สิ่งที่ยังขาด: split payment, partial payment, reference number, change amount, payment notes
  - roadmap ที่เกี่ยวข้อง: Payment State Flow, Split Payment
  - refactor path: เปลี่ยนจากปุ่ม method-based เป็น payment action panel ที่รับ amount/payment method/remaining balance

### 11.7 Product browser และ cart panel

- `_buildZone4()`
  - หน้าที่ปัจจุบัน: product grid + search + scan button
  - สิ่งที่ดี: เป็นพื้นที่หลักของการเลือกสินค้า
  - สิ่งที่ยังขาด: รูปสินค้า, stock badge, scanner flow จริง, quick add, favorites, pagination
  - roadmap ที่เกี่ยวข้อง: Product Browser, Quick Search, Barcode flow, Low-stock badge
  - refactor path: แยกออกเป็น `PosProductBrowser` และเพิ่ม search mode หลายแบบ

- `_buildZone5()`
  - หน้าที่ปัจจุบัน: แสดงรายการสินค้าในตะกร้าและจำนวนรายการ
  - สิ่งที่ดี: empty state ดีและเข้าใจง่าย
  - สิ่งที่ยังขาด: note ต่อ item, line discount, split item, hold state, order status indicator
  - roadmap ที่เกี่ยวข้อง: Cart & Adjustments, Hold/Resume, Discount Engine
  - refactor path: สร้าง `PosCartPanel` และแยก cart item row ออกเป็น widget ย่อย

- `_qtyButton()`
  - หน้าที่ปัจจุบัน: ปุ่ม +/- สำหรับ qty
  - refactor path: เพิ่ม disabled state และ accessibility label

- `_glassCard()`
  - หน้าที่ปัจจุบัน: wrapper สไตล์ card
  - refactor path: ย้ายไป shared style component เพื่อใช้ซ้ำทั้ง app

### 11.8 Checkout และ order finalization

- `_showPaymentDialog(method)`
  - หน้าที่ปัจจุบัน: แสดงสรุปยอดและยืนยันก่อนชำระ
  - สิ่งที่ดี: มี confirmation step ก่อน commit ออเดอร์
  - สิ่งที่ยังขาด: receipt preview, split payment, partial amount, payment metadata
  - roadmap ที่เกี่ยวข้อง: Payment Flow, Receipt & Printing
  - refactor path: เปลี่ยนเป็น full payment sheet ที่รองรับ split, change, print option, และ validation

- `_dialogRow()`
  - หน้าที่ปัจจุบัน: helper แสดงบรรทัดใน dialog
  - refactor path: รวมกับ summary formatter กลาง

- `_processPayment(method)`
  - หน้าที่ปัจจุบัน: เรียก `InventoryService.createPosOrder`, แสดงผลสำเร็จ, clear cart, reload data
  - สิ่งที่ดี: finalization flow ใช้งานได้จริงในระดับพื้นฐาน
  - สิ่งที่ยังขาด: transaction state machine, audit log, receipt print, shift/session, refund linkage, split payment support
  - roadmap ที่เกี่ยวข้อง: Payment State Flow, Void/Refund/Audit, Shift/Cash Drawer, Receipt & Printing
  - refactor path: ย้ายไป `PosCheckoutService` และแยกขั้นตอนเป็น validate → create order → settle payments → print receipt → reset UI

### 11.9 ลำดับ refactor ที่แนะนำสำหรับไฟล์นี้

1. **แยก model ก่อน**
   - `PosCartItem`
   - `PosOrderContext`
   - `PosOrderSummary`
   - `PosPaymentIntent`

2. **แยก service ก่อนย้าย UI**
   - `PosPricingService`
   - `PosTaxService`
   - `PosDiscountService`
   - `PosOrderService`
   - `PosPaymentService`

3. **แยก widget ตามหน้าที่**
   - `PosHeader`
   - `PosCategoryRail`
   - `PosProductBrowser`
   - `PosCartPanel`
   - `PosPaymentPanel`
   - `PosOrderSummaryCard`

4. **เปลี่ยน state management**
   - ใช้ controller / provider / bloc เพื่อแยก state ของ catalog, cart, context, payment

5. **ต่อฐานข้อมูลตาม roadmap**
   - `pos_orders`
   - `pos_order_items`
   - `pos_payments`
   - `pos_discounts`
   - `pos_order_status_logs`
   - `pos_shift_sessions`
   - `pos_void_refunds`

### 11.10 สรุปเชิงปฏิบัติ

- `pos_page.dart` ตอนนี้เหมาะเป็น **POS พื้นฐานที่ขายสินค้าได้จริง**
- ถ้าต้องการให้เหมาะกับ Tree Law Zoo Valley แบบครบวงจร ต้องเริ่มที่
  - order context
  - pricing engine
  - payment state flow
  - hold/resume
  - customer/table integration

เอกสารส่วนนี้ตั้งใจให้ใช้เป็น **แผน refactor ทีละฟังก์ชัน** และเป็น **memory สำหรับงาน POS** ในอนาคต

## 12) โมเดลการรับผิดชอบบิลสำหรับ walk-in / customer ทั่วไป

เพื่อให้ตรวจสอบย้อนหลังได้ชัดเจน ระบบ POS ของ Tree Law Zoo Valley ควรแยก 3 บทบาทออกจากกัน:

- **Customer**
  - ใช้สำหรับผู้ซื้อสินค้า/บริการ
  - ถ้าเป็นลูกค้าที่เลือกจากระบบ ให้ผูกกับ `customer_user_id` หรือ `pos_customers`
  - ถ้าเป็น walk-in อาจเว้นว่างหรือใช้ customer record เฉพาะ

- **Responsible staff / Sales staff**
  - ต้องมีทุกบิล
  - ผูกกับ `responsible_user_id` ใน `pos_orders`
  - ใช้ใน HRM เป็น toggle `is_sales_staff_group` หรือ `is_sales_staff`

- **Cashier**
  - คนที่กดชำระเงินหรือบันทึกบิล
  - เก็บเป็น `cashier_user_id` เพื่อดูว่าใครทำรายการ

### ตารางที่เกี่ยวข้อง

- `user_groups`
  - `is_customer_group`
  - `is_sales_staff_group`

- `users`
  - `is_sales_staff`

- `pos_orders`
  - `order_type`
  - `responsible_user_id`
  - `responsible_user_name`
  - `cashier_user_id`
  - `cashier_user_name`
  - `customer_user_id`
  - `customer_name`

- `pos_customers`
  - รองรับลูกค้า walk-in และลูกค้าที่ผูกกับ user

### UX Flow ที่ควรยึด

1. เปิดบิล
2. เลือกพนักงานผู้รับผิดชอบจาก header ของ POS
3. เลือกหรือเว้นว่าง customer ตามประเภทบิล
4. กดชำระเงิน
5. บันทึก order พร้อม staff traceability

### หลักการสำคัญ

- บิล walk-in **ต้องมี responsible staff เสมอ**
- customer และ staff **ห้ามใช้แทนกัน**
- HRM ใช้ toggle เพื่อระบุ group ที่ใช้เป็น customer หรือ sales staff ได้
- POS ใช้ข้อมูลนี้เพื่อกรองรายชื่อและบังคับ flow การชำระเงิน

## 13) Seating / Table Integration สำหรับแต่ละร้าน

ถ้าร้านมีหน้า "ที่นั่ง/โต๊ะ" แยกตามสาขาหรือโซน ควรเชื่อมหน้านั้นเข้ากับ POS โดยตรง เพื่อให้ flow การเปิดบิลเป็นแบบ operational มากกว่าการเลือกด้วยมือทุกครั้ง

### เป้าหมาย

- แตะโต๊ะ/ที่นั่งแล้วเปิดบิล POS ได้ทันที
- เมื่อเปิดบิล dine-in ให้ระบบเติมข้อมูลโต๊ะอัตโนมัติ
- รองรับการย้ายโต๊ะ, hold bill, และ resume bill
- ผูกสถานะโต๊ะกับ order ปัจจุบันได้แบบ real-time

### ตารางที่ควรมี

- `pos_tables`
  - `id`
  - `store_id`
  - `zone`
  - `table_code` หรือ `seat_code`
  - `table_name`
  - `capacity`
  - `status` (`available`, `occupied`, `reserved`, `cleaning`, `disabled`)
  - `current_order_id`
  - `current_customer_id`
  - `current_responsible_user_id`
  - `updated_at`

- `pos_table_sessions`
  - ใช้เก็บรอบการใช้งานโต๊ะ
  - เหมาะกับการวัดเวลา dine-in, move table, และ reopen bill
  - ฟิลด์แนะนำ:
    - `table_id`
    - `order_id`
    - `opened_by`
    - `opened_at`
    - `closed_at`
    - `status`

- `pos_order_events`
  - ใช้บันทึกเหตุการณ์สำคัญ เช่น เปิดโต๊ะ, ย้ายโต๊ะ, hold, resume, ชำระเงิน, ปิดบิล

### UX Flow ที่ควรใช้

1. เปิดหน้า Seating / Table
2. เลือกโต๊ะที่ว่างหรือโต๊ะที่มีบิลค้างอยู่
3. ระบบส่ง context ไป POS:
   - `order_type = dine_in`
   - `table_id`
   - `table_name` / `table_code`
   - `customer_user_id` ถ้ามี
   - `responsible_user_id` ถ้ามีคนเปิดบิลไว้แล้ว
4. POS เปิดขึ้นพร้อมสรุปโต๊ะและบิล
5. ผู้ใช้งานเลือก/ยืนยันพนักงานผู้รับผิดชอบ
6. เพิ่มสินค้าและชำระเงิน
7. ปิดบิลแล้วอัปเดตสถานะโต๊ะกลับเป็นว่าง

### พฤติกรรมสำคัญที่ควรมี

- **Table click**
  - ถ้าโต๊ะว่าง → สร้างบิลใหม่
  - ถ้าโต๊ะมีบิลอยู่ → เปิดบิลเดิม

- **Move table**
  - เปลี่ยน `table_id` ใน order และอัปเดต session/event

- **Hold / Resume**
  - หากลูกค้าออกไปชั่วคราว ให้บันทึกสถานะโต๊ะและบิลไว้

- **Walk-in shared flow**
  - ถ้าเป็น walk-in ที่ไม่มีโต๊ะ ให้ยังบังคับเลือก responsible staff เหมือนเดิม

### สิ่งที่ควรเพิ่มใน `pos_orders`

- `table_id`
- `table_name`
- `table_status_snapshot`
- `opened_from_seating_page` (boolean)

### สรุปการเชื่อม

- หน้า Seating/Table = จุดเริ่มต้นของ dine-in flow
- หน้า POS = จุดจัดการสินค้าและชำระเงิน
- `pos_tables` = source of truth ของโต๊ะ/ที่นั่ง
- `pos_orders` = source of truth ของบิล
- `pos_table_sessions` / `pos_order_events` = ประวัติการใช้งานและการย้ายสถานะ
