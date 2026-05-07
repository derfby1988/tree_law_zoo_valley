# วิเคราะห์และออกแบบ UI จัดการสูตร Priority Score

## 1. วิเคราะห์ความต้องการ

### ปัญหาที่ต้องการแก้:
- สูตร Priority Score อาจต้องปรับเปลี่ยนตามธุรกิจ (seasonality, สินค้าเปลี่ยน, กลยุทธ์ใหม่)
- ไม่อยากแก้โค้ดทุกครั้งที่ต้องปรับ weight หรือ threshold
- ต้องการ A/B testing หรือทดลองสูตรใหม่โดยไม่กระทบระบบเดิม

### ผู้ใช้งานระบบ:
1. **Manager/Owner** - ต้องการปรับ weight ตามกลยุทธ์ร้าน
2. **Data Analyst** - ต้องการทดลองสูตรใหม่และดูผลลัพธ์
3. **Admin** - ต้องการดูประวัติการเปลี่ยนแปลงและ rollback ได้

---

## 2. โครงสร้างข้อมูลที่ต้องเก็บ

### ตาราง: `promotion_formula_configs`
```sql
CREATE TABLE promotion_formula_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL, -- "สูตรมาตรฐาน 2568", "สูตรเทศกาลสงกรานต์"
  description TEXT,
  is_active BOOLEAN DEFAULT false,
  is_default BOOLEAN DEFAULT false,
  
  -- Weights (รวมเป็น 1.0 หรือ 100%)
  weight_margin DECIMAL(3,2) DEFAULT 0.25,          -- กำไร
  weight_expiry DECIMAL(3,2) DEFAULT 0.35,          -- ความเร่งด่วนหมดอายุ
  weight_seasonal DECIMAL(3,2) DEFAULT 0.20,        -- ฤดูกาล
  weight_festival DECIMAL(3,2) DEFAULT 0.10,        -- เทศกาล
  weight_ingredient_expiry DECIMAL(3,2) DEFAULT 0.10, -- วัตถุดิบ
  
  -- Threshold JSONB (เก็บแบบยืดหยุ่น)
  margin_thresholds JSONB DEFAULT '{"excellent":50,"good":30,"fair":10,"poor":0}'::jsonb,
  expiry_thresholds JSONB DEFAULT '{"expired":0,"critical":3,"urgent":7,"warning":14,"notice":30}'::jsonb,
  seasonal_thresholds JSONB DEFAULT '{"in_season":100,"ending":80,"off_season":0}'::jsonb,
  festival_thresholds JSONB DEFAULT '{"today":100,"soon_1_7":90,"soon_8_14":70,"far":0}'::jsonb,
  ingredient_thresholds JSONB DEFAULT '{"critical":7,"warning":14,"ok":999}'::jsonb,
  
  -- Discount recommendations
  discount_ranges JSONB DEFAULT '[
    {"min_score":80,"max_score":100,"discount_pct":"30-50","label":"ด่วนมาก","color":"#FF4444"},
    {"min_score":60,"max_score":79,"discount_pct":"20-30","label":"ด่วนปานกลาง","color":"#FF8800"},
    {"min_score":40,"max_score":59,"discount_pct":"10-20","label":"ปกติ","color":"#FFAA00"},
    {"min_score":0,"max_score":39,"discount_pct":"5-10","label":"ไม่เร่งด่วน","color":"#44AA44"}
  ]'::jsonb,
  
  -- Feature flags
  enabled_criteria JSONB DEFAULT '["margin","expiry","seasonal","festival","ingredient"]'::jsonb,
  
  -- Metadata
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  valid_from DATE DEFAULT CURRENT_DATE,
  valid_until DATE -- NULL = ไม่มีวันหมดอายุ
);

-- Index
CREATE INDEX idx_formula_configs_active ON promotion_formula_configs(is_active);
CREATE INDEX idx_formula_configs_default ON promotion_formula_configs(is_default);
```

