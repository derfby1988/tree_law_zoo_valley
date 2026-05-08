-- =============================================
-- Coupon & Promotion Phase 9: Governance System
-- Tree Law Zoo Valley
-- =============================================
-- Purpose:
-- - Conflict detection for promotions
-- - Approval workflow management
-- - Audit logging for all actions
-- - Override permission system
-- =============================================

-- =============================================
-- 1. Promotion Conflicts Detection Table
-- =============================================
CREATE TABLE IF NOT EXISTS promotion_conflicts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Promotion being checked
  promotion_id UUID REFERENCES pos_promotions(id) ON DELETE CASCADE,
  
  -- Conflict details
  conflict_type TEXT NOT NULL CHECK (conflict_type IN (
    'product_overlap',      -- Same product in multiple promotions
    'time_overlap',         -- Overlapping time periods
    'margin_exceeded',      -- Total discount exceeds margin
    'insufficient_stock',   -- Stock not enough for promotion
    'ingredient_shortage',  -- Ingredient not enough
    'duplicate_coupon',     -- Same coupon code exists
    'incompatible_combo'    -- Incompatible promotion combinations
  )),
  
  -- Severity level
  severity TEXT NOT NULL CHECK (severity IN ('critical', 'warning', 'info')),
  
  -- Conflicting entity
  conflicting_promotion_id UUID REFERENCES pos_promotions(id) ON DELETE CASCADE,
  conflicting_coupon_id UUID REFERENCES pos_discounts(id) ON DELETE CASCADE,
  conflicting_product_id UUID REFERENCES inventory_products(id) ON DELETE CASCADE,
  
  -- Detailed message
  message TEXT NOT NULL,
  message_en TEXT,
  
  -- Suggested resolution
  suggested_action TEXT,
  
  -- Status
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'overridden', 'ignored')),
  
  -- Resolution details
  resolved_by UUID REFERENCES auth.users(id),
  resolved_at TIMESTAMPTZ,
  resolution_note TEXT,
  
  -- Detection timestamp
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for conflict queries
CREATE INDEX idx_promotion_conflicts_promotion ON promotion_conflicts(promotion_id);
CREATE INDEX idx_promotion_conflicts_type ON promotion_conflicts(conflict_type);
CREATE INDEX idx_promotion_conflicts_severity ON promotion_conflicts(severity);
CREATE INDEX idx_promotion_conflicts_status ON promotion_conflicts(status);
CREATE INDEX idx_promotion_conflicts_detected ON promotion_conflicts(detected_at);

-- =============================================
-- 2. Promotion Preview/Simulation Results
-- =============================================
CREATE TABLE IF NOT EXISTS promotion_simulations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Promotion being simulated
  promotion_id UUID REFERENCES pos_promotions(id) ON DELETE CASCADE,
  
  -- Simulation parameters
  simulation_date DATE NOT NULL DEFAULT CURRENT_DATE,
  simulated_by UUID REFERENCES auth.users(id),
  
  -- Impact predictions
  estimated_revenue_impact DECIMAL(15, 2),      -- ผลกระทบรายได้ที่ประมาณการ
  estimated_discount_total DECIMAL(15, 2),      -- ส่วนลดรวมที่ประมาณการ
  estimated_margin_impact DECIMAL(15, 2),       -- ผลกระทบต่อกำไรขั้นต้น
  estimated_customer_count INTEGER,             -- จำนวนลูกค้าที่คาดว่าจะใช้
  
  -- Stock impact
  products_at_risk JSONB,                         -- สินค้าที่อาจหมดสต็อก [{product_id, current_stock, estimated_usage, risk_level}]
  ingredients_at_risk JSONB,                      -- วัตถุดิบที่อาจไม่พอ [{ingredient_id, current_stock, estimated_usage, risk_level}]
  
  -- Historical comparison (if similar promotion existed before)
  similar_promotion_id UUID REFERENCES pos_promotions(id),
  historical_performance JSONB,                 -- ผลงานย้อนหลัง {usage_count, total_discount, avg_per_customer}
  
  -- Simulation results
  risk_assessment TEXT CHECK (risk_assessment IN ('low', 'medium', 'high', 'critical')),
  recommendation TEXT,                            -- คำแนะนำ
  
  -- Approval suggestion
  suggested_approval_level TEXT,                  -- ระดับการอนุมัติที่แนะนำ
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_promotion_simulations_promotion ON promotion_simulations(promotion_id);
CREATE INDEX idx_promotion_simulations_date ON promotion_simulations(simulation_date);

