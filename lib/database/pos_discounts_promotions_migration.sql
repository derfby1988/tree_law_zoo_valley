-- =============================================
-- POS Phase 2 Migration — Tree Law Zoo Valley
-- =============================================
-- ลำดับ dependency ที่ต้องรันก่อนไฟล์นี้:
--   1) pos_orders_migration.sql            (pos_orders, pos_order_lines)
--   2) pos_responsibility_flow_migration.sql (pos_customers, user flags)
--   3) pos_table_session_migration.sql      (restaurant_table_sessions)
-- =============================================
-- ไฟล์นี้ครอบคลุม:
--   A) Discount & Promotion Engine    (ตาราง 1-4)
--   B) Loyalty Program                (ตาราง 5-7)
--   C) Receipt & Printing             (ตาราง 8-10)
--   D) Split Payment                  (ตาราง 11)
--   E) Shift & Cash Drawer            (ตาราง 12)
--   F) Order Status Log / Audit Trail (ตาราง 13)
--   G) Refund & Void                  (ตาราง 14)
--   H) Held Orders (พักบิล)           (ตาราง 15)
-- =============================================

-- =============================================
-- A1. Discount Management
-- =============================================
-- ใช้สำหรับ: ส่วนลดรายบิล, ส่วนลดรายชิ้น, ส่วนลดตามหมวดหมู่
-- ตัวอย่าง: ส่วนลดวันเกิด, ส่วนลดกรุ๊ปทัวร์, ส่วนลดพนักงาน, คูปองออนไลน์

CREATE TABLE IF NOT EXISTS pos_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL,       -- 'fixed' | 'percentage'
  scope TEXT NOT NULL,               -- 'order' | 'item' | 'category'
  value DOUBLE PRECISION NOT NULL,   -- ค่าส่วนลด (จำนวนเงิน หรือ เปอร์เซนต์)
  max_discount DOUBLE PRECISION,     -- ส่วนลดสูงสุด (สำหรับ percentage)
  min_amount DOUBLE PRECISION,       -- ยอดขั้นต่ำที่ใช้ส่วนลดได้
  stackable BOOLEAN DEFAULT false,   -- สามารถซ้อนกับส่วนลดอื่นได้หรือไม่
  priority INT DEFAULT 0,            -- ลำดับ auto-apply (สูง = ใช้ก่อน)
  applicable_category_ids UUID[],    -- หมวดที่ใช้ส่วนลดได้ (NULL = ทุกหมวด)
  customer_group_id UUID,            -- ใช้ได้เฉพาะกลุ่มลูกค้า (NULL = ทุกคน)
  coupon_code TEXT,                  -- รหัสคูปอง (NULL = ไม่ต้องใช้รหัส)
  usage_limit INT,                   -- จำกัดจำนวนครั้งที่ใช้ (NULL = ไม่จำกัด)
  used_count INT DEFAULT 0,          -- จำนวนครั้งที่ใช้แล้ว
  is_active BOOLEAN DEFAULT true,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ถ้าตารางมีอยู่แล้วจาก migration เก่า ให้เพิ่ม columns ใหม่
ALTER TABLE IF EXISTS pos_discounts ADD COLUMN IF NOT EXISTS priority INT DEFAULT 0;
ALTER TABLE IF EXISTS pos_discounts ADD COLUMN IF NOT EXISTS applicable_category_ids UUID[];
ALTER TABLE IF EXISTS pos_discounts ADD COLUMN IF NOT EXISTS customer_group_id UUID;
ALTER TABLE IF EXISTS pos_discounts ADD COLUMN IF NOT EXISTS coupon_code TEXT;
ALTER TABLE IF EXISTS pos_discounts ADD COLUMN IF NOT EXISTS usage_limit INT;
ALTER TABLE IF EXISTS pos_discounts ADD COLUMN IF NOT EXISTS used_count INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_pos_discounts_active ON pos_discounts(is_active);
CREATE INDEX IF NOT EXISTS idx_pos_discounts_scope ON pos_discounts(scope);
CREATE INDEX IF NOT EXISTS idx_pos_discounts_coupon ON pos_discounts(coupon_code) WHERE coupon_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pos_discounts_dates ON pos_discounts(start_at, end_at);

