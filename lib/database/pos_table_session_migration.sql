-- =============================================
-- POS Table Session Migration
-- เป้าหมาย:
-- 1) ผูกโต๊ะกับ current_order_id และ current_session_id
-- 2) รองรับสถานะโต๊ะ available / occupied / reserved / unavailable
-- 3) สร้าง table session สำหรับเปิด POS จากโต๊ะโดยตรง
-- =============================================

-- 1) สร้างตาราง session ของโต๊ะ
CREATE TABLE IF NOT EXISTS restaurant_table_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_id uuid NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
  zone_id uuid REFERENCES restaurant_zones(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES restaurant_bookings(id) ON DELETE SET NULL,
  customer_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  customer_name text,
  customer_phone text,
  status text NOT NULL DEFAULT 'open',
  current_order_id uuid,
  opened_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  opened_at timestamptz DEFAULT now(),
  closed_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  closed_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restaurant_table_sessions_table_status
  ON restaurant_table_sessions(table_id, status);
CREATE INDEX IF NOT EXISTS idx_restaurant_table_sessions_current_order
  ON restaurant_table_sessions(current_order_id);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_restaurant_table_sessions_open
  ON restaurant_table_sessions(table_id)
  WHERE status = 'open';

-- 2) ขยายโต๊ะให้รู้ session/order ปัจจุบัน
ALTER TABLE IF EXISTS restaurant_tables
  ADD COLUMN IF NOT EXISTS current_session_id uuid REFERENCES restaurant_table_sessions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS current_order_id uuid;

ALTER TABLE IF EXISTS restaurant_tables
  ALTER COLUMN status SET DEFAULT 'available';

-- 3) ขยาย pos_orders ให้รู้ table/session โดยตรง
ALTER TABLE IF EXISTS pos_orders
  ADD COLUMN IF NOT EXISTS table_id uuid REFERENCES restaurant_tables(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS table_session_id uuid REFERENCES restaurant_table_sessions(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF to_regclass('public.pos_orders') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'fk_restaurant_table_sessions_current_order_id'
    ) THEN
      ALTER TABLE restaurant_table_sessions
        ADD CONSTRAINT fk_restaurant_table_sessions_current_order_id
        FOREIGN KEY (current_order_id) REFERENCES pos_orders(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'fk_restaurant_tables_current_order_id'
    ) THEN
      ALTER TABLE restaurant_tables
        ADD CONSTRAINT fk_restaurant_tables_current_order_id
        FOREIGN KEY (current_order_id) REFERENCES pos_orders(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- 4) RLS + policy
ALTER TABLE restaurant_table_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON restaurant_table_sessions;
CREATE POLICY "Allow all for authenticated" ON restaurant_table_sessions
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =============================================
-- Checklist / งานที่ยังค้าง
-- [x] เพิ่ม restaurant_table_sessions สำหรับโต๊ะ/ลูกค้า/เซสชัน
-- [x] เพิ่ม current_session_id และ current_order_id บน restaurant_tables
-- [x] เพิ่ม table_id และ table_session_id บน pos_orders
-- [x] บังคับให้โต๊ะมี open session ได้เพียง 1 รายการต่อโต๊ะ
-- [ ] ทดสอบ create/open/close table session จากหน้า seating/table
-- [ ] ทดสอบ pos_orders ผูกกับ table_session_id และอัปเดต current_order_id
-- [ ] ทดสอบปิดโต๊ะแล้วคืน status เป็น available
-- =============================================
