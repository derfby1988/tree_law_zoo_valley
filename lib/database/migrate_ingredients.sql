-- Migration: แยกวัตถุดิบออกจากสินค้าสำเร็จ
-- สร้างตาราง inventory_ingredients และย้ายข้อมูล

-- 1. สร้างตารางวัตถุดิบ (ถ้ายังไม่มี)
-- รันคำสั่งจากไฟล์ create_inventory_ingredients_table.sql ก่อน

-- 2. ค้นหาวัตถุดิบที่มีจำนวน = 0 (สมมติว่าเป็นวัตถุดิบ)
-- และย้ายไปยังตารางใหม่
INSERT INTO inventory_ingredients (
  name,
  unit_id,
  quantity,
  min_quantity,
  cost,
  category_id,
  shelf_id,
  is_active,
  created_at,
  updated_at
)
SELECT 
  name,
  unit_id,
  quantity,
  min_quantity,
  cost,
  category_id,
  shelf_id,
  is_active,
  created_at,
  updated_at
FROM inventory_products 
WHERE quantity = 0 
  AND is_active = true
  AND id IN (
    -- เลือกเฉพาะ 2 รายการล่าสุดที่เป็นวัตถุดิบ
    SELECT id FROM inventory_products 
    WHERE quantity = 0 AND is_active = true 
    ORDER BY created_at DESC 
    LIMIT 2
  );

-- 3. ลบวัตถุดิบออกจากตารางสินค้า
DELETE FROM inventory_products 
WHERE quantity = 0 
  AND is_active = true
  AND id IN (
    SELECT id FROM inventory_products 
    WHERE quantity = 0 AND is_active = true 
    ORDER BY created_at DESC 
    LIMIT 2
  );

-- 4. ตรวจสอบผลลัพธ์
SELECT 'Products after migration' as table_name, COUNT(*) as count FROM inventory_products WHERE is_active = true;
SELECT 'Ingredients after migration' as table_name, COUNT(*) as count FROM inventory_ingredients WHERE is_active = true;

-- 5. แสดงข้อมูลวัตถุดิบที่ย้ายแล้ว
SELECT 
  name,
  quantity,
  cost,
  created_at
FROM inventory_ingredients 
WHERE is_active = true 
ORDER BY created_at DESC;
