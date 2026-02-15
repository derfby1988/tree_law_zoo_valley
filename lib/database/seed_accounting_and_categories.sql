-- =============================================
-- SEED DATA: ผังบัญชีและหมวดหมู่สินค้าสำหรับธุรกิจร้านอาหาร/คาเฟ่
-- เน้นรายละเอียดหมวดยกเว้นภาษี (VAT Exempt) ตามประมวลรัษฎากร มาตรา 81
-- =============================================

-- 0. ปรับปรุงโครงสร้างตาราง account_chart ให้ครบถ้วน (ป้องกันกรณีตารางมีอยู่แล้วแต่ขาดคอลัมน์)
ALTER TABLE account_chart ADD COLUMN IF NOT EXISTS parent_code TEXT REFERENCES account_chart(code) ON DELETE SET NULL;
ALTER TABLE account_chart ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 1;
ALTER TABLE account_chart ADD COLUMN IF NOT EXISTS normal_balance TEXT CHECK (normal_balance IN ('debit','credit'));
ALTER TABLE account_chart ADD COLUMN IF NOT EXISTS industry TEXT;
ALTER TABLE account_chart ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT true;

-- 1. ผังบัญชี (Account Chart)
-- เพิ่มรหัสบัญชีที่จำเป็นสำหรับการแยกประเภทรายได้และต้นทุนตามลักษณะภาษี
INSERT INTO account_chart (code, name_th, type, level, parent_code, normal_balance) VALUES
  -- สินทรัพย์ (Assets) > สินค้าคงเหลือ (1301)
  ('130101', 'สินค้าคงเหลือ-วัตถุดิบอาหารสด (ยกเว้นภาษี)', 'asset', 3, '1301', 'debit'),
  ('130102', 'สินค้าคงเหลือ-ผักและผลไม้สด (ยกเว้นภาษี)', 'asset', 3, '1301', 'debit'),
  ('130103', 'สินค้าคงเหลือ-เนื้อสัตว์และอาหารทะเลสด (ยกเว้นภาษี)', 'asset', 3, '1301', 'debit'),
  ('130104', 'สินค้าคงเหลือ-ไข่และผลิตภัณฑ์นมสด (ยกเว้นภาษี)', 'asset', 3, '1301', 'debit'),
  ('130105', 'สินค้าคงเหลือ-ข้าวสารและธัญพืช (ยกเว้นภาษี)', 'asset', 3, '1301', 'debit'),
  ('130106', 'สินค้าคงเหลือ-เครื่องดื่มและเครื่องปรุง (มีภาษี)', 'asset', 3, '1301', 'debit'),
  ('130107', 'สินค้าคงเหลือ-อาหารแปรรูปและของแห้ง (มีภาษี)', 'asset', 3, '1301', 'debit'),
  ('130108', 'สินค้าคงเหลือ-บรรจุภัณฑ์และวัสดุสิ้นเปลือง (มีภาษี)', 'asset', 3, '1301', 'debit'),

  -- รายได้ (Revenue) > รายได้จากการขาย (4101)
  ('410101', 'รายได้จากการขายอาหารและเครื่องดื่ม (VAT 7%)', 'revenue', 3, '4101', 'credit'),
  ('410102', 'รายได้จากการขายสินค้าเกษตรไม่แปรรูป (ยกเว้นภาษี)', 'revenue', 3, '4101', 'credit'),
  ('410103', 'รายได้จากการขายสินค้ามาตรา 81 อื่นๆ (ยกเว้นภาษี)', 'revenue', 3, '4101', 'credit'),

  -- ต้นทุนขาย (COGS) > ต้นทุนวัตถุดิบ (5101)
  ('510101', 'ต้นทุนวัตถุดิบ-สินค้ามีภาษี (VAT 7%)', 'cogs', 3, '5101', 'debit'),
  ('510102', 'ต้นทุนวัตถุดิบ-สินค้าเกษตรยกเว้นภาษี', 'cogs', 3, '5101', 'debit')
ON CONFLICT (code) DO UPDATE SET 
  name_th = EXCLUDED.name_th,
  type = EXCLUDED.type;

-- 2. หมวดหมู่สินค้า (Categories)
-- แบ่งตามลักษณะทางภาษีและประเภทการใช้งานในร้านอาหาร

