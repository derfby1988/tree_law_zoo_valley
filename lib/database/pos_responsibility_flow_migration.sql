-- =============================================
-- POS Responsibility & Customer Flow Migration
-- เป้าหมาย:
-- 1) ให้ทุกบิล POS มีพนักงานรับผิดชอบจากตาราง users
-- 2) รองรับการตั้งค่า group ว่าเป็น customer group / sales staff group
-- 3) เตรียมตาราง customer สำหรับ walk-in และลูกค้าที่ผูกกับ user
-- 4) สนับสนุน flow โต๊ะ/session ผ่าน migration แยก (pos_table_session_migration.sql)
-- =============================================
-- หมายเหตุ:
-- - ไฟล์นี้ถูกออกแบบให้รันซ้ำได้ (idempotent) เท่าที่โครงสร้าง SQL อนุญาต
-- - ถ้า pos_orders ยังไม่ถูกสร้าง ต้องให้ migration ของตารางหลักรันก่อนเสมอ
-- - flow โต๊ะ/เซสชัน/ current_order_id ถูกจัดการใน pos_table_session_migration.sql

-- 1) เพิ่ม flag ใน user_groups สำหรับใช้ใน HRM
ALTER TABLE IF EXISTS user_groups
  ADD COLUMN IF NOT EXISTS is_customer_group boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_sales_staff_group boolean DEFAULT false;

-- 2) เพิ่ม flag ใน users สำหรับระบุพนักงานขายโดยตรง
ALTER TABLE IF EXISTS users
  ADD COLUMN IF NOT EXISTS is_sales_staff boolean DEFAULT false;

-- 3) ขยาย pos_orders ให้ระบุผู้รับผิดชอบบิลและประเภทการขาย
ALTER TABLE IF EXISTS pos_orders
  ADD COLUMN IF NOT EXISTS order_type text DEFAULT 'walk_in',
  ADD COLUMN IF NOT EXISTS responsible_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS responsible_user_name text,
  ADD COLUMN IF NOT EXISTS cashier_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cashier_user_name text,
  ADD COLUMN IF NOT EXISTS customer_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS customer_name text,
  ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'paid',
  ADD COLUMN IF NOT EXISTS paid_total double precision DEFAULT 0,
  ADD COLUMN IF NOT EXISTS balance_due double precision DEFAULT 0;

-- 4) ตาราง customer สำหรับ walk-in และ customer ที่เลือกใช้ร่วมกับ POS
CREATE TABLE IF NOT EXISTS pos_customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  customer_type text NOT NULL DEFAULT 'walk_in',
  display_name text NOT NULL,
  phone text,
  email text,
  notes text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_customers_user_id ON pos_customers(user_id);
CREATE INDEX IF NOT EXISTS idx_pos_customers_customer_type ON pos_customers(customer_type);

DO $$
BEGIN
  IF to_regclass('public.pos_orders') IS NOT NULL THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_pos_orders_responsible_user ON pos_orders(responsible_user_id)';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_pos_orders_cashier_user ON pos_orders(cashier_user_id)';
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_pos_orders_customer_user ON pos_orders(customer_user_id)';
  END IF;
END $$;

-- =============================================
-- Checklist / งานที่ยังค้าง
-- [x] เพิ่ม flag ใน user_groups สำหรับ customer / sales staff
-- [x] เพิ่ม flag ใน users สำหรับระบุพนักงานขาย
-- [x] ขยาย pos_orders ให้เก็บ responsible / cashier / customer / payment context
-- [x] สร้าง pos_customers สำหรับ walk-in และลูกค้าที่ผูกกับ user
-- [x] ป้องกัน error ตอนสร้าง index เมื่อ pos_orders ยังไม่พร้อม
-- [x] ผูกหน้า seating/table ให้เปิด POS ด้วย table context โดยตรง
-- [x] ทำให้ POS เปิดพร้อม customer/session ของโต๊ะโดยตรง
-- [x] ใช้สถานะโต๊ะ occupied / available ร่วมกับ current_session_id/current_order_id
-- [ ] ตรวจสอบลำดับการรัน migration ในทุก environment
-- [ ] ทบทวนการส่ง order_type = dine_in / walk_in จาก UI จริง
-- [ ] วางแผน backfill ข้อมูลเก่า หากมี order เดิมที่ยังไม่มี responsible user
-- =============================================
