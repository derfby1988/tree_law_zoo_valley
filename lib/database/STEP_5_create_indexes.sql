-- =============================================
-- STEP 5: Create Indexes for Performance
-- =============================================
-- รันใน Supabase SQL Editor
-- ⏱️ เวลา: ~10 วินาที

-- 1. Index for production logs
CREATE INDEX IF NOT EXISTS idx_production_logs_recipe_id 
ON inventory_production_logs(recipe_id);

-- 2. Index for adjustments reference
CREATE INDEX IF NOT EXISTS idx_adjustments_reference_id 
ON inventory_adjustments(reference_id);

-- 3. Index for adjustments product
CREATE INDEX IF NOT EXISTS idx_adjustments_product_id 
ON inventory_adjustments(product_id);

-- 4. Index for production logs created_at (for sorting)
CREATE INDEX IF NOT EXISTS idx_production_logs_created_at 
ON inventory_production_logs(created_at DESC);

-- 5. Index for adjustments created_at (for sorting)
CREATE INDEX IF NOT EXISTS idx_adjustments_created_at 
ON inventory_adjustments(created_at DESC);

-- ✅ ตรวจสอบ
SELECT indexname, tablename 
FROM pg_indexes 
WHERE tablename IN ('inventory_production_logs', 'inventory_adjustments')
AND indexname LIKE 'idx_%';
