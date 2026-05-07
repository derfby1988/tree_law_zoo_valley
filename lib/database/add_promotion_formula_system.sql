-- =====================================================
-- ระบบจัดการสูตร Priority Score สำหรับแนะนำโปรโมชัน
-- =====================================================
-- สร้าง: 7 พฤษภาคม 2568
-- วัตถุประสงค์: เก็บสูตรคำนวณคะแนนแบบยืดหยุ่น ปรับเปลี่ยนได้ไม่ต้องแก้โค้ด
-- =====================================================

-- สูตรที่มีในฐานข้อมูล (13 สูตร):
-- 1. สูตรมาตรฐาน 2568 (active, default, ใช้ได้ตลอด)
-- 2. สูตรเทศกาลสงกรานต์ 2568 (10-20 เม.ย.)
-- 3. สูตรเทศกาลลอยกระทง 2568 (10-20 พ.ย.)
-- 4. สูตรเทศกาลปีใหม่ 2568 (20 ธ.ค. - 5 ม.ค.)
-- 5. สูตรระบายสต็อกด่วน (ใช้ได้ตลอด, เน้น expiry)
-- 6. สูตรเน้นกำไรสูง (ใช้ได้ตลอด, เน้น margin)
-- 7. สูตรฤดูร้อน 2568 (มี.ค. - พ.ค.)
-- 8. สูตรฤดูฝน 2568 (มิ.ย. - ต.ค.)
-- 9. สูตรฤดูหนาว 2568 (พ.ย. - ก.พ.)
-- 10. สูตรวันแม่ 2568 (5-15 ส.ค.)
-- 11. สูตรวันพ่อ 2568 (1-10 ธ.ค.)
-- 12. สูตรตรุษจีน 2568 (15 ม.ค. - 5 ก.พ. 2026)
-- 13. สูตรวาเลนไทน์ 2568 (10-16 ก.พ. 2026)
-- ผู้ใช้สามารถสร้างสูตรเพิ่มได้ผ่านหน้า UI

