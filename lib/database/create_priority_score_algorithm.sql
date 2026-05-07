-- ============================================
-- Priority Score Algorithm for Phase 8
-- ============================================
-- คำนวณคะแนนรวมจาก 5 ปัจจัย: กำไร, ความเร่งด่วนหมดอายุ, ฤดูกาล, เทศกาล, วัตถุดิบ
-- สูตร: คะแนนรวม = (กำไร × 0.25) + (หมดอายุ × 0.35) + (ฤดูกาล × 0.20) + (เทศกาล × 0.10) + (วัตถุดิบ × 0.10)

-- ============================================
-- 1. Margin Score Function
-- ============================================
CREATE OR REPLACE FUNCTION calculate_margin_score(margin_pct numeric) 
RETURNS integer AS $$
BEGIN
  IF margin_pct >= 50 THEN RETURN 100;
  ELSIF margin_pct >= 30 THEN RETURN 70;
  ELSIF margin_pct >= 10 THEN RETURN 40;
  ELSE RETURN 10;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 2. Expiry Score Function
-- ============================================
CREATE OR REPLACE FUNCTION calculate_expiry_score(days_remaining integer) 
RETURNS integer AS $$
BEGIN
  IF days_remaining < 0 THEN RETURN 100; -- หมดอายุแล้ว (บังคับ top priority)
  ELSIF days_remaining <= 3 THEN RETURN 90;
  ELSIF days_remaining <= 7 THEN RETURN 70;
  ELSIF days_remaining <= 14 THEN RETURN 50;
  ELSIF days_remaining <= 30 THEN RETURN 30;
  ELSE RETURN 0;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 3. Seasonal Score Function
-- ============================================
CREATE OR REPLACE FUNCTION calculate_seasonal_score(product_id uuid, current_date date)
RETURNS integer AS $$
DECLARE
  season_start date;
  season_end date;
  days_until_end integer;
