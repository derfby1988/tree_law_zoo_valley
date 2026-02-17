-- =============================================
-- POS Orders & Order Lines
-- =============================================

CREATE TABLE IF NOT EXISTS pos_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT NOT NULL UNIQUE,
  user_id UUID REFERENCES auth.users(id),
  user_name TEXT,
  table_number TEXT,
  subtotal DOUBLE PRECISION DEFAULT 0,
  discount_amount DOUBLE PRECISION DEFAULT 0,
  discount_note TEXT,
  tax_rate DOUBLE PRECISION DEFAULT 0,
  tax_amount DOUBLE PRECISION DEFAULT 0,
  service_rate DOUBLE PRECISION DEFAULT 0,
  service_amount DOUBLE PRECISION DEFAULT 0,
  net_total DOUBLE PRECISION DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pos_order_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES pos_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES inventory_products(id),
  product_name TEXT NOT NULL,
  unit_name TEXT,
  quantity INT NOT NULL DEFAULT 1,
  unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  line_total DOUBLE PRECISION NOT NULL DEFAULT 0,
  tax_exempt BOOLEAN DEFAULT false,
  tax_rate DOUBLE PRECISION DEFAULT 0,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pos_orders_created ON pos_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pos_orders_status ON pos_orders(status);
CREATE INDEX IF NOT EXISTS idx_pos_orders_user ON pos_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_pos_order_lines_order ON pos_order_lines(order_id);
CREATE INDEX IF NOT EXISTS idx_pos_order_lines_product ON pos_order_lines(product_id);

-- RLS
ALTER TABLE pos_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_order_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pos_orders_all" ON pos_orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "pos_order_lines_all" ON pos_order_lines FOR ALL USING (true) WITH CHECK (true);

-- Auto-generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
DECLARE
  today_count INT;
  today_str TEXT;
BEGIN
  today_str := to_char(NOW(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO today_count
    FROM pos_orders
    WHERE order_number LIKE 'POS-' || today_str || '-%';
  NEW.order_number := 'POS-' || today_str || '-' || LPAD(today_count::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_order_number ON pos_orders;
CREATE TRIGGER trg_generate_order_number
  BEFORE INSERT ON pos_orders
  FOR EACH ROW
  WHEN (NEW.order_number IS NULL OR NEW.order_number = '')
  EXECUTE FUNCTION generate_order_number();
