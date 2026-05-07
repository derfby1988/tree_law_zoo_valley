-- ============================================
-- Promotion Recommended Targets View
-- ============================================
-- สร้าง view สำหรับดึงข้อมูลสินค้าแนะนำพร้อมคะแนน Priority Score
-- ใช้ใน Tab "แนะนำ" ของ PromotionProductPickerPage

-- ============================================
-- 1. Create View for Recommended Targets
-- ============================================
CREATE OR REPLACE VIEW promotion_recommended_targets AS
WITH 
-- คำนวณคะแนนแต่ละปัจจัย
product_scores AS (
  SELECT 
    p.id as product_id,
    p.name as product_name,
    p.sku,
    p.price,
    p.cost,
    p.margin_pct,
    p.days_remaining,
    p.stock_quantity,
    p.is_active,
    p.image_url,
    p.category_id,
    p.created_at,
    p.updated_at,
    
    -- คำนวณคะแนนแต่ละปัจจัย
    calculate_margin_score(p.margin_pct) as margin_score,
    calculate_expiry_score(COALESCE(p.days_remaining, 999)) as expiry_score,
    calculate_seasonal_score(p.id) as seasonal_score,
    calculate_festival_score(p.id) as festival_score,
    calculate_ingredient_expiry_score(p.id) as ingredient_score,
    
    -- คำนวณคะแนนรวม (ใช้ฟังก์ชันที่มีอยู่แล้ว)
    CASE 
      WHEN p.is_active = true THEN
        (calculate_margin_score(p.margin_pct) * 0.25) + 
        (calculate_expiry_score(COALESCE(p.days_remaining, 999)) * 0.35) + 
        (COALESCE(calculate_seasonal_score(p.id), 0) * 0.20) + 
        (COALESCE(calculate_festival_score(p.id), 0) * 0.10) + 
        (COALESCE(calculate_ingredient_expiry_score(p.id), 0) * 0.10)
      ELSE 0
    END as priority_score,
    
    -- หมวดหมู่สินค้า
    c.name as category_name,
    
    -- ข้อมูลฤดูกาล
    (SELECT COUNT(*) FROM product_seasons ps 
     WHERE ps.product_id = p.id 
       AND CURRENT_DATE BETWEEN ps.start_date AND ps.end_date) > 0 as is_in_season,
    
    -- ข้อมูลเทศกาล
    (SELECT COUNT(*) FROM product_festivals pf 
     WHERE pf.product_id = p.id 
       AND pf.event_date >= CURRENT_DATE 
       AND (pf.event_date - CURRENT_DATE) <= 14) > 0 as has_upcoming_festival,
    
    -- วัตถุดิบใกล้หมดอายุ
    (SELECT COUNT(*) FROM product_ingredients pi 
     JOIN ingredients i ON pi.ingredient_id = i.id 
     WHERE pi.product_id = p.id 
       AND pi.is_main_ingredient = true 
       AND i.expiry_date IS NOT NULL 
       AND (i.expiry_date - CURRENT_DATE) <= 14) > 0 as has_critical_ingredients

  FROM products p
  LEFT JOIN categories c ON p.category_id = c.id
  WHERE p.is_active = true
),

-- จัดอันดับและกำหนดระดับความสำคัญ
ranked_products AS (
  SELECT 
    *,
    DENSE_RANK() OVER (ORDER BY priority_score DESC, p.margin_pct DESC) as overall_rank,
    NTILE(4) OVER (ORDER BY priority_score DESC) as priority_quartile,
    
    -- กำหนดระดับความสำคัญ
    CASE 
      WHEN priority_score >= 80 THEN 'critical'
      WHEN priority_score >= 60 THEN 'high'
      WHEN priority_score >= 40 THEN 'medium'
      WHEN priority_score >= 20 THEN 'low'
      ELSE 'minimal'
    END as priority_level,
    
    -- ส่วนลดที่แนะนำ (ตามคะแนน)
    CASE 
      WHEN priority_score >= 80 THEN 40.0  -- 40-50%
      WHEN priority_score >= 60 THEN 30.0  -- 30-40%
      WHEN priority_score >= 40 THEN 20.0  -- 20-30%
      WHEN priority_score >= 20 THEN 15.0  -- 15-20%
      ELSE 10.0                             -- 10-15%
    END as suggested_discount_pct,

    -- สาเหตุการแนะนำ
    ARRAY_REMOVE(ARRAY[
      CASE WHEN margin_score >= 70 THEN 'กำไรสูง' END,
      CASE WHEN expiry_score >= 70 THEN 'ใกล้หมดอายุ' END,
      CASE WHEN seasonal_score >= 80 THEN 'อยู่ในฤดูกาล' END,
      CASE WHEN festival_score >= 70 THEN 'ใกล้เทศกาล' END,
      CASE WHEN ingredient_score >= 70 THEN 'วัตถุดิบใกล้หมด' END
    ], NULL) as recommendation_reasons

  FROM product_scores
)

