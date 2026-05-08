-- ============================================================================
-- QR Code Support for Coupons
-- ============================================================================
-- วันที่สร้าง: 8 พฤษภาคม 2568
-- เป้าหมาย: เพิ่ม QR Code support สำหรับคูปองพร้อม validation และ scan logs
-- ============================================================================

-- 1. เพิ่ม field qr_code ในตาราง pos_discounts
ALTER TABLE pos_discounts 
ADD COLUMN IF NOT EXISTS qr_code TEXT,
ADD COLUMN IF NOT EXISTS qr_signature TEXT,
ADD COLUMN IF NOT EXISTS qr_generated_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN pos_discounts.qr_code IS 'QR Code content (base64 JSON)';
COMMENT ON COLUMN pos_discounts.qr_signature IS 'HMAC signature สำหรับตรวจสอบความถูกต้อง';
COMMENT ON COLUMN pos_discounts.qr_generated_at IS 'เวลาที่สร้าง QR Code';

-- 2. สร้างตารางเก็บประวัติการ scan QR Code
CREATE TABLE IF NOT EXISTS pos_coupon_qr_scan_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coupon_id UUID NOT NULL REFERENCES pos_discounts(id) ON DELETE CASCADE,
    order_id UUID REFERENCES pos_orders(id) ON DELETE SET NULL,
    scanned_by UUID REFERENCES users(id),
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    scan_status VARCHAR(50) NOT NULL, -- 'valid', 'invalid', 'expired', 'used', 'limit_exceeded'
    scan_device_info TEXT, -- ข้อมูลอุปกรณ์ที่ใช้ scan
    qr_content JSONB, -- ข้อมูล QR ที่ scan ได้
    validation_result JSONB, -- ผลการตรวจสอบแบบละเอียด
    error_message TEXT, -- ข้อความ error ถ้ามี
    client_ip INET,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE pos_coupon_qr_scan_logs IS 'ประวัติการ scan QR Code ของคูปอง';

-- 3. Indexes สำหรับตาราง scan logs
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_coupon_id ON pos_coupon_qr_scan_logs(coupon_id);
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_order_id ON pos_coupon_qr_scan_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_scanned_at ON pos_coupon_qr_scan_logs(scanned_at);
CREATE INDEX IF NOT EXISTS idx_qr_scan_logs_status ON pos_coupon_qr_scan_logs(scan_status);

-- 4. Function สำหรับสร้าง QR signature (HMAC-SHA256)
-- ใช้ pgcrypto extension ถ้ามี ไม่มีค่าใช้จ่ายเพิ่ม
CREATE OR REPLACE FUNCTION generate_coupon_qr_signature(
    p_coupon_id UUID,
    p_coupon_code TEXT,
    p_expiry_date DATE,
    p_secret_key TEXT DEFAULT 'tlz_coupon_secret_2026'
) RETURNS TEXT AS $$
DECLARE
    v_payload TEXT;
    v_signature TEXT;
BEGIN
    -- สร้าง payload จากข้อมูลสำคัญ
    v_payload := p_coupon_id::TEXT || '|' || 
                 COALESCE(p_coupon_code, '') || '|' || 
                 COALESCE(p_expiry_date::TEXT, '');
    
    -- ใช้ HMAC-SHA256 ถ้ามี pgcrypto ไม่มีก็ใช้ simple hash
    BEGIN
        SELECT encode(hmac(v_payload, p_secret_key, 'sha256'), 'hex') INTO v_signature
        FROM pg_available_extensions WHERE name = 'pgcrypto';
    EXCEPTION WHEN OTHERS THEN
        -- Fallback: ใช้ MD5 ถ้าไม่มี pgcrypto (ไม่ secure แต่ใช้ได้ชั่วคราว)
        v_signature := md5(v_payload || p_secret_key);
    END;
    
    RETURN v_signature;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_coupon_qr_signature IS 'สร้าง HMAC signature สำหรับ QR Code validation';

-- 5. Function สำหรับตรวจสอบ QR signature
CREATE OR REPLACE FUNCTION validate_coupon_qr_signature(
    p_coupon_id UUID,
    p_coupon_code TEXT,
    p_expiry_date DATE,
    p_signature TEXT,
    p_secret_key TEXT DEFAULT 'tlz_coupon_secret_2026'
) RETURNS BOOLEAN AS $$
DECLARE
    v_expected_signature TEXT;
BEGIN
    v_expected_signature := generate_coupon_qr_signature(p_coupon_id, p_coupon_code, p_expiry_date, p_secret_key);
    RETURN v_expected_signature = p_signature;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_coupon_qr_signature IS 'ตรวจสอบความถูกต้องของ QR signature';

