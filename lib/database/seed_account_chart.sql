-- =============================================
-- Seed Account Chart: ผังบัญชีมาตรฐาน + แยกตามประเภทสินค้า
-- รันใน Supabase SQL Editor
-- =============================================
-- Schema จริง: account_chart
--   id UUID PK (auto), code VARCHAR UNIQUE, name_th, name_en, 
--   type CHECK ('asset','liability','equity','revenue','expense','cogs'),
--   parent_id UUID FK, level INT, is_active BOOL, created_at, updated_at

-- =============================================
-- 1. บัญชีสินทรัพย์ (Asset) - หมวด 1xxx
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('1000', 'สินทรัพย์หมุนเวียน', 'Current Assets', 'asset', 1),
('1001', 'สินค้าคงเหลือ', 'Inventory', 'asset', 2),
('1001-01', 'สินค้าคงเหลือ - การเกษตร', 'Inventory - Agriculture', 'asset', 3),
('1001-02', 'สินค้าคงเหลือ - อุตสาหกรรม', 'Inventory - Industrial', 'asset', 3),
('1001-03', 'สินค้าคงเหลือ - อาหารและเครื่องดื่ม', 'Inventory - Food & Beverage', 'asset', 3),
('1001-04', 'สินค้าคงเหลือ - บรรจุภัณฑ์', 'Inventory - Packaging', 'asset', 3),
('1002', 'วัตถุดิบ', 'Raw Materials', 'asset', 2),
('1003', 'เงินสด', 'Cash', 'asset', 2),
('1004', 'บัญชีธนาคาร', 'Bank Accounts', 'asset', 2),
('1005', 'ลูกหนี้การค้า', 'Accounts Receivable', 'asset', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 2. บัญชีหนี้สิน (Liability) - หมวด 2xxx
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('2000', 'หนี้สินหมุนเวียน', 'Current Liabilities', 'liability', 1),
('2001', 'เจ้าหนี้การค้า', 'Accounts Payable', 'liability', 2),
('2002', 'ค่าใช้จ่ายค้างจ่าย', 'Accrued Expenses', 'liability', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 3. ส่วนของเจ้าของ (Equity) - หมวด 3xxx
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('3000', 'ส่วนของเจ้าของ', 'Owner Equity', 'equity', 1),
('3001', 'ทุน', 'Capital', 'equity', 2),
('3002', 'กำไรสะสม', 'Retained Earnings', 'equity', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 4. บัญชีรายได้ (Revenue) - หมวด 4xxx
-- แยกตามประเภทสินค้า
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('4000', 'รายได้', 'Revenue', 'revenue', 1),
('4001', 'รายได้จากการขายสินค้า', 'Sales Revenue', 'revenue', 2),
('4001-01', 'รายได้ - การเกษตร', 'Revenue - Agriculture', 'revenue', 3),
('4001-02', 'รายได้ - อุตสาหกรรม', 'Revenue - Industrial', 'revenue', 3),
('4001-03', 'รายได้ - อาหารและเครื่องดื่ม', 'Revenue - Food & Beverage', 'revenue', 3),
('4001-04', 'รายได้ - บรรจุภัณฑ์', 'Revenue - Packaging', 'revenue', 3),
('4002', 'รายได้จากบริการ', 'Service Revenue', 'revenue', 2),
('4003', 'รายได้อื่น', 'Other Revenue', 'revenue', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 5. บัญชีต้นทุน (COGS) - หมวด 5xxx
-- แยกตามประเภทสินค้า
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('5000', 'ต้นทุนขาย', 'Cost of Goods Sold', 'cogs', 1),
('5001', 'ต้นทุนสินค้า', 'COGS - General', 'cogs', 2),
('5001-01', 'ต้นทุน - การเกษตร', 'COGS - Agriculture', 'cogs', 3),
('5001-02', 'ต้นทุน - อุตสาหกรรม', 'COGS - Industrial', 'cogs', 3),
('5001-03', 'ต้นทุน - อาหารและเครื่องดื่ม', 'COGS - Food & Beverage', 'cogs', 3),
('5001-04', 'ต้นทุน - บรรจุภัณฑ์', 'COGS - Packaging', 'cogs', 3),
('5002', 'ต้นทุนวัตถุดิบ', 'Material Costs', 'cogs', 2),
('5003', 'ค่าแรงงานตรง', 'Direct Labor', 'cogs', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 6. บัญชีค่าใช้จ่าย (Expense) - หมวด 6xxx
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('6000', 'ค่าใช้จ่ายในการดำเนินงาน', 'Operating Expenses', 'expense', 1),
('6001', 'ค่าเช่า', 'Rent Expense', 'expense', 2),
('6002', 'ค่าจ้างและเงินเดือน', 'Salaries', 'expense', 2),
('6003', 'ค่าสาธารณูปโภค', 'Utilities', 'expense', 2),
('6004', 'ค่าขนส่ง', 'Shipping Expense', 'expense', 2),
('6005', 'ค่าเสื่อมราคา', 'Depreciation', 'expense', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 7. ตั้ง parent_id ให้ถูกต้อง (ใช้ subquery หา UUID จาก code)
-- =============================================
UPDATE public.account_chart c
SET parent_id = p.id
FROM public.account_chart p
WHERE 
  -- Level 2 → parent is level 1 (1001→1000, 4001→4000, etc.)
  (c.code LIKE '1001' AND p.code = '1000')
  OR (c.code LIKE '1002' AND p.code = '1000')
  OR (c.code LIKE '1003' AND p.code = '1000')
  OR (c.code LIKE '1004' AND p.code = '1000')
  OR (c.code LIKE '1005' AND p.code = '1000')
  OR (c.code = '2001' AND p.code = '2000')
  OR (c.code = '2002' AND p.code = '2000')
  OR (c.code = '3001' AND p.code = '3000')
  OR (c.code = '3002' AND p.code = '3000')
  OR (c.code = '4001' AND p.code = '4000')
  OR (c.code = '4002' AND p.code = '4000')
  OR (c.code = '4003' AND p.code = '4000')
  OR (c.code = '5001' AND p.code = '5000')
  OR (c.code = '5002' AND p.code = '5000')
  OR (c.code = '5003' AND p.code = '5000')
  OR (c.code = '6001' AND p.code = '6000')
  OR (c.code = '6002' AND p.code = '6000')
  OR (c.code = '6003' AND p.code = '6000')
  OR (c.code = '6004' AND p.code = '6000')
  OR (c.code = '6005' AND p.code = '6000')
  -- Level 3 → parent is level 2 (1001-01→1001, 4001-01→4001, etc.)
  OR (c.code = '1001-01' AND p.code = '1001')
  OR (c.code = '1001-02' AND p.code = '1001')
  OR (c.code = '1001-03' AND p.code = '1001')
  OR (c.code = '1001-04' AND p.code = '1001')
  OR (c.code = '4001-01' AND p.code = '4001')
  OR (c.code = '4001-02' AND p.code = '4001')
  OR (c.code = '4001-03' AND p.code = '4001')
  OR (c.code = '4001-04' AND p.code = '4001')
  OR (c.code = '5001-01' AND p.code = '5001')
  OR (c.code = '5001-02' AND p.code = '5001')
  OR (c.code = '5001-03' AND p.code = '5001')
  OR (c.code = '5001-04' AND p.code = '5001');

-- =============================================
-- 8. อัปเดต inventory_categories ให้ผูกบัญชีแยกตามหมวด
-- =============================================

-- การเกษตร (1-1-xx) → บัญชี xx-01
UPDATE public.inventory_categories
SET inventory_account_code = '1001-01',
    revenue_account_code = '4001-01',
    cost_account_code = '5001-01'
WHERE code LIKE '1-1-%';

-- อุตสาหกรรม (1-2-xx) → บัญชี xx-02
UPDATE public.inventory_categories
SET inventory_account_code = '1001-02',
    revenue_account_code = '4001-02',
    cost_account_code = '5001-02'
WHERE code LIKE '1-2-%';

-- อาหารและเครื่องดื่ม (1-3-xx) → บัญชี xx-03
UPDATE public.inventory_categories
SET inventory_account_code = '1001-03',
    revenue_account_code = '4001-03',
    cost_account_code = '5001-03'
WHERE code LIKE '1-3-%';

-- บรรจุภัณฑ์ (1-4-xx) → บัญชี xx-04
UPDATE public.inventory_categories
SET inventory_account_code = '1001-04',
    revenue_account_code = '4001-04',
    cost_account_code = '5001-04'
WHERE code LIKE '1-4-%';

-- หมวดหลัก สินค้า (1-0-00-00-00) → บัญชีรวม
UPDATE public.inventory_categories
SET inventory_account_code = '1001',
    revenue_account_code = '4001',
    cost_account_code = '5001'
WHERE code = '1-0-00-00-00';

-- =============================================
-- ตรวจสอบผล
-- =============================================
SELECT 'account_chart' AS table_name, COUNT(*) AS count FROM public.account_chart
UNION ALL
SELECT 'categories with accounts', COUNT(*) FROM public.inventory_categories WHERE inventory_account_code IS NOT NULL;
