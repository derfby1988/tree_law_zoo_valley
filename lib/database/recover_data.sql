-- ============================================
-- กู้ข้อมูลจาก Supabase Point-in-Time Recovery
-- ============================================

-- ตรวจสอบว่า Supabase มี PITR หรือไม่
-- ถ้ามี ให้ restore จาก dashboard

-- ทางเลือก: ตรวจสอบว่ามี audit log หรือ backup อื่นหรือไม่

-- ตรวจสอบว่ามีข้อมูลใน deleted rows (ถ้าเปิด soft delete)
-- Supabase ไม่มี recycle bin แต่อาจมี realtime logs

-- ตรวจสอบ Supabase Dashboard > Database > Backups
-- ถ้ามี Daily Backup ให้ restore ข้อมูลจากนั้น

-- ถ้าไม่มี backup เลย ต้องใส่ข้อมูลใหม่
