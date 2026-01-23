-- ตรวจสอบสถานะ RLS บน storage.objects
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'objects' AND schemaname = 'storage';

-- ตรวจสอบ policies ทั้งหมดบน storage.objects
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage';

-- ตรวจสอบ bucket ทั้งหมด
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at
FROM storage.buckets
WHERE name = 'avatars';

-- ตรวจสอบ policies ที่เกี่ยวข้องกับ bucket 'avatars'
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'objects' 
  AND schemaname = 'storage'
  AND (qual ILIKE '%avatars%' OR with_check ILIKE '%avatars%');

-- ตรวจสอบว่า user ปัจจุบันมี permission อะไรบ้าง
SELECT 
    current_user,
    session_user,
    has_table_privilege('storage.objects', 'SELECT') as can_select,
    has_table_privilege('storage.objects', 'INSERT') as can_insert,
    has_table_privilege('storage.objects', 'UPDATE') as can_update,
    has_table_privilege('storage.objects', 'DELETE') as can_delete;