-- =============================================
-- 3. Approval Workflow for Promotions
-- =============================================
CREATE TABLE IF NOT EXISTS promotion_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Promotion being approved
  promotion_id UUID REFERENCES pos_promotions(id) ON DELETE CASCADE,
  
  -- Current status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
    'draft',
    'pending',           -- รอการอนุมัติ
    'under_review',      -- กำลังตรวจสอบ
    'conditionally_approved', -- อนุมัติแบบมีเงื่อนไข
    'approved',          -- อนุมัติแล้ว
    'rejected',          -- ถูกปฏิเสธ
    'requires_override'  -- ต้องการ override
  )),
  
  -- Approval hierarchy
  current_approval_level INTEGER DEFAULT 1,       -- ระดับการอนุมัติปัจจุบัน
  total_approval_levels INTEGER DEFAULT 1,        -- ระดับการอนุมัติทั้งหมดที่ต้องผ่าน
  
  -- Requester info
  requested_by UUID NOT NULL REFERENCES auth.users(id),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Current approver
  assigned_approver_id UUID REFERENCES auth.users(id),
  assigned_group_id UUID REFERENCES user_groups(id),
  
  -- Approval details
  approved_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMPTZ,
  approval_note TEXT,
  
  -- Rejection details
  rejected_by UUID REFERENCES auth.users(id),
  rejected_at TIMESTAMPTZ,
  rejection_reason TEXT,
  
  -- Override details
  overridden_by UUID REFERENCES auth.users(id),
  overridden_at TIMESTAMPTZ,
  override_reason TEXT,
  override_permission_id UUID,                      -- อ้างอิงถึงสิทธิที่ใช้ override
  
  -- Conditions for conditional approval
  conditions JSONB,                                 -- เงื่อนไขการอนุมัติ [{condition, deadline, status}]
  
  -- Auto-approve settings
  auto_approve_threshold DECIMAL(15, 2),          -- ยอดที่อนุมัติอัตโนมัติได้
  is_auto_approved BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_promotion_approvals_promotion ON promotion_approvals(promotion_id);
CREATE INDEX idx_promotion_approvals_status ON promotion_approvals(status);
CREATE INDEX idx_promotion_approvals_requester ON promotion_approvals(requested_by);
CREATE INDEX idx_promotion_approvals_approver ON promotion_approvals(assigned_approver_id);

-- =============================================
-- 4. Approval Workflow History
-- =============================================
CREATE TABLE IF NOT EXISTS promotion_approval_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  approval_id UUID REFERENCES promotion_approvals(id) ON DELETE CASCADE,
  promotion_id UUID REFERENCES pos_promotions(id) ON DELETE CASCADE,
  
  -- Action details
  action TEXT NOT NULL CHECK (action IN (
    'submitted',
    'assigned',
    'reviewed',
    'approved',
    'rejected',
    'overridden',
    'escalated',
    'returned',
    'commented'
  )),
  
  -- Actor
  actor_id UUID NOT NULL REFERENCES auth.users(id),
  actor_group_id UUID REFERENCES user_groups(id),
  
  -- Details
  from_status TEXT,
  to_status TEXT,
  comment TEXT,
  
  -- Level info
  approval_level INTEGER,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_promotion_approval_history_approval ON promotion_approval_history(approval_id);
CREATE INDEX idx_promotion_approval_history_promotion ON promotion_approval_history(promotion_id);
CREATE INDEX idx_promotion_approval_history_actor ON promotion_approval_history(actor_id);