-- =============================================
-- A2. Promotions (Bundle/Seasonal)
-- =============================================
-- ตัวอย่าง: ชุดตั๋วครอบครัว, ซื้อ 3 แถม 1 อาหารสัตว์, โปรฯ วันหยุดยาว

CREATE TABLE IF NOT EXISTS pos_promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  promotion_type TEXT NOT NULL,      -- 'bundle' | 'seasonal' | 'buy_x_get_y' | 'happy_hour'
  discount_id UUID REFERENCES pos_discounts(id) ON DELETE SET NULL,
  min_quantity INT DEFAULT 1,        -- จำนวนขั้นต่ำที่ต้องซื้อ
  free_quantity INT DEFAULT 0,       -- จำนวนที่แถม (สำหรับ buy_x_get_y)
  banner_image_url TEXT,             -- รูป banner โปรโมชัน
  is_active BOOLEAN DEFAULT true,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_promotions ADD COLUMN IF NOT EXISTS min_quantity INT DEFAULT 1;
ALTER TABLE IF EXISTS pos_promotions ADD COLUMN IF NOT EXISTS free_quantity INT DEFAULT 0;
ALTER TABLE IF EXISTS pos_promotions ADD COLUMN IF NOT EXISTS banner_image_url TEXT;

CREATE INDEX IF NOT EXISTS idx_pos_promotions_active ON pos_promotions(is_active);
CREATE INDEX IF NOT EXISTS idx_pos_promotions_type ON pos_promotions(promotion_type);
CREATE INDEX IF NOT EXISTS idx_pos_promotions_dates ON pos_promotions(start_at, end_at);

-- =============================================
-- A3. Promotion Items (สินค้าที่เข้าร่วมโปรโมชั่น)
-- =============================================

