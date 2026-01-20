-- คำแนะนำในการเปลี่ยนแปลงอีเมล (ถ้าจำเป็น)

-- 1. ตรวจสอบว่าสามารถเปลี่ยนแปลงอีเมลได้หรือไม่
SELECT '=== Check Email Change Capability ===' as info;
SELECT 
  'อีเมลเป็น Primary Key' as note,
  'ไม่สามารถแก้ไขโดยตรง' as limitation,
  'ต้องใช้ Supabase Auth API' as solution;

-- 2. ตรวจสอบสถานะปัจจุบันของผู้ใช้
SELECT '=== Current User Info ===' as info;
SELECT 
  au.id,
  au.email,
  au.created_at,
  pu.username,
  pu.full_name,
  pu.phone
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE au.email = 'current-email@example.com'; -- แทนที่ด้วยอีเมลปัจจุบัน

-- 3. แนะนำให้ใช้วิธีที่ปลอดภัยกว่า
SELECT '=== Recommended Approach ===' as info;
SELECT 
  '1. สร้างบัญชีใหม่' as step1,
  '2. โอนย้ายข้อมูล (ถ้าจำเป็น)' as step2,
  '3. ลบบัญชีเก่า' as step3,
  '4. ใช้บัญชีใหม่' as step4;

-- 4. ถ้าจำเป็นต้องเปลี่ยน - ใช้ Flutter code
-- ไม่สามารถทำใน SQL ได้ ต้องใช้ Supabase Auth API
-- ตัวอย่าง code:
/*
await SupabaseService.client.auth.updateUser(
  UserAttributes(email: 'new-email@example.com')
);
*/

-- 5. ตรวจสอบว่ามีการ backup ข้อมูลหรือไม่
SELECT '=== Backup Check ===' as info;
SELECT 
  'ควรมี backup ข้อมูลก่อนเปลี่ยนแปลง' as warning,
  'อาจสูญเสียข้อมูลได้' as risk,
  'ทดสอบในสภาพแวดล้อมทดสอบก่อน' as advice;

-- 6. ทางเลือกอื่นๆ
SELECT '=== Alternative Solutions ===' as info;
SELECT 
  'เพิ่มฟิลด์ secondary_email' as option1,
  'เพิ่มฟิลด์ contact_email' as option2,
  'ใช้ฟิลด์ phone เป็นตัวตนทางเลือก' as option3;
