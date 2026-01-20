-- ตรวจสอบข้อมูลผู้ใช้ปัจจุบันสำหรับ debug หน้าโปรไฟล์

-- 1. ตรวจสอบว่ามีข้อมูลผู้ใช้ในตาราง users หรือไม่
SELECT '=== Current Users in public.users ===' as info;
SELECT 
  id,
  email,
  username,
  full_name,
  phone,
  created_at,
  updated_at
FROM public.users 
ORDER BY created_at DESC;

-- 2. ตรวจสอบ auth.users เพื่อเปรียบเทียบ
SELECT '=== Current Auth Users ===' as info;
SELECT 
  id,
  email,
  created_at,
  raw_user_meta_data
FROM auth.users 
ORDER BY created_at DESC;

-- 3. ตรวจสอบว่ามี user ไหนที่มีใน auth แต่ไม่มีใน public
SELECT '=== Users in auth but not in public ===' as info;
SELECT 
  au.id,
  au.email,
  au.created_at,
  au.raw_user_meta_data
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ORDER BY au.created_at DESC;

-- 4. ทดสอบ query ที่ใช้ใน Flutter
SELECT '=== Testing Flutter Query ===' as info;
-- แทนที่จะใช้ auth.uid() ให้ใช้ ID ของ user ล่าสุด
SELECT *
FROM public.users 
WHERE id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1);

-- 5. ตรวจสอสถานะ RLS policies หลังแก้ไข
SELECT '=== Current RLS Policies ===' as info;
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

-- 6. ทดสอบว่า user ปัจจุบันมีสิทธิ์เข้าถึงข้อมูลไหม
SELECT '=== Testing User Access ===' as info;
-- ใช้ ID ของ user ล่าสุดในการทดสอบ
SELECT 
  'Can access own data' as test,
  COUNT(*) as result
FROM public.users 
WHERE id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1);
