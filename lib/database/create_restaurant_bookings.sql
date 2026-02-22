-- =============================================
-- Restaurant Bookings
-- =============================================

CREATE TABLE IF NOT EXISTS restaurant_bookings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  zone_id UUID NOT NULL REFERENCES restaurant_zones(id) ON DELETE CASCADE,
  table_id UUID NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
  customer_name VARCHAR(255) NOT NULL,
  phone VARCHAR(32) NOT NULL,
  party_size INTEGER DEFAULT 2,
  note TEXT,
  status VARCHAR(20) DEFAULT 'pending', -- pending | confirmed | expired | canceled
  expires_at TIMESTAMPTZ,
  order_id UUID, -- future POS order reference
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bookings_table_status ON restaurant_bookings(table_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_expires ON restaurant_bookings(expires_at);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_restaurant_bookings_updated_at
    BEFORE UPDATE ON restaurant_bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE restaurant_bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated" ON restaurant_bookings
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
