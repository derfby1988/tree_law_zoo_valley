-- ============================================
-- แก้ไข Migration: ย้ายทั้ง 663 รายการเป็นวัตถุดิบ
-- ============================================

-- ขั้นตอนที่ 1: ลบข้อมูลผิดที่คัดลอกไปก่อนหน้า
DELETE FROM inventory_ingredients;

-- ขั้นตอนที่ 2: คัดลอกทั้ง 663 รายการไป inventory_ingredients
INSERT INTO inventory_ingredients (name, unit_id, quantity, min_quantity, cost, category_id, shelf_id, is_active, created_at, updated_at)
SELECT name, unit_id, quantity, min_quantity, cost, category_id, shelf_id, is_active, created_at, updated_at
FROM inventory_products
WHERE is_active = true;

-- ขั้นตอนที่ 3: อัปเดต recipe_ingredients ให้ชี้ไปที่ตารางใหม่
ALTER TABLE inventory_recipe_ingredients ADD COLUMN IF NOT EXISTS ingredient_id UUID;

UPDATE inventory_recipe_ingredients ri
SET ingredient_id = ing.id
FROM inventory_ingredients ing
JOIN inventory_products p ON p.name = ing.name
WHERE ri.product_id = p.id;

-- ขั้นตอนที่ 4: ลบ recipe_ingredients ที่อ้างอิง products เก่า
DELETE FROM inventory_recipe_ingredients WHERE product_id IS NOT NULL;

-- ขั้นตอนที่ 5: ลบข้อมูลทั้งหมดออกจาก inventory_products
DELETE FROM inventory_products WHERE is_active = true;

-- ตรวจสอบผลลัพธ์
SELECT 'Products' as t, COUNT(*) as c FROM inventory_products WHERE is_active = true
UNION ALL
SELECT 'Ingredients' as t, COUNT(*) as c FROM inventory_ingredients WHERE is_active = true;
