-- =============================================
-- เพิ่มระบบประเภทสินค้าแบบ Hierarchical
-- ตามมาตรฐานบัญชีสินค้า
-- รันใน Supabase SQL Editor
-- =============================================

-- Step 1: เพิ่ม columns สำหรับ hierarchy
ALTER TABLE public.inventory_categories
  ADD COLUMN IF NOT EXISTS code TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS parent_code TEXT,
  ADD COLUMN IF NOT EXISTS level INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

-- Step 2: เพิ่ม FK สำหรับ parent_code
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inventory_categories_parent_code_fkey'
  ) THEN
    ALTER TABLE public.inventory_categories
      ADD CONSTRAINT inventory_categories_parent_code_fkey
      FOREIGN KEY (parent_code) REFERENCES public.inventory_categories(code) ON DELETE SET NULL;
  END IF;
END $$;

-- Step 3: เพิ่มข้อมูลมาตรฐานประเภทสินค้า
-- ระดับ 1: หมวดหลัก
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-0-00-00-00', 'สินค้า', 1, 1, NULL, '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 2: หมวดย่อย
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-00-00-00', 'การเกษตร', 2, 10, '1-0-00-00-00', '1001', '4001', '5001'),
  ('1-2-00-00-00', 'อุตสาหกรรม', 2, 20, '1-0-00-00-00', '1001', '4001', '5001'),
  ('1-3-00-00-00', 'อาหารและเครื่องดื่ม', 2, 30, '1-0-00-00-00', '1001', '4001', '5001'),
  ('1-4-00-00-00', 'บรรจุภัณฑ์และวัสดุสิ้นเปลือง', 2, 40, '1-0-00-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 3: การเกษตร
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-01-00-00', 'พืชอาหารและพืชอาหารสัตว์', 3, 100, '1-1-00-00-00', '1001', '4001', '5001'),
  ('1-1-02-00-00', 'สัตว์มีชีวิตและผลิตภัณฑ์จากสัตว์', 3, 200, '1-1-00-00-00', '1001', '4001', '5001'),
  ('1-1-03-00-00', 'ผลิตภัณฑ์ป่าไม้', 3, 300, '1-1-00-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 4: พืชอาหาร
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-01-01-00', 'ข้าว', 4, 110, '1-1-01-00-00', '1001', '4001', '5001'),
  ('1-1-01-02-00', 'ผักและพืชผัก', 4, 120, '1-1-01-00-00', '1001', '4001', '5001'),
  ('1-1-01-03-00', 'ผลไม้', 4, 130, '1-1-01-00-00', '1001', '4001', '5001'),
  ('1-1-01-04-00', 'ธัญพืชและถั่ว', 4, 140, '1-1-01-00-00', '1001', '4001', '5001'),
  ('1-1-01-05-00', 'เครื่องเทศและสมุนไพร', 4, 150, '1-1-01-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 5: ข้าว (ย่อย)
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-01-01-01', 'ข้าวเปลือกจ้าว', 5, 111, '1-1-01-01-00', '1001', '4001', '5001'),
  ('1-1-01-01-02', 'ข้าวเปลือกหอมมะลิ', 5, 112, '1-1-01-01-00', '1001', '4001', '5001'),
  ('1-1-01-01-03', 'ข้าวเปลือกเหนียว', 5, 113, '1-1-01-01-00', '1001', '4001', '5001'),
  ('1-1-01-01-04', 'ข้าวสารเจ้า', 5, 114, '1-1-01-01-00', '1001', '4001', '5001'),
  ('1-1-01-01-05', 'ข้าวสารหอมมะลิ', 5, 115, '1-1-01-01-00', '1001', '4001', '5001'),
  ('1-1-01-01-06', 'ข้าวสารเหนียว', 5, 116, '1-1-01-01-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 4: สัตว์มีชีวิตและผลิตภัณฑ์จากสัตว์
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-02-01-00', 'เนื้อสัตว์', 4, 210, '1-1-02-00-00', '1001', '4001', '5001'),
  ('1-1-02-02-00', 'อาหารทะเล', 4, 220, '1-1-02-00-00', '1001', '4001', '5001'),
  ('1-1-02-03-00', 'ไข่และผลิตภัณฑ์นม', 4, 230, '1-1-02-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 5: เนื้อสัตว์ (ย่อย)
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-02-01-01', 'เนื้อหมู', 5, 211, '1-1-02-01-00', '1001', '4001', '5001'),
  ('1-1-02-01-02', 'เนื้อวัว', 5, 212, '1-1-02-01-00', '1001', '4001', '5001'),
  ('1-1-02-01-03', 'เนื้อไก่', 5, 213, '1-1-02-01-00', '1001', '4001', '5001'),
  ('1-1-02-01-04', 'เนื้อเป็ด', 5, 214, '1-1-02-01-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 5: อาหารทะเล (ย่อย)
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-02-02-01', 'กุ้ง', 5, 221, '1-1-02-02-00', '1001', '4001', '5001'),
  ('1-1-02-02-02', 'ปลา', 5, 222, '1-1-02-02-00', '1001', '4001', '5001'),
  ('1-1-02-02-03', 'ปลาหมึก', 5, 223, '1-1-02-02-00', '1001', '4001', '5001'),
  ('1-1-02-02-04', 'หอย', 5, 224, '1-1-02-02-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 5: ไข่และนม (ย่อย)
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-1-02-03-01', 'ไข่ไก่', 5, 231, '1-1-02-03-00', '1001', '4001', '5001'),
  ('1-1-02-03-02', 'นมสด', 5, 232, '1-1-02-03-00', '1001', '4001', '5001'),
  ('1-1-02-03-03', 'เนย', 5, 233, '1-1-02-03-00', '1001', '4001', '5001'),
  ('1-1-02-03-04', 'ชีส', 5, 234, '1-1-02-03-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 3: อาหารและเครื่องดื่ม
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-3-01-00-00', 'อาหารสำเร็จรูป', 3, 310, '1-3-00-00-00', '1001', '4001', '5001'),
  ('1-3-02-00-00', 'เครื่องดื่ม', 3, 320, '1-3-00-00-00', '1001', '4001', '5001'),
  ('1-3-03-00-00', 'ขนมและเบเกอรี่', 3, 330, '1-3-00-00-00', '1001', '4001', '5001'),
  ('1-3-04-00-00', 'เครื่องปรุงรส', 3, 340, '1-3-00-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 4: เครื่องดื่ม (ย่อย)
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-3-02-01-00', 'เครื่องดื่มร้อน', 4, 321, '1-3-02-00-00', '1001', '4001', '5001'),
  ('1-3-02-02-00', 'เครื่องดื่มเย็น', 4, 322, '1-3-02-00-00', '1001', '4001', '5001'),
  ('1-3-02-03-00', 'เครื่องดื่มแอลกอฮอร์', 4, 323, '1-3-02-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 5: เครื่องดื่มร้อน (ย่อย)
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-3-02-01-01', 'กาแฟ', 5, 3211, '1-3-02-01-00', '1001', '4001', '5001'),
  ('1-3-02-01-02', 'ชา', 5, 3212, '1-3-02-01-00', '1001', '4001', '5001'),
  ('1-3-02-01-03', 'โกโก้', 5, 3213, '1-3-02-01-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 4: เครื่องปรุงรส (ย่อย)
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-3-04-01-00', 'น้ำตาล', 4, 341, '1-3-04-00-00', '1001', '4001', '5001'),
  ('1-3-04-02-00', 'เกลือ', 4, 342, '1-3-04-00-00', '1001', '4001', '5001'),
  ('1-3-04-03-00', 'ซอส', 4, 343, '1-3-04-00-00', '1001', '4001', '5001'),
  ('1-3-04-04-00', 'น้ำมันพืช', 4, 344, '1-3-04-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ระดับ 3: บรรจุภัณฑ์
INSERT INTO public.inventory_categories (code, name, level, sort_order, parent_code, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  ('1-4-01-00-00', 'บรรจุภัณฑ์', 3, 410, '1-4-00-00-00', '1001', '4001', '5001'),
  ('1-4-02-00-00', 'วัสดุสิ้นเปลือง', 3, 420, '1-4-00-00-00', '1001', '4001', '5001')
ON CONFLICT (code) DO NOTHING;

-- ตรวจสอบผล
SELECT code, name, level, parent_code
FROM public.inventory_categories
ORDER BY sort_order, code;
