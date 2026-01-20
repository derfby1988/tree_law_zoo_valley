-- ตรวจสอบข้อมูล "firm" ว่ามาจากไหน

-- 1. ตรวจสอบข้อมูลในตาราง public.users
SELECT '=== Checking public.users for "firm" ===' as info;
SELECT 
  id,
  email,
  username,
  full_name,
  phone,
  created_at,
  updated_at
FROM public.users 
WHERE username = 'firm' 
   OR full_name = 'firm'
   OR email LIKE '%firm%'
ORDER BY created_at DESC;

-- 2. ตรวจสอบข้อมูลใน auth.users metadata
SELECT '=== Checking auth.users metadata for "firm" ===' as info;
SELECT 
  id,
  email,
  created_at,
  raw_user_meta_data
FROM auth.users 
WHERE raw_user_meta_data->>'username' = 'firm'
   OR raw_user_meta_data->>'full_name' = 'firm'
   OR email LIKE '%firm%'
ORDER BY created_at DESC;

-- 3. ตรวจสอบ user ที่ล็อกอินอยู่ปัจจุบัน
SELECT '=== Current User Check ===' as info;
SELECT 
  'Current user ID:' as info,
  auth.uid() as current_user_id;

-- 4. ตรวจสอบข้อมูลของ user ปัจจุบัน
SELECT '=== Current User Data ===' as info;
SELECT 
  pu.id,
  pu.email,
  pu.username,
  pu.full_name,
  pu.phone,
  pu.created_at,
  au.raw_user_meta_data
FROM public.users pu
JOIN auth.users au ON pu.id = au.id
WHERE pu.id = auth.uid();

-- 5. ตรวจสอบว่ามีการลงทะเบียนด้วย "firm" หรือไม่
SELECT '=== Registration History ===' as info;
SELECT 
  au.email,
  au.created_at,
  au.raw_user_meta_data,
  pu.username,
  pu.full_name
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE au.created_at > NOW() - INTERVAL '7 days'
ORDER BY au.created_at DESC;