-- -----------------------------------------------------
-- 1. ตารางเก็บสูตรหลัก (หลายเวอร์ชัน แต่ใช้งานได้ทีละสูตร)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS promotion_formula_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- ข้อมูลพื้นฐานสูตร
  name VARCHAR(100) NOT NULL,                    -- ชื่อสูตร (เช่น "สูตรมาตรฐาน", "สูตรเทศกาลสงกรานต์")
  description TEXT,                               -- รายละเอียดสูตร
  
  -- สถานะการใช้งาน
  is_active BOOLEAN DEFAULT false,                -- ใช้งานอยู่หรือไม่ (ใช้ได้ทีละ 1 สูตร)
  is_default BOOLEAN DEFAULT false,               -- สูตรเริ่มต้น (fallback ถ้าไม่มี active)
  
  -- ช่วงเวลาใช้งาน (NULL = ใช้ได้ตลอดไม่มีจำกัด)
  valid_from DATE DEFAULT CURRENT_DATE,          -- เริ่มใช้งานวันที่ (NULL = ใช้ได้ทุกวันก่อน)
  valid_until DATE,                               -- หมดอายุวันที่ (NULL = ไม่หมดอายุ)
  
  -- น้ำหนักปัจจัย (รวมต้องเป็น 1.00 หรือ 100%)
  -- ค่าเริ่มต้นเป็นสูตรมาตรฐานตามที่กำหนดไว้
  weight_margin DECIMAL(3,2) DEFAULT 0.25,                 -- น้ำหนักกำไร (กำไรสูง = น่าขาย)
  weight_expiry DECIMAL(3,2) DEFAULT 0.35,                 -- น้ำหนักความเร่งด่วนหมดอายุ (ด่วน = ต้องระบาย)
  weight_seasonal DECIMAL(3,2) DEFAULT 0.20,               -- น้ำหนักฤดูกาล (ตามฤดู = น่าสนใจ)
  weight_festival DECIMAL(3,2) DEFAULT 0.10,               -- น้ำหนักเทศกาล (ช่วงเทศกาล = ความต้องการสูง)
  weight_ingredient_expiry DECIMAL(3,2) DEFAULT 0.10,      -- น้ำหนักวัตถุดิบใกล้หมด (วัตถุดิบจะหมด = ทำโปรด่วน)
  
  -- เกณฑ์คะแนนแต่ละปัจจัย (JSONB = ยืดหยุ่นปรับได้)
  -- เก็บเป็นระดับ: ค่าเริ่มต้น -> คะแนนที่ได้
  margin_thresholds JSONB DEFAULT '{
    "excellent": {"min_margin_pct": 50, "score": 100, "label": "กำไรดีมาก"},
    "good": {"min_margin_pct": 30, "score": 70, "label": "กำไรดี"},
    "fair": {"min_margin_pct": 10, "score": 40, "label": "กำไรปกติ"},
    "poor": {"min_margin_pct": 0, "score": 10, "label": "กำไรน้อย"}
  }'::jsonb,
  
  expiry_thresholds JSONB DEFAULT '{
    "expired": {"days_remaining": 0, "score": 100, "label": "หมดอายุแล้ว", "is_critical": true},
    "critical": {"days_remaining": 3, "score": 90, "label": "เหลือ ≤3 วัน", "is_critical": true},
    "urgent": {"days_remaining": 7, "score": 70, "label": "เหลือ 4-7 วัน"},
    "warning": {"days_remaining": 14, "score": 50, "label": "เหลือ 8-14 วัน"},
    "notice": {"days_remaining": 30, "score": 30, "label": "เหลือ 15-30 วัน"}
  }'::jsonb,
  
  seasonal_thresholds JSONB DEFAULT '{
    "in_season": {"is_in_season": true, "score": 100, "label": "อยู่ในฤดูกาล"},
    "ending_soon": {"days_to_end": 30, "score": 80, "label": "ใกล้สิ้นฤดู"},
    "off_season": {"score": 0, "label": "นอกฤดูกาล"}
  }'::jsonb,
  
  festival_thresholds JSONB DEFAULT '{
    "today": {"days_before": 0, "score": 100, "label": "วันเทศกาลพอดี"},
    "soon_1_7": {"days_before": 7, "score": 90, "label": "อีก 1-7 วัน"},
    "soon_8_14": {"days_before": 14, "score": 70, "label": "อีก 8-14 วัน"},
    "far": {"score": 0, "label": "ไม่ใกล้เทศกาล"}
  }'::jsonb,
  
  ingredient_thresholds JSONB DEFAULT '{
    "critical": {"days_remaining": 7, "score": 100, "label": "วัตถุดิบหลักเหลือ ≤7 วัน"},
    "warning": {"days_remaining": 14, "score": 70, "label": "วัตถุดิบหลักเหลือ 8-14 วัน"},
    "ok": {"score": 0, "label": "ไม่มีวัตถุดิบใกล้หมด"}
  }'::jsonb,
  
  -- เกณฑ์ส่วนลดที่แนะนำ (ตามช่วงคะแนน)
  discount_ranges JSONB DEFAULT '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 30, "discount_max_pct": 50, "label": "ด่วนมาก", "color": "#FF4444", "priority": 1},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 20, "discount_max_pct": 30, "label": "ด่วนปานกลาง", "color": "#FF8800", "priority": 2},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 10, "discount_max_pct": 20, "label": "ปกติ", "color": "#FFAA00", "priority": 3},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 5, "discount_max_pct": 10, "label": "ไม่เร่งด่วน", "color": "#44AA44", "priority": 4}
  ]'::jsonb,
  
  -- เปิด/ปิดการใช้งานแต่ละปัจจัย (array of strings)
  enabled_criteria JSONB DEFAULT '["margin", "expiry", "seasonal", "festival", "ingredient"]'::jsonb,
  
  -- ข้อมูลผู้สร้างและเวลา
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES users(id)
);

-- Indexes สำหรับค้นหา
CREATE INDEX IF NOT EXISTS idx_formula_configs_active ON promotion_formula_configs(is_active);
CREATE INDEX IF NOT EXISTS idx_formula_configs_default ON promotion_formula_configs(is_default);
CREATE INDEX IF NOT EXISTS idx_formula_configs_validity ON promotion_formula_configs(valid_from, valid_until);

