-- แก้ไขปัญหา Database error saving new user

-- 1. ตรวจอสถานะ trigger และ policies
SELECT '=== Trigger Status ===' as info;
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as is_enabled,
  tgfoid::regproc as function_name
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

SELECT '=== RLS Policies ===' as info;
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

-- 2. ตรวจอสถานะตาราง users
SELECT '=== Table Status ===' as info;
SELECT 
  schemaname,
  tablename,
  hasindexes,
  hasrules,
  hastriggers,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'users';

-- 3. ตรวจสอสถานะ function
SELECT '=== Function Status ===' as info;
SELECT 
  proname as function_name,
  prosrc as source_code,
  prolang
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- 4. ทดสออการสร้าง user ด้วยตรง
SELECT '=== Test User Creation ===' as info;
-- สร้าง user ทดสอบ
INSERT INTO auth.users (
  id, 
  email, 
  created_at,
  raw_user_meta_data
) VALUES (
  gen_random_uuid(),
  'test@example.com',
  NOW(),
  '{"username": "testuser", "full_name": "Test User", "phone": "0123456789"}'
) ON CONFLICT (id) DO NOTHING;

-- 5. ตรวจสอบว่า user ถูกสร้างใน public.users หรือไม่
SELECT '=== Check Test User ===' as info;
SELECT 
  'auth.users' as table_name,
  COUNT(*) as count
FROM auth.users 
WHERE email = 'test@example.com';

SELECT 
  'public.users' as table_name,
  COUNT(*) as count
FROM public.users 
WHERE email = 'test@example.com';

-- 6. ทดสออการลบ trigger ด้วยตรง
SELECT '=== Manual Trigger Test ===' as info;
-- ลบข้อมูลทดสอบ
DELETE FROM public.users WHERE email = 'test@example.com';

-- สร้างข้อมูลใน public.users ด้วยตรง (จำลองว่า trigger ทำงานหรือไม่)
INSERT INTO public.users (
  id, 
  email, 
  username, 
  full_name, 
  phone,
  created_at,
  updated_at
) VALUES (
  (SELECT id FROM auth.users WHERE email = 'test@example.com' LIMIT 1),
  (SELECT email FROM auth.users WHERE email = 'test@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'username' FROM auth.users WHERE email = 'test@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE email = 'test@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'phone' FROM auth.users WHERE email = 'test@example.com' LIMIT 1),
  NOW(),
  NOW()
);

-- 7. ตรวจสอบผลลัพธ์
SELECT '=== Test Result ===' as info;
SELECT * FROM public.users WHERE email = 'test@example.com';

-- 8. ลบข้อมูลทดสอบ
DELETE FROM auth.users WHERE email = 'test@example.com';
DELETE FROM public.users WHERE email = 'test@example.com';
