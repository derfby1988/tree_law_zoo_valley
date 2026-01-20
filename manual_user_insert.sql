-- แก้ไขปัญหาด้วยการ insert ข้อมูลด้วยตนเองหลังสมัคร

-- ค้นหาผู้ใช้ที่สมัครล่าสุดแต่ยังไม่มีในตาราง users
INSERT INTO public.users (id, email, username, full_name, phone)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'username', split_part(au.email, '@', 1)),
  COALESCE(au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'username', split_part(au.email, '@', 1)),
  au.raw_user_meta_data->>'phone'
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
AND au.created_at > NOW() - INTERVAL '1 hour';

-- ตรวจสอบผลลัพธ์
SELECT * FROM public.users ORDER BY created_at DESC LIMIT 5;

-- ถ้าต้องการแก้ไข user ที่มีอยู่แล้ว
UPDATE public.users 
SET 
  username = COALESCE(
    (SELECT raw_user_meta_data->>'username' FROM auth.users WHERE auth.users.id = users.id),
    username
  ),
  full_name = COALESCE(
    (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE auth.users.id = users.id),
    (SELECT raw_user_meta_data->>'username' FROM auth.users WHERE auth.users.id = users.id),
    full_name
  ),
  phone = COALESCE(
    (SELECT raw_user_meta_data->>'phone' FROM auth.users WHERE auth.users.id = users.id),
    phone
  )
WHERE id IN (
  SELECT au.id 
  FROM auth.users au 
  JOIN public.users pu ON au.id = pu.id
  WHERE au.raw_user_meta_data IS NOT NULL
  AND au.created_at > NOW() - INTERVAL '1 hour'
);
