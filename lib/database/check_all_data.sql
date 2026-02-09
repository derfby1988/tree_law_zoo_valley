-- ============================================
-- ตรวจสอบสถานะข้อมูลทั้งหมด
-- ============================================

-- ตรวจสอบ inventory_products (รวม is_active = false ด้วย)
SELECT 'Products (all)' as t, COUNT(*) as c FROM inventory_products
UNION ALL
SELECT 'Products (active)' as t, COUNT(*) as c FROM inventory_products WHERE is_active = true
UNION ALL
SELECT 'Ingredients (all)' as t, COUNT(*) as c FROM inventory_ingredients
UNION ALL
SELECT 'Ingredients (active)' as t, COUNT(*) as c FROM inventory_ingredients WHERE is_active = true;
