-- แก้ไข RLS policy ให้ครอบคลุม UPDATE/INSERT/DELETE

-- 1. ลบ policy เดิม
DROP POLICY IF EXISTS "Allow read access for all users" ON inventory_ingredients;
DROP POLICY IF EXISTS "Allow all access for authenticated users" ON inventory_ingredients;

-- 2. สร้าง policy ใหม่ที่ครอบคลุมทั้งหมด
-- SELECT: ทุกคนอ่านได้
CREATE POLICY "ingredients_select" ON inventory_ingredients
  FOR SELECT USING (true);

-- INSERT: authenticated users เท่านั้น
CREATE POLICY "ingredients_insert" ON inventory_ingredients
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- UPDATE: authenticated users เท่านั้น
CREATE POLICY "ingredients_update" ON inventory_ingredients
  FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- DELETE: authenticated users เท่านั้น
CREATE POLICY "ingredients_delete" ON inventory_ingredients
  FOR DELETE USING (auth.role() = 'authenticated');

-- 3. ตรวจสอบ policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'inventory_ingredients';

-- 4. ทดสอบ update
UPDATE inventory_ingredients SET updated_at = NOW() WHERE id = (SELECT id FROM inventory_ingredients LIMIT 1);
SELECT id, name, shelf_id, updated_at FROM inventory_ingredients ORDER BY updated_at DESC LIMIT 3;
