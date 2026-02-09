-- แก้ไขปัญหา Foreign Key - วิธีที่ปลอดภัย

-- 1. คัดลอกข้อมูลไปตารางใหม่ก่อน
INSERT INTO inventory_ingredients (name, unit_id, quantity, min_quantity, cost, category_id, shelf_id, is_active, created_at, updated_at)
SELECT name, unit_id, quantity, min_quantity, cost, category_id, shelf_id, is_active, created_at, updated_at
FROM inventory_products 
WHERE quantity = 0 AND is_active = true 
ORDER BY created_at DESC 
LIMIT 2;

-- 2. อัปเดต inventory_recipe_ingredients ให้ชี้ไปที่ตารางใหม่
-- สร้างคอลัมน์ ingredient_id ใน inventory_recipe_ingredients ก่อน
ALTER TABLE inventory_recipe_ingredients ADD COLUMN IF NOT EXISTS ingredient_id UUID;

-- อัปเดตความสัมพันธ์
UPDATE inventory_recipe_ingredients ri
SET ingredient_id = i.id
FROM inventory_ingredients i
WHERE ri.product_id IN (
  SELECT id FROM inventory_products 
  WHERE quantity = 0 AND is_active = true 
  ORDER BY created_at DESC 
  LIMIT 2
) AND ri.product_id = (
  SELECT id FROM inventory_products p 
  WHERE p.id = ri.product_id AND p.quantity = 0 AND p.is_active = true
);

-- 3. ลบความสัมพันธ์เก่า (แต่ยังไม่ลบข้อมูล)
-- ถ้าต้องการลบจริงๆ ต้องทำตามขั้นตอนถัดไป

-- 4. ตรวจสอบผลลัพธ์
SELECT 'Products remaining' as table_name, COUNT(*) as count FROM inventory_products WHERE is_active = true;
SELECT 'Ingredients created' as table_name, COUNT(*) as count FROM inventory_ingredients WHERE is_active = true;
SELECT 'Recipe ingredients updated' as table_name, COUNT(*) as count FROM inventory_recipe_ingredients WHERE ingredient_id IS NOT NULL;
