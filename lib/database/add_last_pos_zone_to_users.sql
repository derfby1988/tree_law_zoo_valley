-- Migration: Add last_pos_zone_id to store last zone used by each user in POS
-- Date: 2026-05-04

-- Add last_pos_zone_id column to user_profiles or users table
-- Assuming the table is named 'user_profiles' - adjust if different

-- Check if table exists and add column
DO $$
BEGIN
    -- Try to add to user_profiles first
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
        ALTER TABLE user_profiles
        ADD COLUMN IF NOT EXISTS last_pos_zone_id UUID REFERENCES restaurant_zones(id);
        
        COMMENT ON COLUMN user_profiles.last_pos_zone_id IS 'โซน POS ล่าสุดที่พนักงานใช้งาน';
        
    -- If not, try users table
    ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS last_pos_zone_id UUID REFERENCES restaurant_zones(id);
        
        COMMENT ON COLUMN users.last_pos_zone_id IS 'โซน POS ล่าสุดที่พนักงานใช้งาน';
    END IF;
END $$;

-- Verify column exists
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE column_name = 'last_pos_zone_id';
