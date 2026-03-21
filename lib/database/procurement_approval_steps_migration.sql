-- =============================================
-- Migration: Procurement Approval Steps + Audit Logs
-- สำหรับบังคับลำดับอนุมัติตาม priority และเก็บประวัติการอนุมัติ
-- =============================================

CREATE TABLE IF NOT EXISTS procurement_po_approval_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES procurement_purchase_orders(id) ON DELETE CASCADE,
  group_id UUID REFERENCES user_groups(id) ON DELETE SET NULL,
  role_key TEXT NOT NULL,
  priority INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'skipped')),
  approved_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_po_approval_steps_po ON procurement_po_approval_steps(po_id);
CREATE INDEX IF NOT EXISTS idx_po_approval_steps_priority ON procurement_po_approval_steps(priority);
CREATE INDEX IF NOT EXISTS idx_po_approval_steps_status ON procurement_po_approval_steps(status);

CREATE UNIQUE INDEX IF NOT EXISTS idx_po_approval_steps_unique_role_per_po
  ON procurement_po_approval_steps(po_id, role_key);

ALTER TABLE procurement_po_approval_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read PO approval steps" ON procurement_po_approval_steps;
CREATE POLICY "Authenticated users can read PO approval steps"
  ON procurement_po_approval_steps FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can manage PO approval steps" ON procurement_po_approval_steps;
CREATE POLICY "Authenticated users can manage PO approval steps"
  ON procurement_po_approval_steps FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE TABLE IF NOT EXISTS procurement_po_approval_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES procurement_purchase_orders(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  actor_user_id UUID REFERENCES auth.users(id),
  actor_role TEXT,
  priority INTEGER,
  message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_po_approval_audit_po ON procurement_po_approval_audit_logs(po_id);
CREATE INDEX IF NOT EXISTS idx_po_approval_audit_created_at ON procurement_po_approval_audit_logs(created_at DESC);

ALTER TABLE procurement_po_approval_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read PO approval audit logs" ON procurement_po_approval_audit_logs;
CREATE POLICY "Authenticated users can read PO approval audit logs"
  ON procurement_po_approval_audit_logs FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can manage PO approval audit logs" ON procurement_po_approval_audit_logs;
CREATE POLICY "Authenticated users can manage PO approval audit logs"
  ON procurement_po_approval_audit_logs FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION update_po_approval_steps_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_po_approval_steps_updated_at ON procurement_po_approval_steps;
CREATE TRIGGER trg_po_approval_steps_updated_at
  BEFORE UPDATE ON procurement_po_approval_steps
  FOR EACH ROW
  EXECUTE FUNCTION update_po_approval_steps_updated_at();