-- 2.1 กลุ่มสินค้าเกษตรและสัตว์นํ้า (ยกเว้นภาษีมูลค่าเพิ่ม)
INSERT INTO inventory_categories (name, description, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  (
    'ผักสดและผลไม้สด', 
    'พืชผักและผลไม้ทุกชนิดที่ยังสด หรือแช่เย็นเพื่อรักษาคุณภาพ รวมถึงพืชผักผลไม้ที่หั่นเป็นชิ้นแต่ยังคงสภาพธรรมชาติ ไม่ผ่านการปรุงแต่งรส หรือกระบวนการถนอมอาหารที่เข้าข่ายอุตสาหกรรม (ยกเว้นภาษีตามมาตรา 81(1)(ก))', 
    '130102', '410102', '510102'
  ),
  (
    'เนื้อสัตว์และอาหารทะเลสด', 
    'เนื้อสัตว์ทุกชนิด (หมู, ไก่, วัว, แพะ, แกะ) และสัตว์น้ำ (ปลา, กุ้ง, ปู, หอย) ทั้งสด แช่เย็น หรือแช่แข็ง ที่ยังไม่ผ่านการปรุงแต่งรส หรือแปรรูปเป็นอาหารสำเร็จรูป (ยกเว้นภาษีตามมาตรา 81(1)(ข))', 
    '130103', '410102', '510102'
  ),
  (
    'ไข่สด', 
    'ไข่เป็ด ไข่ไก่ ไข่นกกระทา และไข่สัตว์ปีกอื่นๆ ที่ยังมิได้แปรรูป หรือปรุงแต่งรส (ยกเว้นภาษีตามมาตรา 81(1)(ข))', 
    '130104', '410102', '510102'
  ),
  (
    'นมสด', 
    'น้ำนมสดจากสัตว์ทุกชนิด ทั้งที่ยังไม่ได้แปรรูป หรือผ่านการพาสเจอร์ไรซ์/สเตอริไลซ์ แต่ไม่มีการปรุงแต่งรสชาติ (เช่น รสจืด ยกเว้นภาษี แต่ถ้ารสหวาน/ช็อกโกแลต ต้องเสียภาษี) (ยกเว้นภาษีตามมาตรา 81(1)(ข))', 
    '130104', '410102', '510102'
  ),
  (
    'ข้าวสารและธัญพืช', 
    'ข้าวเปลือก ข้าวสาร ข้าวกล้อง และธัญพืชต่างๆ (ถั่ว, งา, ข้าวโพด) ที่ยังไม่ได้แปรรูปเป็นขนมหรืออาหารสำเร็จรูป (ยกเว้นภาษีตามมาตรา 81(1)(ก))', 
    '130105', '410102', '510102'
  ),
  (
    'สมุนไพรสดและเครื่องเทศดิบ', 
    'สมุนไพรสด เช่น ตะไคร้ ข่า ใบมะกรูด พริกสด และเครื่องเทศที่ยังไม่แปรรูปเป็นผงบรรจุซองมาตรฐานอุตสาหกรรม (ยกเว้นภาษี)', 
    '130102', '410102', '510102'
  )
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  inventory_account_code = EXCLUDED.inventory_account_code,
  revenue_account_code = EXCLUDED.revenue_account_code,
  cost_account_code = EXCLUDED.cost_account_code;

-- 2.2 กลุ่มสินค้าทั่วไป (มีภาษีมูลค่าเพิ่ม)
INSERT INTO inventory_categories (name, description, inventory_account_code, revenue_account_code, cost_account_code) VALUES
  (
    'เครื่องปรุงรส', 
    'ผลิตภัณฑ์ปรุงแต่งรสอาหาร เช่น น้ำปลา ซีอิ๊ว น้ำมันหอย น้ำตาลทราย เกลือ ผงชูรส ซอสพริก ซอสมะเขือเทศ (เสียภาษี VAT 7%)', 
    '130106', '410101', '510101'
  ),
  (
    'อาหารแปรรูปและของแห้ง', 
    'อาหารที่ผ่านการถนอมอาหาร บรรจุกระป๋อง หรือแปรรูปแล้ว เช่น บะหมี่กึ่งสำเร็จรูป ปลากระป๋อง ไส้กรอก แฮม เบคอน ลูกชิ้น (เสียภาษี VAT 7%)', 
    '130107', '410101', '510101'
  ),
  (
    'เครื่องดื่ม', 
    'เครื่องดื่มทุกชนิด เช่น น้ำอัดลม น้ำเปล่าบรรจุขวด กาแฟ ชา นมปรุงแต่งรส น้ำผลไม้ผสม (เสียภาษี VAT 7%)', 
    '130106', '410101', '510101'
  ),
  (
    'เบเกอรี่และของหวาน', 
    'ขนมปัง เค้ก คุกกี้ และขนมหวานต่างๆ ที่ผ่านการปรุงสุกแล้ว (เสียภาษี VAT 7%)', 
    '130107', '410101', '510101'
  ),
  (
    'บรรจุภัณฑ์', 
    'วัสดุสิ้นเปลืองสำหรับใส่อาหารและเครื่องดื่ม เช่น กล่องโฟม กล่องกระดาษ แก้วน้ำ หลอด ถุงพลาสติก ช้อนส้อมพลาสติก (เสียภาษี VAT 7%)', 
    '130108', '410101', '510101'
  ),
  (
    'ผลิตภัณฑ์ทำความสะอาด', 
    'น้ำยาล้างจาน น้ำยาถูพื้น ผงซักฟอก และอุปกรณ์ทำความสะอาดต่างๆ (เสียภาษี VAT 7%)', 
    '130108', '410101', '510101'
  )
ON CONFLICT (name) DO UPDATE SET 
  description = EXCLUDED.description,
  inventory_account_code = EXCLUDED.inventory_account_code,
  revenue_account_code = EXCLUDED.revenue_account_code,
  cost_account_code = EXCLUDED.cost_account_code;

-- 3. กฎภาษี (Tax Rules)
-- สร้างกฎภาษีผูกกับหมวดหมู่เพื่อการคำนวณอัตโนมัติ

-- ตรวจสอบและสร้างตาราง inventory_tax_rules หากยังไม่มี
-- และเพิ่มคอลัมน์ source หากตารางมีอยู่แล้วแต่ยังไม่มีคอลัมน์นี้
CREATE TABLE IF NOT EXISTS inventory_tax_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES inventory_categories(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL DEFAULT 'both' CHECK (item_type IN ('product', 'ingredient', 'both')),
  is_tax_exempt BOOLEAN NOT NULL DEFAULT false,
  tax_rate DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
  tax_inclusion TEXT NOT NULL DEFAULT 'excluded' CHECK (tax_inclusion IN ('included', 'excluded')),
  rule_name TEXT NOT NULL,
  legal_reference TEXT,
  source TEXT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  priority INT NOT NULL DEFAULT 1,
  requires_manual_review BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT inventory_tax_rules_effective_range_chk CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- เพิ่มคอลัมน์ source หากตารางมีอยู่แล้วแต่ยังไม่มีคอลัมน์นี้
ALTER TABLE inventory_tax_rules ADD COLUMN IF NOT EXISTS source TEXT;

-- ล้างกฎเก่าที่สร้างจาก seed (source = seed_detailed)
DELETE FROM inventory_tax_rules WHERE source = 'seed_detailed';

-- กฎสำหรับสินค้าเกษตรยกเว้นภาษี
INSERT INTO inventory_tax_rules (category_id, item_type, is_tax_exempt, tax_rate, tax_inclusion, rule_name, legal_reference, source, priority, is_active, effective_from)
SELECT 
  id, 
  'both', 
  true, 
  0.0, 
  'excluded', 
  'สินค้าเกษตรยกเว้นภาษี (VAT Exempt)', 
  'ประมวลรัษฎากร มาตรา 81 (1) (ก)-(ข)', 
  'seed_detailed',
  10,
  true,
  '2024-01-01'
FROM inventory_categories 
WHERE name IN ('ผักสดและผลไม้สด', 'เนื้อสัตว์และอาหารทะเลสด', 'ไข่สด', 'นมสด', 'ข้าวสารและธัญพืช', 'สมุนไพรสดและเครื่องเทศดิบ');

-- กฎสำหรับสินค้าทั่วไปมีภาษี
INSERT INTO inventory_tax_rules (category_id, item_type, is_tax_exempt, tax_rate, tax_inclusion, rule_name, legal_reference, source, priority, is_active, effective_from)
SELECT 
  id, 
  'both', 
  false, 
  7.0, 
  'included', 
  'สินค้าทั่วไป (VAT 7%)', 
  'ประมวลรัษฎากร ภาษีมูลค่าเพิ่ม', 
  'seed_detailed',
  10,
  true,
  '2024-01-01'
FROM inventory_categories 
WHERE name IN ('เครื่องปรุงรส', 'อาหารแปรรูปและของแห้ง', 'เครื่องดื่ม', 'เบเกอรี่และของหวาน', 'บรรจุภัณฑ์', 'ผลิตภัณฑ์ทำความสะอาด');
