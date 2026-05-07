-- =============================================
-- Fix: Add output_product_id column to inventory_recipes
-- =============================================
-- วันที่สร้าง: 6 พฤษภาคม 2568
-- ใช้สำหรับ: เพิ่ม column ที่หายไปใน inventory_recipes
-- สาเหตุ: Phase 4 availability functions ต้องใช้ column นี้
-- =============================================

-- 1. Add column output_product_id (ถ้ายังไม่มี)
ALTER TABLE inventory_recipes
  ADD COLUMN IF NOT EXISTS output_product_id UUID REFERENCES inventory_products(id);

-- 2. Add index for faster lookup
CREATE INDEX IF NOT EXISTS idx_inventory_recipes_output_product_id
  ON inventory_recipes(output_product_id);

-- 3. Add comment
COMMENT ON COLUMN inventory_recipes.output_product_id IS 'สินค้าที่ผลิตได้จากสูตรอาหารนี้';

-- =============================================
-- ตรวจสอบว่า column ถูกเพิ่มแล้ว
-- =============================================
SELECT 
    'output_product_id column' as check_item,
    EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'inventory_recipes' 
        AND column_name = 'output_product_id'
    ) as exists;
