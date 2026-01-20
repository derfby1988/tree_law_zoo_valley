-- ลบ trigger และ function เดิม
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- สร้าง function ใหม่ที่ดีขึ้น
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
      phone
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
      new.raw_user_meta_data->>'phone'
    );
  END IF;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- สร้าง trigger ใหม่
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ทดสอบ trigger ด้วยข้อมูลจำลอง
-- (สามารถ comment out ได้ถ้าไม่ต้องการทดสอบ)
/*
INSERT INTO auth.users (
  id, 
  email, 
  raw_user_meta_data
) VALUES (
  gen_random_uuid(),
  'test@example.com',
  '{"username": "testuser", "full_name": "Test User", "phone": "0123456789"}'
);
*/