-- Constraint: น้ำหนักรวมต้องเป็น 1.00 (100%)
-- ลบ constraint ก่อนถ้ามีอยู่แล้ว (เพื่อให้รันได้หลายครั้ง)
ALTER TABLE promotion_formula_configs 
DROP CONSTRAINT IF EXISTS chk_weights_sum_to_1;

ALTER TABLE promotion_formula_configs 
ADD CONSTRAINT chk_weights_sum_to_1 
CHECK (
  weight_margin + weight_expiry + weight_seasonal + weight_festival + weight_ingredient_expiry = 1.00
);

-- Constraint: ไม่ให้มีสูตร active มากกว่า 1 อัน (ใช้ trigger)
-- หรือจะ handle ที่ application layer ก็ได้

-- -----------------------------------------------------
-- 2. ตารางเก็บประวัติการเปลี่ยนแปลง (Audit Log)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS promotion_formula_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  formula_id UUID REFERENCES promotion_formula_configs(id) ON DELETE CASCADE,
  changed_by UUID REFERENCES users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  change_type VARCHAR(50) NOT NULL,  -- 'created', 'updated', 'activated', 'deactivated', 'deleted'
  field_changed VARCHAR(100),        -- ฟิลด์ที่เปลี่ยน (ถเป็น 'updated')
  old_value TEXT,                    -- ค่าเก่า
  new_value TEXT,                  -- ค่าใหม่
  reason TEXT,                      -- เหตุผลในการเปลี่ยนแปลง (optional)
  
  -- เก็บส snapshot ของสูตรทั้งชุดตอนเปลี่ยน (สำหรับ rollback)
  formula_snapshot JSONB
);

CREATE INDEX IF NOT EXISTS idx_formula_history_formula_id ON promotion_formula_history(formula_id);
CREATE INDEX IF NOT EXISTS idx_formula_history_changed_at ON promotion_formula_history(changed_at DESC);

-- -----------------------------------------------------
-- 3. View สำหรับดึงสูตรที่ใช้งานอยู่ (active + อยู่ในช่วงเวลา)
-- -----------------------------------------------------
CREATE OR REPLACE VIEW promotion_active_formula AS
SELECT 
  f.*,
  u.email as created_by_email,
  updater.email as updated_by_email
FROM promotion_formula_configs f
LEFT JOIN users u ON f.created_by = u.id
LEFT JOIN users updater ON f.updated_by = updater.id
WHERE f.is_active = true
  AND (f.valid_from IS NULL OR f.valid_from <= CURRENT_DATE)
  AND (f.valid_until IS NULL OR f.valid_until >= CURRENT_DATE)
LIMIT 1;  -- ควรมีแค่ 1 สูตที่ active อยู่

-- -----------------------------------------------------
-- 4. Function: คำนวณคะแนนเบื้องต้น (Raw Scores) - Hybrid SQL Part
-- -----------------------------------------------------
-- นี้คือส่วน SQL ที่คำนวณ raw scores เร็วๆ ใน database
-- จากนั้น Dart จะมาคำนวณ weighted score และ sort

CREATE OR REPLACE FUNCTION calculate_raw_scores_for_product(
  p_product_id UUID,
  p_formula_id UUID DEFAULT NULL  -- NULL = ใช้สูตรที่ active
)
RETURNS TABLE (
  product_id UUID,
  margin_score INT,
  expiry_score INT,
  seasonal_score INT,
  festival_score INT,
  ingredient_score INT
) AS $$
DECLARE
  v_formula_id UUID;
  v_formula RECORD;
  v_margin_pct DECIMAL(10,2);
  v_days_to_expiry INT;
  v_is_in_season BOOLEAN;
  v_days_to_season_end INT;
  v_closest_festival_days INT;
  v_ingredient_days INT;
