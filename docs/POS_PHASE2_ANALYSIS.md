# POS Phase 2 — สถานะ & งานคงค้าง

> Tree Law Zoo Valley — อัปเดตล่าสุด 23 มี.ค. 2569 (21:41)

---

## 1. สิ่งที่เสร็จแล้ว ✅

| # | Feature | ไฟล์หลัก |
|---|---------|---------|
| 1 | เลือกสินค้า/หมวดหมู่, ตะกร้า, คำนวณภาษี+ค่าบริการ | `pos_page.dart` |
| 2 | ชำระเงิน 4 วิธี (เงินสด, เครดิต, โอน, QR) | `pos_page.dart` |
| 3 | เลือกลูกค้า + แสดง Loyalty แต้ม | `pos_customer_picker_widget.dart`, `pos_loyalty_display_widget.dart` |
| 4 | เพิ่มส่วนลด (UI) | `pos_discount_panel_widget.dart` |
| 5 | ตัวอย่างใบเสร็จ (Dialog preview) | `pos_receipt_preview_widget.dart` |
| 6 | พนักงานรับผิดชอบ + เชื่อมโต๊ะ/Session | `pos_page.dart` |
| 7 | รัน SQL migration 15 ตาราง | `pos_discounts_promotions_migration.sql` |
| 8 | บันทึกส่วนลด → `pos_order_discounts` | `inventory_service.dart` (step 3) |
| 9 | Loyalty auto-earn หลังชำระ | `inventory_service.dart` (step 4) |
| 10 | Order Status Log (audit trail) | `inventory_service.dart` (step 5) |
| 11 | Hold/Resume Orders (พักบิล/เรียกกลับ) | `pos_held_order_model.dart`, `pos_held_order_service.dart`, `pos_page.dart` |
| 12 | ผูก Hold Order กับ Table Session | `pos_held_order_service.dart` |

---

## 2. งานคงค้าง — ลำดับความสำคัญ

### Phase 2B — Shift & Cash Drawer (3-5 วัน) ⬅️ ถัดไป
> จำเป็นสำหรับการบริหารเงินสดและตรวจสอบย้อนหลัง

| # | งาน | รายละเอียด |
|---|------|-----------|
| 1 | **สร้าง Shift model + service** | `PosShift` model, `PosShiftService` |
| 2 | **UI: เปิด/ปิดกะ** | Dialog ใส่ยอดเงินเปิด/ปิด |
| 3 | **บังคับเปิดกะก่อนขาย** | ตรวจว่ามี shift เปิดอยู่ก่อนชำระ |
| 4 | **รายงานสรุปกะ** | ยอดขาย, จำนวนบิล, ส่วนลด, คืนเงิน |

### Phase 2D — Split Payment (2-3 วัน)
> ลูกค้ากลุ่มต้องการจ่ายหลายวิธี

| # | งาน | รายละเอียด |
|---|------|-----------|
| 5 | **สร้าง PaymentSplit model + service** | |
| 6 | **UI: Dialog แยกจ่าย** | เพิ่มวิธีจ่ายหลายรายการ + calculator |
| 7 | **แก้ _processPayment** | รองรับหลาย payment methods |

### Phase 2E — Refund & Void (3-5 วัน)
> สำคัญสำหรับ accountability

| # | งาน | รายละเอียด |
|---|------|-----------|
| 8 | **สร้าง Refund model + service** | |
| 9 | **UI: หน้า Order History** | ค้นหา/กรองบิลเก่า |
| 10 | **UI: Dialog คืนเงิน** | เลือกคืนทั้งบิลหรือบางรายการ |
| 11 | **Approval flow** | ผู้จัดการอนุมัติก่อนคืนเงิน |
| 12 | **คืน stock อัตโนมัติ** | อัปเดต inventory เมื่อคืนสินค้า |

### Phase 2F — Receipt Printing จริง (5-7 วัน)
> เชื่อมเครื่องพิมพ์ Bluetooth/Network

| # | งาน | รายละเอียด |
|---|------|-----------|
| 13 | **เพิ่ม dependencies** | `esc_pos_utils`, `bluetooth_print`, `printing` |
| 14 | **Printer discovery** | ค้นหาเครื่องพิมพ์ Bluetooth/LAN |
| 15 | **Receipt formatter** | สร้าง ESC/POS commands จาก template |
| 16 | **Auto-print หลังชำระ** | ถ้าตั้งค่า auto_print = true |
| 17 | **PDF receipt** | สำหรับ email/Line/บันทึกดิจิทัล |

---

## 3. UX Flow ที่ยังขาด

### 3.1 Shift Management
```
[เปิดกะ (นับเงินเปิด)] → [ขายของตลอดวัน] → [ปิดกะ (นับเงินปิด)]
→ ระบบคำนวณส่วนต่าง → รายงานประจำกะ
```

### 3.2 Split Payment
```
[กดชำระ] → [เลือก "แยกจ่าย"] → [เพิ่มวิธีจ่าย #1: เงินสด 500฿]
→ [เพิ่มวิธีจ่าย #2: โอน 300฿] → [ยืนยัน] → บันทึก pos_payment_splits
```

### 3.3 Refund/Void
```
[เปิดประวัติบิล] → [เลือกบิล] → [ขอคืนเงิน/ยกเลิก]
→ [ผู้จัดการอนุมัติ] → [คืนเงิน + คืน stock]
```

---

## 4. Database Entity Relationship (ภาพรวม)

```
pos_shifts (กะ)
  └── pos_orders (บิล)
        ├── pos_order_lines (รายการสินค้า)
        ├── pos_order_discounts (ส่วนลดที่ใช้)
        ├── pos_payment_splits (การแยกจ่าย)
        ├── pos_order_status_log (ประวัติสถานะ)
        ├── pos_refunds → pos_refund_items (คืนเงิน)
        ├── pos_receipt_history (ประวัติใบเสร็จ)
        └── pos_loyalty_transactions (แต้มสะสม)

pos_customers (ลูกค้า)
  └── pos_customer_loyalty_wallets (กระเป๋าแต้ม)
        └── pos_loyalty_transactions

pos_discounts (ส่วนลด) ← pos_promotions (โปรโมชัน)
                              └── pos_promotion_items (สินค้าในโปร)

pos_held_orders (บิลที่พัก)
pos_receipt_templates + pos_printer_profiles (ตั้งค่าใบเสร็จ/เครื่องพิมพ์)
```

---

*อัปเดตล่าสุด 23 มี.ค. 2569 21:41 — Cascade*
