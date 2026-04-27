-- =============================================
-- Migration: Batch Tracking System
-- รองรับการจัดการ batch สำหรับทั้ง Products และ Ingredients
-- รวมถึงการ track วันหมดอายุ, ต้นทุนราย batch, และผู้จำหน่าย
-- =============================================

-- =============================================
-- 1. ตารางหลัก: inventory_item_batches
-- =============================================
CREATE TABLE IF NOT EXISTS inventory_item_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- ระบุประเภทและ reference (แยกกันชัดเจน)
  item_type TEXT NOT NULL CHECK (item_type IN ('product', 'ingredient')),
  product_id UUID REFERENCES inventory_products(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES inventory_ingredients(id) ON DELETE CASCADE,
  
  -- ข้อมูล batch
  batch_number TEXT NOT NULL,
  quantity DOUBLE PRECISION NOT NULL DEFAULT 0,
  
  -- วันที่สำคัญ
  expiry_date DATE,
  received_date DATE DEFAULT CURRENT_DATE,
  manufactured_date DATE,
  
  -- ตำแหน่ง (รองรับคลัง/ชั้นวางร่วมกัน)
  warehouse_id UUID REFERENCES inventory_warehouses(id),
  shelf_id UUID REFERENCES inventory_shelves(id),
  
  -- ผู้จำหน่าย (requirement: วิเคราะห์จัดซื้อ)
  supplier_id UUID,
  supplier_name TEXT,
  supplier_batch_code TEXT, -- เลขล็อตจากผู้จำหน่าย
  
  -- ต้นทุนราย batch (requirement: COGS แม่นยำ)
  unit_cost DOUBLE PRECISION,
  currency TEXT DEFAULT 'THB',
  total_cost DOUBLE PRECISION GENERATED ALWAYS AS (quantity * COALESCE(unit_cost, 0)) STORED,
  
  -- สถานะ
  is_expired BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  is_disposed BOOLEAN DEFAULT false,
  disposed_at TIMESTAMPTZ,
  
  -- การรับเข้า
  received_from_procurement_id UUID, -- เชื่อมกับ procurement_items
  received_reference TEXT, -- เลขที่ใบสั่งซื้อ/ใบส่งของ
  
  -- Metadata
  notes TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Constraints
  CONSTRAINT chk_item_reference CHECK (
    (item_type = 'product' AND product_id IS NOT NULL AND ingredient_id IS NULL) OR
    (item_type = 'ingredient' AND ingredient_id IS NOT NULL AND product_id IS NULL)
  ),
  CONSTRAINT chk_quantity_not_negative CHECK (quantity >= 0),
  CONSTRAINT chk_unit_cost_not_negative CHECK (unit_cost IS NULL OR unit_cost >= 0)
);

-- =============================================
-- 2. Indexes สำหรับ Query ที่รวดเร็ว
-- =============================================
CREATE INDEX IF NOT EXISTS idx_batches_product_active 
  ON inventory_item_batches(product_id, is_active, expiry_date);
  
CREATE INDEX IF NOT EXISTS idx_batches_ingredient_active 
  ON inventory_item_batches(ingredient_id, is_active, expiry_date);
  
CREATE INDEX IF NOT EXISTS idx_batches_fefo 
  ON inventory_item_batches(item_type, expiry_date, received_date, quantity) 
  WHERE is_active = true AND quantity > 0;
  
CREATE INDEX IF NOT EXISTS idx_batches_shelf 
  ON inventory_item_batches(shelf_id, item_type, is_active);
  
CREATE INDEX IF NOT EXISTS idx_batches_warehouse 
  ON inventory_item_batches(warehouse_id, item_type, is_active);
  
CREATE INDEX IF NOT EXISTS idx_batches_supplier 
  ON inventory_item_batches(supplier_id, received_date DESC);
  
CREATE INDEX IF NOT EXISTS idx_batches_expiry_alert 
  ON inventory_item_batches(expiry_date) 
  WHERE is_expired = false AND is_active = true AND quantity > 0;
  
CREATE INDEX IF NOT EXISTS idx_batches_batch_number 
  ON inventory_item_batches(batch_number);
  
