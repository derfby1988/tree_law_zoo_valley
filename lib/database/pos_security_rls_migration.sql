-- ============================================================================
-- POS Security: RLS + Audit Log Hardening (S-1, S-2)
-- ============================================================================
-- S-1: RLS policies สำหรับทุกตาราง pos_*
-- S-2: Audit log แบบ insert-only (ห้าม UPDATE/DELETE)
-- ============================================================================

-- ============================================================================
-- S-1: RLS Policies — ทุกตาราง pos_*
-- ============================================================================

-- เปิด RLS สำหรับตารางที่ยังไม่ได้เปิด
ALTER TABLE IF EXISTS pos_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pos_refund_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS pos_held_orders ENABLE ROW LEVEL SECURITY;

-- Policy template: authenticated users สามารถ read/write ได้
-- (application-level enforcement ทำผ่าน PermissionService)

-- pos_refunds
DROP POLICY IF EXISTS "auth_read_refunds" ON pos_refunds;
CREATE POLICY "auth_read_refunds" ON pos_refunds FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_refunds" ON pos_refunds;
CREATE POLICY "auth_insert_refunds" ON pos_refunds FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_refunds" ON pos_refunds;
CREATE POLICY "auth_update_refunds" ON pos_refunds FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- pos_refund_items
DROP POLICY IF EXISTS "auth_read_refund_items" ON pos_refund_items;
CREATE POLICY "auth_read_refund_items" ON pos_refund_items FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_refund_items" ON pos_refund_items;
CREATE POLICY "auth_insert_refund_items" ON pos_refund_items FOR INSERT TO authenticated WITH CHECK (true);

-- pos_held_orders
DROP POLICY IF EXISTS "auth_read_held_orders" ON pos_held_orders;
CREATE POLICY "auth_read_held_orders" ON pos_held_orders FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_held_orders" ON pos_held_orders;
CREATE POLICY "auth_insert_held_orders" ON pos_held_orders FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_held_orders" ON pos_held_orders;
CREATE POLICY "auth_update_held_orders" ON pos_held_orders FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "auth_delete_held_orders" ON pos_held_orders;
CREATE POLICY "auth_delete_held_orders" ON pos_held_orders FOR DELETE TO authenticated USING (true);

-- pos_discounts
DROP POLICY IF EXISTS "auth_read_discounts" ON pos_discounts;
CREATE POLICY "auth_read_discounts" ON pos_discounts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_discounts" ON pos_discounts;
CREATE POLICY "auth_insert_discounts" ON pos_discounts FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_discounts" ON pos_discounts;
CREATE POLICY "auth_update_discounts" ON pos_discounts FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- pos_promotions
DROP POLICY IF EXISTS "auth_read_promotions" ON pos_promotions;
CREATE POLICY "auth_read_promotions" ON pos_promotions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_promotions" ON pos_promotions;
CREATE POLICY "auth_insert_promotions" ON pos_promotions FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_promotions" ON pos_promotions;
CREATE POLICY "auth_update_promotions" ON pos_promotions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- pos_promotion_items
DROP POLICY IF EXISTS "auth_read_promotion_items" ON pos_promotion_items;
CREATE POLICY "auth_read_promotion_items" ON pos_promotion_items FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_promotion_items" ON pos_promotion_items;
CREATE POLICY "auth_insert_promotion_items" ON pos_promotion_items FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_delete_promotion_items" ON pos_promotion_items;
CREATE POLICY "auth_delete_promotion_items" ON pos_promotion_items FOR DELETE TO authenticated USING (true);

-- pos_order_discounts
DROP POLICY IF EXISTS "auth_read_order_discounts" ON pos_order_discounts;
CREATE POLICY "auth_read_order_discounts" ON pos_order_discounts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_order_discounts" ON pos_order_discounts;
CREATE POLICY "auth_insert_order_discounts" ON pos_order_discounts FOR INSERT TO authenticated WITH CHECK (true);