BEGIN
  -- หาสูตรที่จะใช้
  IF p_formula_id IS NULL THEN
    SELECT id INTO v_formula_id 
    FROM promotion_formula_configs 
    WHERE is_active = true 
      AND (valid_from IS NULL OR valid_from <= CURRENT_DATE)
      AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
    LIMIT 1;
  ELSE
    v_formula_id := p_formula_id;
  END IF;
  
  -- ดึงข้อมูลสูตร
  SELECT * INTO v_formula FROM promotion_formula_configs WHERE id = v_formula_id;
  
  IF v_formula IS NULL THEN
    RAISE EXCEPTION 'ไม่พบสูตรที่ใช้งาน';
  END IF;
  
  -- คำนวณ Margin Score
  SELECT 
    CASE 
      WHEN (price - cost_price) / NULLIF(price, 0) * 100 >= (v_formula.margin_thresholds->'excellent'->>'min_margin_pct')::NUMERIC THEN (v_formula.margin_thresholds->'excellent'->>'score')::INT
      WHEN (price - cost_price) / NULLIF(price, 0) * 100 >= (v_formula.margin_thresholds->'good'->>'min_margin_pct')::NUMERIC THEN (v_formula.margin_thresholds->'good'->>'score')::INT
      WHEN (price - cost_price) / NULLIF(price, 0) * 100 >= (v_formula.margin_thresholds->'fair'->>'min_margin_pct')::NUMERIC THEN (v_formula.margin_thresholds->'fair'->>'score')::INT
      ELSE (v_formula.margin_thresholds->'poor'->>'score')::INT
    END INTO margin_score
  FROM products WHERE id = p_product_id;
  
  -- คำนวณ Expiry Score (จาก product expiry dates)
  SELECT 
    CASE 
      WHEN expiry_date < CURRENT_DATE THEN (v_formula.expiry_thresholds->'expired'->>'score')::INT
      WHEN (expiry_date - CURRENT_DATE) <= (v_formula.expiry_thresholds->'critical'->>'days_remaining')::INT THEN (v_formula.expiry_thresholds->'critical'->>'score')::INT
      WHEN (expiry_date - CURRENT_DATE) <= (v_formula.expiry_thresholds->'urgent'->>'days_remaining')::INT THEN (v_formula.expiry_thresholds->'urgent'->>'score')::INT
      WHEN (expiry_date - CURRENT_DATE) <= (v_formula.expiry_thresholds->'warning'->>'days_remaining')::INT THEN (v_formula.expiry_thresholds->'warning'->>'score')::INT
      WHEN (expiry_date - CURRENT_DATE) <= (v_formula.expiry_thresholds->'notice'->>'days_remaining')::INT THEN (v_formula.expiry_thresholds->'notice'->>'score')::INT
      ELSE 0
    END INTO expiry_score
  FROM product_expiry_tracking WHERE product_id = p_product_id AND is_active = true
  ORDER BY expiry_date ASC LIMIT 1;
  
  -- ถ้าไม่มีข้อมูล expiry ให้เป็น 0
  IF expiry_score IS NULL THEN expiry_score := 0; END IF;
  IF margin_score IS NULL THEN margin_score := 0; END IF;
  
  -- Seasonal, Festival, Ingredient scores (simplified - ต้องมีตารางข้อมูลเพิ่ม)
  -- TODO: Implement ตามข้อมูลที่มี
  seasonal_score := 0;
  festival_score := 0;
  ingredient_score := 0;
  
  RETURN QUERY SELECT p_product_id, margin_score, expiry_score, seasonal_score, festival_score, ingredient_score;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------
-- 5. Seed Data: สูตรมาตรฐานเริ่มต้น
-- -----------------------------------------------------
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  created_by
)
SELECT 
  'สูตรมาตรฐาน 2568',
  'สูตรแนะนำสินค้าสำหรับโปรโมชันแบบมาตรฐาน เน้นสินค้าใกล้หมดอายุเป็นหลัก',
  true,  -- active
  true,  -- default
  '2025-01-01',
  NULL,  -- ไม่หมดอายุ
  0.25, 0.35, 0.20, 0.10, 0.10,
  (SELECT id FROM users LIMIT 1)  -- ใช้ user แรกที่มี
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรมาตรฐาน 2568'
);

