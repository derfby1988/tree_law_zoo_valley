-- =============================================
-- Restaurant Booking Lock & Prepaid Migration
-- เป้าหมาย:
-- 1) เพิ่ม payment_status / paid_at ให้ restaurant_bookings
-- 2) เพิ่ม current_booking_id ให้ restaurant_tables เพื่อใช้ล็อกโต๊ะจาก booking
-- 3) ทำให้ schema เดิมรองรับ booking ที่ชำระล่วงหน้าและคืนโต๊ะเมื่อยกเลิกจริง
-- =============================================

ALTER TABLE IF EXISTS restaurant_bookings
  ADD COLUMN IF NOT EXISTS payment_status varchar(20) DEFAULT 'unpaid',
  ADD COLUMN IF NOT EXISTS paid_at timestamptz;

ALTER TABLE IF EXISTS restaurant_tables
  ADD COLUMN IF NOT EXISTS current_booking_id uuid;

CREATE INDEX IF NOT EXISTS idx_restaurant_tables_current_booking
  ON restaurant_tables(current_booking_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_bookings_payment_status
  ON restaurant_bookings(payment_status);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_restaurant_bookings_active_table
  ON restaurant_bookings(table_id)
  WHERE status IN ('pending', 'confirmed');

-- =============================================
-- Checklist / งานที่ยังค้าง
-- [x] เพิ่ม payment_status และ paid_at ให้ restaurant_bookings
-- [x] เพิ่ม current_booking_id ให้ restaurant_tables
-- [x] รองรับ booking ที่ชำระล่วงหน้าและล็อกโต๊ะได้
-- [x] กัน active booking ซ้อนกันบนโต๊ะเดียวกันด้วย unique index
-- [ ] ทดสอบ create / cancel / expire booking บนฐานข้อมูลเดิม
-- [ ] ทดสอบคืนโต๊ะหลังยกเลิก booking ที่ชำระล่วงหน้าแล้ว
-- =============================================
