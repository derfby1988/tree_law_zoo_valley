-- ทำความสะอาดข้อมูลผู้ใช้ซ้ำ

-- 1. ตรวจสอบ user ที่ซ้ำ
SELECT '=== Check Duplicate Users ===' as info;
SELECT 
  au.id,
  au.email,
  au.created_at as auth_created,
  pu.created_at as public_created,
  au.raw_user_meta_data
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE au.id = '005a284b-7548-4a0a-b4cd-6793ecd7c0ba';

-- 2. ตรวจสอบว่ามี user ซ้ำกันหรือไม่
SELECT '=== All Users with Same Email ===' as info;
SELECT 
  'auth.users' as table_name,
  id,
  email,
  created_at,
  raw_user_meta_data
FROM auth.users 
WHERE email = 'apisek.pu@mail.com'
ORDER BY created_at;

SELECT 
  'public.users' as table_name,
  id,
  email,
  username,
  full_name,
  phone,
  created_at
FROM public.users 
WHERE email = 'apisek.pu@mail.com'
ORDER BY created_at;

-- 3. ลบข้อมูลซ้ำ (ถ้าจำเป็น)
-- คำเตือน: รันคำสั่งนี้เฉพาะถ้าแน่ใจว่าต้องการลบข้อมูลซ้ำ

-- 3.1 ลบข้อมูลใน public.users ที่ซ้ำกัน
SELECT '=== Delete Duplicate from public.users ===' as info;
DELETE FROM public.users 
WHERE id = '005a284b-7548-4a0a-b4cd-6793ecd7c0ba';

-- 3.2 ลบข้อมูลใน auth.users ที่ซ้ำกัน (ถ้าจำเป็น)
-- DELETE FROM auth.users 
-- WHERE id = '005a284b-7548-4a0a-b4cd-6793ecd7c0ba';

-- 4. ตรวจสอบว่าลบสำเร็จหรือไม่
SELECT '=== Check After Deletion ===' as info;
SELECT 
  'auth.users' as table_name,
  COUNT(*) as count
FROM auth.users 
WHERE id = '005a284b-7548-4a0a-b4cd-6793ecd7c0ba';

SELECT 
  'public.users' as table_name,
  COUNT(*) as count
FROM public.users 
WHERE id = '005a284b-7548-4a0a-b4cd-6793ecd7c0ba';

-- 5. ตรวจสอบ trigger ที่อาจทำงานซ้ำ
SELECT '=== Check Trigger Status ===' as info;
SELECT 
  tgname as trigger_name,
  tgenabled as is_enabled,
  tgfoid::regproc as function_name
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- 6. แก้ไข trigger ให้ไม่ทำงานซ้ำ
SELECT '=== Fix Trigger to Prevent Duplicates ===' as info;
-- ลบ trigger เก่า
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- สร้าง function ใหม่ที่มีการตรวจสอบซ้ำ
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

-- สร้าง trigger ใหม่
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 7. ตรวจสอสุดท้าย
SELECT '=== Final Status ===' as info;
SELECT 
  tgname as trigger_name,
  tgenabled as is_enabled
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

SELECT 
  proname as function_name
FROM pg_proc 
WHERE proname = 'handle_new_user';
