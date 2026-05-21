-- ============================================================================
-- Daily Coupon Share Tokens (Phase 13 - P0)
-- ============================================================================
-- โครงสร้างสำหรับ share token ของคูปองรายวันแบบรวมสิทธิ์
-- เก็บ token, expiry, จำนวนสิทธิ์ที่ใช้ได้ และข้อมูลสำหรับ group coupon
-- ============================================================================

CREATE TABLE IF NOT EXISTS daily_coupon_share_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    discount_id UUID NOT NULL REFERENCES pos_discounts(id) ON DELETE CASCADE,
    coupon_code TEXT NOT NULL,
    coupon_audience TEXT NOT NULL DEFAULT 'group',
    share_token TEXT NOT NULL UNIQUE,
    group_size INT NOT NULL DEFAULT 2,
    max_uses INT NOT NULL DEFAULT 2,
    uses_count INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    last_used_at TIMESTAMPTZ,
    last_used_member_identifier TEXT,
    last_used_channel TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (group_size >= 2),
    CHECK (max_uses >= group_size),
    CHECK (uses_count >= 0)
);

ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS coupon_code TEXT;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS coupon_audience TEXT DEFAULT 'group';
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS share_token TEXT;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS group_size INT DEFAULT 2;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS max_uses INT DEFAULT 2;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS uses_count INT DEFAULT 0;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS revoked_reason TEXT;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS last_used_member_identifier TEXT;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS last_used_channel TEXT;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS updated_by UUID;
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS daily_coupon_share_tokens ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_daily_coupon_share_tokens_discount ON daily_coupon_share_tokens(discount_id);
CREATE INDEX IF NOT EXISTS idx_daily_coupon_share_tokens_token ON daily_coupon_share_tokens(share_token);
CREATE INDEX IF NOT EXISTS idx_daily_coupon_share_tokens_expires_at ON daily_coupon_share_tokens(expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_daily_coupon_share_tokens_revoked_at ON daily_coupon_share_tokens(revoked_at);

COMMENT ON TABLE daily_coupon_share_tokens IS 'โทเคนสำหรับแชร์คูปองรายวันแบบรวมสิทธิ์';
COMMENT ON COLUMN daily_coupon_share_tokens.share_token IS 'token ที่ใช้แชร์ให้สมาชิกในคูปองรายกลุ่ม';
COMMENT ON COLUMN daily_coupon_share_tokens.group_size IS 'จำนวนสมาชิกของคูปองรายกลุ่ม';
COMMENT ON COLUMN daily_coupon_share_tokens.max_uses IS 'จำนวนครั้งสูงสุดที่ token นี้ใช้ได้';

CREATE OR REPLACE FUNCTION get_active_daily_coupon_share_token(p_discount_id UUID)
RETURNS daily_coupon_share_tokens
LANGUAGE plpgsql
AS $$
DECLARE
    v_token daily_coupon_share_tokens;
BEGIN
    SELECT *
    INTO v_token
    FROM daily_coupon_share_tokens
    WHERE discount_id = p_discount_id
      AND revoked_at IS NULL
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;

    RETURN v_token;
END;
$$;

CREATE OR REPLACE FUNCTION create_or_refresh_daily_coupon_share_token(
    p_discount_id UUID,
    p_coupon_code TEXT,
    p_coupon_audience TEXT DEFAULT 'group',
    p_group_size INT DEFAULT 2,
    p_expires_at TIMESTAMPTZ DEFAULT NULL,
    p_created_by UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_force_new BOOLEAN DEFAULT FALSE
)
RETURNS daily_coupon_share_tokens
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing daily_coupon_share_tokens;
    v_group_size INT := GREATEST(COALESCE(p_group_size, 2), 2);
    v_max_uses INT := GREATEST(COALESCE(p_group_size, 2), 2);
    v_expires_at TIMESTAMPTZ := COALESCE(p_expires_at, NOW() + INTERVAL '1 day');
    v_token TEXT;
BEGIN
    SELECT *
    INTO v_existing
    FROM daily_coupon_share_tokens
    WHERE discount_id = p_discount_id
      AND revoked_at IS NULL
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND AND NOT p_force_new THEN
        UPDATE daily_coupon_share_tokens
        SET coupon_code = p_coupon_code,
            coupon_audience = COALESCE(p_coupon_audience, 'group'),
            group_size = v_group_size,
            max_uses = v_max_uses,
            expires_at = v_expires_at,
            updated_by = p_created_by,
            metadata = COALESCE(metadata, '{}'::jsonb) || COALESCE(p_metadata, '{}'::jsonb),
            updated_at = NOW()
        WHERE id = v_existing.id
        RETURNING * INTO v_existing;

        RETURN v_existing;
    END IF;

    v_token := 'TLZ-SH-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::text, '-', '') FROM 1 FOR 16));

    INSERT INTO daily_coupon_share_tokens (
        discount_id,
        coupon_code,
        coupon_audience,
        share_token,
        group_size,
        max_uses,
        uses_count,
        expires_at,
        created_by,
        updated_by,
        metadata
    ) VALUES (
        p_discount_id,
        p_coupon_code,
        COALESCE(p_coupon_audience, 'group'),
        v_token,
        v_group_size,
        v_max_uses,
        0,
        v_expires_at,
        p_created_by,
        p_created_by,
        COALESCE(p_metadata, '{}'::jsonb)
    )
    RETURNING * INTO v_existing;

    RETURN v_existing;
END;
$$;

CREATE OR REPLACE FUNCTION consume_daily_coupon_share_token(
    p_share_token TEXT,
    p_member_identifier TEXT DEFAULT NULL,
    p_channel TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS daily_coupon_share_tokens
LANGUAGE plpgsql
AS $$
DECLARE
    v_token daily_coupon_share_tokens;
BEGIN
    UPDATE daily_coupon_share_tokens
    SET uses_count = uses_count + 1,
        last_used_at = NOW(),
        last_used_member_identifier = p_member_identifier,
        last_used_channel = p_channel,
        metadata = COALESCE(metadata, '{}'::jsonb) || COALESCE(p_metadata, '{}'::jsonb),
        updated_at = NOW(),
        revoked_at = CASE WHEN uses_count + 1 >= max_uses THEN NOW() ELSE revoked_at END,
        revoked_reason = CASE WHEN uses_count + 1 >= max_uses THEN 'MAX_USES_REACHED' ELSE revoked_reason END
    WHERE id = (
        SELECT id
        FROM daily_coupon_share_tokens
        WHERE share_token = p_share_token
          AND revoked_at IS NULL
          AND expires_at > NOW()
          AND uses_count < max_uses
        ORDER BY created_at DESC
        LIMIT 1
    )
    RETURNING * INTO v_token;

    IF NOT FOUND THEN
        IF EXISTS (
            SELECT 1
            FROM daily_coupon_share_tokens
            WHERE share_token = p_share_token
        ) THEN
            RAISE EXCEPTION 'Share token exhausted or expired';
        END IF;

        RAISE EXCEPTION 'Share token not found';
    END IF;

    RETURN v_token;
END;
$$;
