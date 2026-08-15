-- ============================================================================
-- POS Cash Movements (P5-6d: Cash In/Out ระหว่างกะ)
-- ============================================================================
-- บันทึกการเบิก/ฝาก/นำเงินออกระหว่างกะ (paid-in / paid-out / drop)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pos_cash_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID NOT NULL REFERENCES pos_shifts(id) ON DELETE CASCADE,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('paid_in', 'paid_out', 'drop')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reason TEXT NOT NULL,
    performed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    performed_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pos_cash_movements_shift ON pos_cash_movements(shift_id);
CREATE INDEX IF NOT EXISTS idx_pos_cash_movements_type ON pos_cash_movements(movement_type);

ALTER TABLE pos_cash_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth_read_cash_movements" ON pos_cash_movements;
CREATE POLICY "auth_read_cash_movements" ON pos_cash_movements FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_cash_movements" ON pos_cash_movements;
CREATE POLICY "auth_insert_cash_movements" ON pos_cash_movements FOR INSERT TO authenticated WITH CHECK (true);

COMMENT ON TABLE pos_cash_movements IS 'บันทึกการเบิก/ฝาก/นำเงินออกระหว่างกะ';
COMMENT ON COLUMN pos_cash_movements.movement_type IS 'paid_in=ฝากเงินเข้า, paid_out=เบิกเงินออก, drop=นำเงินส่วนเกินออกเก็บ';
