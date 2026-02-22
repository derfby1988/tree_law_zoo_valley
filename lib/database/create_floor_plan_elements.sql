-- =============================================
-- Floor Plan Elements (Text & Shapes)
-- =============================================

CREATE TABLE IF NOT EXISTS floor_plan_elements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  zone_id UUID NOT NULL REFERENCES restaurant_zones(id) ON DELETE CASCADE,
  element_type VARCHAR(20) NOT NULL,  -- 'text' | 'rect' | 'circle' | 'line'
  label TEXT,                          -- ข้อความ (สำหรับ text)
  pos_x DOUBLE PRECISION NOT NULL DEFAULT 0.1,
  pos_y DOUBLE PRECISION NOT NULL DEFAULT 0.1,
  width DOUBLE PRECISION DEFAULT 0.15,
  height DOUBLE PRECISION DEFAULT 0.08,
  color VARCHAR(20) DEFAULT '#607D8B', -- hex color string
  font_size DOUBLE PRECISION DEFAULT 14,
  rotation DOUBLE PRECISION DEFAULT 0,  -- หมุน (องศา)
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_floor_plan_elements_zone ON floor_plan_elements(zone_id);

ALTER TABLE floor_plan_elements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON floor_plan_elements;
CREATE POLICY "Allow all for authenticated" ON floor_plan_elements
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS update_floor_plan_elements_updated_at ON floor_plan_elements;
CREATE TRIGGER update_floor_plan_elements_updated_at
    BEFORE UPDATE ON floor_plan_elements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- Table Types (ประเภทโต๊ะ)
-- =============================================

CREATE TABLE IF NOT EXISTS restaurant_table_types (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,          -- ชื่อประเภท เช่น "โต๊ะกลม 6 ที่"
  shape VARCHAR(20) DEFAULT 'rect',    -- 'rect' | 'circle' | 'rounded'
  color VARCHAR(20) DEFAULT '#1493FF', -- hex color
  default_capacity INTEGER DEFAULT 4,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_table_types_active ON restaurant_table_types(is_active);

ALTER TABLE restaurant_table_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON restaurant_table_types;
CREATE POLICY "Allow all for authenticated" ON restaurant_table_types
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS update_table_types_updated_at ON restaurant_table_types;
CREATE TRIGGER update_table_types_updated_at
    BEFORE UPDATE ON restaurant_table_types
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed data
INSERT INTO restaurant_table_types (name, shape, color, default_capacity, sort_order) VALUES
  ('โต๊ะเล็ก (2 ที่)', 'rect', '#F19EDC', 2, 1),
  ('โต๊ะกลาง (4 ที่)', 'rect', '#1493FF', 4, 2),
  ('โต๊ะใหญ่ (6 ที่)', 'rect', '#1493FF', 6, 3),
  ('โต๊ะกลม (4 ที่)', 'circle', '#3B82F6', 4, 4),
  ('บาร์/เคาน์เตอร์', 'rounded', '#F0B400', 2, 5)
ON CONFLICT DO NOTHING;
