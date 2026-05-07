-- =============================================
-- Phase 4: Availability & Procurement Rules
-- =============================================
-- วันที่สร้าง: 6 พฤษภาคม 2568
-- เป้าหมาย: สร้าง RPC functions สำหรับตรวจสอบสินค้าพร้อมขาย
-- กฎธุรกิจ:
--   - stock > 0 = พร้อมขาย
--   - วัตถุดิบพอ = ผลิตได้ > 1 ชิ้น
--   - pending procurement = PO ทั้งหมดยกเว้น completed/cancelled
--   - block เมื่อไม่พร้อม
-- =============================================

-- =============================================
-- 1. RPC: ตรวจสอบสินค้าพร้อมขาย (Simple - Stock Only)
-- =============================================
CREATE OR REPLACE FUNCTION check_product_availability(
    p_product_id UUID,
    p_require_in_stock BOOLEAN DEFAULT true,
    p_include_pending_procurement BOOLEAN DEFAULT false
)
RETURNS TABLE (
    product_id UUID,
    is_available BOOLEAN,
    current_stock NUMERIC,
    pending_procurement_quantity NUMERIC,
    available_quantity NUMERIC,
    reason TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_current_stock NUMERIC := 0;
    v_pending_qty NUMERIC := 0;
    v_available NUMERIC := 0;
    v_is_available BOOLEAN := false;
    v_reason TEXT := '';
BEGIN
    -- ดึง stock ปัจจุบันจาก stock_summary view
    SELECT COALESCE(ss.total_quantity, 0)
    INTO v_current_stock
    FROM inventory_stock_summary ss
    WHERE ss.item_id = p_product_id AND ss.item_type = 'product';
    
    -- ถ้าไม่มีข้อมูลใน stock_summary ถือว่า stock = 0
    IF v_current_stock IS NULL THEN
        v_current_stock := 0;
    END IF;
    
    -- คำนวณ pending procurement (ถ้าต้องการ)
    IF p_include_pending_procurement THEN
        SELECT COALESCE(SUM(pol.quantity - COALESCE(pol.received_quantity, 0)), 0)
        INTO v_pending_qty
        FROM procurement_purchase_order_lines pol
        JOIN procurement_purchase_orders po ON pol.po_id = po.id
        WHERE pol.product_id = p_product_id
          AND po.status NOT IN ('completed', 'cancelled');
    END IF;
    
    -- คำนวณ available quantity
    v_available := v_current_stock + v_pending_qty;
    
    -- ตรวจสอบว่าพร้อมขายหรือไม่
    IF p_require_in_stock THEN
        -- ต้องมี stock > 0 หรือมี pending procurement (ถ้าเปิดใช้)
        v_is_available := v_available > 0;
        
        IF v_is_available THEN
            IF v_current_stock > 0 THEN
                v_reason := 'มีสต็อกพร้อมขาย ' || v_current_stock::TEXT || ' ชิ้น';
            ELSE
                v_reason := 'รอรับสินค้าจากการจัดซื้อ ' || v_pending_qty::TEXT || ' ชิ้น';
            END IF;
        ELSE
            IF p_include_pending_procurement THEN
                v_reason := 'ไม่มีสต็อกและไม่มีรายการจัดซื้อ';
            ELSE
                v_reason := 'สต็อกหมด (คงเหลือ 0 ชิ้น)';
            END IF;
        END IF;
    ELSE
        -- ไม่ require stock ถือว่าพร้อมเสมอ
        v_is_available := true;
        v_reason := 'ไม่ตรวจสอบสต็อก';
    END IF;
    
    RETURN QUERY SELECT 
        p_product_id,
        v_is_available,
        v_current_stock,
        v_pending_qty,
        v_available,
        v_reason;
END;
$$;

-- =============================================
-- 2. RPC: ดึง pending procurement quantity
-- =============================================
CREATE OR REPLACE FUNCTION get_pending_procurement_quantity(
    p_product_id UUID
)
RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE
    v_pending_qty NUMERIC;
BEGIN
    SELECT COALESCE(SUM(pol.quantity - COALESCE(pol.received_quantity, 0)), 0)
    INTO v_pending_qty
    FROM procurement_purchase_order_lines pol
    JOIN procurement_purchase_orders po ON pol.po_id = po.id
    WHERE pol.product_id = p_product_id
      AND po.status NOT IN ('completed', 'cancelled');
      
    RETURN COALESCE(v_pending_qty, 0);
END;
$$;

-- =============================================
-- 3. RPC: ตรวจสอบวัตถุดิบในสูตรอาหารพอหรือไม่
-- =============================================
-- กฎ: ต้องผลิตได้ > 1 ชิ้น (ทุกวัตถุดิบต้องพอสำหรับ yield_quantity)
CREATE OR REPLACE FUNCTION check_recipe_ingredients_sufficient(
    p_product_id UUID
)
RETURNS TABLE (
    product_id UUID,
    recipe_id UUID,
    can_produce BOOLEAN,
    max_possible_servings INTEGER,
    ingredient_count INTEGER,
    sufficient_ingredients INTEGER,
    insufficient_ingredients TEXT[],
    reason TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_recipe_id UUID;
    v_yield_quantity NUMERIC;
    v_ingredient_count INTEGER := 0;
    v_sufficient_count INTEGER := 0;
    v_max_servings INTEGER := 999999;
    v_can_produce BOOLEAN := false;
    v_insufficient_list TEXT[] := ARRAY[]::TEXT[];
    v_reason TEXT := '';
    rec RECORD;
BEGIN
    -- หา recipe_id และ yield_quantity จาก product (recipe มี output_product_id อ้างอิงถึง product)
    SELECT r.id, r.yield_quantity
    INTO v_recipe_id, v_yield_quantity
    FROM inventory_recipes r
    WHERE r.output_product_id = p_product_id AND r.is_active = true;
    
    -- ถ้าไม่มีสูตร ถือว่าไม่ใช่สินค้าผลิต ส่งคืน NULL
    IF v_recipe_id IS NULL THEN
        RETURN QUERY SELECT 
            p_product_id,
            NULL::UUID,
            NULL::BOOLEAN,
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::TEXT[],
            'ไม่ใช่สินค้าผลิต (ไม่มีสูตรอาหาร)'::TEXT;
        RETURN;
    END IF;
    
    -- ตรวจสอบแต่ละวัตถุดิบในสูตร
    FOR rec IN 
        SELECT 
            i.id as ingredient_id,
            i.name as ingredient_name,
            ri.quantity_required,
            COALESCE(ss.total_quantity, 0) as current_stock
        FROM inventory_recipe_ingredients ri
        JOIN inventory_ingredients i ON ri.ingredient_id = i.id
        LEFT JOIN inventory_stock_summary ss ON i.id = ss.item_id AND ss.item_type = 'ingredient'
        WHERE ri.recipe_id = v_recipe_id
    LOOP
        v_ingredient_count := v_ingredient_count + 1;
        
        -- คำนวณจำนวนที่ผลิตได้จากวัตถุดิบนี้
        IF rec.quantity_required > 0 THEN
            DECLARE
                v_possible_from_ingredient INTEGER;
            BEGIN
                v_possible_from_ingredient := FLOOR(rec.current_stock / rec.quantity_required)::INTEGER;
                
                IF v_possible_from_ingredient > 0 THEN
                    v_sufficient_count := v_sufficient_count + 1;
                ELSE
                    v_insufficient_list := array_append(v_insufficient_list, 
                        rec.ingredient_name || ' (ต้องการ ' || rec.quantity_required || ' มี ' || rec.current_stock || ')');
                END IF;
                
                -- หาค่าต่ำสุดที่ผลิตได้จากทุกวัตถุดิบ
                IF v_possible_from_ingredient < v_max_servings THEN
                    v_max_servings := v_possible_from_ingredient;
                END IF;
            END;
        END IF;
    END LOOP;
    
    -- ตรวจสอบว่าผลิตได้ > 1 ชิ้นหรือไม่
    v_can_produce := v_max_servings > 1;
    
    -- สร้าง reason
    IF v_can_produce THEN
        v_reason := 'สามารถผลิตได้ ' || v_max_servings || ' ชิ้น (ทุกวัตถุดิบพอ)';
    ELSE
        IF v_max_servings = 0 THEN
            v_reason := 'ไม่สามารถผลิตได้ (วัตถุดิบไม่พอ): ' || array_to_string(v_insufficient_list, ', ');
        ELSE
            v_reason := 'ผลิตได้น้อยเกินไป (' || v_max_servings || ' ชิ้น) ต้องการ > 1 ชิ้น';
        END IF;
    END IF;
    
    RETURN QUERY SELECT 
        p_product_id,
        v_recipe_id,
        v_can_produce,
        v_max_servings,
        v_ingredient_count,
        v_sufficient_count,
        v_insufficient_list,
        v_reason;
END;
$$;

-- =============================================
-- 4. RPC: ตรวจสอบสินค้าพร้อมขายแบบครบวงจร
-- =============================================
-- รวมทั้ง stock, recipe ingredients, และ pending procurement
CREATE OR REPLACE FUNCTION check_product_full_availability(
    p_product_id UUID,
    p_require_in_stock BOOLEAN DEFAULT true,
    p_require_sufficient_ingredients BOOLEAN DEFAULT false,
    p_include_pending_procurement BOOLEAN DEFAULT false
)
RETURNS TABLE (
    product_id UUID,
    is_available BOOLEAN,
    availability_status TEXT,
    current_stock NUMERIC,
    pending_procurement NUMERIC,
    recipe_possible_servings INTEGER,
    total_available NUMERIC,
    disabled_reason TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_stock NUMERIC := 0;
    v_pending NUMERIC := 0;
    v_recipe_servings INTEGER := NULL;
    v_total_available NUMERIC := 0;
    v_is_available BOOLEAN := false;
    v_status TEXT := '';
    v_reason TEXT := '';
    v_has_recipe BOOLEAN := false;
BEGIN
    -- 1. ดึง stock ปัจจุบัน
    SELECT COALESCE(ss.total_quantity, 0)
    INTO v_stock
    FROM inventory_stock_summary ss
    WHERE ss.item_id = p_product_id AND ss.item_type = 'product';
    
    -- 2. ดึง pending procurement
    IF p_include_pending_procurement THEN
        SELECT get_pending_procurement_quantity(p_product_id)
        INTO v_pending;
    END IF;
    
    -- 3. ตรวจสอบสูตรอาหาร (ถ้าเป็น product ที่ผลิตจาก recipe)
    -- recipe มี output_product_id อ้างอิงถึง product
    SELECT r.id IS NOT NULL
    INTO v_has_recipe
    FROM inventory_recipes r
    WHERE r.output_product_id = p_product_id;
    
    IF v_has_recipe AND p_require_sufficient_ingredients THEN
        SELECT max_possible_servings
        INTO v_recipe_servings
        FROM check_recipe_ingredients_sufficient(p_product_id);
    END IF;
    
    -- 4. คำนวณ total available
    IF v_has_recipe AND p_require_sufficient_ingredients THEN
        -- ถ้าต้องการเช็คสูตร ใช้ผลิตได้จาก recipe เป็นหลัก
        v_total_available := COALESCE(v_recipe_servings, 0);
    ELSE
        -- ถ้าไม่ใช่สินค้าผลิต หรือไม่ต้องการเช็คสูตร ใช้ stock + pending
        v_total_available := v_stock + v_pending;
    END IF;
    
    -- 5. ตรวจสอบว่าพร้อมขายหรือไม่
    IF p_require_in_stock OR p_require_sufficient_ingredients THEN
        v_is_available := v_total_available > 0;
        
        IF v_is_available THEN
            IF v_has_recipe AND p_require_sufficient_ingredients THEN
                IF v_recipe_servings > 1 THEN
                    v_status := 'ready';
                    v_reason := 'พร้อมผลิต ' || v_recipe_servings || ' ชิ้น';
                ELSE
                    v_status := 'limited';
                    v_reason := 'ผลิตได้จำกัด (' || COALESCE(v_recipe_servings, 0) || ' ชิ้น)';
                END IF;
            ELSE
                IF v_stock > 0 THEN
                    v_status := 'in_stock';
                    v_reason := 'มีสต็อก ' || v_stock || ' ชิ้น';
                ELSIF v_pending > 0 THEN
                    v_status := 'pending_procurement';
                    v_reason := 'รอรับสินค้า ' || v_pending || ' ชิ้น';
                ELSE
                    v_status := 'out_of_stock';
                    v_reason := 'สต็อกหมด';
                    v_is_available := false;
                END IF;
            END IF;
        ELSE
            v_status := 'not_available';
            v_reason := CASE 
                WHEN v_has_recipe AND p_require_sufficient_ingredients THEN 'วัตถุดิบไม่พอผลิต'
                ELSE 'สินค้าหมด'
            END;
        END IF;
    ELSE
        -- ไม่ต้องการเช็คอะไรเลย
        v_is_available := true;
        v_status := 'no_check';
        v_reason := 'ไม่ตรวจสอบสต็อก/สูตร';
    END IF;
    
    RETURN QUERY SELECT 
        p_product_id,
        v_is_available,
        v_status,
        v_stock,
        v_pending,
        v_recipe_servings,
        v_total_available,
        v_reason;
END;
$$;

-- =============================================
-- 5. RPC: ดึงรายการสินค้าพร้อมขาย (Bulk Check)
-- =============================================
CREATE OR REPLACE FUNCTION get_available_products(
    p_require_in_stock BOOLEAN DEFAULT true,
    p_require_sufficient_ingredients BOOLEAN DEFAULT false,
    p_include_pending_procurement BOOLEAN DEFAULT false
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    is_available BOOLEAN,
    availability_status TEXT,
    current_stock NUMERIC,
    pending_procurement NUMERIC,
    recipe_possible_servings INTEGER,
    disabled_reason TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        fa.is_available,
        fa.availability_status,
        fa.current_stock,
        fa.pending_procurement,
        fa.recipe_possible_servings,
        fa.disabled_reason
    FROM inventory_products p
    CROSS JOIN LATERAL check_product_full_availability(
        p.id, 
        p_require_in_stock, 
        p_require_sufficient_ingredients, 
        p_include_pending_procurement
    ) fa
    WHERE p.is_active = true;
END;
$$;

-- =============================================
-- 6. สร้าง View สำหรับดูสรุป availability ทั้งหมด
-- =============================================
CREATE OR REPLACE VIEW product_availability_summary AS
SELECT 
    p.id as product_id,
    p.name as product_name,
    p.category_id,
    c.name as category_name,
    p.price,
    p.cost,
    COALESCE(ss.total_quantity, 0) as current_stock,
    COALESCE(ss.batch_count, 0) as batch_count,
    ss.earliest_expiry,
    CASE 
        WHEN r.id IS NOT NULL THEN true 
        ELSE false 
    END as has_recipe,
    r.yield_quantity as recipe_yield,
    -- Pending procurement
    COALESCE((
        SELECT SUM(pol.quantity - COALESCE(pol.received_quantity, 0))
        FROM procurement_purchase_order_lines pol
        JOIN procurement_purchase_orders po ON pol.po_id = po.id
        WHERE pol.product_id = p.id AND po.status NOT IN ('completed', 'cancelled')
    ), 0) as pending_procurement_quantity
FROM inventory_products p
LEFT JOIN inventory_categories c ON p.category_id = c.id
LEFT JOIN inventory_stock_summary ss ON p.id = ss.item_id AND ss.item_type = 'product'
LEFT JOIN inventory_recipes r ON r.output_product_id = p.id
WHERE p.is_active = true;

-- =============================================
-- 7. Grant permissions
-- =============================================
-- ให้สิทธิ์ authenticated users เรียกใช้ functions
GRANT EXECUTE ON FUNCTION check_product_availability(UUID, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_procurement_quantity(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_recipe_ingredients_sufficient(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_product_full_availability(UUID, BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_products(BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated;
GRANT SELECT ON product_availability_summary TO authenticated;

-- =============================================
-- 8. Comments for documentation
-- =============================================
COMMENT ON FUNCTION check_product_availability IS 'ตรวจสอบว่าสินค้ามี stock พร้อมขายหรือไม่ (stock > 0)';
COMMENT ON FUNCTION check_recipe_ingredients_sufficient IS 'ตรวจสอบว่าวัตถุดิบในสูตรพอผลิตสินค้าได้มากกว่า 1 ชิ้นหรือไม่';
COMMENT ON FUNCTION check_product_full_availability IS 'ตรวจสอบสินค้าพร้อมขายแบบครบวงจร (stock + recipe + procurement)';
COMMENT ON FUNCTION get_available_products IS 'ดึงรายการสินค้าทั้งหมดพร้อมสถานะ availability';
COMMENT ON VIEW product_availability_summary IS 'View สรุปข้อมูล availability ของสินค้าทั้งหมด';
