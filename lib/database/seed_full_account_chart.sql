-- =============================================
-- ผังบัญชีมาตรฐานไทย (ตามกรมพัฒนาธุรกิจการค้า)
-- ~150 บัญชี ครอบคลุมทุกหมวด 1-8
-- รันใน Supabase SQL Editor
-- =============================================
-- หมายเหตุ: ใช้ ON CONFLICT (code) DO NOTHING เพื่อไม่ทับบัญชีที่มีอยู่แล้ว

-- =============================================
-- หมวด 1: สินทรัพย์ (Assets)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
-- 1.1 สินทรัพย์หมุนเวียน
('1000', 'สินทรัพย์หมุนเวียน', 'Current Assets', 'asset', 1),
('1100', 'เงินสดและรายการเทียบเท่าเงินสด', 'Cash and Cash Equivalents', 'asset', 2),
('1101', 'เงินสด', 'Cash on Hand', 'asset', 3),
('1102', 'เงินฝากธนาคาร - ออมทรัพย์', 'Savings Account', 'asset', 3),
('1103', 'เงินฝากธนาคาร - กระแสรายวัน', 'Current Account', 'asset', 3),
('1104', 'เงินสดย่อย', 'Petty Cash', 'asset', 3),
('1105', 'เงินฝากประจำ', 'Fixed Deposit', 'asset', 3),

('1200', 'ลูกหนี้การค้าและตั๋วเงินรับ', 'Trade Receivables', 'asset', 2),
('1201', 'ลูกหนี้การค้า', 'Accounts Receivable', 'asset', 3),
('1202', 'ตั๋วเงินรับ', 'Notes Receivable', 'asset', 3),
('1203', 'ค่าเผื่อหนี้สงสัยจะสูญ', 'Allowance for Doubtful Accounts', 'asset', 3),
('1204', 'รายได้ค้างรับ', 'Accrued Revenue', 'asset', 3),
('1205', 'ลูกหนี้อื่น', 'Other Receivables', 'asset', 3),

('1300', 'สินค้าคงเหลือ', 'Inventories', 'asset', 2),
('1301', 'สินค้าสำเร็จรูป', 'Finished Goods', 'asset', 3),
('1301-01', 'สินค้าสำเร็จรูป - การเกษตร', 'Finished Goods - Agriculture', 'asset', 4),
('1301-02', 'สินค้าสำเร็จรูป - อุตสาหกรรม', 'Finished Goods - Industrial', 'asset', 4),
('1301-03', 'สินค้าสำเร็จรูป - อาหารและเครื่องดื่ม', 'Finished Goods - Food & Beverage', 'asset', 4),
('1301-04', 'สินค้าสำเร็จรูป - บรรจุภัณฑ์', 'Finished Goods - Packaging', 'asset', 4),
('1302', 'วัตถุดิบ', 'Raw Materials', 'asset', 3),
('1303', 'งานระหว่างทำ', 'Work in Process', 'asset', 3),
('1304', 'วัสดุสิ้นเปลือง', 'Supplies', 'asset', 3),
('1305', 'สินค้าระหว่างทาง', 'Goods in Transit', 'asset', 3),
('1306', 'ค่าเผื่อสินค้าเสื่อมสภาพ', 'Allowance for Obsolete Inventory', 'asset', 3),

('1400', 'สินทรัพย์หมุนเวียนอื่น', 'Other Current Assets', 'asset', 2),
('1401', 'ค่าใช้จ่ายจ่ายล่วงหน้า', 'Prepaid Expenses', 'asset', 3),
('1402', 'ภาษีซื้อ', 'Input VAT', 'asset', 3),
('1403', 'ภาษีซื้อยังไม่ถึงกำหนด', 'Deferred Input VAT', 'asset', 3),
('1404', 'ภาษีหัก ณ ที่จ่าย', 'Withholding Tax Receivable', 'asset', 3),
('1405', 'เงินมัดจำ', 'Deposits', 'asset', 3),
('1406', 'เงินทดรองจ่าย', 'Advance Payments', 'asset', 3),

