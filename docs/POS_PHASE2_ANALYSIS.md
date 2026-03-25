## POS Phase 2 — งานคงค้าง

> Tree Law Zoo Valley — อัปเดตล่าสุด 24 มี.ค. 2569

---

## สถานะปัจจุบัน

งานหลักที่อยู่ระหว่างพัฒนา Phase 2 เสร็จแล้ว ได้แก่:

- Shift & Cash Drawer
- Refund & Void
- Hold / Resume Orders
- Core POS flow, customer, discounts, loyalty, receipt preview

ตอนนี้เหลือเฉพาะงานด้านล่างเท่านั้น:

---

## 1. งานคงค้าง — Split Payment
> ลูกค้ากลุ่มต้องการจ่ายหลายวิธี

| # | งาน | รายละเอียด |
|---|------|-----------|
| 1 | **เพิ่มปุ่มแก้รายการแยกจ่ายใน UI** | ปรับ UX ให้แก้ split payment ได้สะดวก |
| 2 | **ผูก UI กับ calculator** | รองรับ split หลายรายการ + ยอดรวมอัตโนมัติ |
| 3 | **ส่งข้อมูลเข้า `_processPayment`** | รองรับหลายวิธีจ่ายตอนบันทึกบิล |

---

## 2. งานคงค้าง — Receipt Printing จริง
> เพิ่มหน้า Printer Settings จากไอคอนด้านซ้าย (ถัดจากประวัติออเดอร์/คืนเงิน) และเชื่อมเครื่องพิมพ์ Bluetooth/Network

| # | งาน | รายละเอียด |
|---|------|-----------|
| 4 | **เพิ่มหน้า Printer Settings** | เปิดจากไอคอนด้านซ้าย และเลือกได้ทั้ง Bluetooth / Network |
| 5 | **ค้นหา IP ร้านอัตโนมัติ** | ตรวจจับ IP ปัจจุบันของร้านตอนเปิดหน้า POS และตั้งค่าใหม่ทุกครั้ง |
| 6 | **Receipt formatter** | ทำในหน้า Printer Settings หน้าเดียวกัน และแปลงเป็น ESC/POS commands |
| 7 | **เพิ่ม dependencies** | `esc_pos_utils`, `bluetooth_print`, `printing` |
| 8 | **Auto-print หลังชำระ** | ถ้าตั้งค่า auto_print = true |
| 9 | **Print log + reprint** | บันทึกประวัติพิมพ์ และพิมพ์ซ้ำใบเสร็จได้ |
| 10 | **PDF receipt** | สำหรับ email/Line/บันทึกดิจิทัล |

---

*อัปเดตล่าสุด 24 มี.ค. 2569 — Cascade*