-- สูตรเทศกาลตัวอย่าง (ยังไม่ active)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  festival_thresholds
)
SELECT 
  'สูตรเทศกาลสงกรานต์ 2568',
  'สูตรพิเศษสำหรับเทศกาลสงกรานต์ เน้นความเหมาะสมกับเทศกาลมากขึ้น',
  false,  -- ยังไม่ active
  false,
  '2025-04-10',
  '2025-04-20',
  0.20, 0.25, 0.15, 0.30, 0.10,  -- เพิ่มน้ำหนัก festival
  '[
    {"days_before": 0, "score": 100, "label": "วันเทศกาล"},
    {"days_before": 3, "score": 95, "label": "อีก 1-3 วัน"},
    {"days_before": 7, "score": 85, "label": "อีก 4-7 วัน"},
    {"days_before": 14, "score": 70, "label": "อีก 8-14 วัน"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรเทศกาลสงกรานต์ 2568'
);

-- สูตรเทศกาลลอยกระทง (เน้นเทศกาล + ฤดูกาล)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  seasonal_thresholds, festival_thresholds, discount_ranges
)
SELECT 
  'สูตรเทศกาลลอยกระทง 2568',
  'สูตรสำหรับเทศกาลลอยกระทง เน้นสินค้าตามฤดูกาลและความเหมาะสมกับเทศกาล',
  false,
  false,
  '2025-11-10',
  '2025-11-20',
  0.20, 0.20, 0.30, 0.25, 0.05,  -- เน้น seasonal (30%) + festival (25%)
  '{
    "in_season": {"is_in_season": true, "score": 100, "label": "อยู่ในฤดูกาล"},
    "ending_soon": {"days_to_end": 15, "score": 85, "label": "ใกล้สิ้นฤดู"},
    "off_season": {"score": 0, "label": "นอกฤดูกาล"}
  }'::jsonb,
  '[
    {"days_before": 0, "score": 100, "label": "วันลอยกระทง"},
    {"days_before": 3, "score": 95, "label": "อีก 1-3 วัน"},
    {"days_before": 7, "score": 80, "label": "อีก 4-7 วัน"},
    {"days_before": 14, "score": 60, "label": "อีก 8-14 วัน"}
  ]'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 20, "discount_max_pct": 35, "label": "แนะนำด่วน", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 15, "discount_max_pct": 25, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 10, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 5, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรเทศกาลลอยกระทง 2568'
);

-- สูตรเทศกาลปีใหม่ (Christmas & New Year)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  festival_thresholds, discount_ranges
)
SELECT 
  'สูตรเทศกาลปีใหม่ 2568',
  'สูตรสำหรับช่วงคริสต์มาสและปีใหม่ เน้นสินค้าของขวัญและจัดเลี้ยง',
  false,
  false,
  '2025-12-20',
  '2026-01-05',
  0.25, 0.15, 0.10, 0.40, 0.10,  -- เน้น festival (40%) มากที่สุด
  '[
    {"days_before": 0, "score": 100, "label": "วันเทศกาล"},
    {"days_before": 3, "score": 95, "label": "อีก 1-3 วัน"},
    {"days_before": 7, "score": 85, "label": "อีก 4-7 วัน"},
    {"days_before": 14, "score": 70, "label": "อีก 8-14 วัน"},
    {"days_before": 30, "score": 50, "label": "อีก 15-30 วัน"}
  ]'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 25, "discount_max_pct": 40, "label": "ของขวัญยอดนิยม", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 15, "discount_max_pct": 25, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 10, "discount_max_pct": 15, "label": "ทั่วไป", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 5, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรเทศกาลปีใหม่ 2568'
);

