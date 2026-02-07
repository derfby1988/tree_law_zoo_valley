-- =============================================
-- Migration: Granular Permissions System
-- สร้างตาราง group_tab_permissions และ group_action_permissions
-- สำหรับกำหนดสิทธิ์ระดับ Tab และ ปุ่ม/Action
-- =============================================

-- ตาราง: group_tab_permissions
-- กำหนดสิทธิ์การเข้าถึง Tab ของแต่ละกลุ่ม
CREATE TABLE IF NOT EXISTS group_tab_permissions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id uuid NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,
  tab_id text NOT NULL,
  can_access boolean DEFAULT true,
  assigned_by uuid REFERENCES auth.users(id),
  assigned_at timestamptz DEFAULT now(),
  UNIQUE(group_id, tab_id)
);

-- ตาราง: group_action_permissions
-- กำหนดสิทธิ์การใช้งานปุ่ม/Action ของแต่ละกลุ่ม
CREATE TABLE IF NOT EXISTS group_action_permissions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id uuid NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,
  action_id text NOT NULL,
  can_access boolean DEFAULT true,
  assigned_by uuid REFERENCES auth.users(id),
  assigned_at timestamptz DEFAULT now(),
  UNIQUE(group_id, action_id)
);

-- =============================================
-- RLS Policies
-- =============================================

-- Enable RLS
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

-- =============================================
-- RPC Function: ดึงรายชื่อสมาชิกในกลุ่ม (bypass RLS อย่างปลอดภัย)
-- is_active ดึงจากตาราง users เพื่อบล็อค/ปลดบล็อคผู้ใช้ทั้งระบบ
-- =============================================
CREATE OR REPLACE FUNCTION get_group_members(p_group_id uuid)
RETURNS TABLE (
  user_id uuid,
  full_name text,
  email text,
  username text,
  avatar_url text,
  is_active boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    u.id AS user_id,
    u.full_name::text,
    u.email::text,
    u.username::text,
    u.avatar_url::text,
    COALESCE(u.is_active, true) AS is_active
  FROM user_group_members ugm
  JOIN users u ON u.id = ugm.user_id
  WHERE ugm.group_id = p_group_id
  ORDER BY u.full_name;
$$;

-- =============================================
-- Indexes สำหรับ Performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_group_tab_permissions_group_id 
  ON group_tab_permissions(group_id);
CREATE INDEX IF NOT EXISTS idx_group_tab_permissions_tab_id 
  ON group_tab_permissions(tab_id);
CREATE INDEX IF NOT EXISTS idx_group_action_permissions_group_id 
  ON group_action_permissions(group_id);
CREATE INDEX IF NOT EXISTS idx_group_action_permissions_action_id 
  ON group_action_permissions(action_id);