CREATE TABLE IF NOT EXISTS pos_promotion_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_id UUID NOT NULL REFERENCES pos_promotions(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES inventory_products(id),
  quantity_required INT DEFAULT 1,   -- จำนวนที่ต้องซื้อ (สำหรับ buy_x_get_y)
  is_free_item BOOLEAN DEFAULT false,-- ถ้า true = ของแถม
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_promotion_items ADD COLUMN IF NOT EXISTS is_free_item BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_pos_promotion_items_promotion ON pos_promotion_items(promotion_id);
CREATE INDEX IF NOT EXISTS idx_pos_promotion_items_product ON pos_promotion_items(product_id);

-- =============================================
-- A4. Order Discounts (เชื่อมบิลกับส่วนลด)
-- =============================================

CREATE TABLE IF NOT EXISTS pos_order_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES pos_orders(id) ON DELETE CASCADE,
  discount_id UUID REFERENCES pos_discounts(id) ON DELETE SET NULL,
  promotion_id UUID REFERENCES pos_promotions(id) ON DELETE SET NULL,
  discount_name TEXT NOT NULL,       -- snapshot ชื่อส่วนลด ณ เวลาใช้
  discount_type TEXT NOT NULL,       -- snapshot ประเภท
  discount_value DOUBLE PRECISION NOT NULL, -- snapshot ค่าที่ตั้ง
  discount_amount DOUBLE PRECISION NOT NULL, -- ยอดส่วนลดจริงที่คำนวณแล้ว
  applied_by UUID REFERENCES users(id) ON DELETE SET NULL,
  applied_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_order_discounts ADD COLUMN IF NOT EXISTS promotion_id UUID;
ALTER TABLE IF EXISTS pos_order_discounts ADD COLUMN IF NOT EXISTS discount_name TEXT;
ALTER TABLE IF EXISTS pos_order_discounts ADD COLUMN IF NOT EXISTS discount_type TEXT;
ALTER TABLE IF EXISTS pos_order_discounts ADD COLUMN IF NOT EXISTS discount_value DOUBLE PRECISION;
ALTER TABLE IF EXISTS pos_order_discounts ADD COLUMN IF NOT EXISTS applied_by UUID;

CREATE INDEX IF NOT EXISTS idx_pos_order_discounts_order ON pos_order_discounts(order_id);
CREATE INDEX IF NOT EXISTS idx_pos_order_discounts_discount ON pos_order_discounts(discount_id);

-- =============================================
-- B5. Loyalty Program
-- =============================================
-- ตัวอย่าง: แต้มสะสมสวนสัตว์, สะสมแต้มร้านอาหาร

CREATE TABLE IF NOT EXISTS pos_loyalty_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  points_per_baht DOUBLE PRECISION DEFAULT 1,  -- แต้มต่อบาท
  redemption_rate DOUBLE PRECISION DEFAULT 1,  -- 1 แต้ม = กี่บาท
  min_redeem_points DOUBLE PRECISION DEFAULT 0,-- แต้มขั้นต่ำที่แลกได้
  points_expiry_days INT,                      -- วันหมดอายุ (NULL = ไม่หมดอายุ)
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_loyalty_programs ADD COLUMN IF NOT EXISTS redemption_rate DOUBLE PRECISION DEFAULT 1;
ALTER TABLE IF EXISTS pos_loyalty_programs ADD COLUMN IF NOT EXISTS min_redeem_points DOUBLE PRECISION DEFAULT 0;

-- =============================================
-- B6. Customer Loyalty Wallets
-- =============================================

CREATE TABLE IF NOT EXISTS pos_customer_loyalty_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES pos_customers(id) ON DELETE CASCADE,
  loyalty_program_id UUID NOT NULL REFERENCES pos_loyalty_programs(id),
  total_points DOUBLE PRECISION DEFAULT 0,
  redeemed_points DOUBLE PRECISION DEFAULT 0,
  available_points DOUBLE PRECISION DEFAULT 0,
  tier TEXT DEFAULT 'standard',      -- 'standard' | 'silver' | 'gold' | 'vip'
  last_transaction_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(customer_id, loyalty_program_id)
);

ALTER TABLE IF EXISTS pos_customer_loyalty_wallets ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'standard';

CREATE INDEX IF NOT EXISTS idx_pos_customer_loyalty_wallets_customer ON pos_customer_loyalty_wallets(customer_id);
CREATE INDEX IF NOT EXISTS idx_pos_customer_loyalty_wallets_program ON pos_customer_loyalty_wallets(loyalty_program_id);

-- =============================================
-- B7. Loyalty Transactions
-- =============================================

CREATE TABLE IF NOT EXISTS pos_loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES pos_customer_loyalty_wallets(id) ON DELETE CASCADE,
  order_id UUID REFERENCES pos_orders(id) ON DELETE SET NULL,
  transaction_type TEXT NOT NULL,     -- 'earn' | 'redeem' | 'expire' | 'adjust'
  points DOUBLE PRECISION NOT NULL,
  balance_after DOUBLE PRECISION,    -- ยอดคงเหลือหลังทำรายการ
  reason TEXT,
  expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_loyalty_transactions ADD COLUMN IF NOT EXISTS balance_after DOUBLE PRECISION;
ALTER TABLE IF EXISTS pos_loyalty_transactions ADD COLUMN IF NOT EXISTS created_by UUID;

CREATE INDEX IF NOT EXISTS idx_pos_loyalty_transactions_wallet ON pos_loyalty_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_pos_loyalty_transactions_order ON pos_loyalty_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_pos_loyalty_transactions_type ON pos_loyalty_transactions(transaction_type);

-- =============================================
-- C8. Receipt Templates
-- =============================================