-- สูตรระบายสต็อกด่วน (เน้นสินค้าใกล้หมดอายุ + กำไร)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  expiry_thresholds, margin_thresholds, discount_ranges
)
SELECT 
  'สูตรระบายสต็อกด่วน',
  'สูตรสำหรับช่วงที่ต้องการระบายสต็อกเร่งด่วน เน้นสินค้าใกล้หมดอายุและกำไรที่ยอมได้',
  false,
  false,
  '2025-01-01',
  NULL,  -- ใช้ได้ตลอด
  0.15, 0.50, 0.10, 0.05, 0.20,  -- เน้น expiry (50%) + ingredient (20%)
  '{
    "expired": {"days_remaining": 0, "score": 100, "label": "หมดอายุแล้ว", "is_critical": true},
    "critical": {"days_remaining": 1, "score": 95, "label": "เหลือ 1 วัน", "is_critical": true},
    "urgent": {"days_remaining": 3, "score": 85, "label": "เหลือ 2-3 วัน"},
    "warning": {"days_remaining": 5, "score": 70, "label": "เหลือ 4-5 วัน"},
    "notice": {"days_remaining": 7, "score": 50, "label": "เหลือ 6-7 วัน"}
  }'::jsonb,
  '{
    "excellent": {"min_margin_pct": 30, "score": 100, "label": "กำไรดี"},
    "good": {"min_margin_pct": 15, "score": 70, "label": "กำไรปกติ"},
    "fair": {"min_margin_pct": 5, "score": 40, "label": "กำไรน้อย"},
    "poor": {"min_margin_pct": 0, "score": 20, "label": "ยอมขาดทุนได้"}
  }'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 40, "discount_max_pct": 70, "label": "ระบายด่วน", "color": "#CC0000"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 30, "discount_max_pct": 50, "label": "ลดราคามาก", "color": "#FF4444"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 20, "discount_max_pct": 30, "label": "ลดราคา", "color": "#FF8800"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 10, "discount_max_pct": 20, "label": "ลดเล็กน้อย", "color": "#FFAA00"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรระบายสต็อกด่วน'
);

-- สูตรเน้นกำไรสูง (Profit Maximization)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  margin_thresholds, discount_ranges, enabled_criteria
)
SELECT 
  'สูตรเน้นกำไรสูง',
  'สูตรสำหรับช่วงที่ต้องการ maximize กำไร แนะนำเฉพาะสินค้ากำไรสูงเท่านั้น ไม่เน้นระบาย',
  false,
  false,
  '2025-01-01',
  NULL,
  0.60, 0.10, 0.15, 0.10, 0.05,  -- เน้น margin (60%)
  '{
    "excellent": {"min_margin_pct": 60, "score": 100, "label": "กำไรสูงมาก"},
    "good": {"min_margin_pct": 40, "score": 80, "label": "กำไรสูง"},
    "fair": {"min_margin_pct": 25, "score": 50, "label": "กำไรปกติ"},
    "poor": {"min_margin_pct": 0, "score": 0, "label": "ไม่ผ่านเกณฑ์"}
  }'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 5, "discount_max_pct": 15, "label": "ลดเล็กน้อย", "color": "#44AA44"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 10, "discount_max_pct": 20, "label": "ลดปกติ", "color": "#FFAA00"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 15, "discount_max_pct": 25, "label": "ลดมาก", "color": "#FF8800"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 20, "discount_max_pct": 30, "label": "ลดมากที่สุด", "color": "#FF4444"}
  ]'::jsonb,
  '["margin", "seasonal", "festival"]'  -- ไม่ใช้ expiry, ingredient
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรเน้นกำไรสูง'
);

-- สูตรฤดูร้อน (Summer Season - เน้นสินค้าตามฤดูกาล)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  seasonal_thresholds, discount_ranges
)
SELECT 
  'สูตรฤดูร้อน 2568',
  'สูตรสำหรับช่วงฤดูร้อน (มี.ค. - พ.ค.) เน้นสินค้าที่เหมาะกับอากาศร้อน',
  false,
  false,
  '2025-03-01',
  '2025-05-31',
  0.25, 0.20, 0.40, 0.10, 0.05,  -- เน้น seasonal (40%)
  '{
    "in_season": {"is_in_season": true, "score": 100, "label": "สินค้าฤดูร้อน"},
    "ending_soon": {"days_to_end": 15, "score": 90, "label": "ใกล้หมดฤดู"},
    "off_season": {"score": 10, "label": "ไม่ใช่ฤดูร้อน"}
  }'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 15, "discount_max_pct": 30, "label": "แนะนำมาก", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 10, "discount_max_pct": 20, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 5, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 0, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรฤดูร้อน 2568'
);

