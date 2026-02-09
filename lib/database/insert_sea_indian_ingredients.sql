-- ============================================
-- วัตถุดิบเวียดนาม (Vietnamese Ingredients)
-- calories = kcal ต่อ 1 กรัม
-- category: วัตถุดิบเวียดนาม = b9e65ff8-a54d-4116-825c-0d9bde5f08fd
-- ============================================

INSERT INTO inventory_ingredients (name, category_id, unit_id, quantity, calories, is_active) VALUES
('น้ำมะม่วง (เวียดนาม)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.3500, true),
('ซอสศรีราชา', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.9300, true),
('เส้นเฝอ (เส้นก๋วยเตี๋ยวเวียดนาม)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 1.0900, true),
('เส้นบุ๋น (เส้นขนมจีนเวียดนาม)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 1.0500, true),
('แผ่นไรซ์เปเปอร์', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'fc2bfac6-7743-4407-a2c4-1be67eaccaa5', 0, 3.0000, true),
('ซอสโฮซิน (เวียดนาม)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 2.2000, true),
('น้ำจิ้มเวียดนาม (เนืองจ่าม)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.4500, true),
('ผักชีเวียดนาม (ผักแพว)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.2300, true),
('โหระพาเวียดนาม', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.2300, true),
('ถั่วลิสงคั่ว', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 5.8500, true),
('กาแฟเวียดนาม (ผง)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.5300, true),
('ซอสปลาเวียดนาม (หน่อกมาม)', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.3500, true),
('เครื่องเทศเฝอ', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 2.5000, true),
('หอมเจียว', 'b9e65ff8-a54d-4116-825c-0d9bde5f08fd', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 5.0000, true);

-- ============================================
-- วัตถุดิบลาว (Lao Ingredients)
-- category: วัตถุดิบ = 3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb (ใช้ทั่วไป)
-- ============================================

INSERT INTO inventory_ingredients (name, category_id, unit_id, quantity, calories, is_active) VALUES
('ปลาร้า', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.9700, true),
('น้ำปลาร้า', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.4500, true),
('ข้าวเหนียวนึ่ง', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 1.6900, true),
('ข้าวคั่ว', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.8000, true),
('แจ่ว (น้ำจิ้มลาว)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.5000, true),
('ผักกาดขาว', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.1300, true),
('ผักหนอก (ผักแขยง)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.2500, true),
('ดีปลี', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 2.5100, true),
('ใบยานาง', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.3500, true),
('หน่อไม้สด', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.2700, true);

-- ============================================
-- วัตถุดิบมาเลเซีย (Malaysian Ingredients)
-- category: วัตถุดิบ = 3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb
-- ============================================

INSERT INTO inventory_ingredients (name, category_id, unit_id, quantity, calories, is_active) VALUES
('กะทิมาเลเซีย (ซันตัน)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 2.3000, true),
('ซอสซัมบัล', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 1.5000, true),
('กะปิมาเลเซีย (เบลาจัน)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 1.5200, true),
('ใบเตย (ใบปาหนัน)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', '44763b15-6934-4f13-9011-d3e414fe2eb0', 0, 0.3500, true),
('ขมิ้น', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.1200, true),
('ลูกจันทน์เทศ', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 5.2500, true),
('เส้นหมี่มาเลเซีย (มีฮุน)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.6400, true),
('เส้นก๋วยเตี๋ยวมาเลเซีย (กวยเตี๋ยว)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 1.1000, true),
('ซอสนาซิเลอมัก', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 1.0000, true),
('ผงเรนดัง', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 2.5000, true),
('ถั่วลิสงมาเลเซีย (สำหรับสะเต๊ะ)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 5.6700, true);

-- ============================================
-- วัตถุดิบอินเดีย (Indian Ingredients)
-- category: วัตถุดิบ = 3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb
-- ============================================

INSERT INTO inventory_ingredients (name, category_id, unit_id, quantity, calories, is_active) VALUES
('ผงกะหรี่ (เคอร์รี่พาวเดอร์)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.2500, true),
('ผงขมิ้น (เทอร์เมอริก)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.1200, true),
('ผงยี่หร่า (คิวมิน)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.7500, true),
('ผงผักชี (คอเรียนเดอร์)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 2.9800, true),
('การัมมาซาลา', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.7900, true),
('ผงพริกแดงอินเดีย', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.1400, true),
('ผงมัสตาร์ด', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 5.0800, true),
('เมล็ดเฟนูกรีก', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.2300, true),
('กระวาน', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.1100, true),
('เมล็ดยี่หร่า', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.7500, true),
('เมล็ดผักชี', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 2.9800, true),
('เนยใส (กี)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 9.0000, true),
('โยเกิร์ต', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.5900, true),
('แป้งนาน', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 2.6200, true),
('ข้าวบาสมาติ', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.5600, true),
('ถั่วเลนทิล (ดาล)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.5300, true),
('ถั่วชิกพี (ถั่วลูกไก่)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.6400, true),
('มะเขือเทศบด (กระป๋อง)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'ca685ee6-834d-44ed-a120-f11d6afada82', 0, 0.2900, true),
('ซอสทันดูรี', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', '316dfaab-3888-4dac-ab1a-b256068eb2b4', 0, 0.8000, true),
('หญ้าฝรั่น (ซาฟฟรอน)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 3.1000, true),
('ผงชาอินเดีย (มาซาลาชาย)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 2.5000, true),
('มะม่วงดิบ (อาจาร์)', '3ea9dd88-7dfa-443c-9f73-c3f2f7fbfcfb', 'c140191b-1ca3-4db9-ae9b-da0df37eea37', 0, 0.6000, true);

-- ตรวจสอบ
SELECT 'SE Asian + Indian ingredients' as status, COUNT(*) as count FROM inventory_ingredients WHERE is_active = true;