-- =============================================
-- 5. Audit Log for Coupon/Promotion Management
-- =============================================
CREATE TABLE IF NOT EXISTS coupon_promotion_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Action classification
  action_type TEXT NOT NULL CHECK (action_type IN (
    'coupon_created',
    'coupon_updated',
    'coupon_deleted',
    'coupon_activated',
    'coupon_deactivated',
    'coupon_archived',
    'promotion_created',
    'promotion_updated',
    'promotion_deleted',
    'promotion_activated',
    'promotion_paused',
    'promotion_archived',
    'promotion_scheduled',
    'approval_requested',
    'approval_granted',
    'approval_rejected',
    'conflict_detected',
    'conflict_resolved',
    'override_used',
    'simulation_run',
    'settings_changed'
  )),
  
  -- Entity info
  entity_type TEXT NOT NULL CHECK (entity_type IN ('coupon', 'promotion', 'approval', 'conflict', 'system')),
  entity_id UUID,                                 -- อาจเป็น NULL สำหรับ system actions
  
  -- Actor info
  actor_id UUID NOT NULL REFERENCES auth.users(id),
  actor_group_id UUID REFERENCES user_groups(id),
  actor_ip_address INET,
  actor_user_agent TEXT,
  
  -- Change details
  old_values JSONB,                               -- ค่าเก่า (สำหรับ update)
  new_values JSONB,                               -- ค่าใหม่
  changed_fields TEXT[],                          -- ฟิลด์ที่เปลี่ยนแปลง
  
  -- Context
  page_url TEXT,                                  -- URL ที่ทำการกระทำ
  session_id TEXT,                                -- session ID
  
  -- Reason/notes
  reason TEXT,                                    -- เหตุผลการกระทำ
  notes TEXT,                                     -- บันทึกเพิ่มเติม
  
  -- Related entities
  related_coupon_id UUID REFERENCES pos_discounts(id),
  related_promotion_id UUID REFERENCES pos_promotions(id),
  related_order_id UUID REFERENCES pos_orders(id),
  
  -- Timestamp
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Retention (for data cleanup)
  retention_until DATE                             -- เก็บข้อมูลถึงวันที่
);

-- Indexes for audit queries
CREATE INDEX idx_audit_log_action_type ON coupon_promotion_audit_log(action_type);
CREATE INDEX idx_audit_log_entity ON coupon_promotion_audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON coupon_promotion_audit_log(actor_id);
CREATE INDEX idx_audit_log_created ON coupon_promotion_audit_log(created_at);
CREATE INDEX idx_audit_log_coupon ON coupon_promotion_audit_log(related_coupon_id);
CREATE INDEX idx_audit_log_promotion ON coupon_promotion_audit_log(related_promotion_id);

-- Partitioning for large audit logs (optional, for future)
-- Can be partitioned by month/year when data grows

-- =============================================
-- 6. Override Permissions for Governance
-- =============================================
CREATE TABLE IF NOT EXISTS promotion_override_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Permission holder
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  group_id UUID REFERENCES user_groups(id) ON DELETE CASCADE,
  
  -- Ensure at least one of user_id or group_id is set
  CONSTRAINT user_or_group_required CHECK (
    (user_id IS NOT NULL) OR (group_id IS NOT NULL)
  ),
  
  -- Override capabilities
  can_override_conflicts BOOLEAN DEFAULT FALSE,      -- สามารถ override conflicts ได้
  can_override_approval BOOLEAN DEFAULT FALSE,       -- สามารถ override approval ได้
  can_override_margin_limit BOOLEAN DEFAULT FALSE,   -- สามารถ override ข้อจำกัด margin ได้
  can_override_stock_check BOOLEAN DEFAULT FALSE,    -- สามารถ override การตรวจสต็อกได้
  
  -- Limits
  max_override_amount DECIMAL(15, 2),               -- ยอดสูงสุดที่สามารถ override ได้
  override_count_limit INTEGER,                     -- จำนวนครั้งที่ override ได้ (NULL = ไม่จำกัด)
  
  -- Scope
  applicable_promotion_types TEXT[],                -- ประเภทโปรโมชั่นที่สามารถ override ได้
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  valid_from DATE DEFAULT CURRENT_DATE,
  valid_until DATE,                                 -- NULL = ไม่มีวันหมดอายุ
  
  -- Tracking
  granted_by UUID REFERENCES auth.users(id),
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  revoked_by UUID REFERENCES auth.users(id),
  revoked_at TIMESTAMPTZ,
  revocation_reason TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint for user/group and permission type
  CONSTRAINT unique_user_permission UNIQUE NULLS NOT DISTINCT (user_id, group_id)
);

