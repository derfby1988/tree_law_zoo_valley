-- =============================================
-- Phase 5: Expiry Targeting
-- =============================================
-- วันที่สร้าง: 6 พฤษภาคม 2568
-- เป้าหมาย: ระบายสินค้าและวัตถุดิบใกล้หมดอายุผ่านโปรโมชั่น
-- กฎธุรกิจ:
--   - สินค้าใกล้หมดอายุ = ที่เหลือ < 7 วัน (หรือกำหนดเอง)
--   - วัตถุดิบใกล้หมดอายุ = ที่เหลือ < 7 วัน
--   - แนะนำเมนูที่ใช้วัตถุดิบนั้นเพื่อระบาย
-- =============================================

-- =============================================
-- 1. VIEW: สินค้าใกล้หมดอายุ (พร้อม batch details)
-- =============================================
DROP VIEW IF EXISTS promotion_expiring_product_targets;

CREATE VIEW promotion_expiring_product_targets AS
WITH batch_expiry AS (
    -- รวม batch ที่ใกล้หมดอายุของแต่ละสินค้า
    SELECT 
        b.product_id,
        SUM(b.quantity) as expiring_quantity,
        MIN(b.expiry_date) as earliest_expiry,
        COUNT(b.id) as batch_count,
        jsonb_agg(
            jsonb_build_object(
                'batch_id', b.id,
                'batch_number', b.batch_number,
                'quantity', b.quantity,
                'expiry_date', b.expiry_date,
                'days_until_expiry', (b.expiry_date - CURRENT_DATE)
            ) ORDER BY b.expiry_date
        ) FILTER (WHERE b.expiry_date IS NOT NULL) as batch_details
    FROM inventory_item_batches b
    WHERE b.is_active = true 
        AND b.quantity > 0
        AND b.expiry_date IS NOT NULL
    GROUP BY b.product_id
)
SELECT 
    p.id as product_id,
    p.name as product_name,
    p.category_id,
    c.name as category_name,
    p.price as current_price,
    p.cost,
    p.min_quantity,
    
    -- ข้อมูล expiry
    be.earliest_expiry,
    (be.earliest_expiry - CURRENT_DATE) as days_until_expiry,
    be.expiring_quantity,
    be.batch_count,
    
    -- ข้อมูล batch
    be.batch_details,
    
    -- ข้อมูล stock รวม
    COALESCE(ss.total_quantity, 0) as total_stock,
    COALESCE(ss.total_quantity, 0) as available_stock,
    
    -- สถานะ
    CASE 
        WHEN be.earliest_expiry <= CURRENT_DATE THEN 'expired'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 THEN 'critical'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 THEN 'warning'
        ELSE 'normal'
    END as expiry_status,
    
    -- เหตุผลสำหรับโปรโมชั่น
    CASE 
        WHEN be.earliest_expiry <= CURRENT_DATE 
            THEN 'สินค้าหมดอายุแล้ว ' || be.expiring_quantity::TEXT || ' ' || COALESCE(u.name, 'ชิ้น') || ' ต้องระบายด่วน'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 
            THEN 'สินค้าใกล้หมดอายุ ' || (be.earliest_expiry - CURRENT_DATE)::TEXT || ' วัน (' || be.expiring_quantity::TEXT || ' ' || COALESCE(u.name, 'ชิ้น') || ')'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 
            THEN 'สินค้าใกล้หมดอายุ ' || (be.earliest_expiry - CURRENT_DATE)::TEXT || ' วัน'
        ELSE 'สินค้ายังไม่ใกล้หมดอายุ'
    END as promotion_reason,
    
    -- metadata สำหรับแนะนำโปรโมชั่น
    jsonb_build_object(
        'suggested_discount_percent', 
            CASE 
                WHEN be.earliest_expiry <= CURRENT_DATE THEN 50
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 THEN 30
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 THEN 20
                ELSE 10
            END,
        'urgency_level',
            CASE 
                WHEN be.earliest_expiry <= CURRENT_DATE THEN 'critical'
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 THEN 'high'
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 THEN 'medium'
                ELSE 'low'
            END,
        'recommended_quantity', be.expiring_quantity
    ) as promotion_metadata,
    
    -- สถานะการแสดงใน tab
    true as is_expiring_target,
    CURRENT_DATE as check_date
    
