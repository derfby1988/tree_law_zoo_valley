-- TREE LAW ZOO Valley Seed Data
-- ข้อมูลตัวอย่างสำหรับการทดสอบ

-- 1. สร้างหมวดหมู่อาหาร
INSERT INTO categories (name_th, name_en, description, sort_order) VALUES
('อาหารไทย', 'Thai Food', 'อาหารไทยแท้', 1),
('อาหารญี่ปุ่น', 'Japanese Food', 'อาหารญี่ปุ่น', 2),
('อาหารจีน', 'Chinese Food', 'อาหารจีน', 3),
('เครื่องดื่ม', 'Beverages', 'เครื่องดื่มต่างๆ', 4),
('ของหวาน', 'Desserts', 'ของหวาน', 5);

-- 2. สร้างโต๊ะ
INSERT INTO tables (table_number, capacity, location, description) VALUES
(1, 2, 'ด้านใน', 'โต๊ะสำหรับ 2 คน ริมหน้าต่าง'),
(2, 2, 'ด้านใน', 'โต๊ะสำหรับ 2 คน ใกล้ทางเข้า'),
(3, 4, 'ด้านใน', 'โต๊ะสำหรับ 4 คน กลางห้อง'),
(4, 4, 'ด้านใน', 'โต๊ะสำหรับ 4 คน ติดผนัง'),
(5, 6, 'ด้านนอก', 'โต๊ะสำหรับ 6 คน ระเบียง'),
(6, 8, 'ด้านนอก', 'โต๊ะสำหรับ 8 คน สวน'),
(7, 10, 'ห้อง VIP', 'โต๊ะสำหรับ 10 คน ห้องส่วนตัว'),
(8, 12, 'ห้อง VIP', 'โต๊ะสำหรับ 12 คน ห้องใหญ่');

-- 3. สร้างเมนูอาหาร
INSERT INTO menu_items (category_id, name_th, name_en, description_th, price, preparation_time, is_available) VALUES
-- อาหารไทย
(1, 'ผัดไทย', 'Pad Thai', 'ผัดไทยรสดั้นเดิม ใส่กุ้งสด เต้าหู้ ถั่วงอก', 120, 15, true),
(1, 'ต้มยำกุ้ง', 'Tom Yum Goong', 'ต้มยำกุ้งแม่น้ำเผือกรสเผ็ดดี', 180, 20, true),
(1, 'ผัดซีอิ๊ว', 'Pad See Ew', 'ผัดซีอิ๊วหมูย่าง ผักกวางตุ้ง', 100, 15, true),
(1, 'แกงเขียวหวานไก่', 'Green Curry Chicken', 'แกงเขียวหวานไก่ต้ม ใส้ยี่หร่า', 140, 20, true),
(1, 'มัสมั่นไก่', 'Massaman Curry', 'มัสมั่นไก่นุ่ม มันฝรั่ง ถั่วลิสง', 160, 25, true),

-- อาหารญี่ปุ่น
(2, 'ซูชิเซ็ต', 'Sushi Set', 'ซูชิสด 12 ชิ้น ปลาไข่ ปลาหมึก', 220, 20, true),
(2, 'ราเม็ง', 'Ramen', 'ราเม็งน้ำดำหมูชาชู ไข่ตุ๋น', 150, 15, true),
(2, 'เทมปุระ', 'Tempura', 'เทมปุระกุ้ง หอย ผัก', 180, 15, true),
(2, 'ซาชิมิ', 'Sashimi', 'ซาชิมิปลาแซลมอน ทูน่า', 280, 10, true),

-- อาหารจีน
(3, 'ข้าวผัด', 'Fried Rice', 'ข้าวผัดหมู ไข่ ผัก', 90, 10, true),
(3, 'ติ่มซำ', 'Dim Sum', 'ติ่มซำหมูสับ กุ้ง ซาลาเปา', 120, 20, true),
(3, 'หมูแดง', 'Char Siu', 'หมูแดงรสดั้นเดิม', 140, 15, true),
(3, 'เกี๊ยวซ่า', 'Wonton Soup', 'เกี๊ยวซ่าไก่ ผัก', 80, 10, true),

-- เครื่องดื่ม
(4, 'น้ำมะนาว', 'Lemon Juice', 'น้ำมะนาวสดหวานอมเปรี้ยว', 40, 5, true),
(4, 'ชาเย็น', 'Thai Tea', 'ชาเย็นไทย', 35, 5, true),
(4, 'กาแฟ', 'Coffee', 'กาแฟร้อน/เย็น', 50, 5, true),
(4, 'โคล่า', 'Cola', 'โคล่าเป็น', 30, 2, true),

-- ของหวาน
(5, 'ข้าวเหนียวมะม่วง', 'Mango Sticky Rice', 'ข้าวเหนียวมะม่วงสุดฟิน', 80, 5, true),
(5, 'ลูกชิ้นหน้าต่างๆ', 'Various Toppings', 'ลูกชิ้นไทยหน้าต่างๆ', 60, 5, true),
(5, 'ไอศกรีม', 'Ice Cream', 'ไอศกรีมวนิลา ช็อกโกแลต', 70, 3, true);