CREATE INDEX idx_override_permissions_user ON promotion_override_permissions(user_id);
CREATE INDEX idx_override_permissions_group ON promotion_override_permissions(group_id);
CREATE INDEX idx_override_permissions_active ON promotion_override_permissions(is_active);

-- =============================================
-- 7. Governance Rules and Policies
-- =============================================
CREATE TABLE IF NOT EXISTS promotion_governance_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Rule identification
  rule_name TEXT NOT NULL,
  rule_code TEXT UNIQUE NOT NULL,                   -- รหัสกฎสำหรับอ้างอิงในโค้ด
  
  -- Rule type
  rule_type TEXT NOT NULL CHECK (rule_type IN (
    'conflict_threshold',       -- เกณฑ์การตรวจจับ conflict
    'approval_requirement',     -- เงื่อนไขการต้องอนุมัติ
    'margin_protection',        -- การป้องกัน margin
    'stock_protection',         -- การป้องกันสต็อก
    'auto_approval',            -- เงื่อนไขอนุมัติอัตโนมัติ
    'override_limit',           -- ข้อจำกัดการ override
    'audit_requirement'         -- เงื่อนไขการบันทึก audit
  )),
  
  -- Rule configuration
  config JSONB NOT NULL,                            -- การตั้งค่ากฎ
  
  -- Example configs:
  -- conflict_threshold: {min_overlap_days: 3, severity_weights: {...}}
  -- approval_requirement: {amount_thresholds: [{max: 5000, level: 1}, {max: 50000, level: 2}]}
  -- margin_protection: {max_discount_percent: 30, min_margin_after: 10}
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  priority INTEGER DEFAULT 100,                   -- ลำดับความสำคัญ (ต่ำ = สำคัญกว่า)
  
  -- Validity
  valid_from DATE DEFAULT CURRENT_DATE,
  valid_until DATE,
  
  -- Description
  description TEXT,
  description_en TEXT,
  
  -- Metadata
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_governance_rules_type ON promotion_governance_rules(rule_type);
CREATE INDEX idx_governance_rules_active ON promotion_governance_rules(is_active);
CREATE INDEX idx_governance_rules_code ON promotion_governance_rules(rule_code);

-- =============================================
-- 8. Functions for Governance
-- =============================================

-- Function to detect conflicts for a promotion
CREATE OR REPLACE FUNCTION detect_promotion_conflicts(p_promotion_id UUID)
RETURNS TABLE (
  conflict_type TEXT,
  severity TEXT,
  conflicting_entity_id UUID,
  message TEXT,
  suggested_action TEXT
) AS $$
DECLARE
  v_promotion RECORD;
  v_product RECORD;
BEGIN
  -- Get promotion details
  SELECT * INTO v_promotion FROM pos_promotions WHERE id = p_promotion_id;
  
  IF v_promotion IS NULL THEN
    RETURN;
  END IF;
  
  -- Check 1: Product overlap with other active promotions
  RETURN QUERY
  SELECT 
    'product_overlap'::TEXT as conflict_type,
    'warning'::TEXT as severity,
    p2.id as conflicting_entity_id,
    'สินค้า ' || string_agg(DISTINCT ip.name, ', ') || ' อยู่ในโปรโมชัน ' || p2.name || ' ด้วย'::TEXT as message,
    'พิจารณารวมโปรโมชันหรือปรับเปลี่ยนช่วงเวลา'::TEXT as suggested_action
  FROM pos_promotions p2
  JOIN pos_promotion_target_products ptp2 ON p2.id = ptp2.promotion_id
  JOIN inventory_products ip ON ptp2.product_id = ip.id
  WHERE p2.id != p_promotion_id
    AND p2.is_active = true
    AND p2.status = 'active'
    AND (p2.start_date, p2.end_date) OVERLAPS (v_promotion.start_date, v_promotion.end_date)
    AND ptp2.product_id IN (
      SELECT product_id FROM pos_promotion_target_products WHERE promotion_id = p_promotion_id
    )
  GROUP BY p2.id, p2.name;
  
  -- Check 2: Time overlap with incompatible promotion types
  RETURN QUERY
  SELECT 
    'time_overlap'::TEXT as conflict_type,
    'info'::TEXT as severity,
    p2.id as conflicting_entity_id,
    'มีโปรโมชัน ' || p2.name || ' ที่ทับซ้อนกับช่วงเวลา'::TEXT as message,
    'ตรวจสอบว่าสามารถทำงานร่วมกันได้หรือไม่'::TEXT as suggested_action
  FROM pos_promotions p2
  WHERE p2.id != p_promotion_id
    AND p2.is_active = true
    AND p2.status = 'active'
    AND (p2.start_date, p2.end_date) OVERLAPS (v_promotion.start_date, v_promotion.end_date)
    AND p2.promotion_type != v_promotion.promotion_type;
  
  -- Check 3: Margin protection (if discount exceeds acceptable margin)
  -- This would require calculating expected discount vs product margins
  
  RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to log audit events