-- View สุดท้าย
SELECT 
  product_id,
  product_name,
  sku,
  price,
  cost,
  margin_pct,
  days_remaining,
  stock_quantity,
  image_url,
  category_id,
  category_name,
  is_active,
  created_at,
  updated_at,
  
  -- คะแนนทั้งหมด
  margin_score,
  expiry_score,
  seasonal_score,
  festival_score,
  ingredient_score,
  priority_score,
  
  -- การจัดอันดับ
  overall_rank,
  priority_quartile,
  priority_level,
  
  -- ข้อมูลเพิ่มเติม
  is_in_season,
  has_upcoming_festival,
  has_critical_ingredients,
  
  -- คำแนะนำ
  suggested_discount_pct,
  recommendation_reasons,

  -- Metadata
  CURRENT_DATE as calculation_date,
  EXTRACT(EPOCH FROM NOW()) as calculation_timestamp

FROM ranked_products
WHERE priority_score > 0  -- แสดงเฉพาะที่มีคะแนน
ORDER BY priority_score DESC, overall_rank ASC;

-- ============================================
-- 2. Create Indexes for View Performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_promotion_recommended_targets_score ON promotion_recommended_targets(priority_score DESC);
CREATE INDEX IF NOT EXISTS idx_promotion_recommended_targets_rank ON promotion_recommended_targets(overall_rank);
CREATE INDEX IF NOT EXISTS idx_promotion_recommended_targets_level ON promotion_recommended_targets(priority_level);
CREATE INDEX IF NOT EXISTS idx_promotion_recommended_targets_category ON promotion_recommended_targets(category_id);
CREATE INDEX IF NOT EXISTS idx_promotion_recommended_targets_expiry ON promotion_recommended_targets(days_remaining);
CREATE INDEX IF NOT EXISTS idx_promotion_recommended_targets_seasonal ON promotion_recommended_targets(is_in_season) WHERE is_in_season = true;
CREATE INDEX IF NOT EXISTS idx_promotion_recommended_targets_festival ON promotion_recommended_targets(has_upcoming_festival) WHERE has_upcoming_festival = true;

-- ============================================
-- 3. Create Materialized View (Optional - for better performance)
-- ============================================
-- ถ้าต้องการ performance ดีขึ้น สามารถสร้าง materialized view
-- Refresh ทุกวันหรือทุกชั่วโมง
/*
CREATE MATERIALIZED VIEW promotion_recommended_targets_mv AS
SELECT * FROM promotion_recommended_targets;

CREATE INDEX idx_mv_promotion_recommended_targets_score ON promotion_recommended_targets_mv(priority_score DESC);

-- Function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_promotion_recommended_targets()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY promotion_recommended_targets_mv;
END;
$$ LANGUAGE plpgsql;
*/

-- ============================================
-- 4. Comments
-- ============================================
COMMENT ON VIEW promotion_recommended_targets IS 'View สำหรับดึงข้อมูลสินค้าแนะนำพร้อมคะแนน Priority Score จาก 5 ปัจจัย';
COMMENT ON COLUMN promotion_recommended_targets.priority_score IS 'คะแนนรวม Priority Score (0-100)';
COMMENT ON COLUMN promotion_recommended_targets.priority_level IS 'ระดับความสำคัญ: critical/high/medium/low/minimal';
COMMENT ON COLUMN promotion_recommended_targets.suggested_discount_pct IS 'ส่วนลดที่แนะนำ (%)';
COMMENT ON COLUMN promotion_recommended_targets.recommendation_reasons IS 'สาเหตุการแนะนำ (array)';

-- ============================================
-- 5. Sample Queries
-- ============================================
/*
-- ดูสินค้าแนะนำ 10 อันดับแรก
SELECT * FROM promotion_recommended_targets 
ORDER BY priority_score DESC 
LIMIT 10;

-- ดูสินค้าที่ต้องการด่วน (critical/high)
SELECT * FROM promotion_recommended_targets 
WHERE priority_level IN ('critical', 'high')
ORDER BY priority_score DESC;

-- ดูสินค้าตามหมวดหมู่
SELECT * FROM promotion_recommended_targets 
WHERE category_id = 'your-category-id'
ORDER BY priority_score DESC;

-- ดูสินค้าที่ใกล้หมดอายุ
SELECT * FROM promotion_recommended_targets 
WHERE days_remaining <= 14
ORDER BY priority_score DESC;

-- ดูสินค้าตามฤดูกาล
SELECT * FROM promotion_recommended_targets 
WHERE is_in_season = true
ORDER BY priority_score DESC;
*/
