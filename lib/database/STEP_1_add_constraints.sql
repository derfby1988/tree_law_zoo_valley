-- =============================================
-- STEP 1: Add CHECK Constraints
-- =============================================
-- รันใน Supabase SQL Editor
-- ⏱️ เวลา: ~5 วินาที

-- 1. Add CHECK constraint to inventory_products
ALTER TABLE inventory_products
ADD CONSTRAINT check_quantity_not_negative
CHECK (quantity >= 0);

-- 2. Add CHECK constraint to inventory_ingredients
ALTER TABLE inventory_ingredients
ADD CONSTRAINT check_ingredient_quantity_not_negative
CHECK (quantity >= 0);

-- ✅ ตรวจสอบ
SELECT constraint_name, table_name 
FROM information_schema.table_constraints 
WHERE constraint_type = 'CHECK' 
AND table_name IN ('inventory_products', 'inventory_ingredients');