-- สูตรฤดูฝน (Rainy Season)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  seasonal_thresholds, discount_ranges
)
SELECT 
  'สูตรฤดูฝน 2568',
  'สูตรสำหรับช่วงฤดูฝน (มิ.ย. - ต.ค.) เน้นสินค้าที่เหมาะกับอากาศฝนตก',
  false,
  false,
  '2025-06-01',
  '2025-10-31',
  0.25, 0.20, 0.40, 0.10, 0.05,  -- เน้น seasonal (40%)
  '{
    "in_season": {"is_in_season": true, "score": 100, "label": "สินค้าฤดูฝน"},
    "ending_soon": {"days_to_end": 15, "score": 90, "label": "ใกล้หมดฤดู"},
    "off_season": {"score": 10, "label": "ไม่ใช่ฤดูฝน"}
  }'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 15, "discount_max_pct": 30, "label": "แนะนำมาก", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 10, "discount_max_pct": 20, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 5, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 0, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรฤดูฝน 2568'
);

-- สูตรฤดูหนาว (Winter Season)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  seasonal_thresholds, discount_ranges
)
SELECT 
  'สูตรฤดูหนาว 2568',
  'สูตรสำหรับช่วงฤดูหนาว (พ.ย. - ก.พ.) เน้นสินค้าที่เหมาะกับอากาศหนาว',
  false,
  false,
  '2025-11-01',
  '2026-02-28',
  0.25, 0.20, 0.40, 0.10, 0.05,  -- เน้น seasonal (40%)
  '{
    "in_season": {"is_in_season": true, "score": 100, "label": "สินค้าฤดูหนาว"},
    "ending_soon": {"days_to_end": 15, "score": 90, "label": "ใกล้หมดฤดู"},
    "off_season": {"score": 10, "label": "ไม่ใช่ฤดูหนาว"}
  }'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 15, "discount_max_pct": 30, "label": "แนะนำมาก", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 10, "discount_max_pct": 20, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 5, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 0, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรฤดูหนาว 2568'
);

-- สูตรวันแม่ (Mother's Day)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  festival_thresholds, discount_ranges
)
SELECT 
  'สูตรวันแม่ 2568',
  'สูตรสำหรับวันแม่ เน้นของขวัญและการจัดเลี้ยงครอบครัว',
  false,
  false,
  '2025-08-05',
  '2025-08-15',
  0.25, 0.15, 0.10, 0.40, 0.10,  -- เน้น festival (40%)
  '[
    {"days_before": 0, "score": 100, "label": "วันแม่"},
    {"days_before": 2, "score": 95, "label": "อีก 1-2 วัน"},
    {"days_before": 5, "score": 85, "label": "อีก 3-5 วัน"},
    {"days_before": 10, "score": 70, "label": "อีก 6-10 วัน"}
  ]'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 20, "discount_max_pct": 35, "label": "แนะนำมาก", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 15, "discount_max_pct": 25, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 10, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 5, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรวันแม่ 2568'
);

-- สูตรวันพ่อ (Father's Day)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  festival_thresholds, discount_ranges
)
SELECT 
  'สูตรวันพ่อ 2568',
  'สูตรสำหรับวันพ่อ เน้นของขวัญและอาหารจัดเลี้ยง',
  false,
  false,
  '2025-12-01',
  '2025-12-10',
  0.25, 0.15, 0.10, 0.40, 0.10,  -- เน้น festival (40%)
  '[
    {"days_before": 0, "score": 100, "label": "วันพ่อ"},
    {"days_before": 2, "score": 95, "label": "อีก 1-2 วัน"},
    {"days_before": 5, "score": 85, "label": "อีก 3-5 วัน"},
    {"days_before": 10, "score": 70, "label": "อีก 6-10 วัน"}
  ]'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 20, "discount_max_pct": 35, "label": "แนะนำมาก", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 15, "discount_max_pct": 25, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 10, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 5, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรวันพ่อ 2568'
);

-- สูตรตรุษจีน (Chinese New Year)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  festival_thresholds, discount_ranges
)
SELECT 
  'สูตรตรุษจีน 2568',
  'สูตรสำหรับเทศกาลตรุษจีน เน้นของมงคลและอาหารเทศกาล',
  false,
  false,
  '2026-01-15',
  '2026-02-05',
  0.25, 0.15, 0.10, 0.40, 0.10,  -- เน้น festival (40%)
  '[
    {"days_before": 0, "score": 100, "label": "วันตรุษจีน"},
    {"days_before": 3, "score": 95, "label": "อีก 1-3 วัน"},
    {"days_before": 7, "score": 85, "label": "อีก 4-7 วัน"},
    {"days_before": 14, "score": 70, "label": "อีก 8-14 วัน"}
  ]'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 20, "discount_max_pct": 35, "label": "แนะนำมาก", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 15, "discount_max_pct": 25, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 10, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 5, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรตรุษจีน 2568'
);

