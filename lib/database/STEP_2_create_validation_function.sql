-- =============================================
-- STEP 2: Create Validation Function
-- =============================================
-- รันใน Supabase SQL Editor
-- ⏱️ เวลา: ~10 วินาที

CREATE OR REPLACE FUNCTION check_recipe_can_produce(
  p_recipe_id UUID,
  p_batch_quantity INT DEFAULT 1
)
RETURNS TABLE (
  can_produce BOOLEAN,
  missing_ingredients JSONB
) AS $$
DECLARE
  v_missing JSONB := '[]'::JSONB;
  v_ingredient RECORD;
  v_current_qty DOUBLE PRECISION;
  v_total_needed DOUBLE PRECISION;
BEGIN
  -- Check each ingredient
  FOR v_ingredient IN
    SELECT 
      p.id,
      p.name,
      ri.quantity,
      p.quantity as current_stock
    FROM inventory_recipe_ingredients ri
    JOIN inventory_products p ON p.id = ri.product_id
    WHERE ri.recipe_id = p_recipe_id
  LOOP
    v_total_needed := v_ingredient.quantity * p_batch_quantity;
    v_current_qty := v_ingredient.current_stock;
    
    IF v_current_qty < v_total_needed THEN
      v_missing := v_missing || jsonb_build_object(
        'product_id', v_ingredient.id::TEXT,
        'product_name', v_ingredient.name,
        'needed', v_total_needed,
        'current', v_current_qty,
        'shortage', v_total_needed - v_current_qty
      );
    END IF;
  END LOOP;
  
  RETURN QUERY SELECT 
    (v_missing = '[]'::JSONB)::BOOLEAN,
    v_missing;
END;
$$ LANGUAGE plpgsql;

-- ✅ ทดสอบ
-- SELECT * FROM check_recipe_can_produce('recipe_id_here', 1);
