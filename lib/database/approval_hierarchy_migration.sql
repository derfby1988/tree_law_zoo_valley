-- =============================================
-- Migration: Approval Hierarchy Rules
-- สำหรับกำหนดวงเงินอนุมัติและลำดับการอนุมัติใน HRM
-- =============================================

CREATE TABLE IF NOT EXISTS approval_hierarchy_rules (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id uuid NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,
  max_amount numeric(14,2),
  is_unlimited boolean NOT NULL DEFAULT false,
  priority integer NOT NULL DEFAULT 99,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT approval_hierarchy_rules_group_unique UNIQUE (group_id),
  CONSTRAINT approval_hierarchy_rules_amount_check CHECK (
    (is_unlimited = true AND max_amount IS NULL) OR
    (is_unlimited = false AND max_amount IS NOT NULL AND max_amount >= 0)
  )
);

CREATE INDEX IF NOT EXISTS idx_approval_hierarchy_rules_priority
  ON approval_hierarchy_rules(priority);

CREATE INDEX IF NOT EXISTS idx_approval_hierarchy_rules_active
  ON approval_hierarchy_rules(is_active);

ALTER TABLE approval_hierarchy_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read approval hierarchy rules" ON approval_hierarchy_rules;
CREATE POLICY "Authenticated users can read approval hierarchy rules"
  ON approval_hierarchy_rules FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can manage approval hierarchy rules" ON approval_hierarchy_rules;
CREATE POLICY "Authenticated users can manage approval hierarchy rules"
  ON approval_hierarchy_rules FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION update_approval_hierarchy_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_approval_hierarchy_updated_at ON approval_hierarchy_rules;
CREATE TRIGGER trg_approval_hierarchy_updated_at
  BEFORE UPDATE ON approval_hierarchy_rules
  FOR EACH ROW
  EXECUTE FUNCTION update_approval_hierarchy_updated_at();
