-- =============================================
-- Coupon & Promotion Phase 7: Analytics Views
-- Tree Law Zoo Valley
-- =============================================
-- Purpose:
-- - Create database views for analytics dashboard
-- - Support summary cards and detailed usage tables
-- - Enable order drill-down functionality
-- =============================================

-- =============================================
-- 1. Coupon/Promotion Usage Summary View
-- =============================================
CREATE OR REPLACE VIEW coupon_promotion_usage_summary AS
SELECT 
  -- Basic info
  CASE 
    WHEN d.id IS NOT NULL THEN 'coupon'
    WHEN p.id IS NOT NULL THEN 'promotion'
  END as type,
  COALESCE(d.id, p.id) as id,
  COALESCE(d.name, p.name) as name,
  COALESCE(d.description, p.description) as description,
  
  -- Usage statistics
  COUNT(od.id) as usage_count,
  COALESCE(SUM(od.discount_amount), 0) as total_discount,
  COUNT(DISTINCT od.order_id) as order_count,
  COUNT(DISTINCT o.customer_id) as unique_customers,
  
  -- Last usage
  MAX(od.applied_at) as last_used_at,
  MIN(od.applied_at) as first_used_at,
  
  -- Date range for filtering
  DATE(od.applied_at) as usage_date,
  EXTRACT(MONTH FROM od.applied_at) as usage_month,
  EXTRACT(YEAR FROM od.applied_at) as usage_year,
  
  -- Additional fields
  COALESCE(d.discount_type, 'promotion') as discount_type,
  COALESCE(d.discount_value, 0) as discount_value,
  COALESCE(p.min_quantity, 0) as min_quantity,
  COALESCE(p.free_quantity, 0) as free_quantity
  
FROM pos_order_discounts od
LEFT JOIN pos_orders o ON od.order_id = o.id
LEFT JOIN pos_discounts d ON od.discount_id = d.id
LEFT JOIN pos_promotions p ON od.promotion_id = p.id
WHERE od.applied_at IS NOT NULL
GROUP BY 
  COALESCE(d.id, p.id),
  COALESCE(d.name, p.name),
  COALESCE(d.description, p.description),
  COALESCE(d.discount_type, 'promotion'),
  COALESCE(d.discount_value, 0),
  COALESCE(p.min_quantity, 0),
  COALESCE(p.free_quantity, 0);

-- =============================================
-- 2. Order Details with Discounts View
-- =============================================
CREATE OR REPLACE VIEW order_discount_details AS
SELECT 
  -- Order info
  o.id as order_id,
  o.order_number,
  o.total_amount as order_total,
  o.final_amount as order_final_amount,
  o.created_at as order_date,
  o.customer_id,
  c.display_name as customer_name,
  
  -- Discount info
  od.id as order_discount_id,
  od.discount_id,
  od.promotion_id,
  od.discount_name,
  od.discount_type,
  od.discount_value,
  od.discount_amount,
  od.applied_at,
  od.applied_by,
  u.display_name as applied_by_name,
  
  -- Discount type classification
  CASE 
    WHEN od.discount_id IS NOT NULL THEN 'coupon'
    WHEN od.promotion_id IS NOT NULL THEN 'promotion'
  END as discount_category,
  
  -- Coupon/Promotion details
  COALESCE(d.name, p.name) as discount_full_name,
  COALESCE(d.description, p.description) as discount_description,
  
  -- Order line details for line-level discounts
  ol.id as order_line_id,
  ol.product_id,
  ip.name as product_name,
  ol.quantity,
  ol.unit_price,
  ol.discount_amount as line_discount_amount,
  ol.final_line_total
  
FROM pos_orders o
LEFT JOIN pos_order_discounts od ON o.id = od.order_id
LEFT JOIN pos_customers c ON o.customer_id = c.id
LEFT JOIN users u ON od.applied_by = u.id
LEFT JOIN pos_discounts d ON od.discount_id = d.id
LEFT JOIN pos_promotions p ON od.promotion_id = p.id
LEFT JOIN pos_order_lines ol ON od.order_line_id = ol.id
LEFT JOIN inventory_products ip ON ol.product_id = ip.id
WHERE o.created_at IS NOT NULL;

