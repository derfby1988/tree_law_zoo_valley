-- ============================================
-- แก้ไข Migration: ย้ายข้อมูลให้ถูกต้อง
-- สินค้าสำเร็จ (product) = 2 รายการ (quantity > 0)
-- วัตถุดิบ (ingredient) = 663 รายการ (ส่วนใหญ่)
-- ============================================

-- ขั้นตอนที่ 1: ลบข้อมูล 2 รายการที่คัดลอกผิดออกจาก inventory_ingredients
DELETE FROM inventory_ingredients;

-- ขั้นตอนที่ 2: ย้ายข้อมูลทั้งหมดจาก inventory_products ไป inventory_ingredients
-- (ยกเว้น 2 รายการที่เป็นสินค้าสำเร็จจริงๆ ซึ่งมี quantity > 0 และเป็น 2 รายการล่าสุด)
-- ก่อนอื่นดูก่อนว่าสินค้าสำเร็จ 2 รายการคืออะไร
SELECT id, name, quantity, price FROM inventory_products 
WHERE is_active = true AND quantity > 0 
ORDER BY quantity DESC 
LIMIT 10;
