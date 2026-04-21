-- =============================================
-- Production Transaction & Validation
-- =============================================

-- 1. Add CHECK constraint to prevent negative quantity
ALTER TABLE inventory_products
ADD CONSTRAINT check_quantity_not_negative
CHECK (quantity >= 0);

ALTER TABLE inventory_ingredients
ADD CONSTRAINT check_ingredient_quantity_not_negative
CHECK (quantity >= 0);

-- 2. Create production transaction function
CREATE OR REPLACE FUNCTION produce_from_recipe(
  p_recipe_id UUID,
  p_batch_quantity INT,
  p_ingredients JSONB,
  p_output_product_id UUID DEFAULT NULL,
  p_user_name TEXT DEFAULT 'ระบบ'
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  production_log_id UUID
) AS $$
DECLARE
  v_ingredient JSONB;
  v_product_id UUID;
  v_qty_per_batch DOUBLE PRECISION;
  v_total_deduct DOUBLE PRECISION;
  v_current_qty DOUBLE PRECISION;
  v_new_qty DOUBLE PRECISION;
  v_output_current_qty DOUBLE PRECISION;
  v_output_new_qty DOUBLE PRECISION;
  v_yield_quantity DOUBLE PRECISION;
  v_production_log_id UUID;
  v_error_message TEXT;
BEGIN
  -- =============================================
  -- Step 1: Validate all ingredients have enough stock
  -- =============================================
  FOR v_ingredient IN SELECT jsonb_array_elements(p_ingredients)
  LOOP
    v_product_id := (v_ingredient->>'product_id')::UUID;
    v_qty_per_batch := (v_ingredient->>'quantity')::DOUBLE PRECISION;
    v_total_deduct := v_qty_per_batch * p_batch_quantity;
    
    -- Get current stock
    SELECT quantity INTO v_current_qty
    FROM inventory_products
    WHERE id = v_product_id;
    
    IF v_current_qty IS NULL THEN
      RETURN QUERY SELECT 
        false::BOOLEAN,
        'สินค้า ID ' || v_product_id::TEXT || ' ไม่พบในระบบ'::TEXT,
        NULL::UUID;
      RETURN;
    END IF;
    
    -- Validate stock is enough
    IF v_current_qty < v_total_deduct THEN
      RETURN QUERY SELECT 
        false::BOOLEAN,
        'สต็อกไม่พอ: ต้อง ' || v_total_deduct::TEXT || ' แต่มีแค่ ' || v_current_qty::TEXT::TEXT,
        NULL::UUID;
      RETURN;
    END IF;
  END LOOP;

  -- =============================================
  -- Step 2: Deduct ingredient stock
  -- =============================================
  FOR v_ingredient IN SELECT jsonb_array_elements(p_ingredients)
  LOOP
    v_product_id := (v_ingredient->>'product_id')::UUID;
    v_qty_per_batch := (v_ingredient->>'quantity')::DOUBLE PRECISION;
    v_total_deduct := v_qty_per_batch * p_batch_quantity;
    
    -- Get current stock again (for audit trail)
    SELECT quantity INTO v_current_qty
    FROM inventory_products
    WHERE id = v_product_id;
    
    v_new_qty := v_current_qty - v_total_deduct;
    
    -- Update product quantity
    UPDATE inventory_products
    SET 
      quantity = v_new_qty,
      updated_at = now()
    WHERE id = v_product_id;
    
    -- Record adjustment
    INSERT INTO inventory_adjustments (
      product_id,
      type,
      quantity_before,
      quantity_after,
      quantity_change,
      reason,
      reference_id,
      user_name,
      status
    ) VALUES (
      v_product_id,
      'produce',
      v_current_qty,
      v_new_qty,
      -v_total_deduct,
      'ผลิตจากสูตร (batch: ' || p_batch_quantity::TEXT || ')',
      p_recipe_id,
      p_user_name,
      'completed'
    );
  END LOOP;

  -- =============================================
  -- Step 3: Add output product stock (if specified)
  -- =============================================
  IF p_output_product_id IS NOT NULL THEN
    SELECT yield_quantity INTO v_yield_quantity
    FROM inventory_recipes
    WHERE id = p_recipe_id;
    
    SELECT quantity INTO v_output_current_qty
    FROM inventory_products
    WHERE id = p_output_product_id;
    
    v_output_new_qty := v_output_current_qty + v_yield_quantity;
    
    UPDATE inventory_products
    SET 
      quantity = v_output_new_qty,
      updated_at = now()
    WHERE id = p_output_product_id;
    
    INSERT INTO inventory_adjustments (
      product_id,
      type,
      quantity_before,
      quantity_after,
      quantity_change,
      reason,
      reference_id,
      user_name,
      status
    ) VALUES (
      p_output_product_id,
      'produce',
      v_output_current_qty,
      v_output_new_qty,
      v_yield_quantity,
      'ผลิตจากสูตร (batch: ' || p_batch_quantity::TEXT || ')',
      p_recipe_id,
      p_user_name,
      'completed'
    );
  END IF;

  -- =============================================
  -- Step 4: Record production log
  -- =============================================
  INSERT INTO inventory_production_logs (
    recipe_id,
    batch_quantity,
    yield_quantity,
    user_name,
    notes
  ) VALUES (
    p_recipe_id,
    p_batch_quantity,
    COALESCE(v_yield_quantity, 0),
    p_user_name,
    'ผลิตสำเร็จ - ' || p_batch_quantity::TEXT || ' batch'
  )
  RETURNING id INTO v_production_log_id;

  -- =============================================
  -- Step 5: Return success
  -- =============================================
  RETURN QUERY SELECT 
    true::BOOLEAN,
    'ผลิตสินค้าสำเร็จ'::TEXT,
    v_production_log_id::UUID;

EXCEPTION WHEN OTHERS THEN
  -- Rollback happens automatically in transaction
  RETURN QUERY SELECT 
    false::BOOLEAN,
    'เกิดข้อผิดพลาด: ' || SQLERRM::TEXT,
    NULL::UUID;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Create validation function for stock check
-- =============================================
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

-- =============================================
-- Create audit trail function
-- =============================================
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

-- =============================================
-- Create indexes for performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_production_logs_recipe_id 
ON inventory_production_logs(recipe_id);

CREATE INDEX IF NOT EXISTS idx_adjustments_reference_id 
ON inventory_adjustments(reference_id);

CREATE INDEX IF NOT EXISTS idx_adjustments_product_id 
ON inventory_adjustments(product_id);

-- =============================================
-- Add columns to production_logs for better tracking
-- =============================================
ALTER TABLE inventory_production_logs
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed' 
  CHECK (status IN ('pending', 'completed', 'failed'));

ALTER TABLE inventory_production_logs
ADD COLUMN IF NOT EXISTS error_message TEXT;

ALTER TABLE inventory_production_logs
ADD COLUMN IF NOT EXISTS total_cost DOUBLE PRECISION DEFAULT 0;
