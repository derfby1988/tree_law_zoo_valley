-- ตรวจสอบสถานะตารางวัตถุดิบ
-- รันคำสั่งนี้เพื่อตรวจสอบว่าตารางถูกสร้างหรือไม่

-- ตรวจสอบว่ามีตาราง inventory_ingredients หรือไม่
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name = 'inventory_ingredients'
) as table_exists;

-- ถ้ามีตาราง ให้ตรวจสอบข้อมูล
SELECT 'inventory_ingredients' as table_name, COUNT(*) as count 
FROM inventory_ingredients 
WHERE is_active = true;

-- ตรวจสอบตารางเดิม
SELECT 'inventory_products' as table_name, COUNT(*) as count 
FROM inventory_products 
WHERE is_active = true;

-- แสดงข้อมูลวัตถุดิบ (ถ้ามี)
SELECT 
  id,
  name,
  quantity,
  cost,
  created_at
FROM inventory_ingredients 
WHERE is_active = true 
ORDER BY created_at DESC
LIMIT 5;
