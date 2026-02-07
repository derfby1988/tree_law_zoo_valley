-- =============================================
-- Migration: แยกตารางประเภทสูตรอาหารและประเภทสินค้า
-- =============================================

-- 1. สร้างตารางใหม่สำหรับประเภทสูตรอาหาร
CREATE TABLE IF NOT EXISTS inventory_recipe_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  color TEXT DEFAULT '#2196F3', -- สีสำหรับแสดงใน UI
  icon TEXT DEFAULT 'restaurant', -- icon name สำหรับแสดงใน UI
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. เปลี่ยนชื่อตารางเดิมให้ชัดเจนว่าเป็นประเภทสินค้า (วัตถุดิบ)
-- ถ้ามีข้อมูลอยู่แล้ว ให้เก็บไว้
-- ตาราง inventory_categories จะใช้สำหรับสินค้า/วัตถุดิบเท่านั้น

-- 3. ย้ายข้อมูลประเภทสูตรอาหารจากตารางเดิมไปตารางใหม่
-- สร้างประเภทสูตรอาหารเริ่มต้น (ตามหมวดหมู่ทั่วไป)
INSERT INTO inventory_recipe_categories (name, description, color, icon) VALUES
  ('อาหารไทย', 'สูตรอาหารไทยทั้งคาวและหวาน', '#FF6F00', 'restaurant'),
  ('อาหารจีน', 'สูตรอาหารจีน', '#D32F2F', 'restaurant'),
  ('อาหารญี่ปุ่น', 'สูตรอาหารญี่ปุ่น', '#C62828', 'restaurant'),
  ('อาหารฝรั่ง', 'สูตรอาหารตะวันตก', '#1565C0', 'restaurant'),
  ('อาหารอิตาเลียน', 'สูตรอาหารอิตาเลียน', '#2E7D32', 'restaurant'),
  ('อาหารเกาหลี', 'สูตรอาหารเกาหลี', '#C62828', 'restaurant'),
  ('อาหารเวียดนาม', 'สูตรอาหารเวียดนาม', '#6A1B9A', 'restaurant'),
  ('อาหารอเมริกัน', 'สูตรอาหารอเมริกัน', '#00695C', 'restaurant'),
  ('อาหารไต้หวัน', 'สูตรอาหารไต้หวัน', '#AD1457', 'restaurant'),
  ('ของหวาน', 'ขนมหวานและเบเกอรี่', '#E91E63', 'cake'),
  ('เครื่องดื่ม', 'เครื่องดื่มทุกชนิด', '#0097A7', 'local_drink'),
  ('เบเกอรี่', 'ขนมอบและเบเกอรี่', '#8D6E63', 'bakery_dining'),
  ('สเต็ก', 'สเต็กเนื้อและสเต็กปลา', '#5D4037', 'set_meal'),
  ('สลัด', 'สลัดและอาหารเพื่อสุขภาพ', '#43A047', 'spa'),
  ('ซุป', 'ซุปและน้ำซุป', '#FF8F00', 'soup_kitchen'),
  ('กับข้าว', 'กับข้าวราดแกง', '#E65100', 'rice_bowl'),
  ('อาหารเช้า', 'อาหารเช้าและบรันช์', '#F9A825', 'wb_sunny'),
  ('ของว่าง', 'ของว่างและอาหารทานเล่น', '#795548', 'tapas'),
  ('อาหารจานด่วน', 'อาหารจานด่วนและฟาสต์ฟู้ด', '#455A64', 'fastfood'),
  ('เมนูพิเศษ', 'เมนูพิเศษตามเทศกาล', '#7B1FA2', 'star')
ON CONFLICT (name) DO NOTHING;

-- 4. แก้ไขตารางสูตรอาหารให้อ้างอิงตารางใหม่
-- ถ้ายังไม่มีคอลัมน์ใหม่ ให้เพิ่ม
ALTER TABLE inventory_recipes 
ADD COLUMN IF NOT EXISTS recipe_category_id UUID REFERENCES inventory_recipe_categories(id);

