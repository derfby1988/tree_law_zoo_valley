-- Phase 4 Schema Check - ตรวจสอบข้อมูลก่อนเริ่ม Availability & Procurement Rules
-- รันคำสั่งเหล่านี้ใน Supabase SQL Editor

-- =============================================
-- 1. CHECK: inventory_stock_summary view
-- =============================================
-- ตรวจสอบว่ามี view นี้หรือไม่ และมีข้อมูลอะไรบ้าง
SELECT 
    'inventory_stock_summary EXISTS' as check_item,
    COUNT(*) as row_count
FROM pg_views 
WHERE viewname = 'inventory_stock_summary';

-- ดูตัวอย่างข้อมูล (ถ้ามี)
SELECT * FROM inventory_stock_summary LIMIT 5;

-- =============================================
-- 2. CHECK: inventory_recipe_ingredients table
-- =============================================
-- ตรวจสอบ schema และข้อมูล
SELECT 
    'inventory_recipe_ingredients EXISTS' as check_item,
    COUNT(*) as row_count
FROM information_schema.tables 
WHERE table_name = 'inventory_recipe_ingredients';

-- ดูโครงสร้างตาราง
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'inventory_recipe_ingredients'
ORDER BY ordinal_position;

-- ดูตัวอย่างข้อมูล (ถ้ามี)
SELECT * FROM inventory_recipe_ingredients LIMIT 5;

-- =============================================
-- 3. CHECK: inventory_ingredients table
-- =============================================
SELECT 
    'inventory_ingredients EXISTS' as check_item,
    COUNT(*) as row_count
FROM information_schema.tables 
WHERE table_name = 'inventory_ingredients';

-- ดูโครงสร้างตาราง
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'inventory_ingredients'
ORDER BY ordinal_position;

-- ดูตัวอย่างข้อมูล
SELECT * FROM inventory_ingredients LIMIT 5;

-- =============================================
-- 4. CHECK: inventory_recipes table
-- =============================================
SELECT 
    'inventory_recipes EXISTS' as check_item,
    COUNT(*) as row_count
FROM information_schema.tables 
WHERE table_name = 'inventory_recipes';

-- ดูโครงสร้างตาราง
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'inventory_recipes'
ORDER BY ordinal_position;

-- ดูสูตรอาหารที่มี
SELECT id, name, yield_quantity, yield_unit 
FROM inventory_recipes 
WHERE is_active = true 
LIMIT 10;

-- =============================================
-- 5. CHECK: Procurement Tables & Status
-- =============================================
-- ตรวจสอบตาราง procurement
SELECT 
    table_name,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'procurement_suppliers') as suppliers_exists,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'procurement_purchase_orders') as po_exists,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'procurement_purchase_order_lines') as po_lines_exists
FROM information_schema.tables
WHERE table_name IN ('procurement_suppliers', 'procurement_purchase_orders', 'procurement_purchase_order_lines')
LIMIT 3;

-- ดูโครงสร้าง procurement_purchase_orders
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'procurement_purchase_orders'
ORDER BY ordinal_position;

-- ดู status ทั้งหมดที่มีใน PO
SELECT DISTINCT status, COUNT(*) as count
FROM procurement_purchase_orders
GROUP BY status;

-- ดูตัวอย่าง PO ที่ไม่ใช่ completed/cancelled (นับเป็น pending procurement)
SELECT 
    po.id,
    po.order_number,
    po.status,
    po.expected_date,
    pol.product_id,
    pol.quantity,
    pol.received_quantity,
    (pol.quantity - COALESCE(pol.received_quantity, 0)) as pending_quantity
FROM procurement_purchase_orders po
JOIN procurement_purchase_order_lines pol ON po.id = pol.po_id
WHERE po.status NOT IN ('completed', 'cancelled')
LIMIT 10;

-- =============================================
-- 6. CHECK: Product ที่มีสูตรอาหาร (Recipe Products)
-- =============================================
-- ดูสินค้าที่ผลิตจากสูตรอาหาร
-- recipe มี output_product_id อ้างอิงถึง product (ไม่ใช่ product มี recipe_id)
SELECT 
    p.id as product_id,
    p.name as product_name,
    r.id as recipe_id,
    r.name as recipe_name,
    r.yield_quantity,
    COUNT(ri.id) as ingredient_count
FROM inventory_recipes r
JOIN inventory_products p ON r.output_product_id = p.id
LEFT JOIN inventory_recipe_ingredients ri ON r.id = ri.recipe_id
WHERE p.is_active = true AND r.is_active = true
GROUP BY p.id, p.name, r.id, r.name, r.yield_quantity
LIMIT 10;

-- =============================================
-- 7. CHECK: Recipe Ingredients Sufficiency
-- =============================================
-- ตรวจสอบว่าวัตถุดิบพอผลิตหรือไม่
-- recipe มี output_product_id อ้างอิงถึง product
SELECT 
    r.id as recipe_id,
    r.name as recipe_name,
    p.id as product_id,
    p.name as product_name,
    r.yield_quantity,
    i.name as ingredient_name,
    ri.quantity_required,
    ss.total_quantity as current_stock,
    CASE 
        WHEN ss.total_quantity >= ri.quantity_required THEN 'พอ'
        ELSE 'ไม่พอ'
    END as can_produce
FROM inventory_recipes r
JOIN inventory_products p ON r.output_product_id = p.id
JOIN inventory_recipe_ingredients ri ON r.id = ri.recipe_id
JOIN inventory_ingredients i ON ri.ingredient_id = i.id
LEFT JOIN inventory_stock_summary ss ON i.id = ss.item_id AND ss.item_type = 'ingredient'
WHERE r.is_active = true AND p.is_active = true
ORDER BY r.name, i.name
LIMIT 20;

-- =============================================
-- 8. SUMMARY: สรุปข้อมูลที่ต้องใช้ใน Phase 4
-- =============================================
WITH checks AS (
    SELECT 
        'inventory_stock_summary view' as item,
        (SELECT COUNT(*) FROM pg_views WHERE viewname = 'inventory_stock_summary') as exists_count
    UNION ALL
    SELECT 
        'inventory_recipes table',
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'inventory_recipes')
    UNION ALL
    SELECT 
        'inventory_recipe_ingredients table',
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'inventory_recipe_ingredients')
    UNION ALL
    SELECT 
        'inventory_ingredients table',
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'inventory_ingredients')
    UNION ALL
    SELECT 
        'procurement_purchase_orders table',
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'procurement_purchase_orders')
    UNION ALL
    SELECT 
        'procurement_purchase_order_lines table',
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'procurement_purchase_order_lines')
)
SELECT 
    item,
    CASE 
        WHEN exists_count > 0 THEN '✅ พร้อม'
        ELSE '❌ ยังไม่มี'
    END as status
FROM checks;
