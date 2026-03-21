# Database SQL Files Organization

โครงสร้างไฟล์ SQL สำหรับ Tree Law Zoo Valley

## 📁 โฟลเดอร์หลัก

```
lib/database/
├── backups/          ← สำรองไฟล์ก่อนจัดระเบียบ
├── migrations/       ← SQL migrations ตามลำดับการรัน
├── setup/           ← SQL สำหรับ setup ครั้งแรก
├── fixes/           ← SQL สำหรับแก้ไขปัญหาเฉพาะหน้า
├── debug/           ← SQL สำหรับ debug และตรวจสอบข้อมูล
├── seed/            ← SQL สำหรับเติมข้อมูลเริ่มต้น
└── README.md        ← ไฟล์นี้
```

## 📋 รายละเอียดแต่ละโฟลเดอร์

### 1. migrations/ - รันตามลำดับ
ไฟล์ที่ต้องรันตามลำดับสำหรับสร้างโครงสร้าง database:
- `001_permissions.sql` - สร้างตาราง permissions
- `002_procurement.sql` - สร้างตาราง procurement
- `003_procurement_permissions.sql` - permissions สำหรับ procurement
- `004_inventory.sql` - สร้างตาราง inventory
- `005_pos_orders.sql` - สร้างตาราง POS orders
- `006_group_sort_order.sql` - เพิ่ม sort_order ให้ groups

**วิธีใช้:** รันใน Supabase SQL Editor ตามลำดับเลข

### 2. setup/ - Setup ครั้งแรก
ไฟล์สำหรับติดตั้งระบบครั้งแรก:
- `complete_procurement_setup.sql` - Setup ครบวงจรสำหรับ procurement
- `complete_migration.sql` - Migration แบบครบถ้วน
- `safe_migration.sql` - Migration แบบปลอดภัย

**วิธีใช้:** รันไฟล์เดียวจบ สำหรับ setup ใหม่

### 3. fixes/ - แก้ไขปัญหา
ไฟล์สำหรับแก้ไขปัญหาเฉพาะหน้า:
- `fix_rls_ingredients.sql` - แก้ไข RLS สำหรับ ingredients
- `fix_rls_ingredients_v2.sql` - แก้ไข RLS ingredients เวอร์ชัน 2
- `fix_migration_step1.sql` - แก้ไข migration step 1
- `fix_migration_final.sql` - แก้ไข migration สุดท้าย
- `fix_inventory_categories_account_columns.sql` - แก้ไขคอลัมน์บัญชี

**วิธีใช้:** รันเมื่อพบปัญหาเฉพาะเรื่อง

### 4. debug/ - Debug และตรวจสอบ
ไฟล์สำหรับตรวจสอบและแก้ไขข้อมูล:
- `check_all_data.sql` - ตรวจสอบข้อมูลทั้งหมด
- `check_migration.sql` - ตรวจสอบ migration
- `check_references.sql` - ตรวจสอบ foreign keys
- `check_units.sql` - ตรวจสอบหน่วย
- `recover_data.sql` - กู้คืนข้อมูล

**วิธีใช้:** รันเพื่อตรวจสอบสถานะระบบ

### 5. seed/ - เติมข้อมูลเริ่มต้น
ไฟล์สำหรับเติมข้อมูลเริ่มต้น:
- `seed_account_chart.sql` - ผังบัญชี
- `seed_accounting_and_categories.sql` - บัญชีและหมวดหมู่
- `seed_full_account_chart.sql` - ผังบัญชีแบบเต็ม
- `seed_all_business_categories.sql` - หมวดหมู่ธุรกิจทั้งหมด
- `thai_ingredients_seed.sql` - วัตถุดิบไทย
- `insert_thai_ingredients.sql` - เพิ่มวัตถุดิบไทย
- `insert_east_asian_ingredients.sql` - วัตถุดิบเอเชียตะวันออก
- `insert_sea_indian_ingredients.sql` - วัตถถิบเอเชียตะวันออกเฉียงใต้และอินเดีย
- `insert_western_bakery_ingredients.sql` - วัตถุดิบตะวันตกและเบเกอรี่

**วิธีใช้:** รันหลังจากสร้างตารางแล้ว

## 🚀 การใช้งาน

### สำหรับระบบใหม่:
1. รัน `migrations/001_permissions.sql`
2. รัน `migrations/002_procurement.sql`
3. รัน `migrations/003_procurement_permissions.sql`
4. รัน `seed/` ตามต้องการ

### สำหรับแก้ไขปัญหา:
1. รัน `debug/check_*.sql` เพื่อตรวจสอบ
2. รัน `fixes/fix_*.sql` เพื่อแก้ไข

### สำหรับ setup ครบวงจร:
- รัน `setup/complete_procurement_setup.sql` เพียงไฟล์เดียว

## ⚠️ หมายเหตุ

- ไฟล์ต้นฉบับยังอยู่ใน `/lib/database/` (ยังไม่ลบ)
- ไฟล์ที่จัดระเบียบเป็น **สำเนา** ไม่กระทบต่อการทำงาน
- ตรวจสอบความถูกต้องก่อนรัน SQL ใน production

---
*จัดระเบียบเมื่อ: 21 March 2026*
