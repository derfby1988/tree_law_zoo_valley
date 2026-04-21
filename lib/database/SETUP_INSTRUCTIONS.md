# 📋 Production Validation Setup Instructions

## 🚀 วิธีการรัน SQL

### **ขั้นตอน:**

1. เปิด **Supabase Dashboard**
2. ไปที่ **SQL Editor**
3. รันแต่ละ STEP ตามลำดับ

---

## 📝 STEP 1: Add CHECK Constraints (5 นาที)

**ไฟล์:** `STEP_1_add_constraints.sql`

**ทำอะไร:**
- ✅ ป้องกัน negative quantity ใน inventory_products
- ✅ ป้องกัน negative quantity ใน inventory_ingredients

**วิธี:**
1. เปิด `STEP_1_add_constraints.sql`
2. Copy ทั้งหมด
3. Paste ใน Supabase SQL Editor
4. Click **Run**
5. ตรวจสอบ: ควรเห็น 2 constraints

**ผลลัพธ์:**
```
✅ check_quantity_not_negative (inventory_products)
✅ check_ingredient_quantity_not_negative (inventory_ingredients)
```

---

## 📝 STEP 2: Create Validation Function (10 นาที)

**ไฟล์:** `STEP_2_create_validation_function.sql`

**ทำอะไร:**
- ✅ สร้าง `check_recipe_can_produce()` function
- ✅ ตรวจสอบว่าสต็อกพอหรือไม่

**วิธี:**
1. เปิด `STEP_2_create_validation_function.sql`
2. Copy ทั้งหมด
3. Paste ใน Supabase SQL Editor
4. Click **Run**
5. ตรวจสอบ: ควรเห็น "CREATE FUNCTION"

**ทดสอบ:**
```sql
-- Copy recipe_id จากตาราง inventory_recipes
SELECT * FROM check_recipe_can_produce('recipe_id_here', 1);

-- ผลลัพธ์:
-- can_produce: true/false
-- missing_ingredients: [...]
```

---

## 📝 STEP 3: Create Transaction Function (15 นาที)

**ไฟล์:** `STEP_3_create_transaction_function.sql`

**ทำอะไร:**
- ✅ สร้าง `produce_from_recipe()` function
- ✅ Validate + Deduct + Record (atomic)

**วิธี:**
1. เปิด `STEP_3_create_transaction_function.sql`
2. Copy ทั้งหมด
3. Paste ใน Supabase SQL Editor
4. Click **Run**
5. ตรวจสอบ: ควรเห็น "CREATE FUNCTION"

**ทดสอบ:**
```sql
-- Copy recipe_id, product_id จากตาราง
SELECT * FROM produce_from_recipe(
  'recipe_id_here',
  1,
  '[{"product_id": "prod_id", "quantity": 100}]'::JSONB,
  'output_product_id_here',
  'test_user'
);

-- ผลลัพธ์:
-- success: true/false
-- message: "ผลิตสำเร็จ" หรือ error message
-- production_log_id: UUID
```

---

## 📝 STEP 4: Create Audit Trail Function (10 นาที)

**ไฟล์:** `STEP_4_create_audit_function.sql`

**ทำอะไร:**
- ✅ สร้าง `get_production_audit_trail()` function
- ✅ ดึง audit trail ของการผลิต

**วิธี:**
1. เปิด `STEP_4_create_audit_function.sql`
2. Copy ทั้งหมด
3. Paste ใน Supabase SQL Editor
4. Click **Run**
5. ตรวจสอบ: ควรเห็น "CREATE FUNCTION"

**ทดสอบ:**
```sql
SELECT * FROM get_production_audit_trail('recipe_id_here');

-- ผลลัพธ์:
-- production_date, batch_quantity, yield_quantity, user_name, ingredient_adjustments
```

---

## 📝 STEP 5: Create Indexes (10 นาที)

**ไฟล์:** `STEP_5_create_indexes.sql`

**ทำอะไร:**
- ✅ สร้าง indexes สำหรับ performance
- ✅ ทำให้ query เร็วขึ้น

