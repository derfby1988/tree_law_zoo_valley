-- ตรวจสอบข้อมูลการลงทะเบียนล่าสุด

-- 1. ตรวจสอบผู้ใช้ใน auth.users ที่สร้างล่าสุด (1 ชั่วโมง)
SELECT '=== Recent Auth Users (Last 1 Hour) ===' as info;
SELECT 
  id,
  email,
  created_at,
  email_confirmed_at,
  raw_user_meta_data
FROM auth.users 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- 2. ตรวจสอบผู้ใช้ใน public.users ที่สร้างล่าสุด (1 ชั่วโมง)
SELECT '=== Recent Public Users (Last 1 Hour) ===' as info;
SELECT 
  id,
  email,
  username,
  full_name,
  phone,
  created_at
FROM public.users 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- 3. เปรียบเทียบข้อมูลระหว่าง auth.users และ public.users
SELECT '=== Data Comparison ===' as info;
SELECT 
  au.id,
  au.email,
  au.created_at as auth_created,
  pu.username,
  pu.full_name,
  pu.phone,
  pu.created_at as public_created,
  CASE 
    WHEN pu.id IS NOT NULL THEN '✅ Synced'
    ELSE '❌ Not Synced'
  END as sync_status
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE au.created_at > NOW() - INTERVAL '1 hour'
ORDER BY au.created_at DESC;

-- 4. ตรวจสอสถานะ trigger
SELECT '=== Trigger Status ===' as info;
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as is_enabled
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- 5. ตรวจสอสถานะ function
SELECT '=== Function Status ===' as info;
SELECT 
  proname as function_name,
  prosrc as source_code
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- 6. นับจำนวนผู้ใช้ทั้งหมด
SELECT '=== Total Users Count ===' as info;
SELECT 
  (SELECT COUNT(*) FROM auth.users) as total_auth_users,
  (SELECT COUNT(*) FROM public.users) as total_public_users;

-- 7. ตรวจสอบข้อมูลที่อาจมีปัญหา (users ใน auth แต่ไม่มีใน public)
SELECT '=== Orphaned Auth Users ===' as info;
SELECT 
  au.id,
  au.email,
  au.created_at,
  au.raw_user_meta_data
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
AND au.created_at > NOW() - INTERVAL '24 hours'
ORDER BY au.created_at DESC;