CREATE TABLE IF NOT EXISTS pos_receipt_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  template_type TEXT NOT NULL,       -- 'thermal_80mm' | 'thermal_58mm' | 'a4'
  header_text TEXT,
  footer_text TEXT,
  logo_url TEXT,
  show_logo BOOLEAN DEFAULT true,
  show_order_number BOOLEAN DEFAULT true,
  show_cashier BOOLEAN DEFAULT true,
  show_table BOOLEAN DEFAULT false,
  show_customer BOOLEAN DEFAULT false,
  show_loyalty BOOLEAN DEFAULT false,
  show_tax_detail BOOLEAN DEFAULT true,
  show_barcode BOOLEAN DEFAULT false,
  show_qr_code BOOLEAN DEFAULT false,
  is_default BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_receipt_templates ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE IF EXISTS pos_receipt_templates ADD COLUMN IF NOT EXISTS show_tax_detail BOOLEAN DEFAULT true;
ALTER TABLE IF EXISTS pos_receipt_templates ADD COLUMN IF NOT EXISTS show_barcode BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS pos_receipt_templates ADD COLUMN IF NOT EXISTS show_qr_code BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS pos_receipt_templates ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false;

-- =============================================
-- C9. Printer Profiles
-- =============================================

CREATE TABLE IF NOT EXISTS pos_printer_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  printer_type TEXT NOT NULL,        -- 'bluetooth' | 'usb' | 'network' | 'pdf'
  connection_type TEXT DEFAULT 'bluetooth', -- 'bluetooth' | 'usb' | 'wifi' | 'lan'
  device_name TEXT,                  -- ชื่อเครื่องพิมพ์ (Bluetooth)
  device_address TEXT,               -- MAC Address (Bluetooth)
  ip_address TEXT,
  port INT,
  paper_width INT DEFAULT 80,        -- มม.
  auto_print BOOLEAN DEFAULT false,  -- พิมพ์อัตโนมัติหลังชำระ
  auto_cut BOOLEAN DEFAULT true,     -- ตัดกระดาษอัตโนมัติ
  is_default BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_printer_profiles ADD COLUMN IF NOT EXISTS connection_type TEXT DEFAULT 'bluetooth';
ALTER TABLE IF EXISTS pos_printer_profiles ADD COLUMN IF NOT EXISTS device_address TEXT;
ALTER TABLE IF EXISTS pos_printer_profiles ADD COLUMN IF NOT EXISTS auto_print BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS pos_printer_profiles ADD COLUMN IF NOT EXISTS auto_cut BOOLEAN DEFAULT true;
ALTER TABLE IF EXISTS pos_printer_profiles ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false;

-- =============================================
-- C10. Receipt History
-- =============================================

CREATE TABLE IF NOT EXISTS pos_receipt_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES pos_orders(id) ON DELETE CASCADE,
  template_id UUID REFERENCES pos_receipt_templates(id) ON DELETE SET NULL,
  printer_id UUID REFERENCES pos_printer_profiles(id) ON DELETE SET NULL,
  receipt_type TEXT DEFAULT 'sale',   -- 'sale' | 'refund' | 'void' | 'copy'
  receipt_content TEXT,              -- JSON ของใบเสร็จ (snapshot)
  print_status TEXT DEFAULT 'pending', -- 'pending' | 'printed' | 'failed'
  printed_at TIMESTAMPTZ,
  printed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  print_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE IF EXISTS pos_receipt_history ADD COLUMN IF NOT EXISTS receipt_type TEXT DEFAULT 'sale';
ALTER TABLE IF EXISTS pos_receipt_history ADD COLUMN IF NOT EXISTS printed_by UUID;

CREATE INDEX IF NOT EXISTS idx_pos_receipt_history_order ON pos_receipt_history(order_id);
CREATE INDEX IF NOT EXISTS idx_pos_receipt_history_status ON pos_receipt_history(print_status);

-- =============================================
-- D11. Payment Splits (แยกจ่าย)
-- =============================================
-- ตัวอย่าง: ลูกค้าจ่ายครึ่งเงินสดครึ่งโอน, หรือคนละครึ่ง

