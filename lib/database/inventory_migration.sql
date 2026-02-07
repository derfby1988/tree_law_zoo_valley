-- =============================================
-- Inventory System Migration
-- รันใน Supabase SQL Editor
-- =============================================

-- 1. ตารางคลังสินค้า (Warehouses)
CREATE TABLE IF NOT EXISTS inventory_warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location TEXT,
  manager TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. ตารางชั้นวาง (Shelves)
CREATE TABLE IF NOT EXISTS inventory_shelves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID REFERENCES inventory_warehouses(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  capacity INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. ตารางประเภทสินค้า (Categories)
CREATE TABLE IF NOT EXISTS inventory_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. ตารางหน่วยนับ (Units)
CREATE TABLE IF NOT EXISTS inventory_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  abbreviation TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. ตารางสินค้า (Products)
CREATE TABLE IF NOT EXISTS inventory_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  category_id UUID REFERENCES inventory_categories(id),
  unit_id UUID REFERENCES inventory_units(id),
  shelf_id UUID REFERENCES inventory_shelves(id),
  quantity DOUBLE PRECISION DEFAULT 0,
  min_quantity DOUBLE PRECISION DEFAULT 0,
  price DOUBLE PRECISION DEFAULT 0,
  cost DOUBLE PRECISION DEFAULT 0,
  expiry_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. ตารางสูตรอาหาร (Recipes)
CREATE TABLE IF NOT EXISTS inventory_recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category_id UUID REFERENCES inventory_categories(id),
  yield_quantity DOUBLE PRECISION DEFAULT 1,
  yield_unit TEXT DEFAULT 'ชิ้น',
  cost DOUBLE PRECISION DEFAULT 0,
  price DOUBLE PRECISION DEFAULT 0,
  description TEXT,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. ตารางส่วนผสมสูตร (Recipe Ingredients)
CREATE TABLE IF NOT EXISTS inventory_recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID REFERENCES inventory_recipes(id) ON DELETE CASCADE,
  product_id UUID REFERENCES inventory_products(id),
  quantity DOUBLE PRECISION NOT NULL DEFAULT 0,
  unit_id UUID REFERENCES inventory_units(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. ตารางการปรับปรุงคลัง (Adjustments)
CREATE TABLE IF NOT EXISTS inventory_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES inventory_products(id),
  type TEXT NOT NULL CHECK (type IN ('purchase', 'return', 'count', 'transfer', 'withdraw', 'damage', 'produce', 'adjust')),
  quantity_before DOUBLE PRECISION DEFAULT 0,
  quantity_after DOUBLE PRECISION DEFAULT 0,
  quantity_change DOUBLE PRECISION DEFAULT 0,
  reason TEXT,
  reference_id UUID,
  user_id UUID,
  user_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. ตารางประวัติการผลิต (Production Log)
CREATE TABLE IF NOT EXISTS inventory_production_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID REFERENCES inventory_recipes(id),
  batch_quantity INT DEFAULT 1,
  yield_quantity DOUBLE PRECISION DEFAULT 0,
  user_id UUID,
  user_name TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- ข้อมูลเริ่มต้น (Seed Data)
-- =============================================

-- คลังสินค้า
INSERT INTO inventory_warehouses (name, location, manager) VALUES
  ('คลังหลัก', 'อาคาร A', 'คุณสมชาย'),
  ('คลังสำรอง', 'อาคาร B', 'คุณมานี');

-- ประเภทสินค้า
INSERT INTO inventory_categories (name, description) VALUES
  ('อาหาร', 'อาหารทุกชนิด'),
  ('เครื่องดื่ม', 'เครื่องดื่มทุกชนิด'),
  ('ของหวาน', 'ขนมหวานและเบเกอรี่'),
  ('วัตถุดิบ', 'วัตถุดิบสำหรับประกอบอาหาร');

-- หน่วยนับ
INSERT INTO inventory_units (name, abbreviation) VALUES
  ('ชิ้น', 'ชิ้น'),
  ('ขวด', 'ขวด'),
  ('กิโลกรัม', 'กก.'),
  ('ลิตร', 'ลิตร'),
  ('ถุง', 'ถุง'),
  ('ฟอง', 'ฟอง'),
  ('กล่อง', 'กล่อง'),
  ('กรัม', 'ก.'),
  ('มิลลิลิตร', 'มล.'),
  ('ถ้วย', 'ถ้วย'),
  ('จาน', 'จาน'),
  ('ชาม', 'ชาม'),
  ('แก้ว', 'แก้ว'),
  ('ช้อนโต๊ะ', 'ช้อนโต๊ะ'),
  ('ช้อนชา', 'ช้อนชา'),
  ('หยิบมือ', 'หยิบมือ'),
  ('มัด', 'มัด'),
  ('ห่อ', 'ห่อ'),
  ('แพ็ค', 'แพ็ค'),
  ('โหล', 'โหล'),
  ('ลัง', 'ลัง'),
  ('กระป๋อง', 'กระป๋อง'),
  ('ขีด', 'ขีด'),
  ('ตัว', 'ตัว'),
  ('ลูก', 'ลูก'),
  ('หัว', 'หัว'),
  ('ต้น', 'ต้น'),
  ('ใบ', 'ใบ'),
  ('แผ่น', 'แผ่น'),
  ('ไม้', 'ไม้'),
  ('เส้น', 'เส้น'),
  ('พวง', 'พวง')
ON CONFLICT (name) DO NOTHING;

-- ชั้นวาง (ต้อง reference warehouse_id จริง)
-- หลังจาก insert warehouses แล้ว ให้ใช้ subquery
INSERT INTO inventory_shelves (warehouse_id, code, capacity)
SELECT w.id, s.code, s.capacity
FROM inventory_warehouses w
CROSS JOIN (VALUES
  ('A1', 100), ('A2', 100), ('B1', 80), ('B2', 80), ('C1', 60), ('C2', 60), ('C3', 60)
) AS s(code, capacity)
WHERE w.name = 'คลังหลัก';

INSERT INTO inventory_shelves (warehouse_id, code, capacity)
SELECT w.id, s.code, s.capacity
FROM inventory_warehouses w
CROSS JOIN (VALUES
  ('D1', 100), ('D2', 100), ('E1', 80)
) AS s(code, capacity)
WHERE w.name = 'คลังสำรอง';

-- สินค้า (ต้อง reference category_id, unit_id, shelf_id จริง)
INSERT INTO inventory_products (name, category_id, unit_id, shelf_id, quantity, min_quantity, price, cost, expiry_date)
SELECT p.name, c.id, u.id, sh.id, p.quantity, p.min_quantity, p.price, p.cost, p.expiry_date::date
FROM (VALUES
  ('แฮมเบอร์เกอร์', 'อาหาร', 'ชิ้น', 'A1', 98, 10, 120, 65, NULL),
  ('โคคา-โคลา', 'เครื่องดื่ม', 'ขวด', 'B1', 45, 10, 45, 20, NULL),
  ('เค้กช็อกโกแลต', 'ของหวาน', 'ชิ้น', 'A2', 8, 10, 85, 35, NULL),
  ('ไอศกรีมวานิลา', 'ของหวาน', 'ชิ้น', 'B2', 5, 10, 60, 25, NULL),
  ('ขนมปังสด', 'อาหาร', 'ถุง', 'C3', 0, 5, 25, 12, NULL),
  ('นมสด', 'วัตถุดิบ', 'ขวด', 'D1', 10, 5, 35, 18, (now() + interval '2 days')::text),
  ('เนื้อสด', 'วัตถุดิบ', 'กิโลกรัม', 'D2', 5, 3, 350, 280, (now() + interval '3 days')::text),
  ('ผักสด', 'วัตถุดิบ', 'กิโลกรัม', 'E1', 8, 5, 80, 40, (now() + interval '1 day')::text),
  ('ขนมปังแฮมเบอร์เกอร์', 'วัตถุดิบ', 'ชิ้น', 'C1', 50, 10, 15, 8, NULL),
  ('เนื้อบด', 'วัตถุดิบ', 'กิโลกรัม', 'D2', 5, 2, 320, 250, (now() + interval '3 days')::text),
  ('ผักกาดหอม', 'วัตถุดิบ', 'กิโลกรัม', 'E1', 8, 3, 60, 30, (now() + interval '2 days')::text),
  ('มะเขือเทศ', 'วัตถุดิบ', 'กิโลกรัม', 'E1', 15, 5, 50, 25, (now() + interval '2 days')::text),
  ('ซอสมะเขือเทศ', 'วัตถุดิบ', 'กิโลกรัม', 'C2', 3, 2, 90, 60, NULL),
  ('แป้งสาลี', 'วัตถุดิบ', 'กิโลกรัม', 'C1', 10, 5, 45, 25, NULL),
  ('ผงโกโก้', 'วัตถุดิบ', 'กิโลกรัม', 'C1', 2, 1, 180, 120, NULL),
  ('น้ำตาล', 'วัตถุดิบ', 'กิโลกรัม', 'C2', 15, 5, 30, 18, NULL),
  ('ไข่ไก่', 'วัตถุดิบ', 'ฟอง', 'D1', 30, 10, 5, 3, (now() + interval '7 days')::text),
  ('เนย', 'วัตถุดิบ', 'กิโลกรัม', 'D1', 4, 2, 220, 160, (now() + interval '14 days')::text),
  ('ครีมสด', 'วัตถุดิบ', 'ลิตร', 'D1', 5, 2, 150, 100, (now() + interval '5 days')::text),
  ('วานิลา', 'วัตถุดิบ', 'ลิตร', 'C2', 1, 1, 350, 250, NULL)
) AS p(name, cat_name, unit_name, shelf_code, quantity, min_quantity, price, cost, expiry_date)
JOIN inventory_categories c ON c.name = p.cat_name
JOIN inventory_units u ON u.name = p.unit_name
JOIN inventory_shelves sh ON sh.code = p.shelf_code;

-- สูตรอาหาร
INSERT INTO inventory_recipes (name, category_id, yield_quantity, yield_unit, cost, price, description)
SELECT r.name, c.id, r.yield_quantity, r.yield_unit, r.cost, r.price, r.description
FROM (VALUES
  ('แฮมเบอร์เกอร์เนื้อ', 'อาหาร', 1, 'ชิ้น', 65, 120, 'แฮมเบอร์เกอร์เนื้อสดพร้อมผักสด'),
  ('เค้กช็อกโกแลต', 'ของหวาน', 8, 'ชิ้น', 280, 85, 'เค้กช็อกโกแลตหน้านิ่ม'),
  ('ไอศกรีมวานิลา', 'ของหวาน', 10, 'ชิ้น', 180, 60, 'ไอศกรีมวานิลาโฮมเมด')
) AS r(name, cat_name, yield_quantity, yield_unit, cost, price, description)
JOIN inventory_categories c ON c.name = r.cat_name;

-- ส่วนผสมสูตร (ต้อง reference recipe_id, product_id จริง)
INSERT INTO inventory_recipe_ingredients (recipe_id, product_id, quantity)
SELECT rec.id, prod.id, ri.quantity
FROM (VALUES
  ('แฮมเบอร์เกอร์เนื้อ', 'ขนมปังแฮมเบอร์เกอร์', 1.0),
  ('แฮมเบอร์เกอร์เนื้อ', 'เนื้อบด', 0.15),
  ('แฮมเบอร์เกอร์เนื้อ', 'ผักกาดหอม', 0.02),
  ('แฮมเบอร์เกอร์เนื้อ', 'มะเขือเทศ', 0.03),
  ('แฮมเบอร์เกอร์เนื้อ', 'ซอสมะเขือเทศ', 0.02),
  ('เค้กช็อกโกแลต', 'แป้งสาลี', 0.3),
  ('เค้กช็อกโกแลต', 'ผงโกโก้', 0.1),
  ('เค้กช็อกโกแลต', 'น้ำตาล', 0.2),
  ('เค้กช็อกโกแลต', 'ไข่ไก่', 3.0),
  ('เค้กช็อกโกแลต', 'เนย', 0.15),
  ('เค้กช็อกโกแลต', 'นมสด', 0.2),
  ('ไอศกรีมวานิลา', 'นมสด', 0.5),
  ('ไอศกรีมวานิลา', 'ครีมสด', 0.3),
  ('ไอศกรีมวานิลา', 'น้ำตาล', 0.15),
  ('ไอศกรีมวานิลา', 'วานิลา', 0.01)
) AS ri(recipe_name, product_name, quantity)
JOIN inventory_recipes rec ON rec.name = ri.recipe_name
JOIN inventory_products prod ON prod.name = ri.product_name;

-- ประวัติการปรับปรุง (ตัวอย่าง)
INSERT INTO inventory_adjustments (product_id, type, quantity_before, quantity_after, quantity_change, reason, user_name, created_at)
SELECT prod.id, a.type, a.qty_before, a.qty_after, a.qty_change, a.reason, a.user_name, (now() - (a.hours_ago || ' hours')::interval)
FROM (VALUES
  ('แฮมเบอร์เกอร์', 'adjust', 98, 100, 2, 'ตรวจนับพบเพิ่ม', 'สมชาย', '2'),
  ('โคคา-โคลา', 'purchase', 40, 50, 10, 'ซื้อเพิ่ม', 'มานี', '4'),
  ('เค้กช็อกโกแลต', 'produce', 5, 8, 3, 'ผลิตจากสูตร', 'วิรัติ', '6')
) AS a(product_name, type, qty_before, qty_after, qty_change, reason, user_name, hours_ago)
JOIN inventory_products prod ON prod.name = a.product_name;

-- =============================================
-- Enable RLS (Row Level Security)
-- =============================================
ALTER TABLE inventory_warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_shelves ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_production_logs ENABLE ROW LEVEL SECURITY;

-- Policy: อนุญาตให้ authenticated users อ่านและเขียนได้ทั้งหมด
CREATE POLICY "Allow all for authenticated" ON inventory_warehouses FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_shelves FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_categories FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_units FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_products FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_recipes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_recipe_ingredients FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_adjustments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON inventory_production_logs FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Policy: อนุญาตให้ anon อ่านได้ (สำหรับ guest mode)
CREATE POLICY "Allow read for anon" ON inventory_warehouses FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_shelves FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_categories FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_units FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_products FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_recipes FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_recipe_ingredients FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_adjustments FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read for anon" ON inventory_production_logs FOR SELECT TO anon USING (true);

-- Policy: อนุญาตให้ anon เขียนได้ (สำหรับ guest mode ทดสอบ)
CREATE POLICY "Allow write for anon" ON inventory_warehouses FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_shelves FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_categories FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_units FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_products FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_recipes FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_recipe_ingredients FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_adjustments FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow write for anon" ON inventory_production_logs FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow update for anon" ON inventory_products FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow update for anon" ON inventory_recipes FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow update for anon" ON inventory_recipe_ingredients FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow delete for anon" ON inventory_recipes FOR DELETE TO anon USING (true);
CREATE POLICY "Allow delete for anon" ON inventory_recipe_ingredients FOR DELETE TO anon USING (true);
CREATE POLICY "Allow delete for anon" ON inventory_products FOR DELETE TO anon USING (true);

-- =============================================
-- Storage Bucket สำหรับรูปสูตรอาหาร
-- =============================================
INSERT INTO storage.buckets (id, name, public) VALUES ('recipe-images', 'recipe-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Allow authenticated upload recipe images" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'recipe-images');
CREATE POLICY "Allow authenticated update recipe images" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'recipe-images');
CREATE POLICY "Allow authenticated delete recipe images" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'recipe-images');
CREATE POLICY "Allow public read recipe images" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'recipe-images');

-- anon policies สำหรับ guest mode
CREATE POLICY "Allow anon upload recipe images" ON storage.objects
  FOR INSERT TO anon WITH CHECK (bucket_id = 'recipe-images');
CREATE POLICY "Allow anon update recipe images" ON storage.objects
  FOR UPDATE TO anon USING (bucket_id = 'recipe-images');
CREATE POLICY "Allow anon delete recipe images" ON storage.objects
  FOR DELETE TO anon USING (bucket_id = 'recipe-images');

-- =============================================
-- Fix: Add unique constraint for existing tables
-- =============================================
-- รันคำสั่งนี้หากตาราง inventory_products มีอยู่แล้วและไม่มี unique constraint
ALTER TABLE inventory_products ADD CONSTRAINT IF NOT EXISTS inventory_products_name_unique UNIQUE (name);
