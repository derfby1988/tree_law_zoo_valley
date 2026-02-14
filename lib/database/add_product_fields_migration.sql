-- =============================================
-- Migration: เพิ่มคอลัมน์ใหม่ในตาราง inventory_products
-- สำหรับรองรับ สินค้า/วัตถุดิบ, ภาษี, และรูปภาพ
-- รันใน Supabase SQL Editor
-- =============================================

-- 1. เพิ่มคอลัมน์ item_type (product / ingredient)
ALTER TABLE inventory_products
  ADD COLUMN IF NOT EXISTS item_type TEXT DEFAULT 'product'
  CHECK (item_type IN ('product', 'ingredient'));

-- 2. เพิ่มคอลัมน์ภาษี
ALTER TABLE inventory_products
  ADD COLUMN IF NOT EXISTS is_tax_exempt BOOLEAN DEFAULT true;

ALTER TABLE inventory_products
  ADD COLUMN IF NOT EXISTS tax_rate DOUBLE PRECISION DEFAULT 0;

ALTER TABLE inventory_products
  ADD COLUMN IF NOT EXISTS tax_inclusion TEXT DEFAULT 'excluded'
  CHECK (tax_inclusion IN ('included', 'excluded'));

-- 3. เพิ่มคอลัมน์รูปภาพ
ALTER TABLE inventory_products
  ADD COLUMN IF NOT EXISTS image_url TEXT;

-- =============================================
-- Storage Bucket สำหรับรูปสินค้า/วัตถุดิบ
-- =============================================
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Policies สำหรับ authenticated users
CREATE POLICY "Allow authenticated upload product images" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product-images');
CREATE POLICY "Allow authenticated update product images" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'product-images');
CREATE POLICY "Allow authenticated delete product images" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'product-images');
CREATE POLICY "Allow public read product images" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'product-images');

-- Policies สำหรับ anon (guest mode)
CREATE POLICY "Allow anon upload product images" ON storage.objects
  FOR INSERT TO anon WITH CHECK (bucket_id = 'product-images');
CREATE POLICY "Allow anon update product images" ON storage.objects
  FOR UPDATE TO anon USING (bucket_id = 'product-images');
CREATE POLICY "Allow anon delete product images" ON storage.objects
  FOR DELETE TO anon USING (bucket_id = 'product-images');
