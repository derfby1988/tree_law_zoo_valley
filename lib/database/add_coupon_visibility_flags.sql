-- ============================================================================
-- Coupon Visibility Flags
-- ============================================================================
-- วันที่สร้าง: 9 พฤษภาคม 2568
-- เป้าหมาย: เพิ่มการควบคุมการแสดงคูปองในแต่ละหน้า UI
-- ============================================================================

-- 1. เพิ่ม field ควบคุมการแสดงคูปอง
ALTER TABLE pos_discounts 
ADD COLUMN IF NOT EXISTS show_in_coupon_tab BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS show_in_pos_discount_dialog BOOLEAN DEFAULT false;

COMMENT ON COLUMN pos_discounts.show_in_coupon_tab IS 'แสดงคูปองในแถบคูปอง หน้าคูปอง & โปรโมชัน';
COMMENT ON COLUMN pos_discounts.show_in_pos_discount_dialog IS 'แสดงคูปองใน dialog เลือกส่วนลด หน้า POS';

-- 2. อัปเดตคูปองที่มีอยู่แล้วให้แสดงในทั้งสองที่ (backward compatibility)
-- ถ้าคูปองเป็น active และยังไม่ได้ตั้งค่า visibility ให้ตั้งค่าเป็น true ทั้งสอง
UPDATE pos_discounts 
SET show_in_coupon_tab = true,
    show_in_pos_discount_dialog = true
WHERE is_active = true 
  AND show_in_coupon_tab IS NULL 
  AND show_in_pos_discount_dialog IS NULL;

-- 3. Function สำหรับดึงคูปองที่แสดงในแถบคูปอง (หน้าคูปอง & โปรโมชัน)
CREATE OR REPLACE FUNCTION get_visible_coupons_for_coupon_tab(
    p_user_group_id UUID DEFAULT NULL
) RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    coupon_code TEXT,
    discount_type TEXT,
    discount_value NUMERIC,
    min_order_amount NUMERIC,
    max_discount_amount NUMERIC,
    start_at TIMESTAMP WITH TIME ZONE,
    end_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN,
    usage_limit INTEGER,
    current_usage INTEGER,
    qr_code TEXT,
    applicable_user_group_ids UUID[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.description,
        c.coupon_code,
        c.discount_type,
        c.discount_value,
        c.min_order_amount,
        c.max_discount_amount,
        c.start_at,
        c.end_at,
        c.is_active,
        c.usage_limit,
        c.current_usage,
        c.qr_code,
        c.applicable_user_group_ids
    FROM pos_discounts d
    WHERE d.show_in_coupon_tab = true
      AND d.is_active = true
      AND (d.start_at IS NULL OR d.start_at <= NOW())
      AND (d.end_at IS NULL OR d.end_at >= NOW())
      AND (d.usage_limit IS NULL OR d.used_count < d.usage_limit)
      AND (
          p_user_group_id IS NULL 
          OR d.customer_group_id IS NULL 
          OR d.customer_group_id = p_user_group_id::TEXT
      )
    ORDER BY d.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_visible_coupons_for_coupon_tab IS 'ดึงคูปองที่แสดงในแถบคูปอง (หน้าคูปอง & โปรโมชัน) พร้อม filter ตาม user group';

-- 4. Function สำหรับดึงคูปองที่แสดงใน POS discount dialog
CREATE OR REPLACE FUNCTION get_visible_coupons_for_pos(
    p_user_group_id UUID DEFAULT NULL
) RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    coupon_code TEXT,
    discount_type TEXT,
    discount_value NUMERIC,
    min_order_amount NUMERIC,
    max_discount_amount NUMERIC,
    start_at TIMESTAMP WITH TIME ZONE,
    end_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN,
    usage_limit INTEGER,
    current_usage INTEGER,
    qr_code TEXT,
    applicable_user_group_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.name,
        d.description,
        d.coupon_code,
        d.discount_type,
        d.value AS discount_value,
        d.min_amount AS min_order_amount,
        d.max_discount AS max_discount_amount,
        d.start_at,
        d.end_at,
        d.is_active,
        d.usage_limit,
        d.used_count AS current_usage,
        d.qr_code,
        d.customer_group_id AS applicable_user_group_id
    FROM pos_discounts d
    WHERE d.show_in_pos_discount_dialog = true
      AND d.is_active = true
      AND (d.start_at IS NULL OR d.start_at <= NOW())
      AND (d.end_at IS NULL OR d.end_at >= NOW())
      AND (d.usage_limit IS NULL OR d.used_count < d.usage_limit)
      AND (
          p_user_group_id IS NULL 
          OR d.customer_group_id IS NULL 
          OR d.customer_group_id = p_user_group_id::TEXT
      )
    ORDER BY d.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_visible_coupons_for_pos IS 'ดึงคูปองที่แสดงใน dialog เลือกส่วนลด หน้า POS พร้อม filter ตาม user group';

-- ============================================================================
-- สรุป: เพิ่มควบคุมการแสดงคูปอง
-- ============================================================================
-- ✅ pos_discounts: เพิ่ม show_in_coupon_tab, show_in_pos_discount_dialog
-- ✅ Functions: get_visible_coupons_for_coupon_tab, get_visible_coupons_for_pos
-- ============================================================================