-- 4. สร้างโปรโมชั่น
INSERT INTO promotions (title, description, discount_type, discount_value, min_order_amount, start_date, end_date) VALUES
('ลด 10% สำหรับอาหารไทย', 'ลด 10% สำหรับเมนูอาหารไทยทุกรายการ', 'percentage', 10, 200, '2024-01-01', '2024-12-31'),
('ซื้อ 2 แถม 1 เครื่องดื่ม', 'ซื้อเครื่องดื่ม 2 แก้ว แถม 1 แก้ว', 'buy_one_get_one', 0, 60, '2024-01-01', '2024-06-30'),
('ลด 50 บาท สำหรับอาหารจีน', 'ลด 50 บาท เมื่อสั่งอาหารจีน 300 บาทขึ้นไป', 'fixed_amount', 50, 300, '2024-01-01', '2024-12-31');

-- 5. สร้างผู้ใช้
INSERT INTO users (username, email, full_name, phone, role, is_active) VALUES
('admin', 'admin@treezoo.com', 'Administrator', '0800000001', 'admin', true),
('staff1', 'staff1@treezoo.com', 'สมชาย ใจดี', '0800000002', 'staff', true),
('staff2', 'staff2@treezoo.com', 'สมศรี รักดี', '0800000003', 'staff', true),
('customer1', 'customer1@email.com', 'ลูกค้าคนที่ 1', '0900000001', 'customer', true),
('customer2', 'customer2@email.com', 'ลูกค้าคนที่ 2', '0900000002', 'customer', true);

-- 6. สร้างการตั้งค่า
INSERT INTO settings (key, value, description, data_type, is_public, category) VALUES
('restaurant_name', 'TREE LAW ZOO Valley', 'ชื่อร้านอาหาร', 'string', true, 'general'),
('restaurant_phone', '0800000000', 'เบอร์โทรศัพท์ร้าน', 'string', true, 'contact'),
('restaurant_address', '123 ถนนสุขุมวิท กรุงเทพฯ', 'ที่อยู่ร้าน', 'string', true, 'contact'),
('opening_hours', '{"monday":"11:00-22:00","tuesday":"11:00-22:00","wednesday":"11:00-22:00","thursday":"11:00-22:00","friday":"11:00-22:00","saturday":"11:00-23:00","sunday":"11:00-23:00"}', 'เวลาเปิด-ปิด', 'json', true, 'general'),
('currency', 'THB', 'สกุลเงิน', 'string', true, 'general'),
('tax_rate', '7', 'อัตราภาษี (%)', 'number', false, 'billing'),
('service_charge', '10', 'ค่าบริการ (%)', 'number', false, 'billing'),
('max_booking_days', '30', 'จำนวนวันสูงสุดที่จองได้', 'number', false, 'booking'),
('booking_time_slot', '30', 'ช่วงเวลาการจอง (นาที)', 'number', false, 'booking'),
('auto_confirm_booking', 'false', 'ยืนยันการจองอัตโนมัติ', 'boolean', false, 'booking'),
('enable_online_payment', 'false', 'เปิดใช้งานการชำระเงินออนไลน์', 'boolean', false, 'payment');

-- 7. สร้างการจองตัวอย่าง
INSERT INTO bookings (table_id, customer_name, customer_phone, booking_date, booking_time, number_of_people, status, special_requests) VALUES
(3, 'สมชาย ใจดี', '0900000001', '2024-01-26', '19:00', 4, 'confirmed', 'โต๊ะริมหน้าต่าง'),
(5, 'สมศรี รักดี', '0900000002', '2024-01-26', '20:00', 6, 'pending', 'มีเด็ก 2 คน'),
(1, 'ลูกค้าคนที่ 1', '0900000003', '2024-01-27', '18:30', 2, 'confirmed', 'ฉลองวันเกิด');

-- 8. สร้างคำสั่งซื้อตัวอย่าง
INSERT INTO orders (table_id, order_number, items, subtotal, tax_amount, total_amount, status, staff_id) VALUES
(3, 'ORD001', '[{"item_id":1,"quantity":2,"price":120},{"item_id":14,"quantity":3,"price":40}]', 360, 25.2, 385.2, 'completed', 'staff1'),
(5, 'ORD002', '[{"item_id":6,"quantity":1,"price":220},{"item_id":7,"quantity":2,"price":150}]', 520, 36.4, 556.4, 'preparing', 'staff2');

-- 9. สร้าง sync log ตัวอย่าง
INSERT INTO sync_log (table_name, operation, record_id, sync_version, device_id, status) VALUES
('tables', 'insert', 1, 1, 'main_server', 'success'),
('tables', 'insert', 2, 1, 'main_server', 'success'),
('menu_items', 'insert', 1, 1, 'main_server', 'success'),
('bookings', 'insert', 1, 1, 'main_server', 'success');

-- แสดงข้อมูลที่สร้าง
SELECT 'Categories' as table_name, COUNT(*) as count FROM categories
UNION ALL
SELECT 'Tables', COUNT(*) FROM tables
UNION ALL
SELECT 'Menu Items', COUNT(*) FROM menu_items
UNION ALL
SELECT 'Promotions', COUNT(*) FROM promotions
UNION ALL
SELECT 'Users', COUNT(*) FROM users
UNION ALL
SELECT 'Settings', COUNT(*) FROM settings
UNION ALL
SELECT 'Bookings', COUNT(*) FROM bookings
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders
UNION ALL
SELECT 'Sync Log', COUNT(*) FROM sync_log;