FROM inventory_products p
LEFT JOIN inventory_categories c ON p.category_id = c.id
LEFT JOIN inventory_units u ON p.unit_id = u.id
LEFT JOIN batch_expiry be ON p.id = be.product_id
LEFT JOIN inventory_stock_summary ss ON p.id = ss.item_id AND ss.item_type = 'product'
WHERE p.is_active = true
    AND be.earliest_expiry IS NOT NULL
    AND (be.earliest_expiry - CURRENT_DATE) <= 30;  -- แสดงเฉพาะที่หมดอายุภายใน 30 วัน

-- =============================================
-- 2. VIEW: วัตถุดิบใกล้หมดอายุ พร้อมเมนูที่ใช้
-- =============================================
DROP VIEW IF EXISTS promotion_expiring_ingredient_targets;

CREATE VIEW promotion_expiring_ingredient_targets AS
WITH batch_expiry AS (
    -- รวม batch ที่ใกล้หมดอายุของแต่ละวัตถุดิบ
    SELECT 
        b.ingredient_id,
        SUM(b.quantity) as expiring_quantity,
        MIN(b.expiry_date) as earliest_expiry,
        COUNT(b.id) as batch_count,
        jsonb_agg(
            jsonb_build_object(
                'batch_id', b.id,
                'batch_number', b.batch_number,
                'quantity', b.quantity,
                'expiry_date', b.expiry_date,
                'days_until_expiry', (b.expiry_date - CURRENT_DATE)
            ) ORDER BY b.expiry_date
        ) FILTER (WHERE b.expiry_date IS NOT NULL) as batch_details
    FROM inventory_item_batches b
    WHERE b.is_active = true 
        AND b.quantity > 0
        AND b.ingredient_id IS NOT NULL
        AND b.expiry_date IS NOT NULL
    GROUP BY b.ingredient_id
),
recipe_usage AS (
    -- หาว่าวัตถุดิบนี้ใช้ในเมนู (สูตร) ไหนบ้าง
    SELECT 
        ri.product_id as ingredient_id,
        jsonb_agg(
            jsonb_build_object(
                'recipe_id', r.id,
                'recipe_name', r.name,
                'output_product_id', r.output_product_id,
                'output_product_name', p.name,
                'quantity_required', ri.quantity,
                'yield_quantity', r.yield_quantity,
                'possible_servings', FLOOR(be.expiring_quantity / NULLIF(ri.quantity, 0))
            ) ORDER BY r.name
        ) as affected_recipes,
        COUNT(DISTINCT r.id) as recipe_count
    FROM inventory_recipe_ingredients ri
    JOIN inventory_recipes r ON ri.recipe_id = r.id AND r.is_active = true
    LEFT JOIN inventory_products p ON r.output_product_id = p.id
    JOIN batch_expiry be ON ri.product_id = be.ingredient_id
    WHERE ri.product_id IS NOT NULL
    GROUP BY ri.product_id
)
SELECT 
    i.id as ingredient_id,
    i.name as ingredient_name,
    i.category_id,
    c.name as category_name,
    
    -- ข้อมูล expiry
    be.earliest_expiry,
    (be.earliest_expiry - CURRENT_DATE) as days_until_expiry,
    be.expiring_quantity,
    be.batch_count,
    be.batch_details,
    
    -- ข้อมูล stock
    COALESCE(ss.total_quantity, 0) as total_stock,
    
    -- สูตรอาหารที่ใช้วัตถุดิบนี้
    ru.affected_recipes,
    ru.recipe_count,
    
    -- สถานะ
    CASE 
        WHEN be.earliest_expiry <= CURRENT_DATE THEN 'expired'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 THEN 'critical'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 THEN 'warning'
        ELSE 'normal'
    END as expiry_status,
    
    -- เหตุผลสำหรับโปรโมชั่น
    CASE 
        WHEN be.earliest_expiry <= CURRENT_DATE 
            THEN 'วัตถุดิบหมดอายุแล้ว ' || be.expiring_quantity::TEXT || ' ' || COALESCE(u.name, 'หน่วย') || ' ควรทำโปรโมชั่นระบาย ' || COALESCE(ru.recipe_count, 0)::TEXT || ' เมนู'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 
            THEN 'วัตถุดิบใกล้หมดอายุ ' || (be.earliest_expiry - CURRENT_DATE)::TEXT || ' วัน (' || be.expiring_quantity::TEXT || ' ' || COALESCE(u.name, 'หน่วย') || ') - ใช้ใน ' || COALESCE(ru.recipe_count, 0)::TEXT || ' เมนู'
        WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 
            THEN 'วัตถุดิบใกล้หมดอายุ ' || (be.earliest_expiry - CURRENT_DATE)::TEXT || ' วัน - ใช้ใน ' || COALESCE(ru.recipe_count, 0)::TEXT || ' เมนู'
        ELSE 'วัตถุดิบยังไม่ใกล้หมดอายุ'
    END as promotion_reason,
    
    -- metadata สำหรับแนะนำโปรโมชั่น
    jsonb_build_object(
        'suggested_discount_percent', 
            CASE 
                WHEN be.earliest_expiry <= CURRENT_DATE THEN 40
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 THEN 25
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 THEN 15
                ELSE 10
            END,
        'urgency_level',
            CASE 
                WHEN be.earliest_expiry <= CURRENT_DATE THEN 'critical'
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 3 THEN 'high'
                WHEN (be.earliest_expiry - CURRENT_DATE) <= 7 THEN 'medium'
                ELSE 'low'
            END,
        'recommended_quantity', be.expiring_quantity,
        'affected_recipe_count', COALESCE(ru.recipe_count, 0),
        'affected_recipes', COALESCE(ru.affected_recipes, '[]'::jsonb)
    ) as promotion_metadata,
    
    -- สถานะการแสดงใน tab
    true as is_expiring_target,
    CURRENT_DATE as check_date
    
