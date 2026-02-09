-- ============================================
-- ขั้นตอนที่ 1: เพิ่มคอลัมน์ calories
-- ============================================
ALTER TABLE inventory_ingredients ADD COLUMN IF NOT EXISTS calories DECIMAL(10,4) DEFAULT 0;

-- ============================================
-- ขั้นตอนที่ 2: ตรวจสอบข้อมูล units และ categories ที่มีอยู่
-- ============================================
SELECT 'UNITS' as type, id, name, abbreviation FROM inventory_units ORDER BY name;
SELECT 'CATEGORIES' as type, id, name FROM inventory_categories ORDER BY name;
