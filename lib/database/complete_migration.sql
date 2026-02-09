-- ============================================
-- สร้างตารางวัตถุดิบ (รันครั้งเดียว)
-- ============================================

-- สร้างตาราง
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

-- เพิ่ม indexes
CREATE INDEX IF NOT EXISTS idx_inventory_ingredients_name ON inventory_ingredients(name);
CREATE INDEX IF NOT EXISTS idx_inventory_ingredients_active ON inventory_ingredients(is_active);

-- เพิ่ม trigger สำหรับ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_inventory_ingredients_updated_at ON inventory_ingredients;
CREATE TRIGGER update_inventory_ingredients_updated_at 
    BEFORE UPDATE ON inventory_ingredients 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ย้ายข้อมูลวัตถุดิบ (รันหลังจากสร้างตาราง)
-- ============================================

-- ค้นหาวัตถุดิบที่มีจำนวน = 0 (สมมติว่าเป็นวัตถุดิบ)
-- และย้ายไปยังตารางใหม่ (เลือก 2 รายการล่าสุด)
WITH ingredients_to_move AS (
  SELECT id, name, unit_id, quantity, min_quantity, cost, category_id, shelf_id, 
         is_active, created_at, updated_at
  FROM inventory_products 
  WHERE quantity = 0 AND is_active = true 
  ORDER BY created_at DESC 
  LIMIT 2
)
INSERT INTO inventory_ingredients (
  name, unit_id, quantity, min_quantity, cost, category_id, shelf_id,
  is_active, created_at, updated_at
)
SELECT 
  name, unit_id, quantity, min_quantity, cost, category_id, shelf_id,
  is_active, created_at, updated_at
FROM ingredients_to_move;

-- ลบวัตถุดิบออกจากตารางสินค้า
DELETE FROM inventory_products 
WHERE id IN (
  SELECT id FROM (
    SELECT id FROM inventory_products 
    WHERE quantity = 0 AND is_active = true 
    ORDER BY created_at DESC 
    LIMIT 2
  ) AS to_delete
);

-- ============================================
-- ตรวจสอบผลลัพธ์
-- ============================================

-- แสดงผลลัพธ์
SELECT 'Products after migration' as table_name, COUNT(*) as count 
FROM inventory_products WHERE is_active = true;

SELECT 'Ingredients after migration' as table_name, COUNT(*) as count 
FROM inventory_ingredients WHERE is_active = true;

-- แสดงข้อมูลวัตถุดิบที่ย้ายแล้ว
SELECT 
  name,
  quantity,
  cost,
  created_at
FROM inventory_ingredients 
WHERE is_active = true 
ORDER BY created_at DESC;
