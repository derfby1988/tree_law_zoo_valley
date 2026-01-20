-- ปิดการยืนยันอีเมลชั่วคราวเพื่อทดสอบ
-- (ใช้เฉพาะตอน development เท่านั้น!)

-- ตรวจสอบการตั้งค่าปัจจุบัน
SELECT * FROM auth.config WHERE key = 'site_url';

-- ปิดการยืนยันอีเมล (development mode)
UPDATE auth.config 
SET value = 'false' 
WHERE key = 'enable_email_confirmations';

-- หรือตั้งค่าให้ skip email confirmation
UPDATE auth.config 
SET value = 'true' 
WHERE key = 'disable_signup';

-- ตรวจสอบค่าที่เปลี่ยนแปลง
SELECT * FROM auth.config WHERE key IN ('enable_email_confirmations', 'disable_signup');

-- หมายเหตุ: วิธีนี้เหมาะสำหรับ development เท่านั้น
-- ใน production ควรเปิด email confirmation ไว้เพื่อความปลอดภัย