FROM inventory_ingredients i
LEFT JOIN inventory_categories c ON i.category_id = c.id
LEFT JOIN inventory_units u ON i.unit_id = u.id
LEFT JOIN batch_expiry be ON i.id = be.ingredient_id
LEFT JOIN recipe_usage ru ON i.id = ru.ingredient_id
LEFT JOIN inventory_stock_summary ss ON i.id = ss.item_id AND ss.item_type = 'ingredient'
WHERE i.is_active = true
    AND be.earliest_expiry IS NOT NULL
    AND (be.earliest_expiry - CURRENT_DATE) <= 30;  -- แสดงเฉพาะที่หมดอายุภายใน 30 วัน

-- =============================================
-- 3. RPC: ดึงสินค้าใกล้หมดอายุตามช่วงวัน
-- =============================================
CREATE OR REPLACE FUNCTION get_expiring_products(
    p_days_threshold INT DEFAULT 7,
    p_include_expired BOOLEAN DEFAULT true
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    category_name TEXT,
    current_price DOUBLE PRECISION,
    expiring_quantity NUMERIC,
    days_until_expiry INTEGER,
    expiry_status TEXT,
    promotion_reason TEXT,
    promotion_metadata JSONB,
    batch_details JSONB
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.product_id,
        t.product_name,
        t.category_name,
        t.current_price,
        t.expiring_quantity,
        t.days_until_expiry::INTEGER,
        t.expiry_status,
        t.promotion_reason,
        t.promotion_metadata,
        t.batch_details
    FROM promotion_expiring_product_targets t
    WHERE (t.days_until_expiry <= p_days_threshold OR p_include_expired)
        AND (NOT p_include_expired OR t.days_until_expiry >= 0)
    ORDER BY t.days_until_expiry ASC, t.expiring_quantity DESC;
END;
$$;

-- =============================================
-- 4. RPC: ดึงวัตถุดิบใกล้หมดอายุตามช่วงวัน
-- =============================================
CREATE OR REPLACE FUNCTION get_expiring_ingredients(
    p_days_threshold INT DEFAULT 7,
    p_include_expired BOOLEAN DEFAULT true
)
RETURNS TABLE (
    ingredient_id UUID,
    ingredient_name TEXT,
    category_name TEXT,
    expiring_quantity NUMERIC,
    days_until_expiry INTEGER,
    expiry_status TEXT,
    promotion_reason TEXT,
    promotion_metadata JSONB,
    affected_recipes JSONB,
    batch_details JSONB
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.ingredient_id,
        t.ingredient_name,
        t.category_name,
        t.expiring_quantity,
        t.days_until_expiry::INTEGER,
        t.expiry_status,
        t.promotion_reason,
        t.promotion_metadata,
        t.affected_recipes,
        t.batch_details
    FROM promotion_expiring_ingredient_targets t
    WHERE (t.days_until_expiry <= p_days_threshold OR p_include_expired)
        AND (NOT p_include_expired OR t.days_until_expiry >= 0)
    ORDER BY t.days_until_expiry ASC, t.recipe_count DESC, t.expiring_quantity DESC;
END;
$$;

-- =============================================
-- 5. RPC: ดึงเมนูที่แนะนำจากวัตถุดิบใกล้หมดอายุ
-- =============================================
CREATE OR REPLACE FUNCTION get_recipes_from_expiring_ingredients(
    p_ingredient_ids UUID[] DEFAULT NULL,
    p_days_threshold INT DEFAULT 7
)
RETURNS TABLE (
    recipe_id UUID,
    recipe_name TEXT,
    output_product_id UUID,
    output_product_name TEXT,
    yield_quantity DOUBLE PRECISION,
    possible_servings INTEGER,
    expiring_ingredients JSONB,
    urgency_level TEXT,
    suggested_discount_percent INT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH expiring_ingredients AS (
        SELECT * FROM promotion_expiring_ingredient_targets
        WHERE (p_ingredient_ids IS NULL OR ingredient_id = ANY(p_ingredient_ids))
            AND days_until_expiry <= p_days_threshold
    ),
    recipe_calculations AS (
        SELECT 
            (jsonb_array_elements(e.affected_recipes)->>'recipe_id')::UUID as recipe_id,
            (jsonb_array_elements(e.affected_recipes)->>'recipe_name')::TEXT as recipe_name,
            (jsonb_array_elements(e.affected_recipes)->>'output_product_id')::UUID as output_product_id,
            (jsonb_array_elements(e.affected_recipes)->>'output_product_name')::TEXT as output_product_name,
            (jsonb_array_elements(e.affected_recipes)->>'yield_quantity')::DOUBLE PRECISION as yield_quantity,
            (jsonb_array_elements(e.affected_recipes)->>'possible_servings')::INTEGER as possible_servings,
            e.ingredient_id,
            e.ingredient_name,
            e.days_until_expiry,
            e.expiring_quantity,
            e.expiry_status,
            e.promotion_metadata->>'urgency_level' as ingredient_urgency
        FROM expiring_ingredients e
    )
    SELECT 
        rc.recipe_id,
        rc.recipe_name,
        rc.output_product_id,
        rc.output_product_name,
        rc.yield_quantity,
        MIN(rc.possible_servings)::INTEGER as possible_servings,
        jsonb_agg(
            jsonb_build_object(
                'ingredient_id', rc.ingredient_id,
                'ingredient_name', rc.ingredient_name,
                'expiring_quantity', rc.expiring_quantity,
                'days_until_expiry', rc.days_until_expiry,
                'expiry_status', rc.expiry_status
            )
        ) as expiring_ingredients,
        CASE 
            WHEN MIN(rc.days_until_expiry) <= 0 THEN 'critical'
            WHEN MIN(rc.days_until_expiry) <= 3 THEN 'high'
            WHEN MIN(rc.days_until_expiry) <= 7 THEN 'medium'
            ELSE 'low'
        END as urgency_level,
        CASE 
            WHEN MIN(rc.days_until_expiry) <= 0 THEN 40
            WHEN MIN(rc.days_until_expiry) <= 3 THEN 25
            WHEN MIN(rc.days_until_expiry) <= 7 THEN 15
            ELSE 10
        END::INT as suggested_discount_percent
    FROM recipe_calculations rc
    GROUP BY rc.recipe_id, rc.recipe_name, rc.output_product_id, rc.output_product_name, rc.yield_quantity
    ORDER BY MIN(rc.days_until_expiry) ASC, MIN(rc.possible_servings) DESC;
END;
$$;

-- =============================================
-- 6. Grant permissions
-- =============================================
GRANT SELECT ON promotion_expiring_product_targets TO authenticated;
GRANT SELECT ON promotion_expiring_ingredient_targets TO authenticated;
GRANT EXECUTE ON FUNCTION get_expiring_products(INT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_expiring_ingredients(INT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recipes_from_expiring_ingredients(UUID[], INT) TO authenticated;

-- =============================================
-- 7. Comments
-- =============================================
COMMENT ON VIEW promotion_expiring_product_targets IS 'สินค้าใกล้หมดอายุที่ควรทำโปรโมชั่นระบาย';
COMMENT ON VIEW promotion_expiring_ingredient_targets IS 'วัตถุดิบใกล้หมดอายุพร้อมเมนูที่ใช้เพื่อระบาย';
COMMENT ON FUNCTION get_expiring_products IS 'ดึงสินค้าใกล้หมดอายุตามช่วงวันที่กำหนด';
COMMENT ON FUNCTION get_expiring_ingredients IS 'ดึงวัตถุดิบใกล้หมดอายุตามช่วงวันที่กำหนด';
COMMENT ON FUNCTION get_recipes_from_expiring_ingredients IS 'แนะนำเมนูจากวัตถุดิบใกล้หมดอายุเพื่อทำโปรโมชั่น';
