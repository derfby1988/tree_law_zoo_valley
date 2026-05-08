-- ============================================================================
-- QR Code Support for Promotions
-- ============================================================================
-- วันที่สร้าง: 8 พฤษภาคม 2568
-- เป้าหมาย: เพิ่ม QR Code support สำหรับโปรโมชันทุกประเภท
-- ============================================================================

-- 1. เพิ่ม field qr_code ในตาราง pos_promotions
ALTER TABLE pos_promotions 
ADD COLUMN IF NOT EXISTS qr_code TEXT,
ADD COLUMN IF NOT EXISTS qr_signature TEXT,
ADD COLUMN IF NOT EXISTS qr_generated_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN pos_promotions.qr_code IS 'QR Code content (JSON สำหรับโปรโมชัน)';
COMMENT ON COLUMN pos_promotions.qr_signature IS 'HMAC signature สำหรับตรวจสอบความถูกต้อง';
COMMENT ON COLUMN pos_promotions.qr_generated_at IS 'เวลาที่สร้าง QR Code';

-- 2. สร้างตารางเก็บประวัติการ scan QR Code สำหรับโปรโมชัน
CREATE TABLE IF NOT EXISTS pos_promotion_qr_scan_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES pos_promotions(id) ON DELETE CASCADE,
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

COMMENT ON TABLE pos_promotion_qr_scan_logs IS 'ประวัติการ scan QR Code ของโปรโมชัน';

-- 3. Indexes สำหรับตาราง scan logs
CREATE INDEX IF NOT EXISTS idx_promotion_qr_scan_logs_promotion_id ON pos_promotion_qr_scan_logs(promotion_id);
CREATE INDEX IF NOT EXISTS idx_promotion_qr_scan_logs_order_id ON pos_promotion_qr_scan_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_promotion_qr_scan_logs_scanned_at ON pos_promotion_qr_scan_logs(scanned_at);
CREATE INDEX IF NOT EXISTS idx_promotion_qr_scan_logs_status ON pos_promotion_qr_scan_logs(scan_status);

-- 4. Function สำหรับสร้าง QR signature สำหรับโปรโมชัน (HMAC-SHA256)
CREATE OR REPLACE FUNCTION generate_promotion_qr_signature(
    p_promotion_id UUID,
    p_promotion_code TEXT,
    p_expiry_date DATE,
    p_secret_key TEXT DEFAULT 'tlz_promotion_secret_2026'
) RETURNS TEXT AS $$
DECLARE
    v_payload TEXT;
    v_signature TEXT;
BEGIN
    -- สร้าง payload จากข้อมูลสำคัญ
    v_payload := p_promotion_id::TEXT || '|' || 
                 COALESCE(p_promotion_code, '') || '|' || 
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

COMMENT ON FUNCTION generate_promotion_qr_signature IS 'สร้าง HMAC signature สำหรับ Promotion QR Code validation';

-- 5. Function สำหรับตรวจสอบ QR signature ของโปรโมชัน
CREATE OR REPLACE FUNCTION validate_promotion_qr_signature(
    p_promotion_id UUID,
    p_promotion_code TEXT,
    p_expiry_date DATE,
    p_signature TEXT,
    p_secret_key TEXT DEFAULT 'tlz_promotion_secret_2026'
) RETURNS BOOLEAN AS $$
DECLARE
    v_expected_signature TEXT;
BEGIN
    v_expected_signature := generate_promotion_qr_signature(p_promotion_id, p_promotion_code, p_expiry_date, p_secret_key);
    RETURN v_expected_signature = p_signature;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_promotion_qr_signature IS 'ตรวจสอบความถูกต้องของ Promotion QR signature';

