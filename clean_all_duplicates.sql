-- ทำความสะอาดข้อมูลซ้ำทั้งหมด

-- 1. ตรวจสอบ user ที่มีปัญหา
SELECT '=== Check Problematic User ===' as info;
SELECT 
  au.id,
  au.email,
  au.created_at as auth_created,
  pu.created_at as public_created,
  CASE 
    WHEN pu.id IS NOT NULL THEN 'Exists in public.users'
    ELSE 'Missing in public.users'
  END as status
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE au.id = 'a8996a10-9e60-4caf-badf-2fc401eff732';

-- 2. ตรวจสอบว่ามีข้อมูลซ้ำกันหรือไม่
SELECT '=== Check All Duplicates ===' as info;
SELECT 
  au.id,
  au.email,
  COUNT(pu.id) as public_user_count,
  COUNT(au.id) as auth_user_count
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
GROUP BY au.id, au.email
HAVING COUNT(pu.id) > 1 OR COUNT(au.id) > 1;

-- 3. ลบข้อมูลซ้ำทั้งหมด
SELECT '=== Clean All Duplicates ===' as info;

-- 3.1 ลบข้อมูลใน public.users ที่มีปัญหา
DELETE FROM public.users 
WHERE id = 'a8996a10-9e60-4caf-badf-2fc401eff732';

-- 3.2 หรือลบทั้งหมดที่อาจมีปัญหา
-- DELETE FROM public.users WHERE id IN (
--   SELECT id FROM auth.users WHERE email = 'apisek.pu@mail.com'
-- );

-- 4. ตรวจสอบว่าลบสำเร็จหรือไม่
SELECT '=== Check After Deletion ===' as info;
SELECT 
  'auth.users' as table_name,
  COUNT(*) as count
FROM auth.users 
WHERE id = 'a8996a10-9e60-4caf-badf-2fc401eff732';

SELECT 
  'public.users' as table_name,
  COUNT(*) as count
FROM public.users 
WHERE id = 'a8996a10-9e60-4caf-badf-2fc401eff732';

-- 5. ปิด RLS ชั่วคราวเพื่อทำความสะอาด
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 6. สร้างข้อมูลที่หายไป (ถ้าจำเป็น)
SELECT '=== Create Missing Data ===' as info;
INSERT INTO public.users (
  id, 
  email, 
  username, 
  full_name, 
  phone,
  created_at,
  updated_at
) 
SELECT 
  au.id,
  au.email,
  COALESCE(
    au.raw_user_meta_data->>'username', 
    split_part(au.email, '@', 1)
  ),
  COALESCE(
    au.raw_user_meta_data->>'full_name', 
    au.raw_user_meta_data->>'username',
    split_part(au.email, '@', 1)
  ),
  au.raw_user_meta_data->>'phone',
  au.created_at,
  au.created_at
FROM auth.users au
WHERE au.id = 'a8996a10-9e60-4caf-badf-2fc401eff732'
AND NOT EXISTS (
  SELECT 1 FROM public.users pu WHERE pu.id = au.id
);

-- 7. เปิด RLS ใหม่
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 8. ตรวจสอบสุดท้าย
SELECT '=== Final Check ===' as info;
SELECT 
  au.id,
  au.email,
  pu.username,
  pu.full_name,
  pu.phone,
  pu.created_at as public_created
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE au.id = 'a8996a10-9e60-4caf-badf-2fc401eff732';

-- 9. ทดสออการสมัครใหม่
SELECT '=== Test New Registration ===' as info;
-- สร้าง user ทดสอบใหม่
INSERT INTO auth.users (
  id, 
  email, 
  created_at,
  raw_user_meta_data
) VALUES (
  gen_random_uuid(),
  'test_clean@example.com',
  NOW(),
  '{"username": "testclean", "full_name": "Test Clean", "phone": "0123456789"}'
) ON CONFLICT (id) DO NOTHING;

-- 10. ตรวจสอบว่า trigger ทำงาน
SELECT '=== Check Trigger Result ===' as info;
SELECT 
  'auth.users' as table_name,
  COUNT(*) as count
FROM auth.users 
WHERE email = 'test_clean@example.com';

SELECT 
  'public.users' as table_name,
  COUNT(*) as count
FROM public.users 
WHERE email = 'test_clean@example.com';

-- 11. ลบข้อมูลทดสอบ
DELETE FROM auth.users WHERE email = 'test_clean@example.com';
DELETE FROM public.users WHERE email = 'test_clean@example.com';

-- 12. สรุปสถานะ
SELECT '=== Summary ===' as info;
SELECT 
  'Cleanup completed' as status,
  'Ready for new registration' as message;
