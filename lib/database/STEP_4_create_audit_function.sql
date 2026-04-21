-- =============================================
-- STEP 4: Create Audit Trail Function
-- =============================================
-- รันใน Supabase SQL Editor
-- ⏱️ เวลา: ~10 วินาที

CREATE OR REPLACE FUNCTION get_production_audit_trail(
  p_recipe_id UUID
)
RETURNS TABLE (
  production_date TIMESTAMPTZ,
  batch_quantity INT,
  yield_quantity DOUBLE PRECISION,
  user_name TEXT,
  ingredient_adjustments JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pl.created_at,
    pl.batch_quantity,
    pl.yield_quantity,
    pl.user_name,
    jsonb_agg(
      jsonb_build_object(
        'product_name', p.name,
        'quantity_before', ia.quantity_before,
        'quantity_after', ia.quantity_after,
        'quantity_change', ia.quantity_change,
        'adjustment_type', ia.type
      )
    ) as ingredient_adjustments
  FROM inventory_production_logs pl
  LEFT JOIN inventory_adjustments ia ON ia.reference_id = pl.recipe_id
  LEFT JOIN inventory_products p ON p.id = ia.product_id
  WHERE pl.recipe_id = p_recipe_id
  GROUP BY pl.id, pl.created_at, pl.batch_quantity, pl.yield_quantity, pl.user_name
  ORDER BY pl.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ✅ ทดสอบ
-- SELECT * FROM get_production_audit_trail('recipe_id_here');