-- 6. Function สำหรับ validate QR Code แบบครบวงจรสำหรับโปรโมชัน
CREATE OR REPLACE FUNCTION validate_promotion_by_qr(
    p_qr_json JSONB,
    p_scanned_by UUID DEFAULT NULL,
    p_order_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_promotion_id UUID;
    v_promotion_code TEXT;
    v_signature TEXT;
    v_expiry TEXT;
    v_result JSONB;
    v_promotion RECORD;
    v_scan_status TEXT;
    v_error_msg TEXT;
BEGIN
    -- Extract data from QR
    v_promotion_id := (p_qr_json->>'promotion_id')::UUID;
    v_promotion_code := p_qr_json->>'code';
    v_signature := p_qr_json->>'sig';
    v_expiry := p_qr_json->>'exp';
    
    -- Default result
    v_result := jsonb_build_object(
        'valid', false,
        'promotion_id', v_promotion_id,
        'code', v_promotion_code
    );
    
    -- Check 1: Promotion exists
    SELECT * INTO v_promotion FROM pos_promotions WHERE id = v_promotion_id;
    IF v_promotion IS NULL THEN
        v_scan_status := 'invalid';
        v_error_msg := 'ไม่พบโปรโมชันในระบบ';
        
        -- Log scan
        INSERT INTO pos_promotion_qr_scan_logs (promotion_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_promotion_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 2: Signature valid
    IF NOT validate_promotion_qr_signature(v_promotion_id, v_promotion_code, v_expiry::DATE, v_signature) THEN
        v_scan_status := 'invalid';
        v_error_msg := 'QR Code ไม่ถูกต้อง (signature mismatch)';
        
        INSERT INTO pos_promotion_qr_scan_logs (promotion_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_promotion_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 3: Active status
    IF NOT v_promotion.is_active OR v_promotion.lifecycle_status NOT IN ('active', 'scheduled') THEN
        v_scan_status := 'invalid';
        v_error_msg := 'โปรโมชันไม่อยู่ในสถานะใช้งาน (' || v_promotion.lifecycle_status || ')';
        
        INSERT INTO pos_promotion_qr_scan_logs (promotion_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_promotion_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- Check 4: Date valid
    IF v_promotion.end_at IS NOT NULL AND v_promotion.end_at < NOW() THEN
        v_scan_status := 'expired';
        v_error_msg := 'โปรโมชันหมดอายุแล้ว';
        
        INSERT INTO pos_promotion_qr_scan_logs (promotion_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_promotion_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    IF v_promotion.start_at IS NOT NULL AND v_promotion.start_at > NOW() THEN
        v_scan_status := 'invalid';
        v_error_msg := 'โปรโมชันยังไม่เริ่มใช้งาน';
        
        INSERT INTO pos_promotion_qr_scan_logs (promotion_id, order_id, scanned_by, scan_status, qr_content, validation_result, error_message)
        VALUES (v_promotion_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result, v_error_msg);
        
        RETURN v_result || jsonb_build_object('error', v_error_msg, 'status', v_scan_status);
    END IF;
    
    -- All checks passed
    v_scan_status := 'valid';
    v_result := jsonb_build_object(
        'valid', true,
        'promotion_id', v_promotion_id,
        'code', v_promotion_code,
        'name', v_promotion.name,
        'promotion_type', v_promotion.promotion_type,
        'status', v_scan_status
    );
    
    -- Log successful scan
    INSERT INTO pos_promotion_qr_scan_logs (promotion_id, order_id, scanned_by, scan_status, qr_content, validation_result)
    VALUES (v_promotion_id, p_order_id, p_scanned_by, v_scan_status, p_qr_json, v_result);
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_promotion_by_qr IS 'Validate Promotion QR Code แบบครบวงจร พร้อมบันทึก log';

-- 7. Trigger สำหรับ auto-generate QR Code เมื่อสร้าง/อัปเดตโปรโมชัน
CREATE OR REPLACE FUNCTION auto_generate_promotion_qr()
RETURNS TRIGGER AS $$
DECLARE
    v_qr_json JSONB;
    v_signature TEXT;
    v_promotion_code TEXT;
BEGIN
    -- Generate unique promotion code from ID if not exists
    v_promotion_code := COALESCE(
        NEW.code,
        'PROMO_' || substring(NEW.id::TEXT, 1, 8)
    );
    
    -- Generate QR content
    v_signature := generate_promotion_qr_signature(
        NEW.id, 
        v_promotion_code, 
        NEW.end_at::DATE
    );
    
    v_qr_json := jsonb_build_object(
        'v', 1,
        'type', 'tlz_promotion',
        'code', v_promotion_code,
        'promotion_id', NEW.id,
        'promotion_type', NEW.promotion_type,
        'exp', NEW.end_at::DATE,
        'sig', v_signature
    );
    
    NEW.qr_code := v_qr_json::TEXT;
    NEW.qr_signature := v_signature;
    NEW.qr_generated_at := NOW();
    
    -- Update code field if it was null
    IF NEW.code IS NULL THEN
        NEW.code := v_promotion_code;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_generate_promotion_qr ON pos_promotions;

CREATE TRIGGER trg_auto_generate_promotion_qr
    BEFORE INSERT OR UPDATE OF end_at, is_active, promotion_type
    ON pos_promotions
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_promotion_qr();

-- 10. เพิ่ม field code ใน pos_promotions ถ้ายังไม่มี
-- ใช้สำหรับเก็บรหัสโปรโมชันที่สั้นกว่า ID (เหมือน coupon_code)
ALTER TABLE pos_promotions 
ADD COLUMN IF NOT EXISTS code TEXT UNIQUE;

-- 8. View สำหรับดู QR scan analytics ของโปรโมชัน
CREATE OR REPLACE VIEW promotion_qr_scan_analytics AS
SELECT 
    p.id AS promotion_id,
    p.name AS promotion_name,
    p.code AS promotion_code,
    COUNT(DISTINCT s.id) AS total_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'valid' THEN s.id END) AS valid_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'invalid' THEN s.id END) AS invalid_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'expired' THEN s.id END) AS expired_scans,
    COUNT(DISTINCT CASE WHEN s.scan_status = 'used' THEN s.id END) AS used_scans,
    MAX(s.scanned_at) AS last_scan_at
FROM pos_promotions p
LEFT JOIN pos_promotion_qr_scan_logs s ON p.id = s.promotion_id
WHERE p.qr_code IS NOT NULL
GROUP BY p.id, p.name, p.code;

-- 9. สร้าง RLS policies สำหรับตาราง scan logs
ALTER TABLE pos_promotion_qr_scan_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for authenticated users" 
ON pos_promotion_qr_scan_logs FOR SELECT 
TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" 
ON pos_promotion_qr_scan_logs FOR INSERT 
TO authenticated WITH CHECK (true);

-- ============================================================================
-- สรุป: เพิ่มฟีเจอร์ QR Code สำหรับโปรโมชัน
-- ============================================================================
-- ✅ pos_promotions: เพิ่ม qr_code, qr_signature, qr_generated_at, code
-- ✅ pos_promotion_qr_scan_logs: ตารางเก็บประวัติการ scan (แยกจากคูปอง)
-- ✅ Functions: generate_promotion_qr_signature, validate_promotion_qr_signature, validate_promotion_by_qr
-- ✅ Trigger: auto_generate_promotion_qr (สร้าง QR อัตโนมัติ)
-- ✅ View: promotion_qr_scan_analytics (วิเคราะห์การใช้งาน)
-- ✅ RLS policies: ป้องกันข้อมูล
-- ============================================================================