-- 6. Function สำหรับ validate QR Code แบบครบวงจร
CREATE OR REPLACE FUNCTION validate_coupon_by_qr(
    p_qr_json JSONB,
    p_scanned_by UUID DEFAULT NULL,
    p_order_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_coupon_id UUID;
    v_coupon_code TEXT;
    v_signature TEXT;
    v_expiry TEXT;
    v_result JSONB;
    v_coupon RECORD;
    v_scan_status TEXT;
    v_error_msg TEXT;
BEGIN
    -- Extract data from QR
    v_coupon_id := (p_qr_json->>'discount_id')::UUID;
    v_coupon_code := p_qr_json->>'code';
    v_signature := p_qr_json->>'sig';
    v_expiry := p_qr_json->>'exp';
    
    -- Default result
    v_result := jsonb_build_object(
        'valid', false,
        'coupon_id', v_coupon_id,
        'code', v_coupon_code
    );
    
    -- Check 1: Coupon exists
    SELECT * INTO v_coupon FROM pos_discounts WHERE id = v_coupon_id;
    IF v_coupon IS NULL THEN
        v_scan_status := 'invalid';
        v_error_msg := 'ไม่พบคูปองในระบบ';
        
        -- Log scan
        INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 2: Signature valid
    IF NOT validate_coupon_qr_signature(v_coupon_id, v_coupon_code, v_expiry::DATE, v_signature) THEN
        v_scan_status := 'invalid';
        v_error_msg := 'QR Code ไม่ถูกต้อง (signature mismatch)';
        
        INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 3: Coupon code match
    IF v_coupon.coupon_code IS DISTINCT FROM v_coupon_code THEN
        v_scan_status := 'invalid';
        v_error_msg := 'รหัสคูปองไม่ตรงกัน';
        
        INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 4: Active status
    IF NOT v_coupon.is_active OR v_coupon.lifecycle_status NOT IN ('active', 'scheduled') THEN
        v_scan_status := 'invalid';
        v_error_msg := 'คูปองไม่อยู่ในสถานะใช้งาน (' || v_coupon.lifecycle_status || ')';
        
        INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 5: Date valid
    IF v_coupon.end_at IS NOT NULL AND v_coupon.end_at < NOW() THEN
        v_scan_status := 'expired';
        v_error_msg := 'คูปองหมดอายุแล้ว';
        
        INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    IF v_coupon.start_at IS NOT NULL AND v_coupon.start_at > NOW() THEN
        v_scan_status := 'invalid';
        v_error_msg := 'คูปองยังไม่เริ่มใช้งาน';
        
        INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 6: Usage limit
    IF v_coupon.usage_limit IS NOT NULL AND v_coupon.used_count >= v_coupon.usage_limit THEN
        v_scan_status := 'limit_exceeded';
        v_error_msg := 'คูปองใช้ครบจำนวนที่กำหนดแล้ว';
        
        INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- All checks passed
    v_scan_status := 'valid';
    v_result := jsonb_build_object(
        'valid', true,
        'coupon_id', v_coupon_id,
        'code', v_coupon_code,
        'name', v_coupon.name,
        'discount_type', v_coupon.discount_type,
        'value', v_coupon.value,
        'status', v_scan_status
    );
    
    -- Log successful scan
    INSERT INTO pos_coupon_qr_scan_logs (coupon_id, order_id, scanned_by, scan_status, qr_content, validation_result)
    VALUES (v_coupon_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result);
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_coupon_by_qr IS 'Validate QR Code แบบครบวงจร พร้อมบันทึก log';

-- 7. Trigger สำหรับ auto-generate QR Code เมื่อสร้าง/อัปเดตคูปอง
CREATE OR REPLACE FUNCTION auto_generate_coupon_qr()
RETURNS TRIGGER AS $$
DECLARE
    v_qr_json JSONB;
    v_signature TEXT;
BEGIN
    -- Generate QR content only if coupon has code
    IF NEW.coupon_code IS NOT NULL AND NEW.coupon_code != '' THEN
        v_signature := generate_coupon_qr_signature(
            NEW.id, 
            NEW.coupon_code, 
            NEW.end_at::DATE
        );
        
        v_qr_json := jsonb_build_object(
            'v', 1,
            'type', 'tlz_coupon',
            'code', NEW.coupon_code,
            'discount_id', NEW.id,
            'exp', NEW.end_at::DATE,
            'sig', v_signature
        );
        
        NEW.qr_code := v_qr_json::TEXT;
        NEW.qr_signature := v_signature;
        NEW.qr_generated_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_generate_coupon_qr ON pos_discounts;

CREATE TRIGGER trg_auto_generate_coupon_qr
    BEFORE INSERT OR UPDATE OF coupon_code, end_at, is_active
    ON pos_discounts
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_coupon_qr();

-- 8. View สำหรับดู QR scan analytics
CREATE OR REPLACE VIEW coupon_qr_scan_analytics AS
SELECT 
    d.id AS coupon_id,
    d.name AS coupon_name,
    d.coupon_code,
    COUNT(DISTINCT s.id) AS total_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'valid' THEN s.id END) AS valid_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'invalid' THEN s.id END) AS invalid_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'expired' THEN s.id END) AS expired_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'used' THEN s.id END) AS used_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'limit_exceeded' THEN s.id END) AS limit_exceeded_scans,
    MAX(s.scanned_at) AS last_scan_at
FROM pos_discounts d
LEFT JOIN pos_coupon_qr_scan_logs s ON d.id = s.coupon_id
WHERE d.coupon_code IS NOT NULL
GROUP BY d.id, d.name, d.coupon_code;

-- 9. สร้าง RLS policies สำหรับตาราง scan logs
ALTER TABLE pos_coupon_qr_scan_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for authenticated users" 
ON pos_coupon_qr_scan_logs FOR SELECT 
TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" 
ON pos_coupon_qr_scan_logs FOR INSERT 
TO authenticated WITH CHECK (true);

-- ============================================================================
-- สรุป: เพิ่มฟีเจอร์ QR Code สำหรับคูปอง
-- ============================================================================
-- ✅ pos_discounts: เพิ่ม qr_code, qr_signature, qr_generated_at
-- ✅ pos_coupon_qr_scan_logs: ตารางเก็บประวัติการ scan
-- ✅ Functions: generate_coupon_qr_signature, validate_coupon_qr_signature, validate_coupon_by_qr
-- ✅ Trigger: auto_generate_coupon_qr (สร้าง QR อัตโนมัติ)
-- ✅ View: coupon_qr_scan_analytics (วิเคราะห์การใช้งาน)
-- ✅ RLS policies: ป้องกันข้อมูล
-- ============================================================================