### ตาราง: `promotion_formula_history`
```sql
CREATE TABLE promotion_formula_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  formula_id UUID REFERENCES promotion_formula_configs(id),
  changed_by UUID REFERENCES users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  change_type VARCHAR(50), -- 'created', 'updated', 'activated', 'deleted'
  old_values JSONB,
  new_values JSONB,
  reason TEXT -- เหตุผลในการเปลี่ยนแปลง
);
```

---

## 3. ออกแบบ UI Tab: "ตั้งค่าสูตรแนะนำ"

### Tab Layout แนะนำ:
```
┌─────────────────────────────────────────────────────────────┐
│  [คูปอง] [โปรโมชั่น] [สินค้าหมดอายุ] [วัตถุดิบ] [วิเคราะห์] [ตั้งค่าสูตร ▼] │
└─────────────────────────────────────────────────────────────┘
```

### โครงสร้างหน้าตั้งค่าสูตร (Index: 5):

#### Section 1: เลือกสูตรที่ใช้งาน (Card ด้านบน)
```
┌─────────────────────────────────────────────────────────┐
│ 📋 เลือกสูตรที่ใช้งาน                                    │
├─────────────────────────────────────────────────────────┤
│ สูตรที่ใช้: [สูตรมาตรฐาน 2568 ▼] [บันทึก] [ยกเลิก]       │
│                                                          │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐         │
│ │ 🏆 มาตรฐาน  │ │ 🎄 เทศกาล   │ │ ➕ สร้างใหม่ │         │
│ │ ใช้งานอยู่  │ │ ใช้: สงกรานต์│ │             │         │
│ └─────────────┘ └─────────────┘ └─────────────┘         │
└─────────────────────────────────────────────────────────┘
```

#### Section 2: น้ำหนักปัจจัย (Weight Sliders)
```
┌─────────────────────────────────────────────────────────┐
│ ⚖️ น้ำหนักปัจจัย (รวมต้อง = 100%)                         │
├─────────────────────────────────────────────────────────┤
│ กำไรสินค้า        [==========░░░░░░░░░░] 25%            │
│ ความเร่งด่วนหมดอายุ [██████████████░░░░] 35% ⚠️ สูงสุด   │
│ ความเหมาะสมฤดูกาล [████████░░░░░░░░░░] 20%            │
│ ความเหมาะสมเทศกาล [████░░░░░░░░░░░░░░] 10%            │
│ วัตถุดิบใกล้หมด   [████░░░░░░░░░░░░░░] 10%            │
│                                                          │
│ [รีเซ็ตค่าเริ่มต้น]                    รวม: 100% ✅     │
└─────────────────────────────────────────────────────────┘
```

