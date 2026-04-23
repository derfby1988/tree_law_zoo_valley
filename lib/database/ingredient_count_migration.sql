-- =============================================
-- Migration: Ingredient Count Records
-- ตาราง: เก็บประวัติการตรวจนับวัตถุดิบ
-- =============================================

CREATE TABLE IF NOT EXISTS ingredient_count_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID NOT NULL REFERENCES inventory_ingredients(id) ON DELETE CASCADE,
  quantity_before NUMERIC(14, 4) NOT NULL DEFAULT 0,
  quantity_counted NUMERIC(14, 4) NOT NULL DEFAULT 0,
  difference NUMERIC(14, 4) GENERATED ALWAYS AS (quantity_counted - quantity_before) STORED,
  counted_by UUID REFERENCES auth.users(id),
  counted_at TIMESTAMPTZ DEFAULT now(),
  notes TEXT,
  batch_id UUID,  -- จัดกลุ่มการตรวจนับครั้งเดียวกัน
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ingredient_count_records_ingredient_id 
  ON ingredient_count_records(ingredient_id);
CREATE INDEX IF NOT EXISTS idx_ingredient_count_records_counted_at 
  ON ingredient_count_records(counted_at DESC);
CREATE INDEX IF NOT EXISTS idx_ingredient_count_records_batch_id 
  ON ingredient_count_records(batch_id);

-- Row Level Security
ALTER TABLE ingredient_count_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read ingredient count records"
  ON ingredient_count_records FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert ingredient count records"
  ON ingredient_count_records FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update ingredient count records"
  ON ingredient_count_records FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can delete ingredient count records"
  ON ingredient_count_records FOR DELETE
  TO authenticated
  USING (true);
