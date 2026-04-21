-- =============================================
-- STEP 3: Create Transaction Function
-- =============================================
-- รันใน Supabase SQL Editor
-- ⏱️ เวลา: ~15 วินาที

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

-- ✅ ทดสอบ
-- SELECT * FROM produce_from_recipe(
--   'recipe_id_here',
--   1,
--   '[{"product_id": "prod_id", "quantity": 100}]'::JSONB,
--   'output_product_id_here',
--   'test_user'
-- );
