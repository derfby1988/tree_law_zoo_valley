-- =============================================
-- Inventory Tax Rules Engine (Thailand)
-- =============================================
-- IMPORTANT:
-- 1) Script นี้เป็นระบบช่วยแนะนำภาษี ไม่ใช่คำปรึกษากฎหมาย
-- 2) ต้องให้ผู้ใช้งาน/นักบัญชีตรวจสอบเอกสารภาษีจริงก่อนใช้งาน
-- 3) ควรทบทวนกฎทุกครั้งที่มีประกาศกฎหมายใหม่

CREATE TABLE IF NOT EXISTS inventory_tax_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES inventory_categories(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL DEFAULT 'both' CHECK (item_type IN ('product', 'ingredient', 'both')),
  is_tax_exempt BOOLEAN NOT NULL DEFAULT false,
  tax_rate DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
  tax_inclusion TEXT NOT NULL DEFAULT 'excluded' CHECK (tax_inclusion IN ('included', 'excluded')),
  rule_name TEXT NOT NULL,
  legal_reference TEXT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  priority INT NOT NULL DEFAULT 1,
  requires_manual_review BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT inventory_tax_rules_effective_range_chk
    CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS idx_inventory_tax_rules_category_type_active
  ON inventory_tax_rules(category_id, item_type, is_active);

CREATE INDEX IF NOT EXISTS idx_inventory_tax_rules_effective_date
  ON inventory_tax_rules(effective_from, effective_to);

CREATE UNIQUE INDEX IF NOT EXISTS ux_inventory_tax_rules_unique_window
  ON inventory_tax_rules(category_id, item_type, effective_from, COALESCE(effective_to, DATE '9999-12-31'));

CREATE OR REPLACE FUNCTION set_inventory_tax_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inventory_tax_rules_updated_at ON inventory_tax_rules;
CREATE TRIGGER trg_inventory_tax_rules_updated_at
  BEFORE UPDATE ON inventory_tax_rules
  FOR EACH ROW
  EXECUTE FUNCTION set_inventory_tax_rules_updated_at();

-- =============================================
-- Seed ตัวอย่างตามนโยบายไทยทั่วไป (แนะนำเบื้องต้น)
-- หมายเหตุ: ใช้ชื่อหมวดจาก inventory_categories แบบประมาณการ
-- =============================================

-- 1) ค่าเริ่มต้นสำหรับหมวดที่ยังไม่มีกฎเฉพาะ: VAT 7% (รวมภาษี)
INSERT INTO inventory_tax_rules (
  category_id,
  item_type,
  is_tax_exempt,
  tax_rate,
  tax_inclusion,
  rule_name,
  legal_reference,
  effective_from,
  priority,
  requires_manual_review,
  is_active
)
SELECT
  c.id,
  'product',
  false,
  7,
  'included',
  'VAT 7% ค่าเริ่มต้น (สินค้า)',
  'ประมวลรัษฎากร ภาษีมูลค่าเพิ่ม (ค่าเริ่มต้นระบบ)',
  DATE '2024-01-01',
  1,
  true,
  true
FROM inventory_categories c
WHERE NOT EXISTS (
  SELECT 1
  FROM inventory_tax_rules r
  WHERE r.category_id = c.id
    AND r.item_type = 'product'
    AND r.effective_from = DATE '2024-01-01'
);

-- 2) กลุ่มวัตถุดิบ/สินค้าเกษตร/อาหารสด (ตัวอย่าง) ตั้งเป็นยกเว้นภาษีเบื้องต้น
-- ต้องตรวจสอบข้อเท็จจริงธุรกรรมแต่ละรายการ
INSERT INTO inventory_tax_rules (
  category_id,
  item_type,
  is_tax_exempt,
  tax_rate,
  tax_inclusion,
  rule_name,
  legal_reference,
  effective_from,
  priority,
  requires_manual_review,
  is_active
)
SELECT
  c.id,
  'both',
  true,
  0,
  'excluded',
  'ยกเว้นภาษี (อาหารสด/เกษตร) - ตรวจสอบเอกสารประกอบ',
  'แนวทางยกเว้นภาษีสำหรับสินค้าบางประเภทตามประมวลรัษฎากร (ต้องตรวจสอบรายการจริง)',
  DATE '2024-01-01',
  10,
  true,
  true
FROM inventory_categories c
WHERE (
  lower(c.name) LIKE '%ผัก%'
  OR lower(c.name) LIKE '%ผลไม้%'
  OR lower(c.name) LIKE '%เนื้อสด%'
  OR lower(c.name) LIKE '%อาหารสด%'
  OR lower(c.name) LIKE '%เกษตร%'
  OR lower(c.name) LIKE '%วัตถุดิบ%'
)
AND NOT EXISTS (
  SELECT 1
  FROM inventory_tax_rules r
  WHERE r.category_id = c.id
    AND r.item_type = 'both'
    AND r.rule_name = 'ยกเว้นภาษี (อาหารสด/เกษตร) - ตรวจสอบเอกสารประกอบ'
);

-- =============================================
-- Optional: Enable RLS (ถ้าโปรเจกต์ใช้ RLS)
-- =============================================
-- ALTER TABLE inventory_tax_rules ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow read inventory tax rules" ON inventory_tax_rules
--   FOR SELECT TO authenticated USING (true);
-- CREATE POLICY "Allow manage inventory tax rules" ON inventory_tax_rules
--   FOR ALL TO authenticated USING (true) WITH CHECK (true);
