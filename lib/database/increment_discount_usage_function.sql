-- =============================================
-- Increment Discount Usage Function
-- =============================================
-- Function to increment used_count when a discount is used
-- Called by PosDiscountService.recordDiscountUsage()

CREATE OR REPLACE FUNCTION increment_discount_usage(p_discount_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE pos_discounts 
    SET used_count = used_count + 1,
        updated_at = now()
    WHERE id = p_discount_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION increment_discount_usage(UUID) TO authenticated;