-- =============================================
-- 3. Analytics Summary Aggregates View
-- =============================================
CREATE OR REPLACE VIEW analytics_summary AS
SELECT 
  -- Overall summary
  COUNT(*) as total_usage_count,
  COALESCE(SUM(discount_amount), 0) as total_discount_amount,
  COUNT(DISTINCT order_id) as total_orders_with_discount,
  COUNT(DISTINCT customer_id) as total_unique_customers,
  
  -- By type
  type,
  COUNT(*) as usage_by_type,
  COALESCE(SUM(discount_amount), 0) as discount_by_type,
  COUNT(DISTINCT id) as unique_discounts_by_type,
  
  -- Date aggregations
  usage_date,
  usage_month,
  usage_year,
  
  -- Calculations
  COALESCE(AVG(discount_amount), 0) as avg_discount_per_usage,
  COALESCE(MAX(discount_amount), 0) as max_discount_per_usage,
  COALESCE(MIN(discount_amount), 0) as min_discount_per_usage
  
FROM coupon_promotion_usage_summary
GROUP BY 
  type,
  usage_date,
  usage_month,
  usage_year;

-- =============================================
-- 4. Top Performing Coupons/Promotions View
-- =============================================
CREATE OR REPLACE VIEW top_performing_discounts AS
SELECT 
  type,
  id,
  name,
  usage_count,
  total_discount,
  order_count,
  unique_customers,
  last_used_at,
  
  -- Performance metrics
  COALESCE(total_discount / NULLIF(usage_count, 0), 0) as avg_discount_per_use,
  COALESCE(order_count / NULLIF(unique_customers, 0), 0) as orders_per_customer,
  
  -- Ranking
  ROW_NUMBER() OVER (PARTITION BY type ORDER BY usage_count DESC) as usage_rank,
  ROW_NUMBER() OVER (PARTITION BY type ORDER BY total_discount DESC) as discount_rank,
  ROW_NUMBER() OVER (PARTITION BY type ORDER BY unique_customers DESC) as customer_rank
  
FROM coupon_promotion_usage_summary
WHERE usage_count > 0;

-- =============================================
-- 5. Customer Usage Patterns View
-- =============================================
CREATE OR REPLACE VIEW customer_discount_usage AS
SELECT 
  -- Customer info
  o.customer_id,
  c.display_name as customer_name,
  c.email,
  c.phone,
  
  -- Usage statistics
  COUNT(DISTINCT od.id) as total_discounts_used,
  COALESCE(SUM(od.discount_amount), 0) as total_discount_received,
  COUNT(DISTINCT o.id) as orders_with_discount,
  COUNT(DISTINCT CASE WHEN od.discount_id IS NOT NULL THEN od.discount_id END) as unique_coupons_used,
  COUNT(DISTINCT CASE WHEN od.promotion_id IS NOT NULL THEN od.promotion_id END) as unique_promotions_used,
  
  -- First and last usage
  MIN(od.applied_at) as first_discount_usage,
  MAX(od.applied_at) as last_discount_usage,
  
  -- Preferences
  CASE 
    WHEN COUNT(CASE WHEN od.discount_id IS NOT NULL THEN 1 END) > 
         COUNT(CASE WHEN od.promotion_id IS NOT NULL THEN 1 END) 
    THEN 'coupon'
    ELSE 'promotion'
  END as preferred_type,
  
  -- Average order value
  COALESCE(AVG(o.final_amount), 0) as avg_order_value_with_discount
  
FROM pos_orders o
LEFT JOIN pos_order_discounts od ON o.id = od.order_id
LEFT JOIN pos_customers c ON o.customer_id = c.id
WHERE o.customer_id IS NOT NULL 
  AND od.id IS NOT NULL
GROUP BY 
  o.customer_id, 
  c.display_name, 
  c.email, 
  c.phone;

-- =============================================
-- 6. Indexes for Performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_coupon_promotion_usage_summary_type 
  ON coupon_promotion_usage_summary(type);

