-- แก้ไข RLS Policies สำหรับ Avatar Upload
-- รันคำสั่งนี้ใน Supabase SQL Editor

-- 1. เปิด RLS บน storage.objects (ถ้าปิดอยู่)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 2. ลบ policies เก่าทั้งหมด (ถ้ามี)
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Public avatar access" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Avatar Upload" ON storage.objects;
DROP POLICY IF EXISTS "Avatar Update" ON storage.objects;
DROP POLICY IF EXISTS "Avatar View" ON storage.objects;
DROP POLICY IF EXISTS "Avatar Delete" ON storage.objects;

-- 3. สร้าง policies ใหม่แบบง่ายและทำงานได้จริง

-- Policy 1: ให้ authenticated users อัปโหลดไฟล์ได้
CREATE POLICY "Avatar Upload" ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
);

-- Policy 2: ให้ทุกคน (authenticated + anon) ดูไฟล์ได้
CREATE POLICY "Avatar View" ON storage.objects
FOR SELECT
USING (
    bucket_id = 'avatars'
);

-- Policy 3: ให้ authenticated users อัปเดตไฟล์ได้
CREATE POLICY "Avatar Update" ON storage.objects
FOR UPDATE
WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
);

-- Policy 4: ให้ authenticated users ลบไฟล์ได้
CREATE POLICY "Avatar Delete" ON storage.objects
FOR DELETE
USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
);

-- 4. ตรวจสอบว่า policies ถูกสร้างแล้ว
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage'
ORDER BY policyname;

-- 5. ทดสอบการทำงาน (optional)
-- สร้างข้อความแสดงว่า policies พร้อมใช้งาน
DO $$
BEGIN
    RAISE NOTICE 'RLS Policies สำหรับ Avatar Upload ถูกสร้างเรียบร้อยแล้ว';
    RAISE NOTICE 'Bucket: avatars';
    RAISE NOTICE 'Policies: Avatar Upload, Avatar View, Avatar Update, Avatar Delete';
    RAISE NOTICE 'Roles: authenticated (upload/update/delete), authenticated+anon (view)';
END $$;