CREATE TABLE IF NOT EXISTS pos_payment_splits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES pos_orders(id) ON DELETE CASCADE,
  payment_method TEXT NOT NULL,      -- 'cash' | 'credit_debit' | 'transfer' | 'qr_code'
  amount DOUBLE PRECISION NOT NULL,
  reference_number TEXT,             -- เลขอ้างอิง (บัตร, สลิปโอน)
  note TEXT,
  paid_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_payment_splits_order ON pos_payment_splits(order_id);

-- =============================================
-- E12. Shifts & Cash Drawer (กะ/ลิ้นชักเงินสด)
-- =============================================
-- ตัวอย่าง: เปิดกะเช้า ปิดกะเย็น นับเงินสด

CREATE TABLE IF NOT EXISTS pos_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_number TEXT,                 -- เลขกะ auto-gen
  opened_by UUID NOT NULL REFERENCES users(id),
  opened_by_name TEXT,
  closed_by UUID REFERENCES users(id),
  closed_by_name TEXT,
  opening_cash DOUBLE PRECISION DEFAULT 0,    -- เงินเปิดกะ
  closing_cash DOUBLE PRECISION,              -- เงินปิดกะ (จริง)
  expected_cash DOUBLE PRECISION,             -- เงินที่ควรมี (คำนวณ)
  cash_difference DOUBLE PRECISION,           -- ส่วนต่าง
  total_sales DOUBLE PRECISION DEFAULT 0,     -- ยอดขายรวม
  total_orders INT DEFAULT 0,                 -- จำนวนบิล
  total_refunds DOUBLE PRECISION DEFAULT 0,   -- ยอดคืนเงิน
  total_discounts DOUBLE PRECISION DEFAULT 0, -- ยอดส่วนลดรวม
  status TEXT DEFAULT 'open',                 -- 'open' | 'closed'
  notes TEXT,
  opened_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_shifts_status ON pos_shifts(status);
CREATE INDEX IF NOT EXISTS idx_pos_shifts_opened_by ON pos_shifts(opened_by);
CREATE INDEX IF NOT EXISTS idx_pos_shifts_opened_at ON pos_shifts(opened_at DESC);

-- เชื่อม pos_orders กับ shift
ALTER TABLE IF EXISTS pos_orders
  ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES pos_shifts(id) ON DELETE SET NULL;

-- =============================================
-- F13. Order Status Log (ประวัติสถานะบิล)
-- =============================================
-- audit trail ว่าบิลเปลี่ยนสถานะอย่างไร

CREATE TABLE IF NOT EXISTS pos_order_status_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES pos_orders(id) ON DELETE CASCADE,
  from_status TEXT,                  -- สถานะก่อนหน้า
  to_status TEXT NOT NULL,           -- สถานะใหม่
  changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  changed_by_name TEXT,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_order_status_log_order ON pos_order_status_log(order_id);
CREATE INDEX IF NOT EXISTS idx_pos_order_status_log_created ON pos_order_status_log(created_at DESC);

-- =============================================
-- G14. Refunds & Voids (คืนเงิน/ยกเลิก)
-- =============================================

CREATE TABLE IF NOT EXISTS pos_refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES pos_orders(id) ON DELETE CASCADE,
  refund_type TEXT NOT NULL,         -- 'full' | 'partial' | 'void'
  refund_amount DOUBLE PRECISION NOT NULL,
  refund_method TEXT,                -- วิธีคืนเงิน
  reason TEXT NOT NULL,
  approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_by_name TEXT,
  refunded_by UUID REFERENCES users(id) ON DELETE SET NULL,
  refunded_by_name TEXT,
  status TEXT DEFAULT 'pending',     -- 'pending' | 'approved' | 'completed' | 'rejected'
  refunded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_refunds_order ON pos_refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_pos_refunds_status ON pos_refunds(status);

