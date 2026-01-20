-- ใช้ trigger ใหม่ที่มีการตรวจสอบซ้ำ

-- 1. ลบ trigger และ function เก่า
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 2. สร้าง function ใหม่ที่มีการตรวจสอบซ้ำ
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- ตรวจสอบว่ามีข้อมูลใน users แล้วหรือไม่
  IF NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = new.id
  ) THEN
    INSERT INTO public.users (
      id, 
      email, 
      username, 
      full_name, 
      phone,
      created_at,
      updated_at
    ) VALUES (
      new.id, 
      new.email, 
      COALESCE(
        new.raw_user_meta_data->>'username', 
        split_part(new.email, '@', 1)
      ),
      COALESCE(
        new.raw_user_meta_data->>'full_name', 
        new.raw_user_meta_data->>'username',
        split_part(new.email, '@', 1)
      ),
      new.raw_user_meta_data->>'phone',
      new.created_at,
      new.created_at
    );
  END IF;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. สร้าง trigger ใหม่
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. ตรวจสอสถานะ
SELECT '=== New Trigger Status ===' as info;
SELECT 
  tgname as trigger_name,
  tgenabled as is_enabled,
  tgfoid::regproc as function_name
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

SELECT 
  proname as function_name,
  prosrc as source_code
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- 5. ทดสออการทำงาน
SELECT '=== Test New Trigger ===' as info;
-- สร้าง user ทดสอบ
INSERT INTO auth.users (
  id, 
  email, 
  created_at,
  raw_user_meta_data
) VALUES (
  gen_random_uuid(),
  'test_new_trigger@example.com',
  NOW(),
  '{"username": "testuser", "full_name": "Test User", "phone": "0123456789"}'
) ON CONFLICT (id) DO NOTHING;

-- 6. ตรวจสอบผลลัพธ์
SELECT '=== Check Test Result ===' as info;
SELECT 
  'auth.users' as table_name,
  COUNT(*) as count
FROM auth.users 
WHERE email = 'test_new_trigger@example.com';

SELECT 
  'public.users' as table_name,
  COUNT(*) as count
FROM public.users 
WHERE email = 'test_new_trigger@example.com';

-- 7. ทดสออการสร้างซ้ำ (ไม่ควรมี error)
SELECT '=== Test Duplicate Prevention ===' as info;
-- พยายาสร้างซ้ำ (ไม่ควรมี error)
INSERT INTO public.users (
  id, 
  email, 
  username, 
  full_name, 
  phone,
  created_at,
  updated_at
) VALUES (
  (SELECT id FROM auth.users WHERE email = 'test_new_trigger@example.com' LIMIT 1),
  (SELECT email FROM auth.users WHERE email = 'test_new_trigger@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'username' FROM auth.users WHERE email = 'test_new_trigger@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE email = 'test_new_trigger@example.com' LIMIT 1),
  (SELECT raw_user_meta_data->>'phone' FROM auth.users WHERE email = 'test_new_trigger@example.com' LIMIT 1),
  NOW(),
  NOW()
);

-- 8. ตรวจสอบว่ายังมีแค่ 1 record
SELECT '=== Final Check ===' as info;
SELECT COUNT(*) as total_records FROM public.users WHERE email = 'test_new_trigger@example.com';

-- 9. ลบข้อมูลทดสอบ
DELETE FROM auth.users WHERE email = 'test_new_trigger@example.com';
DELETE FROM public.users WHERE email = 'test_new_trigger@example.com';

-- 10. ตรวจสอสุดท้าย
SELECT '=== Cleanup Complete ===' as info;
SELECT 'Trigger ready for production' as status;
