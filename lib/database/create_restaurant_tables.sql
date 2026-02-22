-- =============================================
-- Restaurant Zones & Tables Management
-- =============================================

-- ตารางร้าน/โซน (restaurant_zones)
CREATE TABLE IF NOT EXISTS restaurant_zones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  open_time VARCHAR(10),        -- เช่น "10:00"
  close_time VARCHAR(10),       -- เช่น "14:00"
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ตารางโต๊ะ (restaurant_tables)
CREATE TABLE IF NOT EXISTS restaurant_tables (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  zone_id UUID NOT NULL REFERENCES restaurant_zones(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,          -- เช่น "A1", "B2"
  table_type VARCHAR(20) DEFAULT 'small',  -- large | small | bar
  capacity INTEGER DEFAULT 2,
  status VARCHAR(20) DEFAULT 'available',  -- available | unavailable | reserved
  is_bookable BOOLEAN DEFAULT true,        -- false = walk-in only
  sort_order INTEGER DEFAULT 0,
  pos_x DOUBLE PRECISION,                 -- ตำแหน่ง X บนผังร้าน (0.0 - 1.0 relative)
  pos_y DOUBLE PRECISION,                 -- ตำแหน่ง Y บนผังร้าน (0.0 - 1.0 relative)
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_restaurant_zones_active ON restaurant_zones(is_active);
CREATE INDEX IF NOT EXISTS idx_restaurant_tables_zone ON restaurant_tables(zone_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_tables_status ON restaurant_tables(status);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_restaurant_zones_updated_at ON restaurant_zones;
CREATE TRIGGER update_restaurant_zones_updated_at
    BEFORE UPDATE ON restaurant_zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_restaurant_tables_updated_at ON restaurant_tables;
CREATE TRIGGER update_restaurant_tables_updated_at
    BEFORE UPDATE ON restaurant_tables
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE restaurant_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON restaurant_zones;
CREATE POLICY "Allow all for authenticated" ON restaurant_zones
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON restaurant_tables;
CREATE POLICY "Allow all for authenticated" ON restaurant_tables
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Seed data ตัวอย่าง
INSERT INTO restaurant_zones (name, description, open_time, close_time, sort_order) VALUES
  ('ร้านก๋วยเตี๋ยว', 'บริเวณสระน้ำพุ', '10:00', '14:00', 1),
  ('ร้านส้มตำ', 'บริเวณแปลงผัก', '10:00', '20:00', 2)
ON CONFLICT DO NOTHING;
