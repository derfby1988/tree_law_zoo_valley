-- สร้างตารางวัตถุดิบ (inventory_ingredients)
-- แยกออกจากตารางสินค้าสำเร็จ

-- สร้างตารางใหม่
CREATE TABLE IF NOT EXISTS inventory_ingredients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  unit_id UUID REFERENCES inventory_units(id),
  quantity DECIMAL(10,2) DEFAULT 0,
  min_quantity DECIMAL(10,2) DEFAULT 0,
  cost DECIMAL(10,2) DEFAULT 0,
  category_id UUID REFERENCES inventory_categories(id),
  shelf_id UUID REFERENCES inventory_shelves(id),
  supplier_name VARCHAR(255),
  expiry_date DATE,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- เพิ่ม indexes สำหรับการค้นหา
CREATE INDEX IF NOT EXISTS idx_inventory_ingredients_name ON inventory_ingredients(name);
CREATE INDEX IF NOT EXISTS idx_inventory_ingredients_category ON inventory_ingredients(category_id);
CREATE INDEX IF NOT EXISTS idx_inventory_ingredients_unit ON inventory_ingredients(unit_id);
CREATE INDEX IF NOT EXISTS idx_inventory_ingredients_active ON inventory_ingredients(is_active);

-- เพิ่ม trigger สำหรับ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_inventory_ingredients_updated_at 
    BEFORE UPDATE ON inventory_ingredients 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- คอมเมนต์อธิบายตาราง
COMMENT ON TABLE inventory_ingredients IS 'ตารางวัตถุดิบ - ใช้สำหรับสูตรอาหารและการผลิต';
COMMENT ON COLUMN inventory_ingredients.name IS 'ชื่อวัตถุดิบ';
COMMENT ON COLUMN inventory_ingredients.unit_id IS 'หน่วยนับ';
COMMENT ON COLUMN inventory_ingredients.quantity IS 'จำนวนปัจจุบัน';
COMMENT ON COLUMN inventory_ingredients.min_quantity IS 'จำนวนขั้นต่ำที่ต้องมี';
COMMENT ON COLUMN inventory_ingredients.cost IS 'ต้นทุนต่อหน่วย';
COMMENT ON COLUMN inventory_ingredients.category_id IS 'ประเภทวัตถุดิบ';
COMMENT ON COLUMN inventory_ingredients.shelf_id IS 'ชั้นวาง';
COMMENT ON COLUMN inventory_ingredients.supplier_name IS 'ชื่อผู้จัดจำหน่าย';
COMMENT ON COLUMN inventory_ingredients.expiry_date IS 'วันหมดอายุ';
COMMENT ON COLUMN inventory_ingredients.notes IS 'หมายเหตุเพิ่มเติม';
