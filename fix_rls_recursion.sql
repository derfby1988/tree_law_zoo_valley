-- แก้ไขปัญหา infinite recursion ใน RLS policies

-- 1. ลบ policies เดิมที่มีปัญหา
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;

-- 2. สร้าง policies ใหม่ที่ไม่มี recursion

-- Policy สำหรับดูข้อมูลตัวเอง
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

-- Policy สำหรับอัพเดทข้อมูลตัวเอง
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Policy สำหรับ Admin ดูข้อมูลทุกคน (แก้ไข recursion)
CREATE POLICY "Admins can view all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 
      FROM auth.users 
      WHERE id = auth.uid() 
      AND raw_user_meta_data->>'role' = 'admin'
    )
  );

-- 3. เพิ่ม policy สำหรับ insert (ถ้าจำเป็น)
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- 4. ตรวจสอสถานะ policies หลังแก้ไข
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'users';

-- 5. ทดสออ query ง่ายๆ เพื่อยืนยันว่าไม่มี recursion
SELECT 'Testing user access...' as test;
SELECT COUNT(*) as total_users FROM users;

-- ถ้ามีข้อมูล ลอง query แบบมีเงื่อนไข
SELECT 'Testing admin access...' as test;
-- สำหรับ admin ควรเห็นทุกคน
-- สำหรับ user ธรรมดาควรเห็นแค่ตัวเอง