-- pos_loyalty_programs
DROP POLICY IF EXISTS "auth_read_loyalty_programs" ON pos_loyalty_programs;
CREATE POLICY "auth_read_loyalty_programs" ON pos_loyalty_programs FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_loyalty_programs" ON pos_loyalty_programs;
CREATE POLICY "auth_insert_loyalty_programs" ON pos_loyalty_programs FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_loyalty_programs" ON pos_loyalty_programs;
CREATE POLICY "auth_update_loyalty_programs" ON pos_loyalty_programs FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- pos_customer_loyalty_wallets
DROP POLICY IF EXISTS "auth_read_loyalty_wallets" ON pos_customer_loyalty_wallets;
CREATE POLICY "auth_read_loyalty_wallets" ON pos_customer_loyalty_wallets FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_loyalty_wallets" ON pos_customer_loyalty_wallets;
CREATE POLICY "auth_insert_loyalty_wallets" ON pos_customer_loyalty_wallets FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_loyalty_wallets" ON pos_customer_loyalty_wallets;
CREATE POLICY "auth_update_loyalty_wallets" ON pos_customer_loyalty_wallets FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- pos_loyalty_transactions
DROP POLICY IF EXISTS "auth_read_loyalty_transactions" ON pos_loyalty_transactions;
CREATE POLICY "auth_read_loyalty_transactions" ON pos_loyalty_transactions FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_loyalty_transactions" ON pos_loyalty_transactions;
CREATE POLICY "auth_insert_loyalty_transactions" ON pos_loyalty_transactions FOR INSERT TO authenticated WITH CHECK (true);

-- pos_receipt_templates
DROP POLICY IF EXISTS "auth_read_receipt_templates" ON pos_receipt_templates;
CREATE POLICY "auth_read_receipt_templates" ON pos_receipt_templates FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_receipt_templates" ON pos_receipt_templates;
CREATE POLICY "auth_insert_receipt_templates" ON pos_receipt_templates FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_receipt_templates" ON pos_receipt_templates;
CREATE POLICY "auth_update_receipt_templates" ON pos_receipt_templates FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- pos_printer_profiles
DROP POLICY IF EXISTS "auth_read_printer_profiles" ON pos_printer_profiles;
CREATE POLICY "auth_read_printer_profiles" ON pos_printer_profiles FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_printer_profiles" ON pos_printer_profiles;
CREATE POLICY "auth_insert_printer_profiles" ON pos_printer_profiles FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_printer_profiles" ON pos_printer_profiles;
CREATE POLICY "auth_update_printer_profiles" ON pos_printer_profiles FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- pos_receipt_history
DROP POLICY IF EXISTS "auth_read_receipt_history" ON pos_receipt_history;
CREATE POLICY "auth_read_receipt_history" ON pos_receipt_history FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_receipt_history" ON pos_receipt_history;
CREATE POLICY "auth_insert_receipt_history" ON pos_receipt_history FOR INSERT TO authenticated WITH CHECK (true);

-- pos_payment_splits
DROP POLICY IF EXISTS "auth_read_payment_splits" ON pos_payment_splits;
CREATE POLICY "auth_read_payment_splits" ON pos_payment_splits FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_payment_splits" ON pos_payment_splits;
CREATE POLICY "auth_insert_payment_splits" ON pos_payment_splits FOR INSERT TO authenticated WITH CHECK (true);

-- pos_shifts
DROP POLICY IF EXISTS "auth_read_shifts" ON pos_shifts;
CREATE POLICY "auth_read_shifts" ON pos_shifts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_shifts" ON pos_shifts;
CREATE POLICY "auth_insert_shifts" ON pos_shifts FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_shifts" ON pos_shifts;
CREATE POLICY "auth_update_shifts" ON pos_shifts FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- S-2: Audit Log — Insert-Only (ห้าม UPDATE/DELETE)
-- ============================================================================

-- pos_order_status_log: insert-only (ไม่มี policy สำหรับ UPDATE/DELETE)
DROP POLICY IF EXISTS "auth_read_status_log" ON pos_order_status_log;
CREATE POLICY "auth_read_status_log" ON pos_order_status_log FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_status_log" ON pos_order_status_log;
CREATE POLICY "auth_insert_status_log" ON pos_order_status_log FOR INSERT TO authenticated WITH CHECK (true);
-- ไม่มี UPDATE/DELETE policy = ไม่มีใครแก้ไขหรือลบ audit log ได้

