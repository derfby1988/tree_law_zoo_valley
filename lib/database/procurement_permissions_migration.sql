-- =============================================
-- Procurement Permissions Migration
-- เพิ่มสิทธิ์ระบบจัดซื้อจัดจ้าง
-- รันหลังจาก procurement_migration.sql
-- =============================================

-- สิทธิ์ระดับ Tab สำหรับระบบจัดซื้อ (Role-based: หัวหน้าร้าน → ผู้จัดการ → ผู้บริหาร)
INSERT INTO group_tab_permissions (group_id, tab_id, can_access) VALUES
-- ระดับหัวหน้าร้าน (store_manager)
('store_manager', 'procurement_purchase', true),
('store_manager', 'procurement_tracking', false),
('store_manager', 'procurement_receive', true),

-- ระดับผู้จัดการ (manager)
('manager', 'procurement_purchase', true),
('manager', 'procurement_tracking', true),
('manager', 'procurement_receive', true),

-- ระดับผู้บริหาร (admin)
('admin', 'procurement_purchase', true),
('admin', 'procurement_tracking', true),
('admin', 'procurement_receive', true)

ON CONFLICT (group_id, tab_id) DO NOTHING;

-- สิทธิ์ระดับ Action สำหรับระบบจัดซื้อ (Role-based: หัวหน้าร้าน → ผู้จัดการ → ผู้บริหาร)
INSERT INTO group_action_permissions (group_id, action_id, can_access) VALUES
-- สร้าง PO (Create Purchase Order)
('store_manager', 'procurement_purchase_create', false),
('manager', 'procurement_purchase_create', true),
('admin', 'procurement_purchase_create', true),

-- แก้ไข PO (Edit Purchase Order)
('store_manager', 'procurement_purchase_edit', false),
('manager', 'procurement_purchase_edit', true),
('admin', 'procurement_purchase_edit', true),

-- ลบ PO (Delete Purchase Order)
('store_manager', 'procurement_purchase_delete', false),
('manager', 'procurement_purchase_delete', false),
('admin', 'procurement_purchase_delete', true),

-- ส่ง PO (Send Purchase Order)
('store_manager', 'procurement_purchase_send', false),
('manager', 'procurement_purchase_send', true),
('admin', 'procurement_purchase_send', true),

-- อนุมัติ PO ไม่เกิน 5,000 บาท
('store_manager', 'procurement_purchase_approve_5000', false),
('manager', 'procurement_purchase_approve_5000', true),
('admin', 'procurement_purchase_approve_5000', true),

-- อนุมัติ PO ไม่เกิน 50,000 บาท
('store_manager', 'procurement_purchase_approve_50000', false),
('manager', 'procurement_purchase_approve_50000', false),
('admin', 'procurement_purchase_approve_50000', true),

-- อนุมัติ PO ไม่จำกัดวงเงิน
('store_manager', 'procurement_purchase_approve_unlimited', false),
('manager', 'procurement_purchase_approve_unlimited', false),
('admin', 'procurement_purchase_approve_unlimited', true),

-- ยกเลิก PO (Cancel Purchase Order)
('store_manager', 'procurement_purchase_cancel', false),
('manager', 'procurement_purchase_cancel', true),
('admin', 'procurement_purchase_cancel', true),

-- จัดการ Supplier (Create/Edit/Delete)
('store_manager', 'procurement_supplier_manage', false),
('manager', 'procurement_supplier_manage', true),
('admin', 'procurement_supplier_manage', true),

-- รับสินค้าเข้าคลัง (Receive Goods)
('store_manager', 'procurement_receive_goods', true),
('manager', 'procurement_receive_goods', true),
('admin', 'procurement_receive_goods', true),

-- พิมพ์เอกสาร (Print Documents)
('store_manager', 'procurement_print_documents', true),
('manager', 'procurement_print_documents', true),
('admin', 'procurement_print_documents', true),

-- ดูรายงาน (View Reports)
('store_manager', 'procurement_view_reports', false),
('manager', 'procurement_view_reports', true),
('admin', 'procurement_view_reports', true)

ON CONFLICT (group_id, action_id) DO NOTHING;
