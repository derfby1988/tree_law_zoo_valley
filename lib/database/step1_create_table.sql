-- สร้างตารางวัตถุดิบ (รันทีเดียวจบ)
CREATE TABLE inventory_ingredients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  quantity DECIMAL(10,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- เพิ่มคอลัมน์ที่เหลือ
ALTER TABLE inventory_ingredients ADD COLUMN unit_id UUID;
ALTER TABLE inventory_ingredients ADD COLUMN min_quantity DECIMAL(10,2) DEFAULT 0;
ALTER TABLE inventory_ingredients ADD COLUMN cost DECIMAL(10,2) DEFAULT 0;
ALTER TABLE inventory_ingredients ADD COLUMN category_id UUID;
ALTER TABLE inventory_ingredients ADD COLUMN shelf_id UUID;
ALTER TABLE inventory_ingredients ADD COLUMN supplier_name VARCHAR(255);
ALTER TABLE inventory_ingredients ADD COLUMN expiry_date DATE;
ALTER TABLE inventory_ingredients ADD COLUMN notes TEXT;

-- เพิ่ม indexes
CREATE INDEX idx_inventory_ingredients_name ON inventory_ingredients(name);
CREATE INDEX idx_inventory_ingredients_active ON inventory_ingredients(is_active);

-- ตรวจสอบผลลัพธ์
SELECT 'Table created' as status, COUNT(*) as count FROM inventory_ingredients;