-- 1.2 สินทรัพย์ไม่หมุนเวียน
('1500', 'สินทรัพย์ไม่หมุนเวียน', 'Non-Current Assets', 'asset', 1),
('1501', 'ที่ดิน', 'Land', 'asset', 2),
('1502', 'อาคาร', 'Buildings', 'asset', 2),
('1503', 'ค่าเสื่อมราคาสะสม - อาคาร', 'Accumulated Depreciation - Buildings', 'asset', 2),
('1504', 'เครื่องจักรและอุปกรณ์', 'Machinery and Equipment', 'asset', 2),
('1505', 'ค่าเสื่อมราคาสะสม - เครื่องจักร', 'Accumulated Depreciation - Machinery', 'asset', 2),
('1506', 'เครื่องตกแต่งและติดตั้ง', 'Furniture and Fixtures', 'asset', 2),
('1507', 'ค่าเสื่อมราคาสะสม - เครื่องตกแต่ง', 'Accumulated Depreciation - Furniture', 'asset', 2),
('1508', 'ยานพาหนะ', 'Vehicles', 'asset', 2),
('1509', 'ค่าเสื่อมราคาสะสม - ยานพาหนะ', 'Accumulated Depreciation - Vehicles', 'asset', 2),
('1510', 'อุปกรณ์สำนักงาน', 'Office Equipment', 'asset', 2),
('1511', 'ค่าเสื่อมราคาสะสม - อุปกรณ์สำนักงาน', 'Accumulated Depreciation - Office Equipment', 'asset', 2),
('1512', 'คอมพิวเตอร์และอุปกรณ์', 'Computer and Equipment', 'asset', 2),
('1513', 'ค่าเสื่อมราคาสะสม - คอมพิวเตอร์', 'Accumulated Depreciation - Computer', 'asset', 2),
('1520', 'สินทรัพย์ไม่มีตัวตน', 'Intangible Assets', 'asset', 2),
('1521', 'ค่าลิขสิทธิ์ซอฟต์แวร์', 'Software License', 'asset', 3),
('1522', 'ค่าตัดจำหน่ายสะสม', 'Accumulated Amortization', 'asset', 3)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- หมวด 2: หนี้สิน (Liabilities)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
-- 2.1 หนี้สินหมุนเวียน
('2000', 'หนี้สินหมุนเวียน', 'Current Liabilities', 'liability', 1),
('2100', 'เจ้าหนี้การค้าและตั๋วเงินจ่าย', 'Trade Payables', 'liability', 2),
('2101', 'เจ้าหนี้การค้า', 'Accounts Payable', 'liability', 3),
('2102', 'ตั๋วเงินจ่าย', 'Notes Payable', 'liability', 3),
('2103', 'เจ้าหนี้อื่น', 'Other Payables', 'liability', 3),

('2200', 'ค่าใช้จ่ายค้างจ่าย', 'Accrued Expenses', 'liability', 2),
('2201', 'เงินเดือนค้างจ่าย', 'Accrued Salaries', 'liability', 3),
('2202', 'ดอกเบี้ยค้างจ่าย', 'Accrued Interest', 'liability', 3),
('2203', 'ค่าสาธารณูปโภคค้างจ่าย', 'Accrued Utilities', 'liability', 3),

('2300', 'ภาษีและเงินสมทบค้างจ่าย', 'Tax and Contributions Payable', 'liability', 2),
('2301', 'ภาษีขาย', 'Output VAT', 'liability', 3),
('2302', 'ภาษีหัก ณ ที่จ่ายค้างจ่าย', 'Withholding Tax Payable', 'liability', 3),
('2303', 'เงินสมทบประกันสังคมค้างจ่าย', 'Social Security Payable', 'liability', 3),
('2304', 'ภาษีเงินได้นิติบุคคลค้างจ่าย', 'Corporate Income Tax Payable', 'liability', 3),

('2400', 'หนี้สินหมุนเวียนอื่น', 'Other Current Liabilities', 'liability', 2),
('2401', 'รายได้รับล่วงหน้า', 'Unearned Revenue', 'liability', 3),
('2402', 'เงินรับล่วงหน้าจากลูกค้า', 'Customer Deposits', 'liability', 3),
('2403', 'เงินกู้ยืมระยะสั้น', 'Short-term Loans', 'liability', 3),
('2404', 'ส่วนของเงินกู้ที่ถึงกำหนดภายใน 1 ปี', 'Current Portion of Long-term Debt', 'liability', 3),