CREATE OR REPLACE FUNCTION log_coupon_promotion_audit(
  p_action_type TEXT,
  p_entity_type TEXT,
  p_entity_id UUID,
  p_actor_id UUID,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO coupon_promotion_audit_log (
    action_type,
    entity_type,
    entity_id,
    actor_id,
    old_values,
    new_values,
    changed_fields,
    reason,
    created_at
  ) VALUES (
    p_action_type,
    p_entity_type,
    p_entity_id,
    p_actor_id,
    p_old_values,
    p_new_values,
    CASE WHEN p_old_values IS NOT NULL AND p_new_values IS NOT NULL 
         THEN array(
           SELECT key FROM jsonb_each_text(p_new_values) 
           WHERE p_old_values->key IS DISTINCT FROM p_new_values->key
         )
         ELSE NULL
    END,
    p_reason,
    NOW()
  )
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user has override permission
CREATE OR REPLACE FUNCTION check_override_permission(
  p_user_id UUID,
  p_permission_type TEXT,  -- 'conflict', 'approval', 'margin', 'stock'
  p_amount DECIMAL DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_has_permission BOOLEAN := FALSE;
BEGIN
  -- Check user-specific permissions
  SELECT TRUE INTO v_has_permission
  FROM promotion_override_permissions
  WHERE (user_id = p_user_id OR 
         group_id IN (SELECT group_id FROM user_group_members WHERE user_id = p_user_id))
    AND is_active = true
    AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
    AND CASE p_permission_type
      WHEN 'conflict' THEN can_override_conflicts
      WHEN 'approval' THEN can_override_approval
      WHEN 'margin' THEN can_override_margin_limit
      WHEN 'stock' THEN can_override_stock_check
    END = true
    AND (max_override_amount IS NULL OR p_amount IS NULL OR p_amount <= max_override_amount);
  
  RETURN COALESCE(v_has_permission, FALSE);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 9. Triggers for Automatic Audit Logging
-- =============================================

-- Trigger function for promotion changes
CREATE OR REPLACE FUNCTION trigger_promotion_audit()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM log_coupon_promotion_audit(
      'promotion_created',
      'promotion',
      NEW.id,
      COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid()),
      NULL,
      to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM log_coupon_promotion_audit(
      'promotion_updated',
      'promotion',
      NEW.id,
      COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid()),
      to_jsonb(OLD),
      to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM log_coupon_promotion_audit(
      'promotion_deleted',
      'promotion',
      OLD.id,
      COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid()),
      to_jsonb(OLD),
      NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for coupon changes  
CREATE OR REPLACE FUNCTION trigger_coupon_audit()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM log_coupon_promotion_audit(
      'coupon_created',
      'coupon',
      NEW.id,
      COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid()),
      NULL,
      to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    PERFORM log_coupon_promotion_audit(
      'coupon_updated',
      'coupon',
      NEW.id,
      COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid()),
      to_jsonb(OLD),
      to_jsonb(NEW)
    );
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM log_coupon_promotion_audit(
      'coupon_deleted',
      'coupon',
      OLD.id,
      COALESCE(current_setting('app.current_user_id', true)::UUID, auth.uid()),
      to_jsonb(OLD),
      NULL
    );
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers (uncomment when ready)
-- CREATE TRIGGER promotion_audit_trigger
--   AFTER INSERT OR UPDATE OR DELETE ON pos_promotions
--   FOR EACH ROW EXECUTE FUNCTION trigger_promotion_audit();

-- CREATE TRIGGER coupon_audit_trigger  
--   AFTER INSERT OR UPDATE OR DELETE ON pos_discounts
--   FOR EACH ROW EXECUTE FUNCTION trigger_coupon_audit();

-- =============================================
-- 10. Seed Default Governance Rules
-- =============================================

INSERT INTO promotion_governance_rules (rule_code, rule_name, rule_type, config, description, priority)
VALUES 
  ('CONFLICT_PRODUCT_OVERLAP', 'ตรวจจับสินค้าซ้ำในโปรโมชัน', 'conflict_threshold', 
   '{"min_overlap_days": 1, "severity": "warning"}'::jsonb,
   'ตรวจสอบว่าสินค้าเดียวกันอยู่ในโปรโมชันที่ทับซ้อนกันหรือไม่', 100),
   
  ('CONFLICT_TIME_OVERLAP', 'ตรวจจับช่วงเวลาทับซ้อน', 'conflict_threshold',
   '{"min_overlap_days": 1, "severity": "info"}'::jsonb,
   'แจ้งเตือนเมื่อมีโปรโมชันที่ทับซ้อนกันช่วงเวลา', 200),
   
  ('APPROVAL_AMOUNT_TIER1', 'อนุมัติระดับ 1 (ยอดต่ำ)', 'approval_requirement',
   '{"max_amount": 5000, "required_groups": ["store_manager"], "auto_approve": true}'::jsonb,
   'ยอดส่วนลดรวมไม่เกิน 5,000 บาท อนุมัติอัตโนมัติหรือผ่านหัวหน้าร้าน', 100),
   
  ('APPROVAL_AMOUNT_TIER2', 'อนุมัติระดับ 2 (ยอดกลาง)', 'approval_requirement',
   '{"max_amount": 50000, "required_groups": ["manager"], "auto_approve": false}'::jsonb,
   'ยอดส่วนลดรวม 5,001-50,000 บาท ต้องผ่านผู้จัดการ', 100),
   
  ('APPROVAL_AMOUNT_TIER3', 'อนุมัติระดับ 3 (ยอดสูง)', 'approval_requirement',
   '{"max_amount": null, "required_groups": ["admin"], "auto_approve": false}'::jsonb,
   'ยอดส่วนลดรวมเกิน 50,000 บาท ต้องผ่านผู้บริหาร', 100),
   
  ('MARGIN_PROTECTION_30', 'ป้องกัน Margin 30%', 'margin_protection',
   '{"max_discount_percent": 30, "min_margin_after": 10}'::jsonb,
   'จำกัดส่วนลดไม่ให้เกิน 30% และเหลือ margin อย่างน้อย 10%', 50),
   
  ('STOCK_CHECK_CRITICAL', 'ตรวจสอบสต็อกวิกฤต', 'stock_protection',
   '{"min_days_stock": 7, "severity": "critical"}'::jsonb,
   'เตือนเมื่อสต็อกไม่พอสำหรับโปรโมชัน 7 วัน', 50)

ON CONFLICT (rule_code) DO NOTHING;

-- =============================================
-- Enable RLS (Row Level Security)
-- =============================================

ALTER TABLE promotion_conflicts ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_simulations ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_approval_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_promotion_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_override_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_governance_rules ENABLE ROW LEVEL SECURITY;

-- =============================================
-- Comments for documentation
-- =============================================

COMMENT ON TABLE promotion_conflicts IS 'ตารางเก็บข้อมูล conflicts ที่ตรวจพบระหว่าง promotions';
COMMENT ON TABLE promotion_simulations IS 'ตารางเก็บผลการจำลองผลกระทบของ promotion';
COMMENT ON TABLE promotion_approvals IS 'ตารางจัดการ workflow การอนุมัติ promotion';
COMMENT ON TABLE coupon_promotion_audit_log IS 'Audit log สำหรับทุกการกระทำในระบบคูปองและโปรโมชัน';
COMMENT ON TABLE promotion_override_permissions IS 'สิทธิ์การ override สำหรับ governance';
COMMENT ON TABLE promotion_governance_rules IS 'กฎและนโยบายสำหรับ governance system';
