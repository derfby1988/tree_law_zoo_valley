-- ============================================================================
-- Daily Coupon Entry Logs (Phase 13)
-- ============================================================================
-- บันทึกประวัติการเข้า/ออกพื้นที่สำหรับคูปองรายวัน โดยไม่ใช้ข้อมูล mock
-- ใช้ร่วมกับ pos_order_discounts (ช่องทาง POS) เพื่อวิเคราะห์ timeline ทั้ง 2 ช่องทาง
-- ============================================================================

CREATE TABLE IF NOT EXISTS daily_coupon_entry_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    discount_id UUID NOT NULL REFERENCES pos_discounts(id) ON DELETE CASCADE,
    coupon_code TEXT,
    coupon_audience TEXT DEFAULT 'individual',
    member_identifier TEXT,
    entry_area TEXT NOT NULL,
    gate_id TEXT,
    direction TEXT DEFAULT 'enter', -- enter / exit
    status TEXT DEFAULT 'pending', -- pending/valid/denied
    reason_code TEXT,
    scanned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_info JSONB,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_daily_coupon_entry_logs_discount ON daily_coupon_entry_logs(discount_id);
CREATE INDEX IF NOT EXISTS idx_daily_coupon_entry_logs_scanned_at ON daily_coupon_entry_logs(scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_daily_coupon_entry_logs_status ON daily_coupon_entry_logs(status);

COMMENT ON TABLE daily_coupon_entry_logs IS 'ประวัติการสแกนคูปองรายวันสำหรับสิทธิ์เข้าพื้นที่';
COMMENT ON COLUMN daily_coupon_entry_logs.member_identifier IS 'เก็บรหัสสมาชิกหรือชื่อย่อผู้ใช้สิทธิ์ (สำหรับคูปองรายกลุ่ม)';

-- View สำหรับสรุปยอดการเข้า/ออกต่อวัน (ใช้ใน history tab)
CREATE OR REPLACE VIEW daily_coupon_entry_summary AS
SELECT
    discount_id,
    date_trunc('day', scanned_at) AS usage_day,
    COUNT(*) FILTER (WHERE status = 'valid' AND direction = 'enter') AS total_entries,
    COUNT(*) FILTER (WHERE status = 'valid' AND direction = 'exit') AS total_exits,
    COUNT(*) FILTER (WHERE status <> 'valid') AS total_denied
FROM daily_coupon_entry_logs
GROUP BY discount_id, date_trunc('day', scanned_at);

COMMENT ON VIEW daily_coupon_entry_summary IS 'สรุปจำนวนการเข้า/ออกของคูปองรายวันต่อวัน';
