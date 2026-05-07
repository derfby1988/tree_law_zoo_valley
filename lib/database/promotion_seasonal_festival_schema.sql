-- =============================================
-- Promotion Seasonal & Festival Tags Schema
-- =============================================
-- สำหรับ Phase 3: Product Picker Advanced Filters
-- เพิ่มความสามารถในการกรองสินค้าตามฤดูกาลและเทศกาล

-- =============================================
-- 1. Season Tags
-- =============================================
-- ตารางเก็บข้อมูลฤดูกาล (summer, rainy, winter)

CREATE TABLE IF NOT EXISTS promotion_seasonal_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  name_th TEXT NOT NULL UNIQUE,
  description TEXT,
  start_month INT NOT NULL CHECK (start_month BETWEEN 1 AND 12),
  end_month INT NOT NULL CHECK (end_month BETWEEN 1 AND 12),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert default seasons
INSERT INTO promotion_seasonal_tags (name, name_th, description, start_month, end_month) VALUES
('summer', 'ฤดูร้อน', 'ฤดูร้อน (มีนาคม - พฤษภาคม)', 3, 5),
('rainy', 'ฤดูฝน', 'ฤดูฝน (มิถุนายน - ตุลาคม)', 6, 10),
('winter', 'ฤดูหนาว', 'ฤดูหนาว (พฤศจิกายน - กุมภาพันธ์)', 11, 2)
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- 2. Festival Tags
-- =============================================
-- ตารางเก็บข้อมูลเทศกาลต่างๆ

CREATE TABLE IF NOT EXISTS promotion_festival_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  name_th TEXT NOT NULL UNIQUE,
  description TEXT,
  festival_date DATE,
  is_recurring BOOLEAN DEFAULT true, -- เกิดซ้ำทุกปีหรือไม่
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert common Thai festivals
INSERT INTO promotion_festival_tags (name, name_th, description, festival_date, is_recurring) VALUES
('songkran', 'สงกรานต์', 'ปีใหม่ไทย 13-15 เมษายน', NULL, true),
('loykrathong', 'ลอยกระทง', 'วันลอยกระทง เดือนพฤศจิกายน', NULL, true),
('christmas', 'คริสต์มาส', 'วันคริสต์มาส 25 ธันวาคม', NULL, true),
('newyear', 'ปีใหม่สากล', 'วันขึ้นปีใหม่ 1 มกราคม', NULL, true),
('chinese_new_year', 'ตรุษจีน', 'ปีใหม่จีน', NULL, true),
('valentine', 'วาเลนไทน์', 'วันวาเลนไทน์ 14 กุมภาพันธ์', NULL, true)
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- 3. Product-Season Relations
-- =============================================
-- เชื่อมโยงสินค้ากับฤดูกาล (many-to-many)

CREATE TABLE IF NOT EXISTS promotion_product_seasonal_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES inventory_products(id) ON DELETE CASCADE,
  seasonal_tag_id UUID NOT NULL REFERENCES promotion_seasonal_tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(product_id, seasonal_tag_id)
);

-- =============================================
-- 4. Product-Festival Relations
-- =============================================
-- เชื่อมโยงสินค้ากับเทศกาล (many-to-many)

CREATE TABLE IF NOT EXISTS promotion_product_festival_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES inventory_products(id) ON DELETE CASCADE,
  festival_tag_id UUID NOT NULL REFERENCES promotion_festival_tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(product_id, festival_tag_id)
);

-- =============================================
-- 5. Indexes
-- =============================================

-- Seasonal tags indexes
CREATE INDEX IF NOT EXISTS idx_promotion_seasonal_tags_active ON promotion_seasonal_tags(is_active);
CREATE INDEX IF NOT EXISTS idx_promotion_seasonal_tags_months ON promotion_seasonal_tags(start_month, end_month);

-- Festival tags indexes
CREATE INDEX IF NOT EXISTS idx_promotion_festival_tags_active ON promotion_festival_tags(is_active);
CREATE INDEX IF NOT EXISTS idx_promotion_festival_tags_date ON promotion_festival_tags(festival_date);
CREATE INDEX IF NOT EXISTS idx_promotion_festival_tags_recurring ON promotion_festival_tags(is_recurring);