CREATE INDEX IF NOT EXISTS idx_batches_mixed_shelf 
  ON inventory_item_batches(shelf_id, item_type, is_active, expiry_date);

-- =============================================
-- 3. Trigger อัปเดต updated_at
-- =============================================
CREATE OR REPLACE FUNCTION update_batch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_batch_timestamp ON inventory_item_batches;
CREATE TRIGGER trigger_update_batch_timestamp
  BEFORE UPDATE ON inventory_item_batches
  FOR EACH ROW EXECUTE FUNCTION update_batch_updated_at();

-- =============================================
-- 4. ตาราง Log การเคลื่อนไหวของ Batch
-- =============================================
CREATE TABLE IF NOT EXISTS inventory_batch_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES inventory_item_batches(id) ON DELETE CASCADE,
  
  -- ประเภทการเคลื่อนไหว
  action_type TEXT NOT NULL CHECK (action_type IN (
    'receive',       -- รับเข้า
    'consume',       -- ใช้ไป (ผลิต/ขาย)
    'adjust_count',  -- ปรับจากการตรวจนับ
    'adjust_manual', -- ปรับด้วยมือ
    'transfer',      -- ย้ายคลัง/ชั้น
    'expiry_change', -- เปลี่ยนวันหมดอายุ
    'dispose',       -- ทิ้ง
    'return',        -- คืนของ
    'split'          -- แบ่ง batch
  )),
  
  -- จำนวน
  quantity_before DOUBLE PRECISION NOT NULL,
  quantity_after DOUBLE PRECISION NOT NULL,
  quantity_changed DOUBLE PRECISION GENERATED ALWAYS AS (quantity_after - quantity_before) STORED,
  
  -- ข้อมูลเพิ่มเติมตาม action
  reference_id UUID, -- เชื่อมกับ production_logs, orders, ฯลฯ
  reference_type TEXT, -- 'production', 'pos_order', 'adjustment', 'transfer'
  notes TEXT,
  
  -- ผู้ทำรายการ
  performed_by UUID REFERENCES auth.users(id),
  performed_at TIMESTAMPTZ DEFAULT now(),
  
  -- ตำแหน่งก่อน/หลัง (สำหรับ transfer)
  from_warehouse_id UUID REFERENCES inventory_warehouses(id),
  from_shelf_id UUID REFERENCES inventory_shelves(id),
  to_warehouse_id UUID REFERENCES inventory_warehouses(id),
  to_shelf_id UUID REFERENCES inventory_shelves(id),
  
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_batch_logs_batch ON inventory_batch_logs(batch_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_batch_logs_action ON inventory_batch_logs(action_type, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_batch_logs_reference ON inventory_batch_logs(reference_id, reference_type);
CREATE INDEX IF NOT EXISTS idx_batch_logs_performed ON inventory_batch_logs(performed_by, performed_at DESC);

-- =============================================
-- 5. View สำหรับดูสต็อกรวม (สินค้า + วัตถุดิบ)
-- =============================================
CREATE OR REPLACE VIEW inventory_stock_summary AS
-- สินค้า
SELECT 
  'product' as item_type,
  p.id as item_id,
  p.name as item_name,
  p.category_id,
  c.name as category_name,
  p.unit_id,
  u.name as unit_name,
  COALESCE(SUM(b.quantity), 0) as total_quantity,
  COUNT(b.id) as batch_count,
  MIN(b.expiry_date) as earliest_expiry,
  MAX(b.expiry_date) as latest_expiry,
  SUM(CASE WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN b.quantity ELSE 0 END) as expiring_soon_quantity,
  SUM(CASE WHEN b.expiry_date <= CURRENT_DATE THEN b.quantity ELSE 0 END) as expired_quantity
FROM inventory_products p
LEFT JOIN inventory_item_batches b ON p.id = b.product_id AND b.is_active = true
LEFT JOIN inventory_categories c ON p.category_id = c.id
LEFT JOIN inventory_units u ON p.unit_id = u.id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.category_id, c.name, p.unit_id, u.name

UNION ALL

-- วัตถุดิบ
SELECT 
  'ingredient' as item_type,
  i.id as item_id,
  i.name as item_name,
  i.category_id,
  c.name as category_name,
  i.unit_id,
  u.name as unit_name,
  COALESCE(SUM(b.quantity), 0) as total_quantity,
  COUNT(b.id) as batch_count,
  MIN(b.expiry_date) as earliest_expiry,
  MAX(b.expiry_date) as latest_expiry,
  SUM(CASE WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN b.quantity ELSE 0 END) as expiring_soon_quantity,
  SUM(CASE WHEN b.expiry_date <= CURRENT_DATE THEN b.quantity ELSE 0 END) as expired_quantity
FROM inventory_ingredients i
LEFT JOIN inventory_item_batches b ON i.id = b.ingredient_id AND b.is_active = true
LEFT JOIN inventory_categories c ON i.category_id = c.id
LEFT JOIN inventory_units u ON i.unit_id = u.id
WHERE i.is_active = true
GROUP BY i.id, i.name, i.category_id, c.name, i.unit_id, u.name;

-- =============================================
-- 6. View สำหรับดูรายละเอียด batch พร้อมข้อมูลเต็ม
-- =============================================
CREATE OR REPLACE VIEW inventory_batch_details AS
SELECT 
  b.*,
  -- ข้อมูลสินค้า/วัตถุดิบ
  CASE 
    WHEN b.item_type = 'product' THEN p.name
    ELSE i.name
  END as item_name,
  CASE 
    WHEN b.item_type = 'product' THEN p.category_id
    ELSE i.category_id
  END as category_id,
  c.name as category_name,
  CASE 
    WHEN b.item_type = 'product' THEN p.unit_id
    ELSE i.unit_id
  END as unit_id,
  u.name as unit_name,
  u.abbreviation as unit_abbreviation,
  -- ข้อมูลคลัง/ชั้นวาง
  w.name as warehouse_name,
  s.code as shelf_code,
  -- สถานะ
  CASE 
    WHEN b.expiry_date < CURRENT_DATE THEN 'expired'
    WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'expiring_soon'
    ELSE 'good'
  END as expiry_status,
  (b.expiry_date - CURRENT_DATE) as days_until_expiry
FROM inventory_item_batches b
LEFT JOIN inventory_products p ON b.product_id = p.id
LEFT JOIN inventory_ingredients i ON b.ingredient_id = i.id
LEFT JOIN inventory_categories c ON (
  (b.item_type = 'product' AND p.category_id = c.id) OR
  (b.item_type = 'ingredient' AND i.category_id = c.id)
)
LEFT JOIN inventory_units u ON (
  (b.item_type = 'product' AND p.unit_id = u.id) OR
  (b.item_type = 'ingredient' AND i.unit_id = u.id)
)
LEFT JOIN inventory_warehouses w ON b.warehouse_id = w.id
LEFT JOIN inventory_shelves s ON b.shelf_id = s.id
WHERE b.is_active = true;

-- =============================================
-- 7. View สำหรับแจ้งเตือน
-- =============================================
CREATE OR REPLACE VIEW inventory_expiry_alerts AS
SELECT 
  b.*,
  bd.item_name,
  bd.category_name,
  bd.unit_name,
  bd.warehouse_name,
  bd.shelf_code,
  bd.expiry_status,
  bd.days_until_expiry
FROM inventory_item_batches b
JOIN inventory_batch_details bd ON b.id = bd.id
WHERE b.is_active = true
  AND b.quantity > 0
  AND b.is_expired = false
  AND b.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
ORDER BY b.expiry_date ASC, bd.item_name;

-- =============================================
-- 8. Function สำหรับ FEFO Consume
-- =============================================
CREATE OR REPLACE FUNCTION consume_batch_fefo(
  p_item_id UUID,
  p_item_type TEXT,
  p_quantity_needed DOUBLE PRECISION,
  p_reference_id UUID DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL,
  p_performed_by UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
  batch_id UUID,
  consumed_quantity DOUBLE PRECISION,
  remaining_needed DOUBLE PRECISION
) AS $$
DECLARE
  v_batch RECORD;
  v_take DOUBLE PRECISION;
  v_remaining DOUBLE PRECISION := p_quantity_needed;
BEGIN
  -- ดึง batch ที่ยังไม่หมดอายุ เรียงตาม expiry_date, received_date
  FOR v_batch IN
    SELECT 
      b.id,
      b.quantity,
      b.quantity as original_qty
    FROM inventory_item_batches b
    WHERE 
      CASE 
        WHEN p_item_type = 'product' THEN b.product_id = p_item_id
        ELSE b.ingredient_id = p_item_id
      END
      AND b.item_type = p_item_type
      AND b.is_active = true
      AND b.quantity > 0
      AND (b.expiry_date IS NULL OR b.expiry_date >= CURRENT_DATE)
    ORDER BY b.expiry_date ASC NULLS LAST, b.received_date ASC, b.created_at ASC
  LOOP
    EXIT WHEN v_remaining <= 0;
    
    v_take := LEAST(v_remaining, v_batch.quantity);
    
    -- ลดจำนวนใน batch
    UPDATE inventory_item_batches
    SET quantity = quantity - v_take,
        updated_at = now()
    WHERE id = v_batch.id;
    
    -- บันทึก log
    INSERT INTO inventory_batch_logs (
      batch_id, action_type, quantity_before, quantity_after,
      reference_id, reference_type, performed_by, notes
    ) VALUES (
      v_batch.id, 'consume', v_batch.quantity, v_batch.quantity - v_take,
      p_reference_id, p_reference_type, p_performed_by, p_notes
    );
    
    batch_id := v_batch.id;
    consumed_quantity := v_take;
    remaining_needed := v_remaining - v_take;
    v_remaining := remaining_needed;
    
    RETURN NEXT;
  END LOOP;
  
  RETURN;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 9. Function สำหรับการนับรวมแล้วกระจาย (วัตถุดิบ - FEFO)
-- =============================================
CREATE OR REPLACE FUNCTION adjust_batch_quantities_fefo(
  p_item_id UUID,
  p_item_type TEXT,
  p_counted_total DOUBLE PRECISION,
  p_performed_by UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_batches RECORD;
  v_system_total DOUBLE PRECISION;
  v_diff DOUBLE PRECISION;
  v_remaining DOUBLE PRECISION;
BEGIN
  -- คำนวณยอดรวมในระบบ
  SELECT COALESCE(SUM(quantity), 0) INTO v_system_total
  FROM inventory_item_batches
  WHERE 
    CASE 
      WHEN p_item_type = 'product' THEN product_id = p_item_id
      ELSE ingredient_id = p_item_id
    END
    AND item_type = p_item_type
    AND is_active = true;
  
  v_diff := p_counted_total - v_system_total;
  
  IF v_diff = 0 THEN
    RETURN true;
  END IF;
  
  IF v_diff > 0 THEN
    -- นับได้มากกว่า -> เพิ่ม batch แรก (ของที่รับก่อน)
    SELECT * INTO v_batches
    FROM inventory_item_batches
    WHERE 
      CASE 
        WHEN p_item_type = 'product' THEN product_id = p_item_id
        ELSE ingredient_id = p_item_id
      END
      AND item_type = p_item_type
      AND is_active = true
    ORDER BY received_date ASC, created_at ASC
    LIMIT 1;
    
    IF FOUND THEN
      UPDATE inventory_item_batches
      SET quantity = quantity + v_diff,
          updated_at = now()
      WHERE id = v_batches.id;
      
      INSERT INTO inventory_batch_logs (
        batch_id, action_type, quantity_before, quantity_after,
        performed_by, notes
      ) VALUES (
        v_batches.id, 'adjust_count', v_batches.quantity, v_batches.quantity + v_diff,
        p_performed_by, p_notes || ' (นับรวม +' || v_diff || ')'
      );
    END IF;
  ELSE
    -- นับได้น้อยกว่า -> ลดจาก batch ล่าสุด (ของรับทีหลังก่อน)
    v_remaining := ABS(v_diff);
    
    FOR v_batches IN
      SELECT *
      FROM inventory_item_batches
      WHERE 
        CASE 
          WHEN p_item_type = 'product' THEN product_id = p_item_id
          ELSE ingredient_id = p_item_id
        END
        AND item_type = p_item_type
        AND is_active = true
        AND quantity > 0
      ORDER BY received_date DESC, created_at DESC
    LOOP
      EXIT WHEN v_remaining <= 0;
      
      DECLARE
        v_reduce_by DOUBLE PRECISION := LEAST(v_remaining, v_batches.quantity);
        v_new_qty DOUBLE PRECISION := v_batches.quantity - v_reduce_by;
      BEGIN
        UPDATE inventory_item_batches
        SET quantity = v_new_qty,
            updated_at = now()
        WHERE id = v_batches.id;
        
        INSERT INTO inventory_batch_logs (
          batch_id, action_type, quantity_before, quantity_after,
          performed_by, notes
        ) VALUES (
          v_batches.id, 'adjust_count', v_batches.quantity, v_new_qty,
          p_performed_by, p_notes || ' (นับรวม -' || v_reduce_by || ')'
        );
        
        v_remaining := v_remaining - v_reduce_by;
      END;
    END LOOP;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 10. Function สำหรับสร้าง batch ใหม่
-- =============================================
CREATE OR REPLACE FUNCTION create_inventory_batch(
  p_item_type TEXT,
  p_item_id UUID,
  p_batch_number TEXT,
  p_quantity DOUBLE PRECISION,
  p_expiry_date DATE,
  p_warehouse_id UUID,
  p_shelf_id UUID,
  p_unit_cost DOUBLE PRECISION DEFAULT NULL,
  p_supplier_name TEXT DEFAULT NULL,
  p_received_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_created_by UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_batch_id UUID;
  v_generated_batch_number TEXT;
BEGIN
  -- สร้างเลข batch อัตโนมัติถ้าไม่ระบุ
  IF p_batch_number IS NULL OR p_batch_number = '' THEN
    v_generated_batch_number := 'LOT' || TO_CHAR(now(), 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 8);
  ELSE
    v_generated_batch_number := p_batch_number;
  END IF;
  
  INSERT INTO inventory_item_batches (
    item_type,
    product_id,
    ingredient_id,
    batch_number,
    quantity,
    expiry_date,
    received_date,
    warehouse_id,
    shelf_id,
    unit_cost,
    supplier_name,
    received_reference,
    notes,
    created_by
  ) VALUES (
    p_item_type,
    CASE WHEN p_item_type = 'product' THEN p_item_id ELSE NULL END,
    CASE WHEN p_item_type = 'ingredient' THEN p_item_id ELSE NULL END,
    v_generated_batch_number,
    p_quantity,
    p_expiry_date,
    CURRENT_DATE,
    p_warehouse_id,
    p_shelf_id,
    p_unit_cost,
    p_supplier_name,
    p_received_reference,
    p_notes,
    p_created_by
  )
  RETURNING id INTO v_batch_id;
  
  -- บันทึก log
  INSERT INTO inventory_batch_logs (
    batch_id, action_type, quantity_before, quantity_after,
    performed_by, notes
  ) VALUES (
    v_batch_id, 'receive', 0, p_quantity,
    p_created_by, 'รับเข้าระบบ: ' || p_received_reference
  );
  
  RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 11. Function สำหรับ mark batch หมดอายุ
-- =============================================
CREATE OR REPLACE FUNCTION mark_batch_expired(
  p_batch_id UUID,
  p_disposed BOOLEAN DEFAULT false,
  p_performed_by UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_old_quantity DOUBLE PRECISION;
BEGIN
  SELECT quantity INTO v_old_quantity
  FROM inventory_item_batches
  WHERE id = p_batch_id;
  
  UPDATE inventory_item_batches
  SET is_expired = true,
      is_disposed = p_disposed,
      disposed_at = CASE WHEN p_disposed THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_batch_id;
  
  INSERT INTO inventory_batch_logs (
    batch_id, action_type, quantity_before, quantity_after,
    performed_by, notes
  ) VALUES (
    p_batch_id, 'dispose', v_old_quantity, CASE WHEN p_disposed THEN 0 ELSE v_old_quantity END,
    p_performed_by, p_notes || ' (mark as expired)'
  );
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 12. Function อัปเดตวันหมดอายุ
-- =============================================
CREATE OR REPLACE FUNCTION update_batch_expiry(
  p_batch_id UUID,
  p_new_expiry_date DATE,
  p_reason TEXT DEFAULT NULL,
  p_performed_by UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_old_expiry DATE;
  v_batch_number TEXT;
BEGIN
  SELECT expiry_date, batch_number INTO v_old_expiry, v_batch_number
  FROM inventory_item_batches
  WHERE id = p_batch_id;
  
  UPDATE inventory_item_batches
  SET expiry_date = p_new_expiry_date,
      updated_at = now()
  WHERE id = p_batch_id;
  
  INSERT INTO inventory_batch_logs (
    batch_id, action_type, quantity_before, quantity_after,
    performed_by, notes
  ) VALUES (
    p_batch_id, 'expiry_change', 0, 0,
    p_performed_by, 
    'เปลี่ยนวันหมดอายุ: ' || v_old_expiry || ' -> ' || p_new_expiry_date || 
    COALESCE(' (' || p_reason || ')', '')
  );
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 13. Row Level Security
-- =============================================
ALTER TABLE inventory_item_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_batch_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON inventory_item_batches;
DROP POLICY IF EXISTS "Allow all for authenticated" ON inventory_batch_logs;
DROP POLICY IF EXISTS "Allow read for anon" ON inventory_item_batches;
DROP POLICY IF EXISTS "Allow read for anon" ON inventory_batch_logs;

CREATE POLICY "Allow all for authenticated" ON inventory_item_batches 
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
  
CREATE POLICY "Allow all for authenticated" ON inventory_batch_logs 
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Anon policies (สำหรับ guest mode)
CREATE POLICY "Allow read for anon" ON inventory_item_batches 
  FOR SELECT TO anon USING (true);
  
CREATE POLICY "Allow read for anon" ON inventory_batch_logs 
  FOR SELECT TO anon USING (true);

-- =============================================
-- 14. Migration: สร้าง batch จากข้อมูลเดิม
-- =============================================
-- สร้าง batch จาก expiry_date ที่มีอยู่ใน inventory_products
INSERT INTO inventory_item_batches (
  item_type,
  product_id,
  batch_number,
  quantity,
  expiry_date,
  warehouse_id,
  shelf_id,
  notes
)
SELECT 
  'product' as item_type,
  p.id as product_id,
  'MIGRATED-' || TO_CHAR(now(), 'YYYYMMDD') as batch_number,
  p.quantity,
  p.expiry_date,
  w.id as warehouse_id,
  p.shelf_id,
  'Auto-migrated from product expiry_date'
FROM inventory_products p
LEFT JOIN inventory_shelves s ON p.shelf_id = s.id
LEFT JOIN inventory_warehouses w ON s.warehouse_id = w.id
WHERE p.expiry_date IS NOT NULL
  AND p.quantity > 0
ON CONFLICT DO NOTHING;

-- สร้าง batch จาก expiry_date ที่มีอยู่ใน inventory_ingredients
INSERT INTO inventory_item_batches (
  item_type,
  ingredient_id,
  batch_number,
  quantity,
  expiry_date,
  warehouse_id,
  shelf_id,
  notes
)
SELECT 
  'ingredient' as item_type,
  i.id as ingredient_id,
  'MIGRATED-' || TO_CHAR(now(), 'YYYYMMDD') as batch_number,
  i.quantity,
  i.expiry_date::date,
  w.id as warehouse_id,
  i.shelf_id,
  'Auto-migrated from ingredient expiry_date'
FROM inventory_ingredients i
LEFT JOIN inventory_shelves s ON i.shelf_id = s.id
LEFT JOIN inventory_warehouses w ON s.warehouse_id = w.id
WHERE i.expiry_date IS NOT NULL
  AND i.quantity > 0
ON CONFLICT DO NOTHING;

-- =============================================
-- 15. Verify Migration
-- =============================================
SELECT 'Batch tracking migration complete' as status,
       (SELECT COUNT(*) FROM inventory_item_batches) as total_batches,
       (SELECT COUNT(*) FROM inventory_batch_logs) as total_logs,
       (SELECT COUNT(*) FROM inventory_item_batches WHERE item_type = 'product') as product_batches,
       (SELECT COUNT(*) FROM inventory_item_batches WHERE item_type = 'ingredient') as ingredient_batches;
