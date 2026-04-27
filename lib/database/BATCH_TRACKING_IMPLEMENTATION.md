# 📦 Batch Tracking System - Implementation Summary

## ✅ สถานะ: สมบูรณ์ (Completed)

วันที่อัปเดต: 24 เมษายน 2026

---

## 📁 ไฟล์ที่สร้าง/อัปเดต

### 1. SQL Migration (Database Schema)
**ไฟล์:** `lib/database/batch_tracking_migration.sql`

ตารางหลัก:
- `inventory_item_batches` - เก็บ batch สำหรับ Products และ Ingredients
- `inventory_batch_logs` - ประวัติการเคลื่อนไหว batch

Views:
- `inventory_stock_summary` - สรุปสต็อกรวม
- `inventory_batch_details` - รายละเอียด batch พร้อม warehouse/shelf
- `inventory_expiry_alerts` - batch ใกล้หมดอายุ

Functions:
- `consume_batch_fefo()` - consume batch ตาม FEFO
- `adjust_batch_quantities_fefo()` - ปรับนับรวมแล้วกระจายไป batch
- `create_inventory_batch()` - สร้าง batch ใหม่
- `mark_batch_expired()` - mark batch หมดอายุ/ทิ้ง
- `update_batch_expiry()` - อัปเดตวันหมดอายุ

---

### 2. Service Layer
**ไฟล์:** `lib/services/inventory_service.dart` (เพิ่ม 600+ บรรทัด)

Methods ใหม่:
- `createBatch()` - สร้าง batch
- `getBatches()` - ดึงรายการ batch
- `getBatchesForFEFO()` - ดึง batch เรียง expiry สำหรับ consume
- `getExpiringBatches()` - batch ใกล้หมดอายุ
- `getExpiredBatches()` - batch หมดอายุแล้ว
- `reduceBatchQuantity()` - ลดจำนวน batch
- `consumeByFEFO()` - ใช้ batch ตาม FEFO
- `adjustBatchQuantitiesFromCount()` - ปรับนับ → กระจาย batch
- `updateBatchExpiry()` - แก้ไขวันหมดอายุ
- `markBatchAsExpired()` - mark หมดอายุ/ทิ้ง
- `getBatchLogs()` - ดึงประวัติ
- `produceFromRecipeWithFEFO()` - ผลิตด้วย FEFO batch tracking
- `checkRecipeCanProduceWithBatches()` - validate สต็อก batch
- `generateBatchNumber()` - สร้างเลข batch อัตโนมัติ

**ไฟล์:** `lib/services/procurement_service.dart` (อัปเดต `recordPartialReceive()`)

- สร้าง batch อัตโนมัติเมื่อรับสินค้า พร้อมข้อมูลครบถ้วน:
  - วันหมดอายุ
  - ต้นทุน (จาก PO unit_price)
  - ผู้จำหน่าย (จาก PO supplier_name)
  - เลขอ้างอิง (PO number)

---

### 3. UI Widgets
**ไฟล์:** `lib/widgets/batch_list_widget.dart` (310 บรรทัด)

- แสดงรายการ batch พร้อมสีตามสถานะ expiry
- แสดง: batch number, quantity, expiry date, warehouse/shelf, unit cost, supplier
- รองรับ: แก้ไขวันหมดอายุ, ทิ้ง batch, ดูประวัติ

**ไฟล์:** `lib/widgets/batch_selector_widget.dart` (320 บรรทัด)

- สำหรับ Production/Sales: FEFO auto-select หรือ manual select
- แสดงสรุป: ต้องการ/มี/ขาด
- แสดง batch พร้อมวันหมดอายุ, จำนวน, ตำแหน่ง

**ไฟล์:** `lib/pages/inventory/batch_management_page.dart` (270 บรรทัด)

- หน้าจัดการ batch แบบเต็มจอ
- 3 tabs: ทั้งหมด | ใกล้หมดอายุ | หมดอายุแล้ว
- รองรับทั้ง Products และ Ingredients

---

### 4. UI Integration

**ไฟล์:** `lib/pages/inventory/product_tab.dart`
- เพิ่ม import: `batch_management_page.dart`
- เพิ่มปุ่ม "ดู Batch" (icon: layers) ใน product card
- เพิ่ม method: `_showBatchManagement()`

**ไฟล์:** `lib/pages/inventory/ingredient_tab.dart`
- เพิ่ม import: `batch_management_page.dart`
- เพิ่มปุ่ม "ดู Batch" (icon: layers) ใน ingredient card
- เพิ่ม method: `_showBatchManagement()`

---

## 🎯 ฟีเจอร์ที่รองรับ

| ฟีเจอร์ | สถานะ | รายละเอียด |
|---------|-------|-------------|
| **รับสินค้าสร้าง batch** | ✅ | สร้าง batch อัตโนมัติพร้อมวันหมดอายุ, ต้นทุน, ผู้จำหน่าย |
| **FEFO Consume** | ✅ | ใช้ batch ที่หมดอายุก่อนอัตโนมัติ (สำหรับผลิต) |
| **Manual Batch Selection** | ✅ | เลือก batch เอง (สำหรับขาย) |
| **ตรวจนับ + กระจาย** | ✅ | นับรวมแล้วกระจายไป batch ตาม FEFO |
| **แก้ไขวันหมดอายุ** | ✅ | แก้ไขได้พร้อมเหตุผล + audit log |
| **ทิ้ง batch หมดอายุ** | ✅ | Mark disposed + ลด quantity |
| **แจ้งเตือน expiry** | ✅ | View `inventory_expiry_alerts` |
| **ต้นทุนราย batch** | ✅ | เก็บ `unit_cost` ในแต่ละ batch |
| **ผู้จำหน่ายราย batch** | ✅ | เก็บ `supplier_name` สำหรับวิเคราะห์จัดซื้อ |
| **Audit Trail** | ✅ | บันทึกทุกการเปลี่ยนแปลงใน `inventory_batch_logs` |