-- pos_loyalty_transactions: insert-only สำหรับ transaction records
-- (มีเฉพาะ SELECT + INSERT policy ด้านบนแล้ว — ไม่มี UPDATE/DELETE)

-- pos_order_discounts: insert-only (บันทึกแล้วห้ามแก้)
-- (มีเฉพาะ SELECT + INSERT policy ด้านบนแล้ว)

-- pos_receipt_history: insert-only
-- (มีเฉพาะ SELECT + INSERT policy ด้านบนแล้ว)

-- pos_payment_splits: insert-only
-- (มีเฉพาะ SELECT + INSERT policy ด้านบนแล้ว)

-- ============================================================================
-- S-5: Manager PIN — เพิ่มคอลัมน์ hashed_pin + failed_attempts
-- ============================================================================

-- เพิ่มตารางสำหรับ manager PIN verification
CREATE TABLE IF NOT EXISTS pos_manager_pins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    pin_hash TEXT NOT NULL,              -- bcrypt/SHA-256 hash
    failed_attempts INT DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE pos_manager_pins ENABLE ROW LEVEL SECURITY;

-- Only the user themselves can read their own PIN hash (for verification)
DROP POLICY IF EXISTS "user_read_own_pin" ON pos_manager_pins;
CREATE POLICY "user_read_own_pin" ON pos_manager_pins FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Only insert/update own PIN
DROP POLICY IF EXISTS "user_manage_own_pin" ON pos_manager_pins;
CREATE POLICY "user_manage_own_pin" ON pos_manager_pins FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "user_update_own_pin" ON pos_manager_pins;
CREATE POLICY "user_update_own_pin" ON pos_manager_pins FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

COMMENT ON TABLE pos_manager_pins IS 'เก็บ hashed PIN สำหรับผู้จัดการ (S-5)';
COMMENT ON COLUMN pos_manager_pins.failed_attempts IS 'จำนวนครั้งที่ใส่ PIN ผิด (reset เมื่อใส่ถูก)';
COMMENT ON COLUMN pos_manager_pins.locked_until IS 'ล็อกถึงเวลา (5 นาทีหลังผิด 5 ครั้ง)';

-- ============================================================================
-- S-9: DB Constraints — ป้องกันค่าติดลบ
-- ============================================================================

-- pos_orders: net_total, discount_amount ต้องไม่ติดลบ
ALTER TABLE IF EXISTS pos_orders
    ADD CONSTRAINT chk_pos_orders_net_total_non_negative CHECK (net_total >= 0),
    ADD CONSTRAINT chk_pos_orders_discount_non_negative CHECK (discount_amount >= 0);

-- pos_order_lines: quantity, unit_price, line_total ต้องไม่ติดลบ
ALTER TABLE IF EXISTS pos_order_lines
    ADD CONSTRAINT chk_pos_order_lines_qty_positive CHECK (quantity > 0),
    ADD CONSTRAINT chk_pos_order_lines_price_non_negative CHECK (unit_price >= 0),
    ADD CONSTRAINT chk_pos_order_lines_total_non_negative CHECK (line_total >= 0);

-- pos_payment_splits: amount ต้องมากกว่า 0
ALTER TABLE IF EXISTS pos_payment_splits
    ADD CONSTRAINT chk_pos_payment_splits_amount_positive CHECK (amount > 0);

-- pos_refunds: refund_amount ต้องมากกว่า 0
ALTER TABLE IF EXISTS pos_refunds
    ADD CONSTRAINT chk_pos_refunds_amount_positive CHECK (refund_amount > 0);

-- pos_shifts: opening_cash ต้องไม่ติดลบ
ALTER TABLE IF EXISTS pos_shifts
    ADD CONSTRAINT chk_pos_shifts_opening_cash_non_negative CHECK (opening_cash >= 0);

-- pos_daily_settlements: counted_cash ต้องไม่ติดลบ
ALTER TABLE IF EXISTS pos_daily_settlements
    ADD CONSTRAINT chk_pos_daily_settlements_counted_cash_non_negative CHECK (counted_cash IS NULL OR counted_cash >= 0);
