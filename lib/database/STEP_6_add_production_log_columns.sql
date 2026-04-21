-- =============================================
-- STEP 6: Add Production Log Columns
-- =============================================
-- รันใน Supabase SQL Editor
-- ⏱️ เวลา: ~5 วินาที

-- 1. Add status column
ALTER TABLE inventory_production_logs
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed' 
  CHECK (status IN ('pending', 'completed', 'failed'));

-- 2. Add error_message column
ALTER TABLE inventory_production_logs
ADD COLUMN IF NOT EXISTS error_message TEXT;

-- 3. Add total_cost column
ALTER TABLE inventory_production_logs
ADD COLUMN IF NOT EXISTS total_cost DOUBLE PRECISION DEFAULT 0;

-- ✅ ตรวจสอบ
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'inventory_production_logs'
ORDER BY ordinal_position;
