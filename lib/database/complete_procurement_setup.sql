-- =============================================
-- Complete Procurement Setup
-- =============================================

-- 1. User Groups (จาก permissions_migration.sql)
CREATE TABLE IF NOT EXISTS user_groups (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. Permission Tables (จาก permissions_migration.sql)
CREATE TABLE IF NOT EXISTS group_tab_permissions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id uuid NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,
    tab_id text NOT NULL,
    can_access boolean DEFAULT true,
    assigned_by uuid REFERENCES auth.users(id),
    assigned_at timestamptz DEFAULT now(),
    UNIQUE(group_id, tab_id)
);

CREATE TABLE IF NOT EXISTS group_action_permissions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id uuid NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,
    action_id text NOT NULL,
    can_access boolean DEFAULT true,
    assigned_by uuid REFERENCES auth.users(id),
    assigned_at timestamptz DEFAULT now(),
    UNIQUE(group_id, action_id)
);

-- 3. Insert User Groups
INSERT INTO user_groups (id, name, description, is_active) VALUES
('store_manager', 'หัวหน้าร้าน', 'ผู้ดูแลรับสินค้า', true),
('manager', 'ผู้จัดการ', 'จัดการทั้งหมด', true),
('admin', 'ผู้บริหาร', 'ผู้บริหารระบบ', true)
ON CONFLICT (id) DO NOTHING;

-- 4. RLS Policies
-- (เพิ่ม policies จาก permissions_migration.sql)
ALTER TABLE user_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_tab_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_action_permissions ENABLE ROW LEVEL SECURITY;

-- group_tab_permissions: ทุกคนที่ login อ่านได้
CREATE POLICY "Authenticated users can read tab permissions"
  ON group_tab_permissions FOR SELECT
  TO authenticated
  USING (true);

-- group_tab_permissions: ทุกคนที่ login เพิ่ม/แก้/ลบได้
CREATE POLICY "Authenticated users can insert tab permissions"
  ON group_tab_permissions FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update tab permissions"
  ON group_tab_permissions FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can delete tab permissions"
  ON group_tab_permissions FOR DELETE
  TO authenticated
  USING (true);

-- group_action_permissions: ทุกคนที่ login อ่านได้
CREATE POLICY "Authenticated users can read action permissions"
  ON group_action_permissions FOR SELECT
  TO authenticated
  USING (true);

-- group_action_permissions: ทุกคนที่ login เพิ่ม/แก้/ลบได้
CREATE POLICY "Authenticated users can insert action permissions"
  ON group_action_permissions FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update action permissions"
  ON group_action_permissions FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can delete action permissions"
  ON group_action_permissions FOR DELETE
  TO authenticated
  USING (true);

-- 5. Procurement Permissions (จาก procurement_permissions_migration.sql)
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
