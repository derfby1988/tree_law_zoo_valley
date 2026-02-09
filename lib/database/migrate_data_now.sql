-- ย้ายวัตถุดิบ 2 รายการไปตารางใหม่
-- (เลือกที่มี quantity = 0)

-- คัดลอกข้อมูลไปตารางใหม่
INSERT INTO inventory_ingredients (name, unit_id, quantity, min_quantity, cost, category_id, shelf_id, is_active, created_at, updated_at)
SELECT name, unit_id, quantity, min_quantity, cost, category_id, shelf_id, is_active, created_at, updated_at
FROM inventory_products 
WHERE quantity = 0 AND is_active = true 
ORDER BY created_at DESC 
LIMIT 2;

-- ลบออกจากตารางเดิม
DELETE FROM inventory_products 
WHERE id IN (
  SELECT id FROM (
    SELECT id FROM inventory_products 
    WHERE quantity = 0 AND is_active = true 
    ORDER BY created_at DESC 
    LIMIT 2
  ) AS to_delete
);

-- ตรวจสอบผลลัพธ์
SELECT 'Products remaining' as table_name, COUNT(*) as count FROM inventory_products WHERE is_active = true;
SELECT 'Ingredients created' as table_name, COUNT(*) as count FROM inventory_ingredients WHERE is_active = true;

-- แสดงข้อมูลวัตถุดิบที่ย้ายแล้ว
SELECT name, quantity, cost, created_at FROM inventory_ingredients WHERE is_active = true ORDER BY created_at DESC;
