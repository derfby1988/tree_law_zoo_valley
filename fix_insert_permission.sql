-- แก้ไขปัญหา INSERT permission สำหรับการสมัครสมาชิก

-- 1. ตรวจสอสถานะปัจจุบัน
SELECT '=== Current RLS Status ===' as info;
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'users';

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

-- 2. แก้ไขปัญหา: ปิด RLS ชั่วคราวเพื่อทดสอบ
-- (ใช้เฉพาะตอน development)
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 3. ทดสออการสร้าง user ใหม่
SELECT '=== Test New User Creation ===' as info;
-- สร้าง user ทดสอบใหม่
INSERT INTO auth.users (
  id, 
  email, 
  created_at,
  raw_user_meta_data
) VALUES (
  gen_random_uuid(),
  'test2@example.com',
  NOW(),
  '{"username": "testuser2", "full_name": "Test User 2", "phone": "0987654321"}'
) ON CONFLICT (id) DO NOTHING;

-- 4. ทดสออ trigger ทำงานหรือไม่
SELECT '=== Check if Trigger Works ===' as info;
SELECT 
  'auth.users' as table_name,
  COUNT(*) as count
FROM auth.users 
WHERE email = 'test2@example.com';

SELECT 
  'public.users' as table_name,
  COUNT(*) as count
FROM public.users 
WHERE email = 'test2@example.com';

-- 5. ถ้ายังไม่ทำงาน ให้สร้างข้อมูลด้วยตรง
SELECT '=== Manual Insert (if trigger fails) ===' as info;
INSERT INTO public.users (
  id, 
  email, 
  username, 
  full_name, 
  phone,
  created_at,
  updated_at
) VALUES (
  (SELECT id FROM auth.users WHERE email = 'test2@example.com' LIMIT 1),
  (SELECT email FROM auth.users WHERE email = 'test2@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'username' FROM auth.users WHERE email = 'test2@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE email = 'test2@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'phone' FROM auth.users WHERE email = 'test2@example.com' LIMIT 1),
  NOW(),
  NOW()
);

-- 6. ตรวจสอบผลลัพธ์
SELECT '=== Final Test Result ===' as info;
SELECT * FROM public.users WHERE email = 'test2@example.com';

-- 7. ลบข้อมูลทดสอบ
DELETE FROM auth.users WHERE email = 'test2@example.com';
DELETE FROM public.users WHERE email = 'test2@example.com';

-- 8. เปิด RLS ใหม่ (แต่แก้ไข policies)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 9. สร้าง policies ใหม่ที่ง่ายกว่า
DROP POLICY IF EXISTS "Enable read access for all users based on user_id" ON users;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON users;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON users;

-- 10. สร้าง policies ใหม่ที่ง่ายและชัดเจน
-- Policy สำหรับ SELECT (ดูข้อมูลตัวเอง)
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

-- Policy สำหรับ UPDATE (อัพเดทตัวเอง)
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Policy สำหรับ INSERT (สร้างข้อมูลตัวเอง) - แก้ไขใหม่
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (true); -- อนุญาติให้ insert ได้เลย

-- 11. ตรวจสอสุดท้าย
SELECT '=== Final Status ===' as info;
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename = 'users';
