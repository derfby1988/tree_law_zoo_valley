-- ตรวจสอบว่าใครอ้างอิงวัตถุดิบเหล่านี้อยู่บ้าง
SELECT 
  ri.id as recipe_ingredient_id,
  ri.quantity as recipe_quantity,
  p.name as product_name,
  p.quantity as product_quantity,
  r.name as recipe_name
FROM inventory_recipe_ingredients ri
JOIN inventory_products p ON ri.product_id = p.id
JOIN inventory_recipes r ON ri.recipe_id = r.id
WHERE p.quantity = 0 AND p.is_active = true
ORDER BY p.created_at DESC;