-- สูตรวาเลนไทน์ (Valentine's Day)
INSERT INTO promotion_formula_configs (
  name, description, is_active, is_default, valid_from, valid_until,
  weight_margin, weight_expiry, weight_seasonal, weight_festival, weight_ingredient_expiry,
  festival_thresholds, discount_ranges
)
SELECT 
  'สูตรวาเลนไทน์ 2568',
  'สูตรสำหรับวันวาเลนไทน์ เน้นของขวัญและอาหารคู่รัก',
  false,
  false,
  '2026-02-10',
  '2026-02-16',
  0.30, 0.15, 0.10, 0.35, 0.10,  -- เน้น festival (35%) + margin (30%)
  '[
    {"days_before": 0, "score": 100, "label": "วาเลนไทน์"},
    {"days_before": 2, "score": 95, "label": "อีก 1-2 วัน"},
    {"days_before": 5, "score": 85, "label": "อีก 3-5 วัน"},
    {"days_before": 10, "score": 70, "label": "อีก 6-10 วัน"}
  ]'::jsonb,
  '[
    {"min_score": 80, "max_score": 100, "discount_min_pct": 15, "discount_max_pct": 30, "label": "แนะนำมาก", "color": "#FF4444"},
    {"min_score": 60, "max_score": 79, "discount_min_pct": 10, "discount_max_pct": 20, "label": "แนะนำ", "color": "#FF8800"},
    {"min_score": 40, "max_score": 59, "discount_min_pct": 5, "discount_max_pct": 15, "label": "ปกติ", "color": "#FFAA00"},
    {"min_score": 0, "max_score": 39, "discount_min_pct": 0, "discount_max_pct": 10, "label": "ไม่แนะนำ", "color": "#44AA44"}
  ]'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM promotion_formula_configs WHERE name = 'สูตรวาเลนไทน์ 2568'
);

-- -----------------------------------------------------
-- 6. Trigger: Auto-update updated_at
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION update_formula_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_formula_configs_updated_at ON promotion_formula_configs;
CREATE TRIGGER trg_formula_configs_updated_at
  BEFORE UPDATE ON promotion_formula_configs
  FOR EACH ROW
  EXECUTE FUNCTION update_formula_updated_at();

-- -----------------------------------------------------
-- 7. RLS Policies
-- -----------------------------------------------------
-- Enable RLS
ALTER TABLE promotion_formula_configs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first (idempotent)
DROP POLICY IF EXISTS allow_select_formulas ON promotion_formula_configs;
DROP POLICY IF EXISTS allow_manage_formulas ON promotion_formula_configs;
DROP POLICY IF EXISTS formula_select_all ON promotion_formula_configs;
DROP POLICY IF EXISTS formula_manage_admin ON promotion_formula_configs;

-- Create SELECT policy (ให้ทุกคน authenticated อ่านได้)
CREATE POLICY allow_select_formulas 
ON promotion_formula_configs 
FOR SELECT 
TO authenticated 
USING (true);

-- Create ALL policy (ให้ผู้มีสิทธิ์ formula_edit จัดการได้)
CREATE POLICY allow_manage_formulas 
ON promotion_formula_configs 
FOR ALL 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM user_permissions 
    WHERE user_id = auth.uid() 
    AND permission_key = 'formula_edit'
  )
);

-- สำหรับ history table
ALTER TABLE promotion_formula_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS allow_select_history ON promotion_formula_history;
DROP POLICY IF EXISTS allow_insert_history ON promotion_formula_history;

CREATE POLICY allow_select_history 
ON promotion_formula_history 
FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY allow_insert_history 
ON promotion_formula_history 
FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_permissions 
    WHERE user_id = auth.uid() 
    AND permission_key = 'formula_edit'
  )
);

-- =====================================================
-- END OF MIGRATION
-- =====================================================