-- 2.2 หนี้สินไม่หมุนเวียน
('2500', 'หนี้สินไม่หมุนเวียน', 'Non-Current Liabilities', 'liability', 1),
('2501', 'เงินกู้ยืมระยะยาว', 'Long-term Loans', 'liability', 2),
('2502', 'หนี้สินตามสัญญาเช่า', 'Lease Liabilities', 'liability', 2),
('2503', 'เงินประกันรับ', 'Security Deposits Received', 'liability', 2),
('2504', 'ประมาณการหนี้สินผลประโยชน์พนักงาน', 'Employee Benefit Obligations', 'liability', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- หมวด 3: ส่วนของเจ้าของ (Equity)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('3000', 'ส่วนของเจ้าของ', 'Owner Equity', 'equity', 1),
('3001', 'ทุนจดทะเบียน', 'Registered Capital', 'equity', 2),
('3002', 'ทุนที่ออกและชำระแล้ว', 'Issued and Paid-up Capital', 'equity', 2),
('3003', 'ส่วนเกินมูลค่าหุ้น', 'Share Premium', 'equity', 2),
('3004', 'กำไรสะสม - จัดสรรแล้ว', 'Appropriated Retained Earnings', 'equity', 2),
('3005', 'กำไรสะสม - ยังไม่ได้จัดสรร', 'Unappropriated Retained Earnings', 'equity', 2),
('3006', 'สำรองตามกฎหมาย', 'Legal Reserve', 'equity', 2),
('3007', 'กำไร(ขาดทุน)สุทธิประจำปี', 'Net Income (Loss) for the Year', 'equity', 2),
('3008', 'ถอนใช้ส่วนตัว', 'Owner Withdrawals', 'equity', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- หมวด 4: รายได้ (Revenue)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('4000', 'รายได้', 'Revenue', 'revenue', 1),
('4100', 'รายได้จากการขายสินค้า', 'Sales Revenue', 'revenue', 2),
('4101', 'ขายสินค้า - ในประเทศ', 'Domestic Sales', 'revenue', 3),
('4101-01', 'ขายสินค้า - การเกษตร', 'Sales - Agriculture', 'revenue', 4),
('4101-02', 'ขายสินค้า - อุตสาหกรรม', 'Sales - Industrial', 'revenue', 4),
('4101-03', 'ขายสินค้า - อาหารและเครื่องดื่ม', 'Sales - Food & Beverage', 'revenue', 4),
('4101-04', 'ขายสินค้า - บรรจุภัณฑ์', 'Sales - Packaging', 'revenue', 4),
('4102', 'ขายสินค้า - ต่างประเทศ', 'Export Sales', 'revenue', 3),
('4103', 'รับคืนสินค้า', 'Sales Returns', 'revenue', 3),
('4104', 'ส่วนลดจ่าย', 'Sales Discounts', 'revenue', 3),

('4200', 'รายได้จากการให้บริการ', 'Service Revenue', 'revenue', 2),
('4201', 'รายได้ค่าบริการ', 'Service Income', 'revenue', 3),
('4202', 'รายได้ค่าที่ปรึกษา', 'Consulting Income', 'revenue', 3),
('4203', 'รายได้ค่าเช่า', 'Rental Income', 'revenue', 3),

('4300', 'รายได้อื่น', 'Other Revenue', 'revenue', 2),
('4301', 'ดอกเบี้ยรับ', 'Interest Income', 'revenue', 3),
('4302', 'กำไรจากการจำหน่ายสินทรัพย์', 'Gain on Disposal of Assets', 'revenue', 3),
('4303', 'กำไรจากอัตราแลกเปลี่ยน', 'Foreign Exchange Gain', 'revenue', 3),
('4304', 'รายได้เบ็ดเตล็ด', 'Miscellaneous Income', 'revenue', 3)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- หมวด 5: ต้นทุนขาย (Cost of Goods Sold)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('5000', 'ต้นทุนขาย', 'Cost of Goods Sold', 'cogs', 1),
('5100', 'ต้นทุนสินค้าที่ขาย', 'Cost of Goods Sold - Direct', 'cogs', 2),
('5101', 'ซื้อสินค้า', 'Purchases', 'cogs', 3),
('5101-01', 'ซื้อสินค้า - การเกษตร', 'Purchases - Agriculture', 'cogs', 4),
('5101-02', 'ซื้อสินค้า - อุตสาหกรรม', 'Purchases - Industrial', 'cogs', 4),
('5101-03', 'ซื้อสินค้า - อาหารและเครื่องดื่ม', 'Purchases - Food & Beverage', 'cogs', 4),
('5101-04', 'ซื้อสินค้า - บรรจุภัณฑ์', 'Purchases - Packaging', 'cogs', 4),
('5102', 'ค่าขนส่งเข้า', 'Freight In', 'cogs', 3),
('5103', 'ส่วนลดรับ', 'Purchase Discounts', 'cogs', 3),
('5104', 'ส่งคืนสินค้า', 'Purchase Returns', 'cogs', 3),

('5200', 'ต้นทุนการผลิต', 'Manufacturing Costs', 'cogs', 2),
('5201', 'วัตถุดิบใช้ไป', 'Raw Materials Used', 'cogs', 3),
('5202', 'ค่าแรงงานทางตรง', 'Direct Labor', 'cogs', 3),
('5203', 'ค่าโสหุ้ยการผลิต', 'Manufacturing Overhead', 'cogs', 3),
('5204', 'ค่าเสื่อมราคา - เครื่องจักร', 'Depreciation - Machinery', 'cogs', 3),
('5205', 'ค่าซ่อมแซมเครื่องจักร', 'Machine Repairs', 'cogs', 3),
('5206', 'ค่าสาธารณูปโภค - โรงงาน', 'Factory Utilities', 'cogs', 3),

('5300', 'ต้นทุนบริการ', 'Cost of Services', 'cogs', 2),
('5301', 'ค่าแรงงานบริการ', 'Service Labor', 'cogs', 3),
('5302', 'วัสดุสิ้นเปลืองบริการ', 'Service Supplies', 'cogs', 3)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- หมวด 6: ค่าใช้จ่ายในการขาย (Selling Expenses)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('6000', 'ค่าใช้จ่ายในการขาย', 'Selling Expenses', 'expense', 1),
('6100', 'ค่าใช้จ่ายเกี่ยวกับพนักงานขาย', 'Sales Staff Expenses', 'expense', 2),
('6101', 'เงินเดือนพนักงานขาย', 'Sales Salaries', 'expense', 3),
('6102', 'ค่าคอมมิชชั่น', 'Sales Commissions', 'expense', 3),
('6103', 'ค่าเบี้ยเลี้ยงพนักงานขาย', 'Sales Allowances', 'expense', 3),
('6104', 'ค่าเดินทางพนักงานขาย', 'Sales Travel Expenses', 'expense', 3),

('6200', 'ค่าใช้จ่ายในการส่งเสริมการขาย', 'Promotional Expenses', 'expense', 2),
('6201', 'ค่าโฆษณา', 'Advertising', 'expense', 3),
('6202', 'ค่าส่งเสริมการขาย', 'Sales Promotion', 'expense', 3),
('6203', 'ค่าตัวอย่างสินค้า', 'Product Samples', 'expense', 3),
('6204', 'ค่าจัดงานแสดงสินค้า', 'Trade Show Expenses', 'expense', 3),

('6300', 'ค่าใช้จ่ายในการจัดส่ง', 'Distribution Expenses', 'expense', 2),
('6301', 'ค่าขนส่งสินค้า', 'Freight Out', 'expense', 3),
('6302', 'ค่าบรรจุหีบห่อ', 'Packing Expenses', 'expense', 3),
('6303', 'ค่าประกันภัยสินค้า', 'Cargo Insurance', 'expense', 3),

('6400', 'ค่าใช้จ่ายในการขายอื่น', 'Other Selling Expenses', 'expense', 2),
('6401', 'ค่าเช่าร้าน/สาขา', 'Store/Branch Rent', 'expense', 3),
('6402', 'ค่าเสื่อมราคา - อุปกรณ์ขาย', 'Depreciation - Sales Equipment', 'expense', 3),
('6403', 'หนี้สูญ', 'Bad Debts', 'expense', 3),
('6404', 'ค่าบริการบัตรเครดิต', 'Credit Card Fees', 'expense', 3)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- หมวด 7: ค่าใช้จ่ายในการบริหาร (Administrative Expenses)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('7000', 'ค่าใช้จ่ายในการบริหาร', 'Administrative Expenses', 'expense', 1),
('7100', 'ค่าใช้จ่ายเกี่ยวกับพนักงาน', 'Staff Expenses', 'expense', 2),
('7101', 'เงินเดือนและค่าจ้าง', 'Salaries and Wages', 'expense', 3),
('7102', 'ค่าล่วงเวลา', 'Overtime', 'expense', 3),
('7103', 'โบนัส', 'Bonuses', 'expense', 3),
('7104', 'เงินสมทบประกันสังคม', 'Social Security Contributions', 'expense', 3),
('7105', 'เงินสมทบกองทุนสำรองเลี้ยงชีพ', 'Provident Fund Contributions', 'expense', 3),
('7106', 'สวัสดิการพนักงาน', 'Employee Benefits', 'expense', 3),
('7107', 'ค่ารักษาพยาบาล', 'Medical Expenses', 'expense', 3),
('7108', 'ค่าฝึกอบรม', 'Training Expenses', 'expense', 3),

('7200', 'ค่าใช้จ่ายสำนักงาน', 'Office Expenses', 'expense', 2),
('7201', 'ค่าเช่าสำนักงาน', 'Office Rent', 'expense', 3),
('7202', 'ค่าไฟฟ้า', 'Electricity', 'expense', 3),
('7203', 'ค่าน้ำประปา', 'Water Supply', 'expense', 3),
('7204', 'ค่าโทรศัพท์และอินเทอร์เน็ต', 'Telephone and Internet', 'expense', 3),
('7205', 'ค่าไปรษณีย์', 'Postage', 'expense', 3),
('7206', 'ค่าวัสดุสำนักงาน', 'Office Supplies', 'expense', 3),
('7207', 'ค่าซ่อมแซมบำรุงรักษา', 'Repairs and Maintenance', 'expense', 3),
('7208', 'ค่าทำความสะอาด', 'Cleaning Expenses', 'expense', 3),

('7300', 'ค่าใช้จ่ายวิชาชีพ', 'Professional Fees', 'expense', 2),
('7301', 'ค่าสอบบัญชี', 'Audit Fees', 'expense', 3),
('7302', 'ค่าที่ปรึกษากฎหมาย', 'Legal Fees', 'expense', 3),
('7303', 'ค่าที่ปรึกษาภาษี', 'Tax Advisory Fees', 'expense', 3),
('7304', 'ค่าบริการทำบัญชี', 'Accounting Service Fees', 'expense', 3),

('7400', 'ค่าเสื่อมราคาและค่าตัดจำหน่าย', 'Depreciation and Amortization', 'expense', 2),
('7401', 'ค่าเสื่อมราคา - อาคาร', 'Depreciation - Buildings', 'expense', 3),
('7402', 'ค่าเสื่อมราคา - เครื่องตกแต่ง', 'Depreciation - Furniture', 'expense', 3),
('7403', 'ค่าเสื่อมราคา - ยานพาหนะ', 'Depreciation - Vehicles', 'expense', 3),
('7404', 'ค่าเสื่อมราคา - อุปกรณ์สำนักงาน', 'Depreciation - Office Equipment', 'expense', 3),
('7405', 'ค่าเสื่อมราคา - คอมพิวเตอร์', 'Depreciation - Computer', 'expense', 3),
('7406', 'ค่าตัดจำหน่ายสินทรัพย์ไม่มีตัวตน', 'Amortization - Intangible Assets', 'expense', 3),

('7500', 'ค่าใช้จ่ายในการบริหารอื่น', 'Other Administrative Expenses', 'expense', 2),
('7501', 'ค่าประกันภัย', 'Insurance', 'expense', 3),
('7502', 'ค่าภาษีและค่าธรรมเนียม', 'Taxes and Fees', 'expense', 3),
('7503', 'ค่าเดินทาง', 'Travel Expenses', 'expense', 3),
('7504', 'ค่ารับรอง', 'Entertainment', 'expense', 3),
('7505', 'เงินบริจาค', 'Donations', 'expense', 3),
('7506', 'ค่าธรรมเนียมธนาคาร', 'Bank Charges', 'expense', 3),
('7507', 'ค่าเบ็ดเตล็ด', 'Miscellaneous Expenses', 'expense', 3)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- หมวด 8: รายได้และค่าใช้จ่ายอื่น (Other Income/Expenses)
-- =============================================
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
('8000', 'รายได้และค่าใช้จ่ายอื่น', 'Other Income and Expenses', 'revenue', 1),
('8100', 'ดอกเบี้ยจ่าย', 'Interest Expense', 'expense', 2),
('8101', 'ดอกเบี้ยจ่าย - เงินกู้', 'Interest on Loans', 'expense', 3),
('8102', 'ดอกเบี้ยจ่าย - สัญญาเช่า', 'Interest on Leases', 'expense', 3),

('8200', 'ขาดทุนอื่น', 'Other Losses', 'expense', 2),
('8201', 'ขาดทุนจากการจำหน่ายสินทรัพย์', 'Loss on Disposal of Assets', 'expense', 3),
('8202', 'ขาดทุนจากอัตราแลกเปลี่ยน', 'Foreign Exchange Loss', 'expense', 3),
('8203', 'ขาดทุนจากการด้อยค่าสินทรัพย์', 'Impairment Loss', 'expense', 3),

('8300', 'ภาษีเงินได้', 'Income Tax', 'expense', 2),
('8301', 'ภาษีเงินได้นิติบุคคล', 'Corporate Income Tax', 'expense', 3),
('8302', 'ภาษีเงินได้รอตัดบัญชี', 'Deferred Income Tax', 'expense', 3)
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- อัปเดต inventory_categories ให้ผูกบัญชีแยกตามหมวด
-- (ใช้รหัสใหม่ 1301-xx แทน 1001-xx)
-- =============================================

-- การเกษตร (1-1-xx) → บัญชีสินค้า 1301-01, รายได้ 4101-01, ต้นทุน 5101-01
UPDATE public.inventory_categories
SET inventory_account_code = '1301-01',
    revenue_account_code = '4101-01',
    cost_account_code = '5101-01'
WHERE code LIKE '1-1-%';

-- อุตสาหกรรม (1-2-xx) → 1301-02, 4101-02, 5101-02
UPDATE public.inventory_categories
SET inventory_account_code = '1301-02',
    revenue_account_code = '4101-02',
    cost_account_code = '5101-02'
WHERE code LIKE '1-2-%';

-- อาหารและเครื่องดื่ม (1-3-xx) → 1301-03, 4101-03, 5101-03
UPDATE public.inventory_categories
SET inventory_account_code = '1301-03',
    revenue_account_code = '4101-03',
    cost_account_code = '5101-03'
WHERE code LIKE '1-3-%';

-- บรรจุภัณฑ์ (1-4-xx) → 1301-04, 4101-04, 5101-04
UPDATE public.inventory_categories
SET inventory_account_code = '1301-04',
    revenue_account_code = '4101-04',
    cost_account_code = '5101-04'
WHERE code LIKE '1-4-%';

-- หมวดหลัก สินค้า (1-0-00-00-00) → บัญชีรวม
UPDATE public.inventory_categories
SET inventory_account_code = '1301',
    revenue_account_code = '4101',
    cost_account_code = '5101'
WHERE code = '1-0-00-00-00';

-- =============================================
-- ตรวจสอบผล
-- =============================================
SELECT 'account_chart' AS table_name, COUNT(*) AS count FROM public.account_chart
UNION ALL
SELECT 'categories with accounts', COUNT(*) FROM public.inventory_categories WHERE inventory_account_code IS NOT NULL;
