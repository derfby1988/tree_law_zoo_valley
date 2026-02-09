-- ============================================
-- ลบข้อมูลจาก inventory_products (แก้ FK constraint)
-- ข้อมูล 663 รายการคัดลอกไป inventory_ingredients แล้ว
-- ============================================

-- ลบ adjustments ที่อ้างอิง products
DELETE FROM inventory_adjustments;

-- ลบ recipe_ingredients ที่อ้างอิง products
DELETE FROM inventory_recipe_ingredients;

-- ลบ products ทั้งหมด
DELETE FROM inventory_products;

-- ตรวจสอบผลลัพธ์
SELECT 'Products' as t, COUNT(*) as c FROM inventory_products
UNION ALL
SELECT 'Ingredients' as t, COUNT(*) as c FROM inventory_ingredients WHERE is_active = true;