-- 5. ย้ายข้อมูล category_id เดิมไป recipe_category_id (ถ้ามี)
-- สร้าง mapping ชั่วคราวเพื่อแปลง category เดิมเป็น recipe_category ใหม่
DO $$
DECLARE
  r RECORD;
  old_cat_name TEXT;
  new_cat_id UUID;
BEGIN
  -- วนลูปผ่านสูตรอาหารทั้งหมด
  FOR r IN SELECT id, category_id FROM inventory_recipes WHERE category_id IS NOT NULL
  LOOP
    -- หาชื่อ category เดิม
    SELECT name INTO old_cat_name FROM inventory_categories WHERE id = r.category_id;
    
    -- หา recipe_category_id ใหม่ที่ตรงกัน (ถ้ามี)
    -- ถ้าไม่ตรง ให้ใช้ 'อาหารไทย' เป็นค่าเริ่มต้น
    IF old_cat_name IS NOT NULL THEN
      SELECT id INTO new_cat_id FROM inventory_recipe_categories WHERE name = old_cat_name;
      
      -- ถ้าไม่เจอ ลองหาจากชื่อที่คล้ายกัน
      IF new_cat_id IS NULL THEN
        SELECT id INTO new_cat_id FROM inventory_recipe_categories 
        WHERE name ILIKE '%' || old_cat_name || '%' LIMIT 1;
      END IF;
      
      -- ถ้ายังไม่เจอ ให้ใช้ 'อาหารไทย'
      IF new_cat_id IS NULL THEN
        SELECT id INTO new_cat_id FROM inventory_recipe_categories WHERE name = 'อาหารไทย';
      END IF;
      
      -- อัปเดตสูตรอาหาร
      UPDATE inventory_recipes 
      SET recipe_category_id = new_cat_id 
      WHERE id = r.id;
    END IF;
  END LOOP;
END $$;

-- 6. ลบ foreign key เก่าและอนุญาต NULL (สำหรับ backwards compatibility)
-- ไม่ลบ category_id ทันทีเพื่อป้องกันข้อผิดพลาด
-- ALTER TABLE inventory_recipes DROP COLUMN IF EXISTS category_id;

-- 7. เปิดใช้งาน RLS สำหรับตารางใหม่
ALTER TABLE inventory_recipe_categories ENABLE ROW LEVEL SECURITY;

-- 8. สร้าง Policy สำหรับตารางใหม่
CREATE POLICY "Allow all for authenticated" ON inventory_recipe_categories 
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow read for anon" ON inventory_recipe_categories 
  FOR SELECT TO anon USING (true);

CREATE POLICY "Allow write for anon" ON inventory_recipe_categories 
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "Allow update for anon" ON inventory_recipe_categories 
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Allow delete for anon" ON inventory_recipe_categories 
  FOR DELETE TO anon USING (true);

-- 9. สร้าง function สำหรับอัปเดต updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- 10. สร้าง trigger สำหรับตารางใหม่
DROP TRIGGER IF EXISTS update_inventory_recipe_categories_updated_at ON inventory_recipe_categories;
CREATE TRIGGER update_inventory_recipe_categories_updated_at
  BEFORE UPDATE ON inventory_recipe_categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- หมายเหตุสำคัญ:
-- =============================================
-- หลังจากรัน migration นี้:
-- 1. ตาราง inventory_categories จะใช้สำหรับสินค้า/วัตถุดิบเท่านั้น
-- 2. ตาราง inventory_recipe_categories จะใช้สำหรับสูตรอาหารเท่านั้น
-- 3. ต้องอัปเดตโค้ด Flutter ให้ใช้ตารางใหม่
-- 4. สามารถลบ category_id จาก inventory_recipes ได้หลังจากย้ายข้อมูลเรียบร้อย
-- =============================================
