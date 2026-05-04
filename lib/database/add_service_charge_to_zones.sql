-- Migration: Add service_charge field to restaurant_zones
-- Date: 2026-05-04

-- Add service_charge column (default 0%)
ALTER TABLE restaurant_zones
ADD COLUMN IF NOT EXISTS service_charge NUMERIC DEFAULT 0;

-- Add comment for documentation
COMMENT ON COLUMN restaurant_zones.service_charge IS 'ค่าบริการในรูปแบบเปอร์เซ็นต์ (0-100), 0 = ไม่คิดค่าบริการ';

-- Verify column exists
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'restaurant_zones' AND column_name = 'service_charge';
