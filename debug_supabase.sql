-- ตรวจสอบสถานะปัจจุบัน
SELECT '=== Current users table ===' as info;
SELECT * FROM public.users LIMIT 5;

SELECT '=== Auth users ===' as info;
SELECT id, email, created_at FROM auth.users ORDER BY created_at DESC LIMIT 5;

SELECT '=== Trigger status ===' as info;
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgfoid::regproc as function_name,
  tgenabled as is_enabled
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

SELECT '=== Function status ===' as info;
SELECT 
  proname as function_name,
  prosrc as source_code
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- ทดสอบ trigger ด้วยข้อมูลจริง
-- (รันคำสั่งนี้เพื่อดูว่า trigger ทำงานหรือไม่)
SELECT '=== Testing trigger ===' as info;

-- ลบข้อมูลทดสอบถ้ามี
DELETE FROM public.users WHERE email LIKE 'test%@example.com';

-- สร้างข้อมูลทดสอบใน auth.users
INSERT INTO auth.users (
  id, 
  email, 
  raw_user_meta_data,
  created_at
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'test123@example.com',
  '{"username": "testuser123", "full_name": "Test User 123", "phone": "0123456789"}',
  NOW()
) ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  raw_user_meta_data = EXCLUDED.raw_user_meta_data;

-- ตรวจสอบผลลัพธ์
SELECT '=== After trigger test ===' as info;
SELECT * FROM public.users WHERE email = 'test123@example.com';

-- ลบข้อมูลทดสอบ
DELETE FROM auth.users WHERE email = 'test123@example.com';
DELETE FROM public.users WHERE email = 'test123@example.com';