#### Section 3: เกณฑ์คะแนน (Collapsible Panels)
```
┌─────────────────────────────────────────────────────────┐
│ 📊 เกณฑ์คะแนนแต่ละปัจจัย ▼                               │
├─────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────┐    │
│ │ 💰 กำไรสินค้า (Margin)                           │    │
│ ├──────────────────────────────────────────────────┤    │
│ │ กำไร ≥ 50%  = 100 คะแนน  [    50] % [    100]    │    │
│ │ กำไร 30-49% =  70 คะแนน  [    30] % [     70]    │    │
│ │ กำไร 10-29% =  40 คะแนน  [    10] % [     40]    │    │
│ │ กำไร < 10%  =  10 คะแนน  [     0] % [     10]    │    │
│ └──────────────────────────────────────────────────┘    │
│                                                          │
│ ┌──────────────────────────────────────────────────┐    │
│ │ ⏰ ความเร่งด่วนหมดอายุ                           │    │
│ ├──────────────────────────────────────────────────┤    │
│ │ หมดอายุแล้ว  = 100 คะแนน  [      0] วัน          │    │
│ │ เหลือ ≤ 3 วัน = 90 คะแนน  [      3] วัน          │    │
│ │ เหลือ 4-7 วัน = 70 คะแนน  [      7] วัน          │    │
│ │ เหลือ 8-14 วัน = 50 คะแนน [     14] วัน          │    │
│ │ เหลือ 15-30 วัน = 30 คะแนน[     30] วัน          │    │
│ └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

#### Section 4: เกณฑ์ส่วนลด (Color-coded Ranges)
```
┌─────────────────────────────────────────────────────────┐
│ 🎯 เกณฑ์ส่วนลดที่แนะนำ                                   │
├─────────────────────────────────────────────────────────┤
│ คะแนน 80-100: ส่วนลด [30]%-[50]% 🔴 ด่วนมาก              │
│ คะแนน 60-79:  ส่วนลด [20]%-[30]% 🟠 ด่วนปานกลาง          │
│ คะแนน 40-59:  ส่วนลด [10]%-[20]% 🟡 ปกติ                  │
│ คะแนน 0-39:   ส่วนลด [ 5]%-[10]% 🟢 ไม่เร่งด่วน          │
└─────────────────────────────────────────────────────────┘
```

#### Section 5: Feature Toggles
```
┌─────────────────────────────────────────────────────────┐
│ 🔧 เปิด/ปิดการใช้งานปัจจัย                              │
├─────────────────────────────────────────────────────────┤
│ [✅] กำไรสินค้า                                         │
│ [✅] ความเร่งด่วนหมดอายุ                               │
│ [✅] ความเหมาะสมฤดูกาล                                 │
│ [✅] ความเหมาะสมเทศกาล                                 │
│ [✅] วัตถุดิบใกล้หมดอายุ                               │
│ [⬜] Slow Moving (รอข้อมูล)                            │
│ [⬜] Overstock (รอข้อมูล)                               │
└─────────────────────────────────────────────────────────┘
```

#### Section 6: ทดสอบสูตร (Simulation)
```
┌─────────────────────────────────────────────────────────┐
│ 🧪 ทดสอบสูตร (Simulation)                                │
├─────────────────────────────────────────────────────────┤
│ เลือกสินค้าทดสอบ: [🔍 ค้นหาสินค้า...           ]        │
│                                                          │
│ ผลการคำนวณ:                                              │
│ ┌──────────────────────────────────────────────────┐    │
│ │ 🍜 ต้มยำกุ้ง (น้ำ)                                  │    │
│ │ กำไร: 45% → 70 คะแนน (×25%) = 17.5                │    │
│ │ หมดอายุ: 5 วัน → 70 คะแนน (×35%) = 24.5           │    │
│ │ ฤดูกาล: ไม่อยู่ในฤดู → 0 (×20%) = 0               │    │
│ │ ─────────────────────────────────                │    │
│ │ รวม: 42 คะแนน → ส่วนลดแนะนำ: 5-10%              │    │
│ └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

#### Section 7: ประวัติการเปลี่ยนแปลง
```
┌─────────────────────────────────────────────────────────┐
│ 📜 ประวัติการเปลี่ยนแปลง (ล่าสุด 10 รายการ)             │
├─────────────────────────────────────────────────────────┤
│ วันนี้ 14:30 น.  - คุณแอดมิน เปลี่ยน weight_expiry: 30%→35%│
│ วานนี้ 09:15 น. - คุณแอดมิน สร้างสูตร "เทศกาลสงกรานต์" │
│ 5 พ.ค. 68      - คุณแอดมิน เปิดใช้งานสูตรมาตรฐาน        │
└─────────────────────────────────────────────────────────┘
```

---

## 4. การทำงานของระบบ

### Flow 1: สร้างสูตรใหม่
1. กด "สร้างสูตรใหม่"
2. ตั้งชื่อสูตร + รายละเอียด
3. ปรับ weights (validate รวม = 100%)
4. ตั้งค่า thresholds แต่ละปัจจัย
5. ตั้งค่า discount ranges
6. เปิด/ปิด criteria ที่ต้องการ
7. ทดสอบด้วยสินค้าจริง (simulation)
8. บันทึก → บันทึกลง `formula_configs` + `formula_history`

### Flow 2: เปลี่ยนสูตรที่ใช้งาน
1. เลือกสูตรจาก dropdown
2. กด "ใช้งานสูตรนี้"
3. ระบบ set `is_active = true` สูตรนี้, `is_active = false` สูตรอื่น
4. บันทึก history พร้อมเหตุผล (optional)
5. แสดง toast: "เปลี่ยนเป็นสูตร XXX แล้ว"