BEGIN
  -- ดึงข้อมูลฤดูกาลของสินค้า
  SELECT ps.start_date, ps.end_date 
  INTO season_start, season_end
  FROM product_seasons ps
  WHERE ps.product_id = product_id
    AND ps.start_date <= current_date
    AND ps.end_date >= current_date
  LIMIT 1;
  
  -- ถ้าไม่มีฤดูกาลหรือไม่ใช่ช่วงฤดูกาล
  IF season_start IS NULL OR season_end IS NULL THEN
    RETURN 0;
  END IF;
  
  -- ถ้าอยู่ในช่วงฤดูกาลพอดี
  IF current_date BETWEEN season_start AND season_end THEN
    RETURN 100;
  END IF;
  
  -- คำนวณวันที่เหลือจนสิ้นฤดูกาล
  days_until_end := season_end - current_date;
  
  -- ใกล้สิ้นฤดูกาล (< 30 วัน)
  IF days_until_end < 30 THEN
    RETURN 80;
  END IF;
  
  RETURN 0; -- นอกฤดูกาล
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 3b. Seasonal Score Function with Default
-- ============================================
CREATE OR REPLACE FUNCTION calculate_seasonal_score(product_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN calculate_seasonal_score(product_id, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 4. Festival Score Function
-- ============================================
CREATE OR REPLACE FUNCTION calculate_festival_score(product_id uuid, current_date date)
RETURNS integer AS $$
DECLARE
  festival_date date;
  days_before integer;
BEGIN
  -- ดึงข้อมูลเทศกาลที่เกี่ยวข้องกับสินค้า
  SELECT pf.event_date 
  INTO festival_date
  FROM product_festivals pf
  WHERE pf.product_id = product_id
    AND pf.event_date >= current_date
  ORDER BY pf.event_date ASC
  LIMIT 1;
  
  -- ถ้าไม่มีเทศกาลที่เกี่ยวข้อง
  IF festival_date IS NULL THEN
    RETURN 0;
  END IF;
  
  -- คำนวณวันที่เหลือถึงเทศกาล
  days_before := festival_date - current_date;
  
  -- วันเทศกาลพอดี
  IF days_before = 0 THEN
    RETURN 100;
  -- ก่อนเทศกาล 1-7 วัน
  ELSIF days_before BETWEEN 1 AND 7 THEN
    RETURN 90;
  -- ก่อนเทศกาล 8-14 วัน
  ELSIF days_before BETWEEN 8 AND 14 THEN
    RETURN 70;
  ELSE
    RETURN 0; -- ไม่ใช่ช่วงเทศกาล
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 4b. Festival Score Function with Default
-- ============================================
CREATE OR REPLACE FUNCTION calculate_festival_score(product_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN calculate_festival_score(product_id, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 5. Ingredient Expiry Score Function
-- ============================================
CREATE OR REPLACE FUNCTION calculate_ingredient_expiry_score(product_id uuid, current_date date)
RETURNS integer AS $$
DECLARE
  critical_count integer := 0;
  warning_count integer := 0;
BEGIN
  -- นับวัตถุดิบหลักที่ใกล้หมดอายุ ≤ 7 วัน
  SELECT COUNT(*)
  INTO critical_count
  FROM product_ingredients pi
  JOIN ingredients i ON pi.ingredient_id = i.id
  WHERE pi.product_id = product_id
    AND pi.is_main_ingredient = true
    AND i.expiry_date IS NOT NULL
    AND (i.expiry_date - current_date) <= 7;
  
  -- นับวัตถุดิบหลักที่ใกล้หมดอายุ 8-14 วัน
  SELECT COUNT(*)
  INTO warning_count
  FROM product_ingredients pi
  JOIN ingredients i ON pi.ingredient_id = i.id
  WHERE pi.product_id = product_id
    AND pi.is_main_ingredient = true
    AND i.expiry_date IS NOT NULL
    AND (i.expiry_date - current_date) BETWEEN 8 AND 14;
  
  -- ถ้ามีวัตถุดิบหลักใกล้หมดอายุ ≤ 7 วัน
  IF critical_count > 0 THEN
    RETURN 100;
  -- ถ้ามีวัตถุดิบหลักใกล้หมดอายุ 8-14 วัน
  ELSIF warning_count > 0 THEN
    RETURN 70;
  ELSE
    RETURN 0; -- ไม่มีวัตถุดิบใกล้หมด
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 5b. Ingredient Expiry Score Function with Default
-- ============================================
CREATE OR REPLACE FUNCTION calculate_ingredient_expiry_score(product_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN calculate_ingredient_expiry_score(product_id, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 6. Total Priority Score Function
-- ============================================
CREATE OR REPLACE FUNCTION calculate_priority_score(
  product_id uuid,
  margin_pct numeric,
  days_remaining integer,
  current_date date
)
RETURNS numeric AS $$
DECLARE
  margin_score integer;
  expiry_score integer;
  seasonal_score integer;
  festival_score integer;
  ingredient_score integer;
  total_score numeric;
BEGIN
  -- คำนวณคะแนนแต่ละปัจจัย
  margin_score := calculate_margin_score(margin_pct);
  expiry_score := calculate_expiry_score(days_remaining);
  seasonal_score := calculate_seasonal_score(product_id, current_date);
  festival_score := calculate_festival_score(product_id, current_date);
  ingredient_score := calculate_ingredient_expiry_score(product_id, current_date);
  
  -- คำนวณคะแนนรวมตามน้ำหนัก
  total_score := (margin_score * 0.25) + 
                 (expiry_score * 0.35) + 
                 (seasonal_score * 0.20) + 
                 (festival_score * 0.10) + 
                 (ingredient_score * 0.10);
  
  RETURN total_score;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 6b. Total Priority Score Function with Default
-- ============================================
CREATE OR REPLACE FUNCTION calculate_priority_score(
  product_id uuid,
  margin_pct numeric,
  days_remaining integer
)
RETURNS numeric AS $$
BEGIN
  RETURN calculate_priority_score(product_id, margin_pct, days_remaining, CURRENT_DATE);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- 7. Test Functions (Commented - depends on actual tables)
-- ============================================
/*
-- ทดสอบการคำนวณคะแนน
SELECT 
  p.name as product_name,
  p.margin_pct,
  calculate_margin_score(p.margin_pct) as margin_score,
  COALESCE(p.days_remaining, 999) as days_remaining,
  calculate_expiry_score(COALESCE(p.days_remaining, 999)) as expiry_score,
  calculate_seasonal_score(p.id) as seasonal_score,
  calculate_festival_score(p.id) as festival_score,
  calculate_ingredient_expiry_score(p.id) as ingredient_score,
  calculate_priority_score(p.id, p.margin_pct, COALESCE(p.days_remaining, 999)) as total_score
FROM products p
WHERE p.is_active = true
ORDER BY total_score DESC
LIMIT 10;
*/

-- ============================================
-- 8. Create Indexes for Performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_products_margin_pct ON products(margin_pct) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_products_days_remaining ON products(days_remaining) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_product_seasons_product_date ON product_seasons(product_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_product_festivals_product_date ON product_festivals(product_id, event_date);
CREATE INDEX IF NOT EXISTS idx_product_ingredients_main ON product_ingredients(product_id) WHERE is_main_ingredient = true;
CREATE INDEX IF NOT EXISTS idx_ingredients_expiry ON ingredients(expiry_date);

-- ============================================
-- 9. Comments
-- ============================================
COMMENT ON FUNCTION calculate_margin_score(numeric) IS 'คำนวณคะแนนกำไร: 50%+=100, 30-49%=70, 10-29%=40, <10%=10';
COMMENT ON FUNCTION calculate_expiry_score(integer) IS 'คำนวณคะแนนความเร่งด่วนหมดอายุ: <0=100, ≤3=90, 4-7=70, 8-14=50, 15-30=30, >30=0';
COMMENT ON FUNCTION calculate_seasonal_score(uuid, date) IS 'คำนวณคะแนนความเหมาะสมฤดูกาล: ในฤดู=100, ใกล้สิ้นฤดู<30วัน=80, นอกฤดู=0';
COMMENT ON FUNCTION calculate_festival_score(uuid, date) IS 'คำนวณคะแนนความเหมาะสมเทศกาล: วันเทศกาล=100, 1-7วัน=90, 8-14วัน=70, อื่น=0';
COMMENT ON FUNCTION calculate_ingredient_expiry_score(uuid, date) IS 'คำนวณคะแนนความเร่งด่วนวัตถุดิบ: ≤7วัน=100, 8-14วัน=70, อื่น=0';
COMMENT ON FUNCTION calculate_priority_score(uuid, numeric, integer, date) IS 'คำนวณคะแนนรวม Priority Score จาก 5 ปัจจัย';
