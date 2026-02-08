-- Migration: เพิ่มคอลัมน์ sort_order ในตาราง user_groups
-- ลำดับที่น้อยกว่า = สิทธิ์สูงกว่า (เช่น 1 = สูงสุด, 2 = รองลงมา)

-- เพิ่มคอลัมน์ sort_order
ALTER TABLE user_groups ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 999;

-- ตั้งค่า sort_order เริ่มต้นตามลำดับ created_at (กลุ่มที่สร้างก่อนจะมีลำดับสูงกว่า)
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY created_at ASC) as rn
  FROM user_groups
)
UPDATE user_groups
SET sort_order = ranked.rn
FROM ranked
WHERE user_groups.id = ranked.id;
