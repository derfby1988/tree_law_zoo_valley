-- =============================================
-- Procurement System Migration
-- รันใน Supabase SQL Editor
-- =============================================

-- 1. ตาราง Suppliers
CREATE TABLE IF NOT EXISTS procurement_suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  tax_id TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  contact_person TEXT,
  payment_terms INTEGER DEFAULT 30, -- วัน
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. ตาราง Purchase Orders
CREATE TABLE IF NOT EXISTS procurement_purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT NOT NULL UNIQUE,
  supplier_id UUID NOT NULL REFERENCES procurement_suppliers(id),
  status TEXT NOT NULL DEFAULT 'draft' 
    CHECK (status IN ('draft', 'sent', 'confirmed', 'partial_received', 'completed', 'cancelled')),
  order_date DATE NOT NULL DEFAULT CURRENT_DATE,
  expected_date DATE,
  subtotal DECIMAL(12,2) DEFAULT 0,
  tax_amount DECIMAL(12,2) DEFAULT 0,
  discount_amount DECIMAL(12,2) DEFAULT 0,
  total_amount DECIMAL(12,2) DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id),
  sent_by UUID REFERENCES auth.users(id),
  sent_at TIMESTAMPTZ,
  approved_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMPTZ,
  cancelled_by UUID REFERENCES auth.users(id),
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. ตาราง PO Lines
CREATE TABLE IF NOT EXISTS procurement_purchase_order_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES procurement_purchase_orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES inventory_products(id),
  product_name TEXT NOT NULL,
  quantity DECIMAL(10,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  line_total DECIMAL(12,2) NOT NULL,
  received_quantity DECIMAL(10,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. ตาราง Store Locations
CREATE TABLE IF NOT EXISTS procurement_store_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  is_main_warehouse BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- Indexes
-- =============================================
CREATE INDEX IF NOT EXISTS idx_procurement_suppliers_active ON procurement_suppliers(is_active);
CREATE INDEX IF NOT EXISTS idx_procurement_suppliers_code ON procurement_suppliers(code);

CREATE INDEX IF NOT EXISTS idx_procurement_po_status ON procurement_purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_procurement_po_supplier ON procurement_purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_procurement_po_date ON procurement_purchase_orders(order_date DESC);
CREATE INDEX IF NOT EXISTS idx_procurement_po_created_by ON procurement_purchase_orders(created_by);
CREATE INDEX IF NOT EXISTS idx_procurement_po_sent_by ON procurement_purchase_orders(sent_by);
CREATE INDEX IF NOT EXISTS idx_procurement_po_cancelled_by ON procurement_purchase_orders(cancelled_by);
CREATE INDEX IF NOT EXISTS idx_procurement_po_sent_at ON procurement_purchase_orders(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_procurement_po_cancelled_at ON procurement_purchase_orders(cancelled_at DESC);

CREATE INDEX IF NOT EXISTS idx_procurement_po_lines_po ON procurement_purchase_order_lines(po_id);
CREATE INDEX IF NOT EXISTS idx_procurement_po_lines_product ON procurement_purchase_order_lines(product_id);

CREATE INDEX IF NOT EXISTS idx_procurement_locations_active ON procurement_store_locations(is_active);
CREATE INDEX IF NOT EXISTS idx_procurement_locations_main ON procurement_store_locations(is_main_warehouse);

-- =============================================
-- RLS Policies
-- =============================================
ALTER TABLE procurement_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE procurement_purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE procurement_purchase_order_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE procurement_store_locations ENABLE ROW LEVEL SECURITY;

-- Suppliers: ทุกคนที่ login อ่านได้
CREATE POLICY "Authenticated users can read suppliers"
  ON procurement_suppliers FOR SELECT
  TO authenticated
  USING (true);

-- Suppliers: ทุกคนที่ login เพิ่ม/แก้/ลบได้
CREATE POLICY "Authenticated users can manage suppliers"
  ON procurement_suppliers FOR ALL
  TO authenticated
  WITH CHECK (true);

-- Purchase Orders: ทุกคนที่ login อ่านได้
CREATE POLICY "Authenticated users can read purchase orders"
  ON procurement_purchase_orders FOR SELECT
  TO authenticated
  USING (true);

-- Purchase Orders: ทุกคนที่ login เพิ่ม/แก้/ลบได้
CREATE POLICY "Authenticated users can manage purchase orders"
  ON procurement_purchase_orders FOR ALL
  TO authenticated
  WITH CHECK (true);

-- PO Lines: ทุกคนที่ login อ่านได้
CREATE POLICY "Authenticated users can read PO lines"
  ON procurement_purchase_order_lines FOR SELECT
  TO authenticated
  USING (true);

-- PO Lines: ทุกคนที่ login เพิ่ม/แก้/ลบได้
CREATE POLICY "Authenticated users can manage PO lines"
  ON procurement_purchase_order_lines FOR ALL
  TO authenticated
  WITH CHECK (true);

-- Store Locations: ทุกคนที่ login อ่านได้
CREATE POLICY "Authenticated users can read store locations"
  ON procurement_store_locations FOR SELECT
  TO authenticated
  USING (true);

-- Store Locations: ทุกคนที่ login เพิ่ม/แก้/ลบได้
CREATE POLICY "Authenticated users can manage store locations"
  ON procurement_store_locations FOR ALL
  TO authenticated
  WITH CHECK (true);

-- =============================================
-- Functions for auto-updating timestamps
-- =============================================
CREATE OR REPLACE FUNCTION update_procurement_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS trg_procurement_suppliers_updated_at ON procurement_suppliers;
CREATE TRIGGER trg_procurement_suppliers_updated_at
    BEFORE UPDATE ON procurement_suppliers
    FOR EACH ROW
    EXECUTE FUNCTION update_procurement_updated_at();

DROP TRIGGER IF EXISTS trg_procurement_po_updated_at ON procurement_purchase_orders;
CREATE TRIGGER trg_procurement_po_updated_at
    BEFORE UPDATE ON procurement_purchase_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_procurement_updated_at();

-- =============================================
-- Function for generating PO numbers
-- =============================================
CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TEXT AS $$
DECLARE
    prefix TEXT := 'PO';
    year_part TEXT := to_char(now(), 'YY');
    month_part TEXT := to_char(now(), 'MM');
    seq_num TEXT;
BEGIN
    -- Get next sequence for this month
    SELECT LPAD(COUNT(*) + 1, 4, '0') 
    INTO seq_num
    FROM procurement_purchase_orders 
    WHERE order_date >= date_trunc('month', now())
      AND order_date < date_trunc('month', now()) + interval '1 month';
    
    RETURN prefix || year_part || month_part || seq_num;
END;
$$ LANGUAGE plpgsql;