-- Product relation indexes
CREATE INDEX IF NOT EXISTS idx_product_seasonal_tags_product ON promotion_product_seasonal_tags(product_id);
CREATE INDEX IF NOT EXISTS idx_product_seasonal_tags_season ON promotion_product_seasonal_tags(seasonal_tag_id);
CREATE INDEX IF NOT EXISTS idx_product_festival_tags_product ON promotion_product_festival_tags(product_id);
CREATE INDEX IF NOT EXISTS idx_product_festival_tags_festival ON promotion_product_festival_tags(festival_tag_id);

-- =============================================
-- 6. Helper Functions
-- =============================================

-- Function to get current season
CREATE OR REPLACE FUNCTION get_current_season()
RETURNS TEXT AS $$
DECLARE
    current_month INT := EXTRACT(MONTH FROM CURRENT_DATE);
    season_name TEXT;
BEGIN
    SELECT name INTO season_name
    FROM promotion_seasonal_tags
    WHERE is_active = true
      AND (
        (start_month <= end_month AND current_month BETWEEN start_month AND end_month)
        OR
        (start_month > end_month AND (current_month >= start_month OR current_month <= end_month))
      )
    LIMIT 1;
    
    RETURN COALESCE(season_name, 'all');
END;
$$ LANGUAGE plpgsql;

-- Function to get current/upcoming festivals
CREATE OR REPLACE FUNCTION get_current_festivals(days_ahead INT DEFAULT 30)
RETURNS TABLE (
    id UUID,
    name TEXT,
    name_th TEXT,
    festival_date DATE,
    days_until INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ft.id,
        ft.name,
        ft.name_th,
        ft.festival_date,
        CASE 
            WHEN ft.festival_date IS NULL THEN NULL
            ELSE ft.festival_date - CURRENT_DATE
        END as days_until
    FROM promotion_festival_tags ft
    WHERE ft.is_active = true
      AND (
        ft.festival_date IS NULL -- Recurring festivals
        OR ft.festival_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + days_ahead * INTERVAL '1 day')
      )
    ORDER BY 
        CASE 
            WHEN ft.festival_date IS NULL THEN 1
            ELSE ft.festival_date - CURRENT_DATE
        END;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 7. Views for Product Picker
-- =============================================

-- View: Products with seasonal tags
CREATE OR REPLACE VIEW promotion_products_with_seasonal_tags AS
SELECT 
    p.id as product_id,
    p.name as product_name,
    st.id as seasonal_tag_id,
    st.name as seasonal_name,
    st.name_th as seasonal_name_th,
    st.start_month,
    st.end_month
FROM inventory_products p
JOIN promotion_product_seasonal_tags pst ON p.id = pst.product_id
JOIN promotion_seasonal_tags st ON pst.seasonal_tag_id = st.id
WHERE p.is_active = true
  AND st.is_active = true;

-- View: Products with festival tags
CREATE OR REPLACE VIEW promotion_products_with_festival_tags AS
SELECT 
    p.id as product_id,
    p.name as product_name,
    ft.id as festival_tag_id,
    ft.name as festival_name,
    ft.name_th as festival_name_th,
    ft.festival_date,
    ft.is_recurring
FROM inventory_products p
JOIN promotion_product_festival_tags pft ON p.id = pft.product_id
JOIN promotion_festival_tags ft ON pft.festival_tag_id = ft.id
WHERE p.is_active = true
  AND ft.is_active = true;

-- =============================================
-- 8. Grant Permissions
-- =============================================

GRANT SELECT, INSERT, UPDATE, DELETE ON promotion_seasonal_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON promotion_festival_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON promotion_product_seasonal_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON promotion_product_festival_tags TO authenticated;

GRANT SELECT ON promotion_products_with_seasonal_tags TO authenticated;
GRANT SELECT ON promotion_products_with_festival_tags TO authenticated;

GRANT EXECUTE ON FUNCTION get_current_season() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_festivals(INT) TO authenticated;
