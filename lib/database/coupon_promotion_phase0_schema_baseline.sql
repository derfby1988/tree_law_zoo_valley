-- =============================================
-- Coupon & Promotion Phase 0: Schema Baseline
-- Tree Law Zoo Valley
-- =============================================
-- Purpose:
-- - Add missing fields confirmed from Supabase live schema verification
-- - Keep changes additive and safe to re-run
-- - No mock data
-- =============================================

-- =============================================
-- 1. Discount targeting and availability baseline
-- =============================================
ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS applicable_product_ids UUID[];

ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS targeting_mode TEXT DEFAULT 'manual'
  CHECK (targeting_mode IN (
    'manual',
    'product_expiry',
    'ingredient_expiry',
    'high_margin',
    'seasonal_ingredient',
    'festival_event',
    'recommended'
  ));

ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS targeting_rule JSONB DEFAULT '{}'::jsonb;

ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS require_in_stock BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS require_sufficient_ingredients BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS include_pending_procurement BOOLEAN DEFAULT false;

-- Lifecycle status for Thai UI states:
-- draft = แบบร่าง, scheduled = ตั้งเวลาไว้, active = ใช้งานอยู่,
-- paused = หยุดชั่วคราว, expired = หมดอายุ, archived = เก็บถาวร
ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS lifecycle_status TEXT DEFAULT 'active'
  CHECK (lifecycle_status IN ('draft', 'scheduled', 'active', 'paused', 'expired', 'archived'));

-- Usage limit baseline beyond existing total usage_limit / used_count
ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS usage_limit_per_customer INT;

ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS usage_limit_per_day INT;

ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS usage_limit_per_order INT DEFAULT 1;

-- Channel targeting baseline. NULL or empty = all channels.
ALTER TABLE IF EXISTS pos_discounts
  ADD COLUMN IF NOT EXISTS applicable_channels TEXT[];

-- =============================================
-- 2. Promotion targeting and availability baseline
-- =============================================
ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS targeting_mode TEXT DEFAULT 'manual'
  CHECK (targeting_mode IN (
    'manual',
    'product_expiry',
    'ingredient_expiry',
    'high_margin',
    'seasonal_ingredient',
    'festival_event',
    'recommended'
  ));

ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS targeting_rule JSONB DEFAULT '{}'::jsonb;

ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS require_in_stock BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS require_sufficient_ingredients BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS include_pending_procurement BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS lifecycle_status TEXT DEFAULT 'active'
  CHECK (lifecycle_status IN ('draft', 'scheduled', 'active', 'paused', 'expired', 'archived'));

ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS applicable_channels TEXT[];

ALTER TABLE IF EXISTS pos_promotions
  ADD COLUMN IF NOT EXISTS applicable_user_group_ids UUID[];

-- =============================================
-- 3. Usage logging and allocation baseline
-- =============================================
ALTER TABLE IF EXISTS pos_order_discounts
  ADD COLUMN IF NOT EXISTS order_line_id UUID REFERENCES pos_order_lines(id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS pos_order_discounts
  ADD COLUMN IF NOT EXISTS allocation_method TEXT DEFAULT 'order_level'
  CHECK (allocation_method IN ('order_level', 'line_item', 'proportional', 'manual'));

ALTER TABLE IF EXISTS pos_order_lines
  ADD COLUMN IF NOT EXISTS discount_amount DOUBLE PRECISION DEFAULT 0;

ALTER TABLE IF EXISTS pos_order_lines
  ADD COLUMN IF NOT EXISTS final_line_total DOUBLE PRECISION;

-- =============================================
-- 4. Customer and procurement compatibility baseline
-- =============================================
ALTER TABLE IF EXISTS pos_orders
  ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES pos_customers(id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS procurement_purchase_order_lines
  ADD COLUMN IF NOT EXISTS ingredient_id UUID REFERENCES inventory_ingredients(id) ON DELETE SET NULL;

-- =============================================
-- 5. Coupon code baseline for bulk/single-use support
-- =============================================
CREATE TABLE IF NOT EXISTS pos_discount_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  discount_id UUID NOT NULL REFERENCES pos_discounts(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  usage_limit INT DEFAULT 1,
  used_count INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  assigned_customer_id UUID REFERENCES pos_customers(id) ON DELETE SET NULL,
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- 6. Indexes
-- =============================================
CREATE INDEX IF NOT EXISTS idx_pos_discounts_applicable_product_ids
  ON pos_discounts USING GIN (applicable_product_ids);

CREATE INDEX IF NOT EXISTS idx_pos_discounts_targeting_mode
  ON pos_discounts(targeting_mode);

CREATE INDEX IF NOT EXISTS idx_pos_discounts_lifecycle_status
  ON pos_discounts(lifecycle_status);

CREATE INDEX IF NOT EXISTS idx_pos_discounts_applicable_channels
  ON pos_discounts USING GIN (applicable_channels);

CREATE INDEX IF NOT EXISTS idx_pos_promotions_targeting_mode
  ON pos_promotions(targeting_mode);

CREATE INDEX IF NOT EXISTS idx_pos_promotions_lifecycle_status
  ON pos_promotions(lifecycle_status);

CREATE INDEX IF NOT EXISTS idx_pos_promotions_applicable_channels
  ON pos_promotions USING GIN (applicable_channels);

CREATE INDEX IF NOT EXISTS idx_pos_promotions_applicable_user_group_ids
  ON pos_promotions USING GIN (applicable_user_group_ids);

CREATE INDEX IF NOT EXISTS idx_pos_order_discounts_order_line
  ON pos_order_discounts(order_line_id);

CREATE INDEX IF NOT EXISTS idx_pos_orders_customer_id
  ON pos_orders(customer_id);

CREATE INDEX IF NOT EXISTS idx_procurement_po_lines_ingredient
  ON procurement_purchase_order_lines(ingredient_id);

CREATE INDEX IF NOT EXISTS idx_pos_discount_codes_discount
  ON pos_discount_codes(discount_id);

CREATE INDEX IF NOT EXISTS idx_pos_discount_codes_code
  ON pos_discount_codes(code);

CREATE INDEX IF NOT EXISTS idx_pos_discount_codes_customer
  ON pos_discount_codes(assigned_customer_id);

-- =============================================
-- 7. RLS for new coupon code table
-- =============================================
ALTER TABLE pos_discount_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read discount codes"
  ON pos_discount_codes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage discount codes"
  ON pos_discount_codes FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);