**วิธี:**
1. เปิด `STEP_5_create_indexes.sql`
2. Copy ทั้งหมด
3. Paste ใน Supabase SQL Editor
4. Click **Run**
5. ตรวจสอบ: ควรเห็น 5 indexes

**ผลลัพธ์:**
```
✅ idx_production_logs_recipe_id
✅ idx_adjustments_reference_id
✅ idx_adjustments_product_id
✅ idx_production_logs_created_at
✅ idx_adjustments_created_at
```

---

## 📝 STEP 6: Add Production Log Columns (5 นาที)

**ไฟล์:** `STEP_6_add_production_log_columns.sql`

**ทำอะไร:**
- ✅ เพิ่ม status column
- ✅ เพิ่ม error_message column
- ✅ เพิ่ม total_cost column

**วิธี:**
1. เปิด `STEP_6_add_production_log_columns.sql`
2. Copy ทั้งหมด
3. Paste ใน Supabase SQL Editor
4. Click **Run**
5. ตรวจสอบ: ควรเห็น 3 columns เพิ่มเติม

**ผลลัพธ์:**
```
✅ status (pending, completed, failed)
✅ error_message (TEXT)
✅ total_cost (DOUBLE PRECISION)
```

---

## ✅ Verification Checklist

หลังจากรัน STEP ทั้งหมด ให้ตรวจสอบ:

```sql
-- 1. ตรวจสอบ constraints
SELECT constraint_name, table_name 
FROM information_schema.table_constraints 
WHERE constraint_type = 'CHECK' 
AND table_name IN ('inventory_products', 'inventory_ingredients');
-- ควรเห็น 2 constraints

-- 2. ตรวจสอบ functions
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name IN ('check_recipe_can_produce', 'produce_from_recipe', 'get_production_audit_trail');
-- ควรเห็น 3 functions

-- 3. ตรวจสอบ indexes
SELECT indexname, tablename 
FROM pg_indexes 
WHERE tablename IN ('inventory_production_logs', 'inventory_adjustments')
AND indexname LIKE 'idx_%';
-- ควรเห็น 5 indexes

-- 4. ตรวจสอบ columns
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'inventory_production_logs'
AND column_name IN ('status', 'error_message', 'total_cost');
-- ควรเห็น 3 columns
```

---

## 🎯 Total Time

| STEP | Time | Status |
|------|------|--------|
| 1. Constraints | 5 min | ✅ |
| 2. Validation | 10 min | ✅ |
| 3. Transaction | 15 min | ✅ |
| 4. Audit | 10 min | ✅ |
| 5. Indexes | 10 min | ✅ |
| 6. Columns | 5 min | ✅ |
| **Total** | **55 min** | **✅** |

---

## 🚀 Next Steps

หลังจากรัน SQL ทั้งหมด:

1. **Update Flutter Code** — ใช้ new methods ใน inventory_service.dart
2. **Update UI** — เรียก `checkRecipeCanProduce()` ก่อนผลิต
3. **Test** — ทดสอบ validation + production
4. **Deploy** — Push to production

---

## 📞 Troubleshooting

### ❌ Error: "constraint already exists"
```
→ Constraint มีอยู่แล้ว
→ ข้ามไป STEP ถัดไป
```

### ❌ Error: "function already exists"
```
→ Function มีอยู่แล้ว
→ ข้ามไป STEP ถัดไป
```

### ❌ Error: "index already exists"
```
→ Index มีอยู่แล้ว
→ ข้ามไป STEP ถัดไป
```

### ❌ Error: "column already exists"
```
→ Column มีอยู่แล้ว
→ ข้ามไป STEP ถัดไป
```

---

## 📚 File Structure

```
lib/database/
├── STEP_1_add_constraints.sql
├── STEP_2_create_validation_function.sql
├── STEP_3_create_transaction_function.sql
├── STEP_4_create_audit_function.sql
├── STEP_5_create_indexes.sql
├── STEP_6_add_production_log_columns.sql
└── SETUP_INSTRUCTIONS.md (this file)
```

---

**Status: Ready to Run! 🚀**
