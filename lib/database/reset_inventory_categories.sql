-- =============================================
-- Reset inventory_categories: ลบทั้งหมดแล้วเริ่มใหม่
-- รันใน Supabase SQL Editor
-- =============================================

-- Step 1: ปลด category_id ของ ingredients ออกก่อน (set เป็น null)
UPDATE public.inventory_ingredients
SET category_id = NULL
WHERE category_id IS NOT NULL;

-- Step 2: ปลด category_id ของ products ออก (ถ้ามี)
UPDATE public.inventory_products
SET category_id = NULL
WHERE category_id IS NOT NULL;

-- Step 3: ปลด category_id ของ recipes ออก
UPDATE public.inventory_recipes
SET category_id = NULL
WHERE category_id IS NOT NULL;

-- Step 4: ลบ categories ทั้งหมด
DELETE FROM public.inventory_categories;

-- ตรวจสอบผล
SELECT 'ingredients with category' AS check_name, COUNT(*) AS count
FROM public.inventory_ingredients WHERE category_id IS NOT NULL
UNION ALL
SELECT 'products with category', COUNT(*)
FROM public.inventory_products WHERE category_id IS NOT NULL
UNION ALL
SELECT 'remaining categories', COUNT(*)
FROM public.inventory_categories;
