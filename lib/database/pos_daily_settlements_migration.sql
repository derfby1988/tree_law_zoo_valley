-- ============================================================================
-- POS Daily Settlements (P5-6b: End-of-Day / Daily Settlement Flow)
-- ============================================================================
-- ปิดยอดบัญชีประจำวันแบบครบวงจร
-- ใช้ร่วมกับ pos_shifts และ pos_orders เพื่อสรุปยอดขาย-เงินสด-โอน-คืนเงิน
-- ============================================================================

CREATE TABLE IF NOT EXISTS pos_daily_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_date DATE NOT NULL UNIQUE,
    store_id UUID,
    total_sales NUMERIC(12,2) DEFAULT 0,
    total_cash NUMERIC(12,2) DEFAULT 0,
    total_cashless NUMERIC(12,2) DEFAULT 0,
    total_refunds NUMERIC(12,2) DEFAULT 0,
    total_voids NUMERIC(12,2) DEFAULT 0,
    total_discounts NUMERIC(12,2) DEFAULT 0,
    total_loyalty_redeemed NUMERIC(12,2) DEFAULT 0,
    total_tax NUMERIC(12,2) DEFAULT 0,
    total_service_charge NUMERIC(12,2) DEFAULT 0,
    expected_cash NUMERIC(12,2) DEFAULT 0,
    counted_cash NUMERIC(12,2),
    cash_difference NUMERIC(12,2),
    shift_ids JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'closed', 'reopened')),
    closed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    closed_by_name TEXT,
    closed_at TIMESTAMPTZ,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_pos_daily_settlements_date ON pos_daily_settlements(settlement_date DESC);
CREATE INDEX IF NOT EXISTS idx_pos_daily_settlements_status ON pos_daily_settlements(status);

COMMENT ON TABLE pos_daily_settlements IS 'บันทึกการปิดยอดประจำวัน (EOD Settlement)';
COMMENT ON COLUMN pos_daily_settlements.expected_cash IS 'เงินสดที่ควรมีตามระบบ (opening_cash + cash_sales - refunds)';
COMMENT ON COLUMN pos_daily_settlements.counted_cash IS 'เงินสดที่นับได้จริง';
COMMENT ON COLUMN pos_daily_settlements.cash_difference IS 'เงินขาด/เกิน (counted_cash - expected_cash)';
COMMENT ON COLUMN pos_daily_settlements.shift_ids IS 'รายการ shift_id ทั้งหมดที่รวมใน settlement นี้';

-- ============================================================================
-- RLS Policies
-- ============================================================================

ALTER TABLE pos_daily_settlements ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read settlements
CREATE POLICY "Authenticated users can read daily settlements"
    ON pos_daily_settlements FOR SELECT
    TO authenticated
    USING (true);

-- Only users with pos_eod_close permission can insert/update
-- (enforced at application level via PermissionService; RLS allows authenticated writes)
CREATE POLICY "Authenticated users can insert daily settlements"
    ON pos_daily_settlements FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Authenticated users can update daily settlements"
    ON pos_daily_settlements FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================================================
-- Trigger: auto-set updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION set_pos_daily_settlements_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pos_daily_settlements_updated_at ON pos_daily_settlements;
CREATE TRIGGER trg_pos_daily_settlements_updated_at
    BEFORE UPDATE ON pos_daily_settlements
    FOR EACH ROW
    EXECUTE FUNCTION set_pos_daily_settlements_updated_at();