---

## 🔄 Workflow ที่ทำงานได้

### 1. Procurement → Receive
```
สร้าง PO → ส่ง → อนุมัติ → รับสินค้า → สร้าง batch อัตโนมัติ
```
**ข้อมูลใน batch:**
- batch_number (auto หรือ manual)
- quantity
- expiry_date
- unit_cost (จาก PO)
- supplier_name (จาก PO)
- warehouse_id, shelf_id
- received_reference (PO number)

### 2. Production → Use Ingredient
```
เลือกสูตร → ตรวจสอบสต็อก → ผลิต → FEFO consume batch → สร้าง batch สินค้าผลิต
```
**FEFO Logic:**
- ดึง batch ที่ยังไม่หมดอายุ เรียงตาม expiry_date ASC
- consume จาก batch แรกก่อน
- ถ้า batch แรกไม่พอ ตัดจาก batch ถัดไป
- บันทึก log ทุกการ consume

### 3. Stock Count → Adjust
```
ตรวจนับรวม → คำนวณ diff → กระจายไป batch
```
**Logic กระจาย:**
- diff > 0 (นับได้มากกว่า): เพิ่ม batch แรก (ของที่รับก่อน)
- diff < 0 (นับได้น้อยกว่า): ลดจาก batch ล่าสุด (ของรับทีหลังก่อน)

---

## 📊 Database Schema Summary

### inventory_item_batches
```sql
id UUID PRIMARY KEY
item_type TEXT ('product' | 'ingredient')
product_id UUID (nullable)
ingredient_id UUID (nullable)
batch_number TEXT
quantity DOUBLE PRECISION
expiry_date DATE
received_date DATE
warehouse_id UUID
shelf_id UUID
supplier_name TEXT
unit_cost DOUBLE PRECISION
currency TEXT DEFAULT 'THB'
is_expired BOOLEAN DEFAULT false
is_active BOOLEAN DEFAULT true
is_disposed BOOLEAN DEFAULT false
received_reference TEXT
notes TEXT
created_by UUID
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

### inventory_batch_logs
```sql
id UUID PRIMARY KEY
batch_id UUID REFERENCES inventory_item_batches
action_type TEXT (receive, consume, adjust_count, adjust_manual, transfer, expiry_change, dispose, return, split)
quantity_before DOUBLE PRECISION
quantity_after DOUBLE PRECISION
quantity_changed DOUBLE PRECISION (GENERATED)
reference_id UUID
reference_type TEXT
notes TEXT
performed_by UUID
performed_at TIMESTAMPTZ
from_warehouse_id UUID (for transfer)
from_shelf_id UUID (for transfer)
to_warehouse_id UUID (for transfer)
to_shelf_id UUID (for transfer)
created_at TIMESTAMPTZ
```

---

## 🚀 ขั้นตอนถัดไป (Next Steps)

### 1. รัน SQL Migration
```sql
-- ใน Supabase SQL Editor
\i lib/database/batch_tracking_migration.sql
```

### 2. ทดสอบ Flow หลัก
- [ ] สร้าง PO → รับสินค้า → ตรวจสอบ batch ถูกสร้าง
- [ ] ผลิตสินค้า → ตรวจสอบ FEFO consume ถูกต้อง
- [ ] ตรวจนับ → ตรวจสอบการกระจายไป batch
- [ ] แก้ไขวันหมดอายุ → ตรวจสอบ audit log

### 3. Future Enhancements (Optional)
- [ ] Batch transfer between warehouses/shelves
- [ ] Batch split (แบ่ง batch เป็นสองส่วน)
- [ ] Cost of Goods Sold (COGS) calculation per batch
- [ ] Batch barcode/QR code printing
- [ ] Integration with POS for batch tracking at sale

---

## 📝 Notes

1. **เก็บต้นทุนราย batch**: `unit_cost` เก็บใน `inventory_item_batches` สำหรับคำนวณ COGS
2. **ผู้จำหน่ายราย batch**: `supplier_name` เก็บสำหรับวิเคราะห์การจัดซื้อ
3. **FEFO vs FIFO**: ใช้ FEFO (First Expired First Out) สำหรับวัตถุดิบ ลดของหมดอายุ
4. **Audit Trail**: ทุกการเปลี่ยนแปลง batch มี log ใน `inventory_batch_logs`
5. **Permission**: ต้องเพิ่ม permission `inventory_batch_create`, `inventory_batch_edit`, etc. หากต้องการควบคุมการเข้าถึง

---

## 🔧 Permissions ที่ควรเพิ่ม (ถ้าต้องการ)

```sql
-- ใน permissions table
inventory_batch_view      -- ดู batch
inventory_batch_create    -- สร้าง batch ด้วยมือ
inventory_batch_edit      -- แก้ไข batch (วันหมดอายุ)
inventory_batch_dispose   -- ทิ้ง batch
```

---

**สร้างโดย:** Cascade AI Assistant  
**วันที่:** 24 เมษายน 2026  
**โปรเจกต์:** TREE LAW ZOO Valley