-- ตาราง line-item ที่คืน
CREATE TABLE IF NOT EXISTS pos_refund_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  refund_id UUID NOT NULL REFERENCES pos_refunds(id) ON DELETE CASCADE,
  order_line_id UUID NOT NULL REFERENCES pos_order_lines(id) ON DELETE CASCADE,
  quantity INT NOT NULL DEFAULT 1,
  refund_amount DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_refund_items_refund ON pos_refund_items(refund_id);

-- =============================================
-- H15. Held Orders (พักบิล)
-- =============================================
-- สำหรับพักบิลไว้แล้วกลับมาทำต่อ

CREATE TABLE IF NOT EXISTS pos_held_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  held_by UUID NOT NULL REFERENCES users(id),
  held_by_name TEXT,
  order_type TEXT DEFAULT 'walk_in',
  table_id UUID REFERENCES restaurant_tables(id) ON DELETE SET NULL,
  table_number TEXT,
  customer_id UUID REFERENCES pos_customers(id) ON DELETE SET NULL,
  customer_name TEXT,
  cart_data JSONB NOT NULL,          -- snapshot ตะกร้า
  subtotal DOUBLE PRECISION DEFAULT 0,
  discount_data JSONB,              -- snapshot ส่วนลดที่เลือกไว้
  note TEXT,
  status TEXT DEFAULT 'held',        -- 'held' | 'resumed' | 'cancelled'
  held_at TIMESTAMPTZ DEFAULT now(),
  resumed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,            -- หมดอายุอัตโนมัติ
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_held_orders_status ON pos_held_orders(status);
CREATE INDEX IF NOT EXISTS idx_pos_held_orders_held_by ON pos_held_orders(held_by);

-- =============================================
-- ขยาย pos_orders เพิ่มเติม
-- =============================================

ALTER TABLE IF EXISTS pos_orders
  ADD COLUMN IF NOT EXISTS loyalty_points_earned DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS loyalty_points_redeemed DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS loyalty_discount_amount DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS promotion_id UUID REFERENCES pos_promotions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS refund_amount DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refund_status TEXT;  -- NULL | 'partial' | 'full' | 'void'

-- =============================================
-- RLS Policies
-- =============================================

ALTER TABLE pos_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_promotion_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_order_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_loyalty_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_customer_loyalty_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_receipt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_printer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_receipt_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_payment_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_order_status_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_refund_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_held_orders ENABLE ROW LEVEL SECURITY;

-- Allow all for authenticated users (restrict per role later)
DROP POLICY IF EXISTS "pos_discounts_all" ON pos_discounts;
CREATE POLICY "pos_discounts_all" ON pos_discounts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_promotions_all" ON pos_promotions;
CREATE POLICY "pos_promotions_all" ON pos_promotions FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_promotion_items_all" ON pos_promotion_items;
CREATE POLICY "pos_promotion_items_all" ON pos_promotion_items FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_order_discounts_all" ON pos_order_discounts;
CREATE POLICY "pos_order_discounts_all" ON pos_order_discounts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_loyalty_programs_all" ON pos_loyalty_programs;
CREATE POLICY "pos_loyalty_programs_all" ON pos_loyalty_programs FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_customer_loyalty_wallets_all" ON pos_customer_loyalty_wallets;
CREATE POLICY "pos_customer_loyalty_wallets_all" ON pos_customer_loyalty_wallets FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_loyalty_transactions_all" ON pos_loyalty_transactions;
CREATE POLICY "pos_loyalty_transactions_all" ON pos_loyalty_transactions FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_receipt_templates_all" ON pos_receipt_templates;
CREATE POLICY "pos_receipt_templates_all" ON pos_receipt_templates FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_printer_profiles_all" ON pos_printer_profiles;
CREATE POLICY "pos_printer_profiles_all" ON pos_printer_profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_receipt_history_all" ON pos_receipt_history;
CREATE POLICY "pos_receipt_history_all" ON pos_receipt_history FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_payment_splits_all" ON pos_payment_splits;
CREATE POLICY "pos_payment_splits_all" ON pos_payment_splits FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_shifts_all" ON pos_shifts;
CREATE POLICY "pos_shifts_all" ON pos_shifts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_order_status_log_all" ON pos_order_status_log;
CREATE POLICY "pos_order_status_log_all" ON pos_order_status_log FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_refunds_all" ON pos_refunds;
CREATE POLICY "pos_refunds_all" ON pos_refunds FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_refund_items_all" ON pos_refund_items;
CREATE POLICY "pos_refund_items_all" ON pos_refund_items FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "pos_held_orders_all" ON pos_held_orders;
CREATE POLICY "pos_held_orders_all" ON pos_held_orders FOR ALL USING (true) WITH CHECK (true);

