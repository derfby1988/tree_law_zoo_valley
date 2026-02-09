-- ตรวจสอบ RLS และเปิดสิทธิ์ให้อ่านข้อมูลได้

-- 1. ตรวจสอบว่า RLS เปิดอยู่หรือไม่
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'inventory_ingredients';

-- 2. ปิด RLS (ถ้าเปิดอยู่) หรือเพิ่ม policy
ALTER TABLE inventory_ingredients ENABLE ROW LEVEL SECURITY;

-- 3. สร้าง policy ให้ทุกคนอ่านได้
CREATE POLICY "Allow read access for all users" ON inventory_ingredients
  FOR SELECT USING (true);

-- 4. สร้าง policy ให้ authenticated users แก้ไขได้
CREATE POLICY "Allow all access for authenticated users" ON inventory_ingredients
  FOR ALL USING (auth.role() = 'authenticated');

-- 5. ตรวจสอบข้อมูล
SELECT COUNT(*) as total FROM inventory_ingredients WHERE is_active = true;