### Flow 3: คำนวณ Priority Score (Runtime)
```dart
// 1. ดึงสูตรที่ active
final formula = await PromotionService.getActiveFormula();

// 2. ดึง raw scores จาก SQL (คำนวณเร็วใน DB)
final rawScores = await PromotionService.getRawScoresForProducts(productIds);

// 3. คำนวณ weighted score ใน Dart (ยืดหยุ่น)
for (final product in products) {
  double weightedScore = 0;
  
  if (formula.enabledCriteria.contains('margin')) {
    weightedScore += product.marginScore * formula.weightMargin;
  }
  if (formula.enabledCriteria.contains('expiry')) {
    weightedScore += product.expiryScore * formula.weightExpiry;
  }
  // ... ฯลฯ
  
  product.priorityScore = weightedScore.round();
  product.suggestedDiscount = formula.getDiscountForScore(weightedScore);
}

// 4. Sort ตาม priority score
products.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
```

---

## 5. ข้อดีของการออกแบบนี้

### ข้อดี:
1. **ยืดหยุ่น** - ปรับ weight, threshold ได้โดยไม่แก้โค้ด
2. **เก็บประวัติ** - รู้ว่าใครเปลี่ยนอะไรเมื่อไหร่
3. **ทดสอบได้** - สร้างสูตรใหม่และทดสอบก่อนใช้จริง
4. **A/B Testing** - สลับสูตรได้ทันที
5. **ข้อมูลครบ** - บันทึกเหตุผลการเปลี่ยนแปลง
6. **ปลอดภัย** - มี valid_from/valid_until, สูตรเก่ายังอยู่

### ข้อควรระวัง:
1. **Validate weights รวม = 100%** ตอน save
2. **Prevent delete active formula** - ต้องเปลี่ยนสูตรอื่นก่อน
3. **Cache active formula** - ไม่ต้อง query ทุกครั้ง
4. **Version control** - อาจเพิ่ม version number ถ้าต้องการ rollback ละเอียด

---

## 6. การพัฒนา (Implementation Plan)

### Phase A: Database (1 วัน)
- สร้างตาราง `promotion_formula_configs`
- สร้างตาราง `promotion_formula_history`
- สร้าง seed data (สูตรมาตรฐานเริ่มต้น)

### Phase B: Backend APIs (1-2 วัน)
- `GET /formula-configs` - ดึงรายการสูตรทั้งหมด
- `GET /formula-configs/:id` - ดึงรายละเอียดสูตร
- `POST /formula-configs` - สร้างสูตรใหม่
- `PUT /formula-configs/:id` - อัปเดตสูตร
- `POST /formula-configs/:id/activate` - เปิดใช้งานสูตร
- `GET /formula-configs/:id/history` - ดึงประวัติ
- `POST /formula-calculate` - ทดสอบคำนวณ

### Phase C: UI Tab (2-3 วัน)
- เพิ่ม Tab "ตั้งค่าสูตร" ใน CouponPromotionAdminPage
- สร้าง components: WeightSliders, ThresholdEditor, DiscountRanges, FormulaSelector
- เชื่อมต่อ APIs
- ทดสอบ simulation

### Phase D: Integration (1 วัน)
- แก้ไข Priority Score calculation ให้ใช้ config จาก DB
- แก้ไข PromotionProductPickerPage ให้ sort ตามสูตรที่ active
- ทดสอบ end-to-end

---

## 7. สรุป

การเพิ่ม Tab "ตั้งค่าสูตรแนะนำ" เป็น **วิธีที่ดีและเป็นไปได้** เพราะ:

1. **ตอบโจทย์ธุรกิจ** - ผู้จัดการร้านสามารถปรับกลยุทธ์ได้เอง
2. **ไม่กระทบระบบเดิม** - เพิ่ม tab ใหม่ ไม่ต้องแก้ tab อื่น
3. **Extensible** - รองรับ slow moving, overstock ในอนาคต
4. **Data-driven** - มี simulation ให้เห็นผลก่อนใช้จริง

**แนะนำให้เริ่มพัฒนา** หลังจาก Phase 8 Business Recommendation หลักเสร็จ (หรือทำควบคู่กันได้)