-- =============================================
-- Auto-generate Shift Number
-- =============================================
CREATE OR REPLACE FUNCTION generate_shift_number()
RETURNS TRIGGER AS $$
DECLARE
  today_count INT;
  today_str TEXT;
BEGIN
  today_str := to_char(NOW(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO today_count
    FROM pos_shifts
    WHERE shift_number LIKE 'SHIFT-' || today_str || '-%';
  NEW.shift_number := 'SHIFT-' || today_str || '-' || LPAD(today_count::TEXT, 3, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_shift_number ON pos_shifts;
CREATE TRIGGER trg_generate_shift_number
  BEFORE INSERT ON pos_shifts
  FOR EACH ROW
  WHEN (NEW.shift_number IS NULL OR NEW.shift_number = '')
  EXECUTE FUNCTION generate_shift_number();

-- =============================================
-- Seed: Default Receipt Template
-- =============================================
INSERT INTO pos_receipt_templates (name, template_type, header_text, footer_text, is_default, is_active)
SELECT 'ใบเสร็จหลัก', 'thermal_80mm',
       'TREE LAW ZOO VALLEY' || chr(10) || 'ขอบคุณที่ใช้บริการ',
       'สอบถามข้อมูล: 0XX-XXX-XXXX' || chr(10) || 'www.treelawzoo.com',
       true, true
WHERE NOT EXISTS (SELECT 1 FROM pos_receipt_templates WHERE is_default = true);

-- =============================================
-- Seed: Default Loyalty Program
-- =============================================
INSERT INTO pos_loyalty_programs (name, description, points_per_baht, redemption_rate, is_active)
SELECT 'Zoo Points', 'สะสมแต้มทุกการซื้อที่ Tree Law Zoo Valley', 1.0, 1.0, true
WHERE NOT EXISTS (SELECT 1 FROM pos_loyalty_programs WHERE is_active = true);

-- =============================================
-- CHECKLIST / สถานะงาน
-- =============================================
-- [x] A1-A4: Discount & Promotion Engine (ตาราง + index + RLS)
-- [x] B5-B7: Loyalty Program (ตาราง + UNIQUE constraint + seed)
-- [x] C8-C10: Receipt & Printing (ตาราง + default template)
-- [x] D11: Split Payment (ตาราง + index)
-- [x] E12: Shift & Cash Drawer (ตาราง + trigger auto-gen + เชื่อม orders)
-- [x] F13: Order Status Log / Audit Trail
-- [x] G14: Refund & Void (ตาราง + line-item refund)
-- [x] H15: Held Orders / พักบิล (JSONB cart snapshot)
-- [x] ขยาย pos_orders: loyalty, promotion, refund columns
-- [x] RLS policies ครบทุกตาราง
-- [x] Seed data: default receipt template + loyalty program
-- [ ] รัน migration นี้ใน Supabase
-- [ ] สร้าง/อัปเดต Flutter models สำหรับตารางใหม่
-- [ ] สร้าง/อัปเดต Flutter services สำหรับตารางใหม่
-- [ ] เชื่อม _processPayment กับ pos_order_discounts + loyalty earn
-- [ ] สร้าง UI: Shift management, Order history, Refund flow
-- =============================================