CREATE INDEX IF NOT EXISTS idx_coupon_promotion_usage_summary_date 
  ON coupon_promotion_usage_summary(usage_date);

CREATE INDEX IF NOT EXISTS idx_coupon_promotion_usage_summary_id 
  ON coupon_promotion_usage_summary(id);

CREATE INDEX IF NOT EXISTS idx_order_discount_details_order 
  ON order_discount_details(order_id);

CREATE INDEX IF NOT EXISTS idx_order_discount_details_discount 
  ON order_discount_details(discount_id, promotion_id);

CREATE INDEX IF NOT EXISTS idx_order_discount_details_customer 
  ON order_discount_details(customer_id);

CREATE INDEX IF NOT EXISTS idx_analytics_summary_type_date 
  ON analytics_summary(type, usage_date);

CREATE INDEX IF NOT EXISTS idx_customer_discount_usage_customer 
  ON customer_discount_usage(customer_id);

-- =============================================
-- 7. Helper Functions
-- =============================================

-- Function to get analytics summary for date range
CREATE OR REPLACE FUNCTION get_analytics_summary(
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_discount_id UUID DEFAULT NULL,
  p_promotion_id UUID DEFAULT NULL
)
RETURNS TABLE (
  total_usage_count BIGINT,
  total_discount_amount DOUBLE PRECISION,
  total_orders_with_discount BIGINT,
  total_unique_customers BIGINT,
  coupon_usage_count BIGINT,
  promotion_usage_count BIGINT,
  coupon_discount_amount DOUBLE PRECISION,
  promotion_discount_amount DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) as total_usage_count,
    COALESCE(SUM(od.discount_amount), 0) as total_discount_amount,
    COUNT(DISTINCT od.order_id) as total_orders_with_discount,
    COUNT(DISTINCT o.customer_id) as total_unique_customers,
    COUNT(DISTINCT CASE WHEN od.discount_id IS NOT NULL THEN od.id END) as coupon_usage_count,
    COUNT(DISTINCT CASE WHEN od.promotion_id IS NOT NULL THEN od.id END) as promotion_usage_count,
    COALESCE(SUM(CASE WHEN od.discount_id IS NOT NULL THEN od.discount_amount ELSE 0 END), 0) as coupon_discount_amount,
    COALESCE(SUM(CASE WHEN od.promotion_id IS NOT NULL THEN od.discount_amount ELSE 0 END), 0) as promotion_discount_amount
  FROM pos_order_discounts od
  LEFT JOIN pos_orders o ON od.order_id = o.id
  WHERE 
    (p_start_date IS NULL OR DATE(od.applied_at) >= p_start_date)
    AND (p_end_date IS NULL OR DATE(od.applied_at) <= p_end_date)
    AND (p_discount_id IS NULL OR od.discount_id = p_discount_id)
    AND (p_promotion_id IS NULL OR od.promotion_id = p_promotion_id);
END;
$$ LANGUAGE plpgsql;

-- Function to get usage analytics for table
CREATE OR REPLACE FUNCTION get_usage_analytics(
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_discount_id UUID DEFAULT NULL,
  p_promotion_id UUID DEFAULT NULL,
  p_limit INT DEFAULT 100,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  type TEXT,
  id UUID,
  name TEXT,
  usage_count BIGINT,
  total_discount DOUBLE PRECISION,
  order_count BIGINT,
  unique_customers BIGINT,
  last_used_at TIMESTAMPTZ,
  avg_discount_per_use DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    type,
    id,
    name,
    usage_count,
    total_discount,
    order_count,
    unique_customers,
    last_used_at,
    COALESCE(total_discount / NULLIF(usage_count, 0), 0) as avg_discount_per_use
  FROM coupon_promotion_usage_summary
  WHERE 
    (p_start_date IS NULL OR usage_date >= p_start_date)
    AND (p_end_date IS NULL OR usage_date <= p_end_date)
    AND (p_discount_id IS NULL OR (type = 'coupon' AND id = p_discount_id))
    AND (p_promotion_id IS NULL OR (type = 'promotion' AND id = p_promotion_id))
  ORDER BY usage_count DESC, total_discount DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
