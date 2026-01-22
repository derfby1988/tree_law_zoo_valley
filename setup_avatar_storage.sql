-- สร้าง bucket สำหรับเก็บรูปโปรไฟล์
-- วิธีที่ 1: ใช้ Supabase Dashboard (แนะนำ)
-- 1. ไปที่ Supabase Dashboard -> Storage
-- 2. คลิก "New bucket"
-- 3. ชื่อ: avatars
-- 4. Public bucket: เลือก "Public"
-- 5. File size limit: 52428800 (50MB)
-- 6. Allowed MIME types: image/jpeg, image/png, image/gif, image/webp, image/bmp

-- วิธีที่ 2: ใช้ SQL (ถ้ามี permission)
-- ถ้า error "must be owner of table objects" ให้ใช้ Dashboard แทน

-- สร้าง bucket สำหรับ avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars', 
  'avatars', 
  true, 
  52428800, -- 50MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp']
) ON CONFLICT (id) DO NOTHING;

-- สร้าง Row Level Security (RLS) policies
-- ถ้า error ให้ใช้ Dashboard แทน SQL

-- 2.1 ให้ผู้ใช้สามารถอัปโหลดรูปของตัวเองได้
CREATE POLICY "Users can upload their own avatar" ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 2.2 ให้ผู้ใช้สามารถอัปเดตรูปของตัวเองได้
CREATE POLICY "Users can update their own avatar" ON storage.objects
FOR UPDATE
WITH CHECK (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 2.3 ให้ผู้ใช้สามารถดูรูปของตัวเองได้
CREATE POLICY "Users can view their own avatar" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 2.4 ให้ทุกคนสามารถดูรูปโปรไฟล์ได้ (public access)
CREATE POLICY "Public avatar access" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'avatars'
);

-- 2.5 ให้ผู้ใช้สามารถลบรูปของตัวเองได้
CREATE POLICY "Users can delete their own avatar" ON storage.objects
FOR DELETE
USING (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. เปิดใช้งาน RLS บน storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 4. สร้าง function ช่วยในการตรวจสอบ folder name
CREATE OR REPLACE FUNCTION storage.foldername(text)
RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT string_to_array($1, '/') 
$$;

-- 5. ทดสอบการทำงาน (optional)
-- คุณสามารถทดสอบโดยการอัปโหลดไฟล์ผ่าน Supabase Dashboard หรือใช้คำสั่ง:
-- SELECT * FROM storage.buckets WHERE id = 'avatars';
-- SELECT * FROM storage.policies WHERE bucket_id = 'avatars';

-- 6. ตรวจสอบ permissions
-- หลังจากรันคำสั่งนี้ ให้ตรวจสอบว่า bucket ถูกสร้างและมี policies ครบถ้วน
-- SELECT * FROM storage.buckets WHERE name = 'avatars';
-- SELECT * FROM storage.policies WHERE bucket_id = 'avatars';
