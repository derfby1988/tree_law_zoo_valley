-- แก้ไขปัญหา permission denied for table users (แก้ไข column name)

-- 1. ตรวจสอบสถานะปัจจุบัน
SELECT '=== Current RLS Status ===' as info;
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'users';

-- 2. ตรวจสอบ policies ปัจจุบัน
SELECT '=== Current Policies ===' as info;
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

-- 3. ตรวจสอบว่า RLS เปิดอยู่หรือไม่
SELECT '=== RLS Enabled Check ===' as info;
SELECT 
  relname as table_name,
  relrowsecurity as rls_enabled
FROM pg_class 
WHERE relname = 'users';

-- 4. แก้ไขปัญหา: เปิด RLS และสร้าง policies ใหม่
-- 4.1 เปิด RLS บนตาราง users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 4.2 ลบ policies เก่าทั้งหมด
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Enable read access for all users based on user_id" ON users;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON users;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON users;

-- 4.3 สร้าง policies ใหม่ที่ง่ายและชัดเจน
-- Policy สำหรับ SELECT (ดูข้อมูลตัวเอง)
CREATE POLICY "Enable read access for all users based on user_id" ON users
  FOR SELECT USING (auth.uid() = id);

-- Policy สำหรับ UPDATE (อัพเดทตัวเอง)
CREATE POLICY "Enable update for users based on user_id" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Policy สำหรับ INSERT (สร้างข้อมูลตัวเอง)
CREATE POLICY "Enable insert for authenticated users" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- 5. ทดสออว่า user ปัจจุบันมีสิทธิ์หรือไม่
SELECT '=== Permission Test ===' as info;
-- ทดสออด้วย user ID ปัจจุบัน (ต้องแทนที่ด้วย ID จริง)
SELECT 
  'Testing SELECT permission' as test,
  COUNT(*) as result
FROM users 
WHERE id = auth.uid();

-- 6. ถ้ายังไม่ได้ ลองปิด RLS ชั่วคราวเพื่อทดสอบ
-- (ใช้เฉพาะตอน development)
-- ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 7. ตรวจสอสุดท้าย
SELECT '=== Final Status ===' as info;
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename = 'users';

-- 8. ทดสออ query ง่ายๆ
SELECT '=== Simple Query Test ===' as info;
SELECT COUNT(*) as total_users FROM users;
