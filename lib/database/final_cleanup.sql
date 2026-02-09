-- ลบข้อมูลจากตารางเดิม (หลังจากอัปเดตความสัมพันธ์แล้ว)

-- ลบจาก inventory_recipe_ingredients ก่อน
DELETE FROM inventory_recipe_ingredients 
WHERE product_id IN (
  SELECT id FROM (
    SELECT id FROM inventory_products 
    WHERE quantity = 0 AND is_active = true 
    ORDER BY created_at DESC 
    LIMIT 2
  ) AS to_delete
);

-- ลบจาก inventory_products หลังจากไม่มีใครอ้างอิงแล้ว
DELETE FROM inventory_products 
WHERE id IN (
  SELECT id FROM (
    SELECT id FROM inventory_products 
    WHERE quantity = 0 AND is_active = true 
    ORDER BY created_at DESC 
    LIMIT 2
  ) AS to_delete
);

-- ตรวจสอบผลลัพธ์สุดท้าย
SELECT 'Products remaining' as table_name, COUNT(*) as count FROM inventory_products WHERE is_active = true;
SELECT 'Ingredients created' as table_name, COUNT(*) as count FROM inventory_ingredients WHERE is_active = true;
