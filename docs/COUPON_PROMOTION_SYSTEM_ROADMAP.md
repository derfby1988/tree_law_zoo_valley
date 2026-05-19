# Coupon & Promotion System Roadmap

## เป้าหมายหลัก

ระบบคูปองและโปรโมชันของ Tree Law Zoo Valley ต้องไม่ใช่แค่ระบบลดราคา แต่ต้องเป็นเครื่องมือช่วยระบายสินค้าและวัตถุดิบอย่างมีเหตุผล โดยเฉพาะ:

- สินค้าที่ใกล้วันหมดอายุ
- สินค้าที่ใช้วัตถุดิบในสูตรอาหารที่ใกล้วันหมดอายุ
- สินค้าที่มี stock สูง
- สินค้าที่ขายช้า
- สินค้าที่ทำกำไรสูง
- สินค้าที่ผลิตจากวัตถุดิบตามฤดูกาล
- สินค้าตามเทศกาลหรือวันสำคัญ
- สินค้าที่ควรนำมาทำโปรโมชันตาม priority score

## หลักการออกแบบ

- แยก coupon/promotion setup ออกจาก product targeting ที่มีรายการจำนวนมาก
- ใช้ full-screen picker สำหรับการเลือกสินค้า ไม่ยัดรายการยาวใน dialog
- แสดงเหตุผลของคำแนะนำทุกครั้ง ไม่แสดงแค่รายชื่อสินค้า
- Query หนักควรอยู่ที่ database/service layer ไม่ใช่ Flutter UI
- Filter ขั้นสูงควรถูกออกแบบเป็น core feature ไม่ใช่ optional add-on
- ต้องรองรับมือถือเป็นหลัก แต่ยังใช้งานบน tablet/desktop ได้

---

# UI/UX Flow

## 0. Coupon & Promotion Admin Tabs

หน้าจัดการคูปองและโปรโมชันควรแบ่งเป็นแถบหลัก:

```text
[คูปอง] [โปรโมชัน] [สินค้าใกล้หมดอายุ] [วัตถุดิบใกล้หมดอายุ] [วิเคราะห์การใช้งาน] [คูปองรายวันแบบรวมสิทธิ์]
```

### แถบคูปอง

- แสดงรายการคูปอง
- เพิ่ม/แก้ไข/ลบคูปอง
- กำหนด scope, targeting, availability rule

### แถบโปรโมชัน

- แสดงรายการโปรโมชัน
- เพิ่ม/แก้ไข/ลบโปรโมชัน
- กำหนดสินค้า/หมวดหมู่/ช่วงเวลา/เงื่อนไขการใช้งาน

### แถบสินค้าใกล้หมดอายุ (Phase 5)

- แสดงสินค้าที่ใกล้หมดอายุจาก batch tracking
- Filter ตามช่วงวัน (3/7/14/30 วัน + หมดอายุแล้ว)
- แสดงเหตุผล, จำนวนวันเหลือ, ส่วนลดแนะนำ
- ปุ่มสร้างโปรโมชั่นด่วนเพื่อระบายสินค้า

### แถบวัตถุดิบใกล้หมดอายุ (Phase 5)

- แสดงวัตถุดิบที่ใกล้หมดอายุ
- แสดงเมนูที่ใช้วัตถุดิบนั้นเพื่อระบาย
- Filter ตามช่วงวัน
- ปุ่มสร้างโปรโมชั่นด่วนสำหรับเมนูที่เกี่ยวข้อง

### แถบวิเคราะห์การใช้งาน

- สรุปประวัติการใช้คูปองและโปรโมชัน
- แสดงตารางสรุป
- แสดงกราฟแนวโน้ม
- drill-down ไปดูรายละเอียด order และสินค้า

### แถบคูปองรายวันแบบรวมสิทธิ์ (Phase 13 - Planned)

- แอดมินกำหนดคูปองใบเดียวที่รวมสิทธิ์ `ส่วนลด + สิทธิ์เข้าพื้นที่`
- แอดมินตั้งค่าการใช้งานได้เองทั้งหมด: lifecycle, time window, usage limits, stackable, override
- แอดมินกำหนดกติกาแยกตาม event type ได้: `discount`, `entry`
- แอดมินกำหนด QR security policy ได้: expiry, nonce, replay policy, key version
- แอดมินกำหนด monitoring thresholds และ go-live gate ได้จากหน้าเดียว
- มี preview/simulation ก่อน publish ทุกครั้ง

## 1. Coupon Dialog

ใช้สำหรับกรอกข้อมูลหลักของคูปอง:

- ชื่อคูปอง
- คำอธิบาย
- สถานะวงจรชีวิต
  - แบบร่าง
  - ตั้งเวลาไว้
  - ใช้งานอยู่
  - หยุดชั่วคราว
  - หมดอายุ
  - เก็บถาวร
- ประเภทส่วนลด
  - จำนวนเงิน
  - เปอร์เซ็นต์
- การจัดการรหัสคูปอง
  - กำหนดเอง
  - สร้างอัตโนมัติ
  - สร้างหลายรหัส
  - ใช้ครั้งเดียว
  - ใช้ได้หลายครั้ง
- มูลค่าส่วนลด
- ลดสูงสุดไม่เกิน
- ข้อจำกัดการใช้งาน
  - จำนวนครั้งรวมที่ใช้ได้
  - จำนวนครั้งต่อคน
  - จำนวนครั้งต่อวัน
  - ใช้ร่วมกับส่วนลดอื่นได้หรือไม่
- กลุ่มลูกค้าเป้าหมาย
  - ลูกค้าทั้งหมด
  - สมาชิก
  - กลุ่มลูกค้า
  - ลูกค้าวันเกิด
  - ลูกค้า VIP
  - กรุ๊ปทัวร์
- ช่องทางที่ใช้ได้
  - POS หน้าร้าน
  - QR Ordering
  - Delivery
  - Walk-in
  - Table service
  - Group booking
- ขอบเขต
  - ทั้งบิล
  - รายการสินค้า
  - หมวดหมู่
- ยอดขั้นต่ำ
- วันและเวลาเริ่มต้น
- วันและเวลาสิ้นสุด
- สถานะ active
- stackable
- เงื่อนไขความพร้อมของสินค้า/วัตถุดิบ
  - ต้องมีสินค้าในสต็อก
  - ถ้าเป็นสินค้าจากการผลิต ต้องมีวัตถุดิบเพียงพอ
  - รวม/ยกเว้นสินค้าหรือวัตถุดิบที่อยู่ในขั้นตอนจัดซื้อ

## 1.1 Coupon/Promotion Lifecycle

สถานะของคูปองและโปรโมชันควรใช้ภาษาไทยใน UI:

```text
แบบร่าง
ตั้งเวลาไว้
ใช้งานอยู่
หยุดชั่วคราว
หมดอายุ
เก็บถาวร
```

ความหมาย:

- แบบร่าง = ยังไม่พร้อมใช้งานและยังไม่แสดงใน POS
- ตั้งเวลาไว้ = สร้างแล้ว แต่ยังไม่ถึงวัน/เวลาเริ่มต้น
- ใช้งานอยู่ = ใช้งานได้ตามเงื่อนไข
- หยุดชั่วคราว = ปิดใช้งานชั่วคราว แต่ยังเก็บข้อมูลและประวัติไว้
- หมดอายุ = เลยวัน/เวลาสิ้นสุดแล้ว
- เก็บถาวร = ไม่ใช้งานแล้ว แต่เก็บไว้ดูประวัติ/analytics

Flow:

```text
แบบร่าง → ตั้งเวลาไว้ → ใช้งานอยู่ → หมดอายุ → เก็บถาวร
                     ↘ หยุดชั่วคราว ↗
```

Action ที่ควรมี:

- บันทึกแบบร่าง
- ตั้งเวลาเปิดใช้งาน
- เปิดใช้งานทันที
- หยุดชั่วคราว
- เปิดใช้งานต่อ
- เก็บถาวร
- ทำสำเนาคูปอง/โปรโมชัน

## 1.2 Usage Limits และ Abuse Prevention

ควรมีข้อจำกัดเพื่อป้องกันการใช้คูปอง/โปรโมชันเกินเงื่อนไขหรือผิดวัตถุประสงค์

ระดับคูปอง/โปรโมชัน:

- จำนวนครั้งรวมที่ใช้ได้
- จำนวนครั้งต่อคน
- จำนวนครั้งต่อวัน
- จำนวนครั้งต่อ order
- ยอดขั้นต่ำ
- จำกัดจำนวนส่วนลดสูงสุด
- ใช้ร่วมกับส่วนลดอื่นได้หรือไม่
- ใช้กับลูกค้าหรือกลุ่มลูกค้าที่กำหนดเท่านั้น

ระดับ order:

- หนึ่ง order ใช้ได้กี่คูปอง
- ห้ามใช้ซ้อนกับโปรโมชันบางประเภท
- priority เมื่อมีหลายส่วนลด
- ต้องตรวจ usage limit แบบ real-time ก่อนยืนยันชำระเงิน

Abuse prevention:

- ตรวจการใช้ซ้ำผิดปกติ
- log การ override เงื่อนไข
- ส่วนลดเกิน limit ต้องใช้สิทธิ์พิเศษ
- แจ้งเตือนเมื่อ coupon ถูกใช้ใกล้ถึง limit

## 1.3 Coupon Code Management

ระบบควรรองรับการจัดการรหัสคูปองหลายรูปแบบ

รูปแบบรหัส:

- กำหนดรหัสเอง
- สร้างรหัสอัตโนมัติ
- สร้างหลายรหัสพร้อมกัน
- single-use code
- multi-use code
- prefix/suffix
- QR code หรือ barcode สำหรับ coupon

ตัวอย่าง:

```text
SONGKRAN2026
VIP-MEMBER-001
BIRTHDAY-XXXX
```

Flow ที่ควรมี:

- สร้างรหัส
- ตรวจรหัสซ้ำ
- เปิด/ปิดรหัสบางรายการ
- import/export รหัสคูปอง
- ดูประวัติการใช้ของแต่ละรหัส

## 1.4 Customer Targeting

ควรรองรับการเลือกกลุ่มลูกค้าเป้าหมาย เพราะบางคูปอง/โปรโมชันไม่ได้เริ่มจากสินค้า แต่เริ่มจากลูกค้า

ตัวเลือกที่ควรมี:

- ลูกค้าทั้งหมด
- สมาชิก
- กลุ่มลูกค้า
- ลูกค้าวันเกิด
- ลูกค้าที่ไม่ได้มานาน
- ลูกค้าที่ซื้อมาก
- ลูกค้า VIP
- ลูกค้าครอบครัว/เด็ก
- กรุ๊ปทัวร์
- ลูกค้าที่จองล่วงหน้า

ตัวอย่าง:

```text
ลด 10% สำหรับสมาชิกวันเกิด
โปรครอบครัวสำหรับวันเด็ก
โปรเฉพาะกรุ๊ปทัวร์
```

## 1.5 Channel Targeting

ควรกำหนดช่องทางที่คูปอง/โปรโมชันใช้ได้

ช่องทางที่ควรรองรับ:

- POS หน้าร้าน
- QR Ordering
- Delivery
- Walk-in
- Table service
- Group booking
- Event booth
- Online

ตัวอย่าง:

```text
โปรเฉพาะหน้าร้าน
โปรเฉพาะ QR Ordering
โปรเฉพาะการจองโต๊ะล่วงหน้า
```

## 2. Scope = ทั้งบิล

ไม่ต้องมี selector เพิ่ม

Flow:

```text
เลือกขอบเขต = ทั้งบิล
  ↓
ใช้ส่วนลดกับยอดรวมทั้ง order
```

## 3. Scope = หมวดหมู่

ใช้ dropdown multi-select แบบ compact ใน dialog ได้ เพราะจำนวนหมวดหมู่ไม่มากเท่าสินค้า

UI:

```text
เลือกหมวดหมู่ *
[แตะเพื่อเลือก ▼]  3 รายการ

หมวดหมู่ที่เลือก (3)
[น้ำมัน ✕] [อาหาร ✕] [ของฝาก ✕]
```

รายการใน dropdown ควรแสดงจำนวนสินค้า active ต่อหมวด:

```text
☐ น้ำมันและหล่อลื่น      [12]
☐ อาหารสัตว์             [8]
☐ ของฝาก                 [0]
```

## 4. Scope = รายการสินค้า

ไม่ควรเลือกสินค้าใน dialog โดยตรง

ใน dialog ให้แสดงเป็น summary card:

```text
เลือกสินค้า *
┌──────────────────────────────┐
│ สินค้าที่เลือก               │
│ ยังไม่ได้เลือกสินค้า          │
│                         >    │
└──────────────────────────────┘
```

หลังเลือกแล้ว:

```text
เลือกสินค้า *
┌──────────────────────────────┐
│ สินค้าที่เลือก               │
│ 12 รายการ                    │
│                         >    │
└──────────────────────────────┘

[Shell 10W-40 ✕] [Castrol ✕] [กรองน้ำมัน ✕] [+9]
```

กด card เพื่อเปิด `PromotionProductPickerPage`

---

# PromotionProductPickerPage

## Layout หลัก

```text
เลือกสินค้าเข้าร่วมโปรโมชัน

🔍 ค้นหาสินค้า / SKU / Barcode

[ทั้งหมด] [สินค้าใกล้หมดอายุ] [วัตถุดิบใกล้หมดอายุ] [กำไรสูง] [ตามฤดูกาล] [เทศกาล] [แนะนำ]

ตัวกรอง:
[ทุกหมวดหมู่ ▼] [มีสต็อก ▼] [ภายใน 7 วัน ▼]

พบ 42 รายการ | เลือกแล้ว 8

☐ น้ำมันเครื่อง Shell 10W-40
   หมวด: น้ำมัน | ฿350 | คงเหลือ 20

☑ นมกล่องรสจืด
   หมดอายุเร็วสุด: 05/05/2569
   เหลือ 24 กล่อง
   เหตุผล: สินค้าใกล้หมดอายุ

☐ ข้าวผัดหมู
   วัตถุดิบใกล้หมดอายุ: หมูสับ, ไข่ไก่
   ทำได้ประมาณ 18 จาน
   เหตุผล: ใช้วัตถุดิบใกล้หมดอายุ

[เลือกแล้ว 8 รายการ]              [เสร็จ]
```

## Tabs

### 1. ทั้งหมด

ใช้เลือกสินค้าทั่วไป

Filter:

- ค้นหา
- หมวดหมู่
- สถานะสต็อก
- ช่วงราคา
- active เท่านั้นเป็นค่า default

### 2. สินค้าใกล้หมดอายุ

หมายถึงสินค้า/ล็อตสินค้าที่ขายโดยตรงใกล้หมดอายุ

Filter:

- ภายใน 3 วัน
- ภายใน 7 วัน
- ภายใน 14 วัน
- ภายใน 30 วัน
- หมวดหมู่
- มีสต็อก

Card ควรแสดง:

- ชื่อสินค้า
- หมวดหมู่
- วันหมดอายุเร็วสุด
- จำนวนที่ใกล้หมดอายุ
- จำนวนคงเหลือทั้งหมด
- อายุคงเหลือเป็นวัน
- เหตุผล

### 3. วัตถุดิบใกล้หมดอายุ

หมายถึงสินค้า/เมนูที่มีสูตรอาหาร และสูตรนั้นใช้วัตถุดิบล็อตใกล้หมดอายุ

Filter:

- ภายใน 3 วัน
- ภายใน 7 วัน
- ภายใน 14 วัน
- ภายใน 30 วัน
- หมวดหมู่สินค้า/เมนู
- วัตถุดิบ
- ทำได้อย่างน้อย X หน่วย

Card ควรแสดง:

- ชื่อสินค้า/เมนู
- สูตรอาหารที่เกี่ยวข้อง
- รายชื่อวัตถุดิบใกล้หมดอายุ
- วันหมดอายุเร็วสุดของวัตถุดิบ
- จำนวนวัตถุดิบที่ควรใช้
- จำนวนที่ผลิต/ขายได้โดยประมาณ
- เหตุผล

### 4. แนะนำ

รวมรายการที่ระบบแนะนำให้ทำโปรโมชัน

เหตุผลที่ใช้คำนวณ:

- สินค้าใกล้หมดอายุ
- วัตถุดิบใกล้หมดอายุ
- stock สูง
- ขายช้า
- margin ดี
- ใช้วัตถุดิบตามฤดูกาล
- เหมาะกับเทศกาลหรือวันสำคัญ
- priority score สูง

Card ควรแสดง:

- ชื่อสินค้า
- score หรือระดับแนะนำ
- เหตุผลหลัก
- เหตุผลรอง
- action เช่น เลือก, ดูรายละเอียด

### 5. สินค้ากำไรสูง

ใช้ค้นหาสินค้าที่มี gross margin สูง เหมาะกับการทำโปรโมชันเพื่อเพิ่มยอดขายโดยยังรักษากำไร

Filter:

- ระดับกำไร
  - สูง
  - กลาง
  - ต่ำ
- margin ขั้นต่ำ
- หมวดหมู่
- ช่วงราคา
- มีสต็อก

Card ควรแสดง:

- ชื่อสินค้า
- ราคาขาย
- ต้นทุนโดยประมาณ
- gross margin
- gross margin %
- คงเหลือ
- เหตุผล เช่น `กำไรสูง เหมาะกับโปรโมชันเพิ่มยอดขาย`

### 6. สินค้าจากวัตถุดิบตามฤดูกาล

ใช้ค้นหาสินค้า/เมนูที่ผลิตจากวัตถุดิบตามฤดูกาล เพื่อทำโปรโมชันตามช่วงเวลาที่วัตถุดิบมีมาก ราคาดี หรือควรเร่งใช้

Filter:

- ฤดูกาล
  - ร้อน
  - ฝน
  - หนาว
  - กำหนดเอง
- ช่วงเดือน
- วัตถุดิบตามฤดูกาล
- หมวดหมู่สินค้า/เมนู
- มีสต็อกหรือผลิตได้

Card ควรแสดง:

- ชื่อสินค้า/เมนู
- วัตถุดิบตามฤดูกาลที่ใช้
- ช่วงฤดูกาล
- ต้นทุนวัตถุดิบโดยประมาณ
- ทำได้ประมาณกี่หน่วย
- เหตุผล เช่น `ใช้วัตถุดิบตามฤดูกาล: มะม่วง`

### 7. สินค้าตามเทศกาลหรือวันสำคัญ

ใช้ค้นหาสินค้าที่เหมาะกับเทศกาล วันหยุด หรือ event สำคัญ เช่น ปีใหม่ สงกรานต์ วันเด็ก วันแม่ วันพ่อ หรือ event ของสวนสัตว์

Filter:

- เทศกาล/วันสำคัญ
- ช่วงวันที่
- หมวดหมู่
- กลุ่มลูกค้าเป้าหมาย
- สินค้าที่เคยขายดีในเทศกาลเดียวกัน

Card ควรแสดง:

- ชื่อสินค้า
- เทศกาลที่เกี่ยวข้อง
- ช่วงวันที่แนะนำ
- เหตุผล เช่น `เหมาะกับเทศกาลสงกรานต์`
- ยอดขายย้อนหลังในเทศกาลเดียวกัน ถ้ามี

---

# Coupon & Promotion Usage Analytics

ควรอยู่ในแถบใหม่ของหน้าจัดการคูปองและโปรโมชันชื่อ `วิเคราะห์การใช้งาน`

## Layout หลัก

```text
วิเคราะห์การใช้งาน

[วันนี้ ▼] [คูปอง/โปรโมชันทั้งหมด ▼] [ช่องทางขาย ▼] [Export]

┌────────────┐ ┌────────────┐ ┌────────────┐
│ ใช้งานรวม │ │ ส่วนลดรวม  │ │ ยอดขายหลังลด │
│ 128 ครั้ง │ │ ฿12,500    │ │ ฿86,300       │
└────────────┘ └────────────┘ └────────────┘

[กราฟการใช้งานตามวัน]
[กราฟยอดส่วนลด / ยอดขายหลังลด]

ตารางสรุป:
คูปอง/โปรโมชัน | ใช้กี่ครั้ง | ส่วนลดรวม | ยอดขายหลังลด | กำไรขั้นต้น | สินค้าที่ระบายได้ | ใช้ล่าสุด
```

## Summary Cards

- จำนวนครั้งที่ใช้ทั้งหมด
- ยอดส่วนลดรวม
- ยอดขายก่อนลด
- ยอดขายหลังลด
- กำไรขั้นต้นโดยประมาณ
- จำนวนสินค้า/วัตถุดิบที่ระบายได้
- coupon/promotion ที่มีประสิทธิภาพสูงสุด

## Graphs

- จำนวนการใช้คูปอง/โปรโมชันตามวัน
- ยอดส่วนลดรวมตามช่วงเวลา
- ยอดขายก่อนลด vs หลังลด
- กำไรขั้นต้นหลังหักส่วนลด
- Top 10 คูปอง/โปรโมชันที่ถูกใช้มากที่สุด
- Top 10 สินค้าที่ถูกระบายได้มากที่สุด
- เปรียบเทียบก่อน/ระหว่าง/หลังโปรโมชัน

## Summary Table

Column ที่ควรมี:

- ชื่อคูปอง/โปรโมชัน
- ประเภท
- targeting mode
- จำนวนครั้งที่ใช้
- ยอดขายก่อนลด
- ส่วนลดรวม
- ยอดขายหลังลด
- กำไรขั้นต้นโดยประมาณ
- จำนวนสินค้าที่ระบายได้
- จำนวนวัตถุดิบที่ถูกใช้ไป
- วันที่ใช้ล่าสุด
- สถานะ

## Detail Drill-down

กดแถวในตารางเพื่อดูรายละเอียด:

- รายการ order ที่ใช้คูปอง/โปรโมชัน
- วันที่ใช้งาน
- ยอดก่อนลด/หลังลด
- ส่วนลดที่ใช้
- รายการสินค้าใน order
- จำนวนสินค้าที่ถูกระบาย
- วัตถุดิบที่ถูกใช้จากสูตรอาหาร
- พนักงานหรือช่องทางขาย
- ลูกค้า ถ้ามี
- เหตุผล targeting เช่น `สินค้าใกล้หมดอายุ`, `กำไรสูง`, `เทศกาล`

## Filters

- ช่วงวันที่
- ประเภท
  - คูปอง
  - โปรโมชัน
  - ทั้งหมด
- targeting mode
- ช่องทางขาย
- พนักงาน
- หมวดหมู่สินค้า
- สินค้า
- เทศกาล/ฤดูกาล

## Export

- Export CSV/Excel
- Export PDF summary
- Export รายละเอียด order ที่ใช้คูปอง

---

# Filters ที่ควรรองรับ

## Core Filters

- Search text
- Category
- Stock status
  - ทั้งหมด
  - มีสต็อก
  - ใกล้หมด
  - หมดสต็อก
- Price range
- Active only

## Availability Filters

ใช้ควบคุมว่าสินค้าหรือเมนูที่นำไปทำคูปอง/โปรโมชันต้องพร้อมขายหรือพร้อมผลิตจริงหรือไม่

- ต้องมีสินค้าในสต็อก
  - เปิด = แสดงเฉพาะสินค้าที่มี stock พร้อมขาย
  - ปิด = อนุญาตให้เลือกสินค้าแม้ stock เป็น 0
- ถ้าเป็นสินค้าจากการผลิต ต้องมีวัตถุดิบเพียงพอ
  - เปิด = แสดงเฉพาะเมนู/สินค้าที่ผลิตได้จากวัตถุดิบปัจจุบัน
  - ปิด = อนุญาตให้เลือกแม้วัตถุดิบยังไม่พอ
- รวมรายการที่อยู่ในขั้นตอนจัดซื้อ
  - เปิด = นับวัตถุดิบหรือสินค้าที่มี purchase order ระหว่างทางเป็น available soon
  - ปิด = นับเฉพาะ stock ที่มีอยู่จริงเท่านั้น
- แสดงรายการที่ไม่พร้อมพร้อมเหตุผล
  - เปิด = แสดงรายการ disabled พร้อมเหตุผล เช่น `stock ไม่พอ`, `รอจัดซื้อ`, `วัตถุดิบไม่พอ`
  - ปิด = ซ่อนรายการที่ไม่พร้อมทั้งหมด

## Expiry Filters

แยกเป็น 2 แบบชัดเจน:

### Product Expiry

- สินค้าใกล้หมดอายุภายใน 3/7/14/30 วัน
- ใช้กับ batch/lot ของสินค้าโดยตรง

### Ingredient Expiry

- สินค้าที่ใช้วัตถุดิบใกล้หมดอายุภายใน 3/7/14/30 วัน
- ใช้กับ recipe + ingredient batch

## Recommendation Filters

- ระดับแนะนำ
  - สูง
  - กลาง
  - ต่ำ
- เหตุผลการแนะนำ
  - ใกล้หมดอายุ
  - วัตถุดิบใกล้หมดอายุ
  - stock สูง
  - ขายช้า
  - กำไรสูง
  - วัตถุดิบตามฤดูกาล
  - เทศกาล/วันสำคัญ
- sort by priority score

## Margin Filters

- ระดับกำไร
  - สูง
  - กลาง
  - ต่ำ
- gross margin ขั้นต่ำ
- gross margin % ขั้นต่ำ
- หมวดหมู่
- ช่วงราคา

## Seasonal Ingredient Filters

- ฤดูกาล
  - ร้อน
  - ฝน
  - หนาว
  - กำหนดเอง
- ช่วงเดือน
- วัตถุดิบตามฤดูกาล
- สินค้า/เมนูที่ใช้วัตถุดิบนั้น
- ผลิตได้จาก stock วัตถุดิบปัจจุบัน

## Festival/Event Filters

- เทศกาล/วันสำคัญ
- ช่วงวันที่
- หมวดหมู่
- กลุ่มลูกค้าเป้าหมาย
- สินค้าที่เคยขายดีในเทศกาลเดียวกัน
- สินค้าที่กำหนด mapping กับ event โดยตรง

---

# Real Schema Mapping และ No Mock Data Policy

ระบบนี้ต้องใช้ข้อมูลจากตารางจริงเท่านั้น ไม่ใช้ mock data ใน flow ที่นำไปทดสอบหรือใช้งานจริง

ข้อมูลด้านล่างเป็น mapping จาก migration/service ที่มีอยู่ใน codebase ปัจจุบัน และมีการตรวจ Supabase live ด้วย metadata query แบบอ่านอย่างเดียวแล้ว

## Supabase Live Schema Verification

ตรวจด้วย Supabase REST โดยใช้ `select=<column>&limit=0` เพื่อเช็ค table/column เท่านั้น ไม่ดึงข้อมูลธุรกิจ

ผลตรวจ live:

### Tables ที่มีจริงใน Supabase live

- `pos_discounts`
- `pos_promotions`
- `pos_promotion_items`
- `pos_order_discounts`
- `pos_orders`
- `pos_order_lines`
- `inventory_products`
- `inventory_categories`
- `inventory_units`
- `inventory_recipes`
- `inventory_recipe_ingredients`
- `inventory_ingredients`
- `inventory_item_batches`
- `inventory_stock_summary`
- `procurement_purchase_orders`
- `procurement_purchase_order_lines`
- `pos_customers`
- `pos_customer_loyalty_wallets`

### Columns สำคัญที่ยืนยันว่ามีจริง

- `pos_discounts`
  - มี `applicable_category_ids`, `customer_group_id`, `coupon_code`, `usage_limit`, `used_count`, `priority`
- `pos_promotions`
  - มี `min_quantity`, `free_quantity`, `banner_image_url`
- `pos_order_discounts`
  - มี `promotion_id`, `discount_name`, `discount_type`, `discount_value`, `discount_amount`, `applied_by`, `applied_at`
- `inventory_recipe_ingredients`
  - มีทั้ง `product_id` และ `ingredient_id`
- `inventory_ingredients`
  - มีอยู่จริงใน Supabase live
- `inventory_item_batches`
  - มีทั้ง `product_id` และ `ingredient_id`
- `procurement_purchase_order_lines`
  - มี `product_id`, `quantity`, `received_quantity`

### Columns ที่ยังไม่มีใน Supabase live

- `pos_discounts`
  - `applicable_product_ids`
  - `targeting_mode`
  - `targeting_rule`
  - `require_in_stock`
  - `require_sufficient_ingredients`
  - `include_pending_procurement`
- `pos_promotions`
  - `targeting_mode`
  - `targeting_rule`
  - `require_in_stock`
  - `require_sufficient_ingredients`
  - `include_pending_procurement`
- `pos_order_discounts`
  - `order_line_id`
- `pos_orders`
  - `customer_id`
- `pos_order_lines`
  - `discount_amount`
- `procurement_purchase_order_lines`
  - `ingredient_id`

## ตารางจริงที่ใช้ได้ทันที

### Coupon / Discount / Promotion

- `pos_discounts`
  - มี `name`, `description`, `discount_type`, `scope`, `value`, `max_discount`, `min_amount`
  - มี `stackable`, `priority`, `applicable_category_ids`, `customer_group_id`
  - มี `coupon_code`, `usage_limit`, `used_count`
  - มี `is_active`, `start_at`, `end_at`
- `pos_promotions`
  - มี `promotion_type`, `discount_id`, `min_quantity`, `free_quantity`, `banner_image_url`
  - มี `is_active`, `start_at`, `end_at`
- `pos_promotion_items`
  - ใช้ผูก promotion กับ `inventory_products`
  - มี `quantity_required`, `is_free_item`
- `pos_order_discounts`
  - ใช้บันทึกการใช้ discount/promotion ต่อ order
  - มี snapshot `discount_name`, `discount_type`, `discount_value`, `discount_amount`
  - มี `applied_by`, `applied_at`

### POS / Checkout / Usage Logging

- `pos_orders`
  - ใช้เป็น order header สำหรับ checkout
  - service ปัจจุบันบันทึก `subtotal`, `discount_amount`, `tax_amount`, `service_amount`, `net_total`, `payment_method`, `status`
  - รองรับ `customer_id`, `customer_user_id`, `responsible_user_id`, `cashier_user_id`, `shift_id` ตาม service/migration ที่มี
- `pos_order_lines`
  - ใช้บันทึกรายการสินค้าใน order
  - มี `product_id`, `product_name`, `quantity`, `unit_price`, `line_total`
- `pos_order_discounts`
  - ใช้เป็น usage log เบื้องต้นสำหรับ coupon/promotion analytics

### Inventory / Product / Recipe

- `inventory_products`
  - มี `category_id`, `unit_id`, `shelf_id`
  - มี `quantity`, `min_quantity`, `price`, `cost`
  - มี `expiry_date`, `expiry_alert_days`, `is_active`
- `inventory_categories`
  - ใช้กับ category scope และ category filter
- `inventory_units`
  - ใช้แสดงหน่วยสินค้า/วัตถุดิบ
- `inventory_recipes`
  - มี `yield_quantity`, `yield_unit`, `cost`, `price`, `is_active`
- `inventory_recipe_ingredients`
  - ผูกสูตรอาหารกับ `inventory_products` ตาม migration ปัจจุบัน
  - ใช้คำนวณ possible servings สำหรับสินค้าผลิตจากสูตร
- `inventory_adjustments`
  - ใช้ประวัติการเคลื่อนไหว stock
- `inventory_production_logs`
  - ใช้ประวัติการผลิต

### Batch / Expiry / FEFO

- `inventory_item_batches`
  - รองรับทั้ง `item_type = product` และ `item_type = ingredient`
  - มี `product_id`, `ingredient_id`
  - มี `batch_number`, `quantity`, `expiry_date`, `received_date`, `manufactured_date`
  - มี `unit_cost`, `total_cost`
  - มี `is_expired`, `is_active`, `is_disposed`
  - มี `received_from_procurement_id`, `received_reference`
- `inventory_batch_logs`
  - ใช้ track การเคลื่อนไหว batch เช่น receive, consume, transfer, dispose
- `inventory_stock_summary`
  - view สรุป stock รวมของ product/ingredient
  - มี `total_quantity`, `batch_count`, `earliest_expiry`, `expiring_soon_quantity`, `expired_quantity`
- `inventory_batch_details`
  - view รายละเอียด batch พร้อมข้อมูลสินค้า/วัตถุดิบ

### Procurement

- `procurement_suppliers`
- `procurement_purchase_orders`
  - มี status: `draft`, `sent`, `confirmed`, `partial_received`, `completed`, `cancelled`
  - มี `expected_date`
- `procurement_purchase_order_lines`
  - มี `product_id`, `quantity`, `received_quantity`
  - ใช้คำนวณ pending procurement สำหรับสินค้า
- `procurement_store_locations`

### Customer / Loyalty

- `pos_customers`
  - service ปัจจุบันใช้ `display_name`, `phone`, `email`, `customer_type`, `is_active`
- `pos_loyalty_programs`
- `pos_customer_loyalty_wallets`
  - มี `tier` เช่น `standard`, `silver`, `gold`, `vip`
- `pos_loyalty_transactions`

## Gaps เริ่มต้นก่อนเริ่มโครงการ (Historical Baseline)

> หมายเหตุ: รายการด้านล่างเป็นช่องว่างที่ระบุไว้ก่อนเริ่มลงมือทำ Phase 0 เป็นต้นไป
> ให้ยึดสถานะล่าสุดจากหัวข้อ `Development Phases` และ `Summary: ความคืบหน้าโครงการ`

### Discount/Promotion

- `applicable_product_ids` ยังไม่มีใน `pos_discounts`
- lifecycle status ยังไม่มี แผนปัจจุบันมีแค่ `is_active`
- usage limit ยังเป็นระดับรวมเท่านั้น ยังไม่มี per-customer/per-day/per-order
- coupon code มี field เดียว ยังไม่มีตารางสำหรับ bulk/single-use code
- targeting mode/rule ยังไม่มี
- customer targeting ยังมีแค่ `customer_group_id` ยังไม่ครอบคลุมหลาย segment
- channel targeting ยังไม่มี
- availability rules ยังไม่มี:
  - `require_in_stock`
  - `require_sufficient_ingredients`
  - `include_pending_procurement`
- audit/approval/conflict/simulation ยังไม่มี

### Analytics

- `pos_order_discounts` ใช้ทำ usage log เบื้องต้นได้
- ยังไม่มี order-line discount allocation table
- ยังไม่มี analytics views:
  - `coupon_promotion_usage_summary`
  - `coupon_promotion_usage_daily_trend`
  - `coupon_promotion_top_targets`
  - `coupon_promotion_order_details`
  - `coupon_promotion_margin_impact`

### Ingredient / Recipe

- migration ปัจจุบันมี seed ของ `inventory_ingredients` แต่ไม่พบ migration สร้าง `inventory_ingredients` ในไฟล์ที่ตรวจพบ ต้อง verify กับ Supabase live
- `inventory_recipe_ingredients` ปัจจุบันอ้าง `product_id` ไม่ใช่ `ingredient_id` จึงต้องตรวจว่า recipe ใช้ product เป็นวัตถุดิบจริง หรือมี schema ingredient แยกในฐานข้อมูลจริง
- seasonal ingredient metadata ยังไม่มี

### Procurement

- PO line ปัจจุบันรองรับ `product_id` แต่ยังไม่เห็น `ingredient_id`
- การนับ pending procurement สำหรับวัตถุดิบต้อง verify ว่ามี PO ของ ingredient ใน schema จริงหรือไม่

## หลักการสำหรับ Phase 0

- ห้ามใช้ mock data แทนตารางจริง
- ถ้าตาราง/field ยังไม่มี ต้องเพิ่ม migration หรือปิด feature นั้นไว้ก่อน
- ทุก UI filter ต้องอ้างจาก service/query ที่ดึงข้อมูลจริง
- ทุก recommendation ต้องมี `reason` ที่คำนวณจากข้อมูลจริง
- ก่อน implement phase ใด ต้องระบุ source table/view/RPC ให้ชัดเจน

---

# Data Model ที่ควรมี

## pos_discounts

ควรรองรับ:

- applicable_category_ids UUID[]
- applicable_product_ids UUID[]
- targeting_mode TEXT
  - manual
  - product_expiry
  - ingredient_expiry
  - high_margin
  - seasonal_ingredient
  - festival_event
  - recommended
- targeting_rule JSONB
- priority_score NUMERIC
- require_in_stock BOOLEAN
- require_sufficient_ingredients BOOLEAN
- include_pending_procurement BOOLEAN

## pos_promotions

ควรรองรับ:

- promotion_type
- discount_id
- start_at
- end_at
- targeting_mode
- targeting_rule
- require_in_stock
- require_sufficient_ingredients
- include_pending_procurement

## Product/Ingredient Targeting Views

ควรทำเป็น SQL view/RPC แยก ไม่ควร join หนักใน Flutter

### promotion_expiring_product_targets

คืนข้อมูล:

- product_id
- product_name
- category_id
- category_name
- earliest_expiry_date
- days_to_expiry
- expiring_quantity
- current_stock
- pending_procurement_quantity
- available_quantity
- availability_status
- availability_reason
- unit
- reason
- priority_score

### promotion_expiring_ingredient_targets

คืนข้อมูล:

- product_id/menu_id
- product_name/menu_name
- recipe_id
- recipe_name
- expiring_ingredient_ids
- expiring_ingredient_names
- earliest_ingredient_expiry_date
- days_to_expiry
- possible_servings
- pending_procurement_ingredient_quantity
- available_servings_including_procurement
- availability_status
- availability_reason
- reason
- priority_score

### promotion_recommended_targets

คืนข้อมูล:

- target_type
- product_id/menu_id
- target_name
- category_name
- reasons
- primary_reason
- priority_score
- suggested_discount_type
- suggested_discount_value

### promotion_high_margin_targets

คืนข้อมูล:

- product_id/menu_id
- target_name
- category_name
- sale_price
- estimated_cost
- gross_margin
- gross_margin_percent
- current_stock
- pending_procurement_quantity
- available_quantity
- availability_status
- availability_reason
- reason
- priority_score

### promotion_seasonal_ingredient_targets

คืนข้อมูล:

- product_id/menu_id
- target_name
- recipe_id
- seasonal_ingredient_ids
- seasonal_ingredient_names
- season_name
- season_start_month
- season_end_month
- available_ingredient_quantity
- pending_procurement_ingredient_quantity
- possible_servings
- available_servings_including_procurement
- availability_status
- availability_reason
- estimated_cost
- reason
- priority_score

### promotion_festival_event_targets

คืนข้อมูล:

- product_id/menu_id
- target_name
- category_name
- event_id
- event_name
- event_start_date
- event_end_date
- target_customer_group
- historical_sales_quantity
- historical_sales_amount
- reason
- priority_score

---

# Service Layer

ควรมี service เฉพาะสำหรับ promotion targeting:

```dart
class PromotionTargetingService {
  static Future<List<Map<String, dynamic>>> getProducts({ ... });
  static Future<List<Map<String, dynamic>>> getExpiringProducts({required int days, required bool requireInStock, required bool includePendingProcurement});
  static Future<List<Map<String, dynamic>>> getProductsUsingExpiringIngredients({required int days, required bool requireSufficientIngredients, required bool includePendingProcurement});
  static Future<List<Map<String, dynamic>>> getHighMarginTargets({ ... });
  static Future<List<Map<String, dynamic>>> getSeasonalIngredientTargets({ ... });
  static Future<List<Map<String, dynamic>>> getFestivalEventTargets({ ... });
  static Future<List<Map<String, dynamic>>> getRecommendedTargets({ ... });
}
```

หลักการ:

- UI เรียก service ตาม tab/filter
- service เรียก Supabase view/RPC
- ไม่คำนวณ join ซับซ้อนใน widget
- cache ผลลัพธ์ตาม tab/filter ชั่วคราวเพื่อลดโหลด

---

# Performance Strategy

## Database/Service

- ใช้ SQL view หรือ RPC สำหรับ query ซับซ้อน
- ใช้ index กับ expiry_date, product_id, ingredient_id, category_id, is_active, season_month, event_date, procurement_status
- ถ้าข้อมูลมาก ให้ใช้ materialized view สำหรับ recommendation
- ทำ pagination หรือ limit/offset
- แยก query ตาม tab ไม่โหลดทุกอย่างพร้อมกัน
- คำนวณ margin/season/event score ใน view/RPC หรือ materialized view ไม่คำนวณซ้ำใน widget
- availability ต้องคำนวณฝั่ง service/RPC โดยรับ parameter `require_in_stock`, `require_sufficient_ingredients`, `include_pending_procurement`

## Flutter UI

- ใช้ full-screen page
- ใช้ ListView.builder
- debounce search
- lazy load/pagination
- แสดง skeleton/loading state
- แสดง selected summary sticky ด้านล่าง
- ไม่ render chip จำนวนมากใน dialog ให้ใช้ +N

---

# Validation Rules

## Coupon Dialog

- ชื่อคูปอง required
- discount value > 0
- percentage <= 100
- max discount >= 0
- startAt <= endAt
- scope = category ต้องเลือกอย่างน้อย 1 หมวดหมู่
- scope = item ต้องเลือกอย่างน้อย 1 สินค้า
- ถ้าเปิด `ต้องมีสินค้าในสต็อก` ต้องห้ามเลือกสินค้าที่ไม่มี stock พร้อมขาย ยกเว้นเปิดรวมรายการจัดซื้อ
- ถ้าเปิด `ต้องมีวัตถุดิบเพียงพอ` ต้องห้ามเลือกสินค้าผลิตที่วัตถุดิบไม่พอ ยกเว้นเปิดรวมรายการจัดซื้อ

## Product Picker

- เลือกทั้งหมดในผลลัพธ์ต้องหมายถึงผลลัพธ์ปัจจุบันหลัง filter เท่านั้น
- ถ้า filter เปลี่ยน selected items ต้องยังคงอยู่
- ห้าม clear selected โดยไม่ยืนยันถ้ามีหลายรายการ
- รายการที่ไม่พร้อมตาม availability rule ต้อง disabled หรือซ่อนตาม toggle
- รายการ disabled ต้องแสดงเหตุผล เช่น `stock ไม่พอ`, `วัตถุดิบไม่พอ`, `รอจัดซื้อ`

---

# Operational Standards (Single Standard)

ส่วนนี้เป็นมาตรฐานกลางสำหรับทุกทีม (DB/Service/UI/POS/Admin) เพื่อป้องกันกฎซ้ำซ้อนและผลลัพธ์ไม่ตรงกัน

## Admin-first Configuration Policy (บังคับใช้ทุกข้อ)

- ทุกมาตรฐานใน section นี้ต้องถูกตั้งค่าได้ผ่าน UI ของแอดมินในแถบ `คูปองรายวันแบบรวมสิทธิ์`
- ห้าม hardcode กติกาธุรกิจใน widget หรือ client โดยไม่มีตัวเลือกจากแอดมิน
- หากค่าใดไม่มีใน UI ถือว่าใช้ค่า default ที่ประกาศชัดเจนและแสดงในหน้าเดียวกัน
- การเปลี่ยนค่าจากแอดมินต้องมี audit log, ผู้แก้ไข, เวลาแก้ไข, และเหตุผล

### Admin Config Matrix (สำหรับแถบใหม่)

| กลุ่มการตั้งค่า | ตัวอย่างค่า | ผลกับระบบ |
|------------------|-------------|------------|
| Rule Matrix | lifecycle/time/channel/target/scope/usage | ใช้กับ validator กลางทั้ง POS และ Gate |
| Conflict Precedence | ลำดับ type, priority, tie-breaker | ใช้กับ `resolveDiscountConflicts()` |
| Concurrency/Idempotency | idempotency TTL, retry policy, lock mode | ป้องกันการใช้สิทธิ์ซ้ำ/ชนกัน |
| QR Security | key_id, signature_version, expires_at, replay window | เพิ่มความปลอดภัยการสแกน |
| Monitoring | threshold ต่อ reason code, latency alert | แจ้งเตือนและติดตามคุณภาพระบบ |
| UAT/Go-live | pass criteria, rollout gate, rollback owner | ควบคุมการปล่อยระบบอย่างปลอดภัย |

## 1) Rule Matrix (มาตรฐานเดียวทั้งระบบ)

| ลำดับตรวจ | Rule Group | เงื่อนไขหลัก | Data Source | เมื่อไม่ผ่าน | Error/Reason Code |
|-----------|------------|---------------|-------------|--------------|-------------------|
| 1 | Lifecycle | `draft/scheduled/paused/expired/archived` ใช้งานไม่ได้ | `pos_discounts`, `pos_promotions` | block | `LIFECYCLE_INVALID` |
| 2 | Time Window | `start_at <= now <= end_at` | `pos_discounts`, `pos_promotions` | block | `OUTSIDE_TIME_WINDOW` |
| 3 | Visibility | ต้องแสดงในช่องทางที่เรียกใช้งาน | `show_in_coupon_tab`, `show_in_pos_discount_dialog` | hide | `VISIBILITY_BLOCKED` |
| 4 | Channel Targeting | ช่องทางขายต้องอยู่ใน `applicable_channels` | discount/promotion fields | block | `CHANNEL_NOT_ALLOWED` |
| 5 | User Group / Customer Targeting | ต้องอยู่ในกลุ่มที่กำหนด | user group + customer segment | block | `TARGET_NOT_ELIGIBLE` |
| 6 | Scope Matching | order/item/category ต้องตรง scope ที่กำหนด | `scope`, `applicable_*` | block | `SCOPE_NOT_MATCHED` |
| 7 | Usage Limits | รวม/ต่อวัน/ต่อลูกค้า/ต่อออเดอร์ ต้องไม่เกิน | usage logs + counters | block | `USAGE_LIMIT_EXCEEDED` |
| 8 | Availability | stock/ingredients/procurement ต้องผ่าน policy | RPC availability checks | block หรือ warn ตาม policy | `AVAILABILITY_FAILED` |
| 9 | Stackable Policy | ใช้ร่วมกับส่วนลดอื่นได้หรือไม่ | `stackable` + order discounts | block | `STACK_NOT_ALLOWED` |
| 10 | Governance Override | ถ้าเกิน margin/ผิด policy ต้องได้รับอนุมัติ | governance tables/services | block จนกว่าจะ approve | `OVERRIDE_REQUIRED` |

ข้อกำหนด:
- Service layer ต้องเป็นผู้ประเมิน Rule Matrix กลางเพียงจุดเดียว (single evaluator)
- UI แสดงผลตาม reason code เดียวกัน ห้ามนิยามข้อความขัดกับ service
- ทุกการ block/warn ต้องมี reason code บันทึกใน log

### 1.1 Reason Code Catalog (UI/Service Standard)

| Reason Code | ระดับ | UI Message (TH) | UI Message (EN) |
|------------|-------|-----------------|-----------------|
| `LIFECYCLE_INVALID` | block | โปรนี้ยังไม่พร้อมใช้งาน | This promotion is not active yet. |
| `OUTSIDE_TIME_WINDOW` | block | อยู่นอกช่วงเวลาที่กำหนด | Outside allowed time window. |
| `VISIBILITY_BLOCKED` | hide | ไม่แสดงในหน้าปัจจุบัน | Not visible in this screen. |
| `CHANNEL_NOT_ALLOWED` | block | ช่องทางขายนี้ไม่รองรับโปรนี้ | This channel is not allowed. |
| `TARGET_NOT_ELIGIBLE` | block | ผู้ใช้งาน/ลูกค้าไม่เข้าเงื่อนไข | Target is not eligible. |
| `SCOPE_NOT_MATCHED` | block | รายการสินค้าไม่ตรงขอบเขตโปร | Scope does not match current order. |
| `USAGE_LIMIT_EXCEEDED` | block | ใช้สิทธิ์ครบตามจำนวนที่กำหนดแล้ว | Usage limit has been reached. |
| `AVAILABILITY_FAILED` | block/warn | สินค้าหรือวัตถุดิบไม่พร้อมตามเงื่อนไข | Availability requirement failed. |
| `STACK_NOT_ALLOWED` | block | โปรนี้ใช้ร่วมกับส่วนลดอื่นไม่ได้ | Not stackable with other discounts. |
| `OVERRIDE_REQUIRED` | block | ต้องได้รับอนุมัติก่อนใช้งาน | Approval required before apply. |

กติกา:
- ให้แอปใช้ข้อความจากตารางนี้เป็นค่ามาตรฐาน
- หากต้องการปรับคำใน UI ให้คง `Reason Code` เดิมเสมอ
- log ต้องเก็บ `reason_code`, `reason_message_th`, `reason_message_en` สำหรับ analytics

## 2) Conflict Precedence (มาตรฐานการตัดสินโปรชนกัน)

เมื่อมีคูปอง/โปรโมชันหลายรายการที่เข้าเงื่อนไขพร้อมกัน ให้เรียงลำดับดังนี้:

1. โปรที่ผ่าน Rule Matrix ครบก่อน (ตัดรายการไม่ผ่านออกทั้งหมด)
2. นโยบายไม่ให้ซ้อน (`stackable = false`) มีสิทธิ์ตัดรายการอื่นทันที
3. ประเภทส่วนลดเชิงโครงสร้างก่อนส่วนลดเชิงราคา:
   - `buy_x_get_y` / `bundle` / item-level promotion
   - fixed amount
   - percentage
4. `priority` (สูงชนะต่ำ)
5. มูลค่าส่วนลดจริงสุทธิสูงกว่าเป็นผู้ชนะ
6. ถ้าเท่ากัน ให้ใช้ deterministic tie-breaker: `created_at` เก่ากว่า > `id` น้อยกว่า

ข้อกำหนด:
- POS, Admin preview, Simulation ต้องใช้ algorithm เดียวกัน 100%
- ต้องมี RPC/Service method เดียวเช่น `resolveDiscountConflicts()` และห้ามเขียนกติกาซ้ำใน widget

## 3) Concurrency & Idempotency Standard

### 3.1 Idempotency
- ทุกคำสั่ง apply coupon/promotion และ scan QR ต้องมี `idempotency_key`
- กำหนด unique key ที่ระดับธุรกรรม: `(order_id, idempotency_key, action_type)`
- คำขอซ้ำ key เดิมต้องคืนผลลัพธ์เดิม (ไม่บันทึกซ้ำ)

### 3.2 Concurrency Control
- ตอน checkout ให้ lock การใช้งานส่วนลดระดับ order (`SELECT ... FOR UPDATE` หรือเทียบเท่า RPC transaction)
- การเพิ่ม `used_count` ต้องเป็น atomic operation ใน DB function
- ป้องกัน oversubscribe limit โดยตรวจและอัปเดตใน transaction เดียว

### 3.3 Retry Policy
- retry เฉพาะข้อผิดพลาดชั่วคราว (network timeout/5xx)
- ห้าม retry อัตโนมัติเมื่อเป็น business rule fail (`*_NOT_ALLOWED`, `*_EXCEEDED`)
- ทุก retry ต้องใช้ `idempotency_key` เดิม

## 4) QR Security Hardening Standard

- รองรับ `signature_version` และ `key_id` ใน payload
- ทุก QR ต้องมี `issued_at`, `expires_at`, `nonce`
- validation ต้องตรวจ 4 ชั้น:
  - signature ถูกต้อง
  - ไม่หมดอายุ
  - nonce ไม่เคยถูกใช้ซ้ำในช่วงเวลาที่กำหนด
  - coupon/promotion lifecycle ยังใช้งานได้
- ใช้ key rotation ตามรอบ (เช่น รายไตรมาส) โดยรองรับ active key + previous key ชั่วคราว
- scan rate limit ต่ออุปกรณ์/ผู้ใช้/ช่วงเวลา
- log สถานะละเอียด: `valid`, `invalid_signature`, `expired`, `replay_detected`, `rule_blocked`

## 5) Monitoring & Alerting

ต้องมี dashboard กลางและ alert thresholds ชัดเจน

Core metrics:
- apply success rate
- validation fail rate แยกตาม reason code
- average discount per order
- override request rate และ approval rate
- QR invalid/replay rate
- latency ของ RPC สำคัญ (`validate`, `resolve conflict`, `record usage`)

ตัวอย่าง alert:
- `USAGE_LIMIT_EXCEEDED` พุ่งเกิน baseline > 3 เท่าใน 15 นาที
- QR invalid signature > 5% ใน 10 นาที
- discount apply latency p95 > 1.5s ต่อเนื่อง 10 นาที

## 6) UAT Pack (ก่อนขึ้น production)

### Scenario Group A: Functional
- ใช้ coupon ได้เมื่อครบเงื่อนไข
- coupon หมดอายุ/paused ใช้งานไม่ได้
- channel/user group targeting ทำงานถูกต้อง
- stackable และ conflict precedence ให้ผลตรงตาม spec

### Scenario Group B: Edge Cases
- ใช้พร้อมกันหลายเครื่องใน order เดียว (concurrency)
- ส่งคำขอซ้ำด้วย idempotency key เดิม (ต้องไม่ถูกคิดซ้ำ)
- usage limit ใกล้เต็ม/เต็มพอดี
- stock เปลี่ยนระหว่างกำลัง checkout

### Scenario Group C: Security
- QR ปลอมลายเซ็นต้องถูกปฏิเสธ
- QR หมดอายุต้องถูกปฏิเสธ
- QR เดิมสแกนซ้ำต้องจับ replay ได้

### Scenario Group D: Audit
- มี log reason code ครบทุกกรณี block/warn
- ตรวจสอบย้อนหลัง order → discount → approver ได้ครบสาย

## 7) Go-live Checklist

### Owner & SLA Matrix

| งาน | Owner หลัก | SLA เป้าหมาย |
|-----|------------|--------------|
| Migration + Backfill + Dry-run | DBA/Backend | เสร็จก่อน Go-live อย่างน้อย 3 วัน |
| Permission Matrix Review | Product Owner + Admin System | เสร็จก่อน Go-live อย่างน้อย 2 วัน |
| UAT Execution + Sign-off | QA Lead + Business Owner | Pass rate ≥ 95% ก่อน Go-live 1 วัน |
| Monitoring/Alert Setup | DevOps/Backend | ติดตั้งและทดสอบก่อน Go-live 1 วัน |
| Rollback Plan + Runbook | Tech Lead | อนุมัติก่อน Go-live 1 วัน |
| Hypercare (7 วันแรก) | On-call Team (Backend + POS) | ตอบสนอง Critical ≤ 15 นาที, High ≤ 1 ชั่วโมง |

### ก่อนขึ้นระบบ
- migration ครบและผ่าน dry-run
- backfill/compatibility script รันครบ
- permission matrix review ผ่าน
- UAT pass rate ≥ 95% และไม่มี critical issue ค้าง
- dashboard และ alerts เปิดใช้งานแล้ว

### วันขึ้นระบบ
- เปิด feature flags ตามลำดับ (admin → pilot store → all stores)
- เฝ้าดู metrics 2 ชั่วโมงแรกแบบ real-time
- มี rollback plan พร้อม owner ชัดเจน

### หลังขึ้นระบบ 7 วันแรก
- daily review ของ fail reasons top 10
- daily review ของ override และ conflict resolution
- สรุป incident และ action items เข้าสู่ Version History

---

# Development Phases

## สรุปความคืบหน้าภาพรวม

| Phase | สถานะ | ความคืบหน้า | รายละเอียด |
|-------|-------|-------------|-----------|
| 0: Schema & Permission | ✅ เสร็จสมบูรณ์ | 100% | Migration + Permission ครบ |
| 1: Coupon CRUD | ✅ เสร็จสมบูรณ์ | 100% | Form + Validation ครบ |
| 2: POS Integration + Usage Logging | ✅ เสร็จสมบูรณ์ | 100% | Apply + Record ครบ |
| 3: Product Picker Advanced Filters | ✅ เสร็จสมบูรณ์ | 100% | UI + APIs + Pagination + Caching + Sorting + Seasonal/Festival |
| 4: Availability & Procurement Rules | ✅ เสร็จสมบูรณ์ | 100% | RPC + Service + UI + POS Validation ครบ |
| 5: Expiry Targeting | ✅ เสร็จสมบูรณ์ | 100% | RPC + Views + Service + UI Tabs ครบ |
| 6: Promotion CRUD | ✅ เสร็จสมบูรณ์ | 100% | รวมกับ Phase 1 |
| 7: Usage Analytics Tab | ✅ เสร็จสมบูรณ์ | 100% | Analytics MVP พร้อมใช้งานจริง |
| 8: Business Recommendation | ✅ เสร็จสมบูรณ์ | 100% | Priority Score + Recommended Products พร้อมใช้งาน |
| 9: Governance | ✅ เสร็จสมบูรณ์ | 100% | Conflict/Approval/Audit/Override ครบ |
| 10: Advanced Analytics | ⏸️ On Hold | 0% | รอข้อมูลสะสม 3-6 เดือน |
| 11: QR Code System | ✅ เสร็จสมบูรณ์ | 100% | QR generation + validation + logs ครบ |
| 12: Coupon Visibility Control | ✅ เสร็จสมบูรณ์ | 100% | ควบคุมการแสดงคูปองแยกตามหน้าได้ |

**งานที่เสร็จสมบูรณ์แล้ว:**
1. ✅ **Phase 0-1:** Schema, Permission, Coupon/Promotion CRUD ครบ
2. ✅ **Phase 2:** POS apply coupon + validate + usage logging ครบ
3. ✅ **Phase 3:** Product Picker ครบทั้ง UI และ Backend:
   - ✅ High Priority: Performance fix, Filters, Search, Category, Stock, Price
   - ✅ Medium Priority: Pagination, Caching, Sorting
   - ✅ Low Priority: Seasonal/Festival schema และ APIs
4. ✅ **Phase 4:** Availability & Procurement Rules ครบทั้ง Backend และ UI:
   - ✅ SQL RPC functions: `check_product_availability()`, `check_recipe_ingredients_sufficient()`, `get_pending_procurement_quantity()`, `check_product_full_availability()`
   - ✅ `InventoryService` methods สำหรับตรวจสอบ availability
   - ✅ `PosPromotionService` validation methods สำหรับ POS
   - ✅ `PromotionFormPage` UI toggles สำหรับตั้งค่า availability
5. ✅ **Phase 5:** Expiry Targeting ครบทั้ง Backend และ UI:
   - ✅ SQL Views: `promotion_expiring_product_targets`, `promotion_expiring_ingredient_targets`
   - ✅ SQL RPC: `get_expiring_products()`, `get_expiring_ingredients()`, `get_recipes_from_expiring_ingredients()`
   - ✅ `InventoryService` methods: `getExpiringProducts()`, `getExpiringIngredients()`, `getExpirySummary()`
   - ✅ `CouponPromotionAdminPage` UI Tabs: "สินค้าใกล้หมดอายุ" และ "วัตถุดิบใกล้หมดอายุ"
   - ✅ Expiry filters: 3/7/14/30 วัน + หมดอายุแล้ว
   - ✅ Quick promotion creation from expiring items
6. ✅ **Phase 6:** Promotion CRUD (รวมกับ Phase 1)
7. ✅ **Phase 7:** Usage Analytics MVP เสร็จสมบูรณ์
8. ✅ **Phase 8:** Business Recommendation เสร็จสมบูรณ์ (รวม Priority Score)
9. ✅ **Phase 9:** Governance เสร็จสมบูรณ์
10. ✅ **Phase 11-12:** QR Code System และ Coupon Visibility Control เสร็จสมบูรณ์

**งานที่ยังค้าง (Priority ต่ำ/อนาคต):**
1. ⏸️ **Phase 10:** Advanced Analytics (รอข้อมูลสะสมขั้นต่ำ 90 วัน)

---

## Phase 0: Schema & Permission Baseline ✅

**สถานะ:** เสร็จสมบูรณ์ (รัน SQL migration แล้ว)  
**วันที่เสร็จ:** 4 พฤษภาคม 2568

เป้าหมาย: เตรียมฐานข้อมูลและสิทธิ์ให้พร้อมก่อนเริ่ม UI ขนาดใหญ่

### ที่ทำเสร็จแล้ว:
- ✅ ตรวจ schema ปัจจุบันของ discount, promotion, POS order, order line, customer, stock, recipe, procurement
- ✅ เพิ่ม field พื้นฐานที่จำเป็น:
  - ✅ `applicable_product_ids` (UUID[])
  - ✅ `targeting_mode` (TEXT)
  - ✅ `targeting_rule` (JSONB)
  - ✅ `lifecycle_status` (TEXT) - รองรับ: draft, scheduled, active, paused, expired, archived
  - ✅ `usage_limit_per_customer`, `usage_limit_per_day`, `usage_limit_per_order`
  - ✅ `applicable_channels` (TEXT[])
  - ✅ `require_in_stock`, `require_sufficient_ingredients`, `include_pending_procurement`
- ✅ เพิ่ม permission design:
  - ✅ `coupon_promotion` page
  - ✅ `coupon_promotion_coupons`, `coupon_promotion_promotions`, `coupon_promotion_analytics` tabs
  - ✅ `coupon_promotion_main` tab สำหรับ admin page
  - ✅ Action permissions: add/edit/delete สำหรับ coupon และ promotion
- ✅ สร้าง migration file: `lib/database/coupon_promotion_phase0_schema_baseline.sql`
- ✅ รัน migration บน Supabase แล้ว

### Test ผ่าน:
- ✅ เปิด/ปิดสิทธิ์แต่ละ tab/action ได้
- ✅ field ใหม่บันทึกและอ่านกลับได้
- ✅ migration รันซ้ำได้ปลอดภัย (ใช้ IF NOT EXISTS)

## Phase 1: Coupon CRUD ใช้งานได้จริง ✅

**สถานะ:** เสร็จสมบูรณ์ (แก้ไขปัญหาทั้งหมดแล้ว)  
**วันที่เสร็จ:** 4 พฤษภาคม 2568

เป้าหมาย: สร้าง แก้ไข และบันทึกคูปองพื้้นฐานได้ครบ flow

### ที่ทำเสร็จแล้ว:
- ✅ สร้าง `PromotionFormPage` แทน `_showPromotionDialog` (แก้ปัญหา Dialog Rendering Crash)
- ✅ สร้าง `PromotionProductPickerPage` 7 tabs ตาม spec:
  - [ทั้งหมด] [ใกล้หมดอายุ] [วัตถุดิบใกล้หมด] [กำไรสูง] [ตามฤดูกาล] [เทศกาล] [แนะนำ]
- ✅ Coupon/Promotion Form รองรับ:
  - ✅ ชื่อ, คำอธิบาย
  - ✅ ประเภทโปรโมชั่น (bundle/seasonal/buy_x_get_y)
  - ✅ เชื่อมกับส่วนลด (discount linker)
  - ✅ กลุ่มผู้ใช้ที่ใช้ได้ (multi-select chips)
  - ✅ ช่วงเวลา (start/end date picker)
  - ✅ สถานะเปิด/ปิดใช้งาน
  - ✅ เลือกสินค้าผ่าน `PromotionProductPickerPage`
- ✅ Validation สมบูรณ์:
  - ✅ ชื่อต้องไม่ว่าง
  - ✅ วันเริ่มต้นต้องไม่เกินวันสิ้นสุด
  - ✅ Bundle/Buy X Get Y ต้องมีสินค้าอย่างน้อย 1 รายการ
- ✅ Service Integration:
  - ✅ สร้างโปรโมชั่นใหม่ (`PosDiscountService.addDiscount`)
  - ✅ อัปเดตโปรโมชั่น (`PosDiscountService.updateDiscount`)
- ✅ Permission Checks:
  - ✅ เพิ่ม `checkPermissionAndExecute()` ครอบทุก action
  - ✅ เพิ่ม 6 action IDs ใน `user_permissions_page.dart`

### ปัญหาที่แก้ไข:
| ปัญหา | วิธีแก้ |
|-------|---------|
| Dialog Rendering Crash | เปลี่ยนเป็น `PromotionFormPage` + `PromotionProductPickerPage` |
| Product Selector ไม่ตาม Spec | สร้างหน้าเต็มจอ 7 tabs |
| ไม่มี Permission Check | ใช้ `checkPermissionAndExecute()` |

### Test ผ่าน:
- ✅ สร้างคูปอง/โปรโมชั่นใหม่
- ✅ แก้ไขคูปอง/โปรโมชั่น
- ✅ เลือกสินค้าผ่าน `PromotionProductPickerPage`
- ✅ Validation ทำงานถูกต้อง
- ✅ Permission checks ทำงาน
- ✅ บันทึกข้อมูลลง database สำเร็จ

## Phase 2: POS Checkout Integration + Usage Logging ✅

**สถานะ:** ✅ เสร็จสมบูรณ์ 5 พฤษภาคม 2568  
**Dependency:** Phase 1 เสร็จสมบูรณ์แล้ว  
**วันที่อัปเดต:** 4 พฤษภาคม 2568

เป้าหมาย: คูปองที่สร้างใช้ได้จริงตอนขาย และบันทึกประวัติการใช้ได้

### ที่ทำเสร็จแล้ว:
- ✅ Schema พร้อมรองรับ usage logging (`pos_order_discounts` table)
- ✅ POS page refactor แยก widget (เตรียมพื้นที่สำหรับเพิ่ม coupon UI)
- ✅ ช่องกรอก coupon code ใน POS (`PosDiscountPanelWidget`)
- ✅ `_applyCouponCode()` พร้อม validation ครบถ้วน
- ✅ Validate ตอน checkout: lifecycle, date/time, usage limit, channel, min_amount
- ✅ `recordDiscountUsage()` บันทึกการใช้งานลง database
- ✅ `increment_discount_usage()` SQL function สำหรับอัปเดต used_count
- ✅ Mini usage history แสดงในหน้า admin (uses, total discount, unique customers)

### Test ผ่าน:
- ✅ POS apply coupon ทำงานได้จริง
- ✅ Validate ตอน checkout:
  - lifecycle status
  - date/time
  - usage limit
  - customer targeting
  - channel targeting
  - scope item/category/order
  - stackable
- ✅ บันทึกการใช้:
  - order_id
  - discount_id/promotion_id
  - discount_amount
  - order line allocation เบื้องต้น
- ✅ Mini usage history แสดงในหน้าคูปอง

### Test ต้องผ่าน:
- ใช้คูปองใน order จริง
- คูปองหมดอายุ/หยุดชั่วคราวใช้ไม่ได้
- usage limit ทำงาน
- ประวัติการใช้เบื้องต้นถูกบันทึก

## Phase 3: Product Picker Advanced Filters ✅

**สถานะ:** ✅ เสร็จสมบูรณ์ 5-6 พฤษภาคม 2568  
**วันที่เสร็จ UI:** 4 พฤษภาคม 2568  
**วันที่เสร็จ Backend APIs:** 5-6 พฤษภาคม 2568  
**Note:** ทั้ง UI และ Backend API เสร็จสมบูรณ์ 100%

เป้าหมาย: เลือกสินค้าจำนวนมากได้ดีและไม่ทำให้ dialog หนัก พร้อมระบบ filter ขั้นสูง

### ที่ทำเสร็จแล้ว (UI):
- ✅ สร้าง `PromotionProductPickerPage` (หน้าเต็มจอ)
- ✅ เปิดจาก `PromotionFormPage` เมื่อกด "เลือกสินค้า"
- ✅ 7 Tabs ตาม spec:
  - ✅ **ทั้งหมด** - แสดงสินค้าทั้งหมด
  - ✅ **ใกล้หมดอายุ** - กรองตามวันหมดอายุ
  - ✅ **วัตถุดิบใกล้หมด** - แสดงสินค้าที่ใช้วัตถุดิบใกล้หมดอายุ
  - ✅ **กำไรสูง** - กรองตาม margin
  - ✅ **ตามฤดูกาล** - กรองตามฤดูกาลวัตถุดิบ
  - ✅ **เทศกาล** - แสดงสินค้าตามเทศกาล
  - ✅ **แนะนำ** - แสดงสินค้าที่ระบบแนะนำ
- ✅ Search สินค้า
- ✅ Category filter UI
- ✅ Multi-select พร้อม checkbox
- ✅ ปรับ quantity แต่ละรายการ
- ✅ Selected summary แสดงจำนวนที่เลือก
- ✅ ส่ง selected products กลับ `PromotionFormPage`

### ที่ทำเสร็จแล้ว (Backend - High Priority):
- ✅ **Performance Fix** - Batch API `getStockDetailsForProducts()` แก้ N+1 queries
- ✅ **Stock filter** - API `getProductsForPicker(requireInStock: true)`
- ✅ **Price filter** - API `getProductsForPicker(minPrice, maxPrice)`
- ✅ **Search filter** - API `getProductsForPicker(searchQuery)`
- ✅ **Category filter** - API `getProductsForPicker(categoryId)`
- ✅ **Availability checks** - API `checkProductAvailability()`
- ✅ **Select all เฉพาะผลลัพธ์หลัง filter** - ทำงานแล้ว

### ที่ทำเสร็จแล้ว (Backend - Medium Priority):
- ✅ **Pagination APIs** - สำหรับ large datasets:
  - ✅ `getProductsPaginated()` - พร้อม filter และ sorting
  - ✅ `getExpiringProductsPaginated()` - สินค้าใกล้หมดอายุ
  - ✅ `getHighMarginProductsPaginated()` - สินค้ากำไรสูง
- ✅ **Caching System** - API response caching ด้วย cache key:
  - ✅ Cache 5 นาที (configurable)
  - ✅ Auto-expire และ manual clear
  - ✅ Cache stats สำหรับ monitoring
- ✅ **Sorting Options** - รองรับ sort ตามหลาย field:
  - ✅ `name`, `price`, `quantity`, `margin_percent`, `expiry_date`
  - ✅ Ascending/descending ทุก field

### ที่ทำเสร็จแล้ว (Backend - Low Priority):
- ✅ **Seasonal/Festival Schema** - SQL schema สำหรับ:
  - ✅ `promotion_seasonal_tags` - ตารางฤดูกาล
  - ✅ `promotion_festival_tags` - ตารางเทศกาล
  - ✅ `promotion_product_seasonal_links` - ความสัมพันธ์สินค้ากับฤดูกาล
  - ✅ `promotion_product_festival_links` - ความสัมพันธ์สินค้ากับเทศกาล
  - ✅ Views สำหรับดึงข้อมูล seasonal/festival
- ✅ **Seasonal/Festival APIs**:
  - ✅ `getSeasonalProductsForPicker()` - ดึงสินค้าตามฤดูกาล
  - ✅ `getFestivalProductsForPicker()` - ดึงสินค้าตามเทศกาล
  - ✅ `getSeasonalTags()` - ดึงรายการฤดูกาลทั้งหมด
  - ✅ `getFestivalTags()` - ดึงรายการเทศกาลทั้งหมด
  - ✅ `getCurrentSeason()` - ดึงฤดูกาลปัจจุบัน

### Models ที่สร้างใหม่:
- ✅ `/lib/models/promotion_product_model.dart` - Standardized `PromotionProduct` model
- ✅ `/lib/models/pagination_model.dart` - `PaginatedResult` และ `PaginationState`

### APIs ที่สร้าง/อัปเดตใน `InventoryService`:
| Method | คำอธิบาย |
|--------|----------|
| `getProductsForPicker()` | ดึงสินค้าพร้อม filter ทั้งหมด |
| `getStockDetailsForProducts()` | Batch stock lookup (Performance) |
| `getProductsPaginated()` | Pagination พร้อม filter/sort |
| `getExpiringProductsPaginated()` | สินค้าใกล้หมดอายุแบบ paginated |
| `getHighMarginProductsPaginated()` | สินค้ากำไรสูงแบบ paginated |
| `getSeasonalProductsForPicker()` | สินค้าตามฤดูกาล |
| `getFestivalProductsForPicker()` | สินค้าตามเทศกาล |
| `checkProductAvailability()` | ตรวจสอบสินค้าพร้อมขาย |
| `clearCachePattern()` | ล้าง cache ตาม pattern |
| `getCacheStats()` | ดูสถิติ cache |

### ที่ยังค้าง (รอข้อมูลเพิ่มเติม):
- ⏳ **Priority Score Calculation** - รอ algorithm คำนวณ score
- ⏳ **Recommendation Engine** - รอ ML/Business rules

**Dependency:** ✅ Phase 3 เสร็จสมบูรณ์แล้ว ไม่ต้องรอ Phase 4

### Test ผ่าน:
- ✅ เลือกสินค้า 100+ รายการได้
- ✅ filter แล้วยังรักษา selected state
- ✅ เลือกทั้งหมดเฉพาะผลลัพธ์ปัจจุบันได้
- ✅ UI ไม่ค้าง (Performance ดีขึ้นด้วย Pagination + Caching)
- ✅ Sorting ทำงานถูกต้องทุก tab
- ✅ Cache system ทำงานถูกต้อง

## Phase 4: Availability & Procurement Rules ✅

**สถานะ:** ✅ เสร็จสมบูรณ์  
**Dependency:** Phase 2 ✅ เสร็จแล้ว  
**วันที่เสร็จ:** 6 พฤษภาคม 2568

เป้าหมาย: ป้องกันการออกคูปอง/โปรโมชันกับสินค้าหรือวัตถุดิบที่ไม่พร้อมโดยไม่ตั้งใจ

### กฎธุรกิจที่ใช้:
- ✅ **stock > 0** = พร้อมขาย
- ✅ **วัตถุดิบพอ** = ผลิตได้มากกว่า 1 ชิ้น
- ✅ **pending procurement** = นับ PO ทั้งหมดยกเว้น completed/cancelled
- ✅ **block** เมื่อสินค้าไม่พร้อม

### ที่ทำเสร็จแล้ว:

#### **Backend (SQL):**
- ✅ สร้าง SQL Check Script: `lib/database/phase4_schema_check.sql`
- ✅ สร้าง RPC `check_product_availability()` - ตรวจสอบ stock พร้อมขาย
- ✅ สร้าง RPC `get_pending_procurement_quantity()` - ดึงจำนวนรอรับจาก PO
- ✅ สร้าง RPC `check_recipe_ingredients_sufficient()` - ตรวจสอบวัตถุดิบพอผลิต > 1 ชิ้น
- ✅ สร้าง RPC `check_product_full_availability()` - ตรวจสอบแบบครบวงจร
- ✅ สร้าง RPC `get_available_products()` - ดึงรายการสินค้าพร้อมขายทั้งหมด
- ✅ สร้าง View `product_availability_summary`

#### **Service Layer (Dart):**
- ✅ อัปเดต `InventoryService` พร้อม methods:
  - `checkProductAvailability()` - ตรวจสอบ stock
  - `getPendingProcurementQuantity()` - ดึง pending procurement
  - `checkRecipeIngredientsSufficient()` - ตรวจสอบสูตรอาหาร
  - `checkProductFullAvailability()` - ตรวจสอบแบบครบวงจร
  - `getAvailableProducts()` - ดึงสินค้าพร้อมขาย
  - `getProductAvailabilitySummary()` - ดึงสรุปจาก view
  - `checkProductsAvailabilityBatch()` - ตรวจสอบหลายรายการ
  - `filterAvailableProducts()` - กรองเฉพาะสินค้าพร้อมขาย
- ✅ อัปเดต `PosPromotionService` พร้อม methods:
  - `validatePromotionAvailability()` - ตรวจสอบโปรโมชั่นตามกฎ availability
  - `filterAvailablePromotions()` - กรองโปรโมชั่นที่ใช้งานได้
  - `getApplicablePromotionsForPos()` - ดึงโปรโมชั่นสำหรับ POS พร้อม validation

#### **UI Layer (Flutter):**
- ✅ อัปเดต `PosPromotion` model เพิ่ม fields:
  - `requireInStock`
  - `requireSufficientIngredients`
  - `includePendingProcurement`
- ✅ อัปเดต `PromotionFormPage` เพิ่ม Card "กฎการตรวจสอบสินค้าพร้อมขาย":
  - Toggle "ต้องมีสต็อกพร้อมขาย"
  - Toggle "ต้องมีวัตถุดิบพอผลิต"
  - Toggle "นับรวมการจัดซื้อที่รอรับ"
  - Summary box แสดงกฎที่เปิดใช้งาน
- ✅ อัปเดต `PosPromotionService.addPromotion()` และ `updatePromotion()` รองรับ availability fields

### ไฟล์ที่สร้าง/อัปเดต:
- `lib/database/phase4_schema_check.sql` - SQL ตรวจสอบ schema
- `lib/database/coupon_promotion_phase4_availability.sql` - RPC functions
- `lib/models/pos_promotion_model.dart` - เพิ่ม availability fields
- `lib/services/inventory_service.dart` - เพิ่ม availability methods
- `lib/services/pos_promotion_service.dart` - เพิ่ม validation methods
- `lib/pages/promotion_form_page.dart` - เพิ่ม UI toggles

### วิธีใช้:

#### **SQL:**
```sql
-- ตรวจสอบสินค้าพร้อมขาย
SELECT * FROM check_product_availability('product-uuid', true, false);

-- ตรวจสอบวัตถุดิบพอผลิตหรือไม่
SELECT * FROM check_recipe_ingredients_sufficient('product-uuid');

-- ตรวจสอบแบบครบวงจร
SELECT * FROM check_product_full_availability('product-uuid', true, true, true);

-- ดูสรุป availability ทั้งหมด
SELECT * FROM product_availability_summary;
```

#### **Dart (Service):**
```dart
// ตรวจสอบสินค้าพร้อมขาย
final availability = await InventoryService.checkProductFullAvailability(
  productId,
  requireInStock: true,
  requireSufficientIngredients: true,
  includePendingProcurement: true,
);

// ตรวจสอบโปรโมชั่นตามกฎ availability
final validation = await PosPromotionService.validatePromotionAvailability(
  promotionId,
  orderProductIds: ['product-1', 'product-2'],
);

// ดึงโปรโมชั่นที่ใช้งานได้สำหรับ POS
final promotions = await PosPromotionService.getApplicablePromotionsForPos(
  orderProductIds: ['product-1', 'product-2'],
);
```

### Test ได้:
- ✅ SQL RPC functions ทำงานถูกต้อง
- ✅ InventoryService methods พร้อมใช้งาน
- ✅ PosPromotionService validation พร้อมใช้งาน
- ✅ PromotionFormPage UI แสดง toggles ถูกต้อง
- ✅ บันทึก/โหลด availability settings ได้
- ✅ Flutter build ผ่าน - แก้ duplicate methods และ parameter mismatches
- ✅ แอปรันบน Android ได้สำเร็จ

## Phase 5: Expiry Targeting ✅

**สถานะ:** ✅ เสร็จสมบูรณ์  
**Dependency:** Phase 4 ✅ เสร็จแล้ว + `inventory_item_batches` schema  
**วันที่เสร็จ:** 6 พฤษภาคม 2568

เป้าหมาย: ระบายสินค้าและวัตถุดิบใกล้หมดอายุผ่านโปรโมชั่น

### กฎธุรกิจที่ใช้:
- ✅ **critical** = หมดอายุแล้ว หรือ ≤ 3 วัน (ส่วนลด 40-50%)
- ✅ **warning** = 4-7 วัน (ส่วนลด 15-25%)
- ✅ **normal** = 8-30 วัน (ส่วนลด 10%)
- ✅ แนะนำเมนูที่ใช้วัตถุดิบนั้นเพื่อระบาย

### ที่ทำเสร็จแล้ว (Backend):
- ✅ สร้าง View `promotion_expiring_product_targets` - สินค้าใกล้หมดอายุพร้อม batch details
- ✅ สร้าง View `promotion_expiring_ingredient_targets` - วัตถุดิบใกล้หมดอายุพร้อมเมนูที่ใช้
- ✅ สร้าง RPC `get_expiring_products(days_threshold, include_expired)` - ดึงสินค้าตามช่วงวัน
- ✅ สร้าง RPC `get_expiring_ingredients(days_threshold, include_expired)` - ดึงวัตถุดิบตามช่วงวัน
- ✅ สร้าง RPC `get_recipes_from_expiring_ingredients(ingredient_ids, days_threshold)` - แนะนำเมนู
- ✅ อัปเดต `InventoryService` พร้อม methods:
  - `getExpiringProducts()` - สินค้าใกล้หมดอายุ
  - `getExpiringIngredients()` - วัตถุดิบใกล้หมดอายุ
  - `getRecipesFromExpiringIngredients()` - เมนูแนะนำ
  - `getExpirySummary()` - สรุป dashboard
  - `getExpiringProductsByFilter()` - กรองตามช่วง (3/7/14/30 วัน)

### ที่ทำเสร็จแล้ว (UI):
- ✅ **Tab "สินค้าใกล้หมดอายุ"** - ใน CouponPromotionAdminPage
- ✅ **Tab "วัตถุดิบใกล้หมดอายุ"** - แสดงเมนูที่ใช้
- ✅ **Expiry filters** - ปุ่ม 3/7/14/30 วัน + หมดอายุแล้ว
- ✅ **Batch details** - แสดงใน card พร้อมจำนวน
- ✅ **Quick promotion** - ปุ่มสร้างโปรโมชั่นด่วนจากรายการที่เลือก

### ไฟล์ที่สร้าง:
- `lib/database/coupon_promotion_phase5_expiry_targeting.sql` - Views + RPC functions
- `lib/pages/coupon_promotion_admin_page.dart` - อัปเดต UI Tabs สำหรับ expiry targeting

### วิธีใช้:
```sql
-- ดึงสินค้าใกล้หมดอายุภายใน 7 วัน
SELECT * FROM get_expiring_products(7, true);

-- ดึงวัตถุดิบใกล้หมดอายุพร้อมเมนูที่ใช้
SELECT * FROM get_expiring_ingredients(7, true);

-- แนะนำเมนูจากวัตถุดิบใกล้หมดอายุ
SELECT * FROM get_recipes_from_expiring_ingredients(ARRAY['ingredient-uuid'], 7);

-- ดูสรุปทั้งหมด
SELECT * FROM promotion_expiring_product_targets;
SELECT * FROM promotion_expiring_ingredient_targets;
```

### Dart (Service):
```dart
// ดึงสินค้าใกล้หมดอายุ
final products = await InventoryService.getExpiringProducts(
  daysThreshold: 7,
  includeExpired: true,
);

// ดึงวัตถุดิบพร้อมเมนูที่ใช้
final ingredients = await InventoryService.getExpiringIngredients(
  daysThreshold: 7,
);

// ดึงเมนูแนะนำ
final recipes = await InventoryService.getRecipesFromExpiringIngredients(
  ingredientIds: ['ingredient-1', 'ingredient-2'],
  daysThreshold: 7,
);

// กรองตามช่วง
final expiringIn3Days = await InventoryService.getExpiringProductsByFilter('3days');
```

### Test ได้:
- ✅ SQL Views แสดงสินค้า/วัตถุดิบใกล้หมดอายุ
- ✅ SQL RPC functions ทำงานถูกต้อง
- ✅ InventoryService methods พร้อมใช้งาน
- ✅ ส่วนลดแนะนำถูกต้องตามระดับความเร่งด่วน
- ✅ แนะนำเมนูจากวัตถุดิบใกล้หมดอายุ
- ✅ UI Tabs "สินค้าใกล้หมดอายุ" และ "วัตถุดิบใกล้หมดอายุ" พร้อมใช้งาน
- ✅ Expiry filters (3/7/14/30 วัน) ทำงานถูกต้อง
- ✅ Quick promotion creation จากรายการที่เลือก
- ✅ Flutter build ผ่าน - แก้ duplicate methods และ parameter mismatches
- ✅ แอปรันบน Android ได้สำเร็จ

## Phase 6: Promotion CRUD + Campaign Types ✅

**สถานะ:** เสร็จสมบูรณ์ (รวมกับ Phase 1)  
**วันที่เสร็จ:** 4 พฤษภาคม 2568  
**Note:** สร้าง `PromotionFormPage` พร้อมรองรับ promotion types แล้ว

เป้าหมาย: แยก promotion ออกจาก coupon ให้ชัด และเริ่มรองรับ campaign type

### ที่ทำเสร็จแล้ว:
- ✅ `PromotionFormPage` แยกออกจาก Coupon Dialog
- ✅ Promotion types: bundle, seasonal, buy_x_get_y
- ✅ Promotion lifecycle ภาษาไทย
- ✅ Schedule (start/end date)
- ✅ Activation/pause/archive ผ่านสถานะ isActive

- Promotion dialog/page
- Promotion lifecycle ภาษาไทย
- Promotion types:
  - seasonal
  - buy x get y
  - bundle
  - clearance
  - happy hour
- ใช้ product picker ร่วมกัน
- Schedule
- Activation/pause/archive
- POS apply promotion สำหรับ type พื้นฐาน

Test ได้:

- สร้าง promotion
- เลือกสินค้าเป้าหมาย
- ใช้ใน POS ได้บางประเภท
- สถานะ lifecycle ทำงาน

## Phase 7: Usage Analytics Tab - MVP ✅ **สำเร็จสมบูรณ์**

**สถานะ:** เสร็จสมบูรณ์ (7 พฤษภาคม 2568)  
**Dependency:** Phase 2 (Usage Logging)

เป้าหมาย: เห็นผลลัพธ์หลังใช้งานจริงในแถบ `วิเคราะห์การใช้งาน`

### ✅ ที่เสร็จสมบูรณ์แล้ว:
- ✅ **Database Views & Functions** - สร้างเรียบร้อยใน Supabase
  - `coupon_promotion_usage_summary` view
  - `order_discount_details` view
  - `analytics_summary` view
  - `get_analytics_summary()` function
  - `get_usage_analytics()` function
- ✅ **Service Layer Methods** - พัฒนาเสร็จ
  - `getAnalyticsSummary()` - ข้อมูลสรุปสำหรับ dashboard
  - `getUsageAnalytics()` - ข้อมูลการใช้งานโดยละเอียด
  - `getOrderDetailsForDiscount()` - ดูรายละเอียดออเดอร์
- ✅ **UI Implementation** - ใช้งานจริงแทน mock data
  - Summary cards แสดงสถิติการใช้งาน
  - Usage table แสดงรายละเอียด
  - Date range filtering
  - Coupon/Promotion filtering
  - Order drill-down functionality
  - Responsive design สำหรับทุกขนาดหน้าจอ
  - แก้ปัญหา UI การซ้อนทับและ dropdown บดบังข้อความ

### ✅ Test ได้:
- ✅ เห็นจำนวนครั้งที่ใช้ (จากข้อมูลจริง)
- ✅ เห็นยอดส่วนลดรวม (จากข้อมูลจริง)
- ✅ เห็น order ที่เกี่ยวข้อง (จากข้อมูลจริง)
- ✅ ข้อมูลตรงกับ POS order (real-time data)
- ✅ การกรองตามวันที่และประเภททำงาน
- ✅ Order drill-down แสดงรายละเอียดสินค้าและลูกค้า
- ✅ UI ไม่มีการซ้อนทับกันบนทุกขนาดหน้าจอ

## Phase 8: Business Recommendation ✅ **COMPLETED**

**สถานะ:** เสร็จสมบูรณ์  
**วันที่อัปเดต:** 7 พฤษภาคม 2568

เป้าหมาย: เพิ่ม intelligence สำหรับเลือกสินค้าเป้าหมายทางธุรกิจ

### ✅ ที่เสร็จสมบูรณ์ทั้งหมด:
- ✅ **Priority Score Algorithm** - สร้าง 5 PostgreSQL functions คำนวณคะแนนจาก 5 ปัจจัย
- ✅ **Database View** - สร้าง `promotion_recommended_targets` view รวมข้อมูลพร้อมคะแนน
- ✅ **Service Layer** - เพิ่ม `getRecommendedProducts()` API และ helper methods
- ✅ **Dart Model** - สร้าง `RecommendedProduct` model สำหรับข้อมูลแนะนำ
- ✅ **UI Integration** - เชื่อมต่อ Tab "แนะนำ" ใน PromotionProductPickerPage
- ✅ **UI Display** - แสดงคะแนน, อันดับ, สาเหตุ, สต็อก, วันหมดอายุ, ส่วนลดแนะนำ
- ✅ **13 สูตรคำนวณ** - รองรับสูตรแนะนำที่สร้างไว้ก่อนหน้านี้

### 📁 Files ที่สร้าง/แก้ไข:
- ✅ `lib/database/create_priority_score_functions.sql` - 5 functions คำนวณคะแนน
- ✅ `lib/database/create_promotion_recommended_targets_view.sql` - view รวมข้อมูล
- ✅ `lib/services/pos_promotion_service.dart` - API methods สำหรับ recommended products
- ✅ `lib/models/recommended_product_model.dart` - model สำหรับข้อมูลแนะนำ
- ✅ `lib/pages/promotion_product_picker_page.dart` - UI integration และ subtitle display

### 🚀 ความสามารถที่ใช้งานได้:
- ✅ Tab "แนะนำ" แสดงสินค้าตามลำดับคะแนนสูงสุด
- ✅ แสดงข้อมูลครบถ้วน: คะแนนรวม, ระดับความสำคัญ, อันดับ, สาเหตุการแนะนำ
- ✅ แสดงข้อมูลสต็อก: คงเหลือ, วันที่เหลือหมดอายุ, สถานะหมดอายุ
- ✅ แสดงส่วนลดที่แนะนำตามคะแนน
- ✅ สีและไอคอนแสดงระดับความสำคัญ (Critical/High/Medium/Low)
- ✅ รองรับ 13 สูตรคำนวณคะแนนที่สร้างไว้ก่อนหน้านี้

### 🎯 ผลลัพธ์:
ระบบแนะนำสินค้าอัจฉริยะพร้อมใช้งานได้จริง! สามารถเข้าไปทดสอบได้ที่ Promotion Product Picker Page → Tab "แนะนำ"

### ที่เสร็จแล้ว (จาก Phase 3):
- ✅ **Seasonal/Festival Schema** - SQL tables และ views
- ✅ **Seasonal/Festival APIs** - ดึงข้อมูลสินค้าตามฤดูกาล/เทศกาลได้จริง
- ✅ **High Margin APIs** - ดึงสินค้าตามระดับกำไรได้จริง

### สูตร Priority Score (ที่แนะนำ):

```
คะแนนรวม = (กำไร × 0.25) + (ความเร่งด่วนหมดอายุ × 0.35) + (ความเหมาะสมฤดูกาล × 0.20) + (ความเหมาะสมเทศกาล × 0.10) + (ความเร่งด่วนวัตถุดิบ × 0.10)

โดยแต่ละปัจจัยคำนวณดังนี้:

1. กำไร (Margin Score): 0-100 คะแนน
   - กำไร ≥ 50% = 100 คะแนน
   - กำไร 30-49% = 70 คะแนน
   - กำไร 10-29% = 40 คะแนน
   - กำไร < 10% = 10 คะแนน

2. ความเร่งด่วนหมดอายุ (Expiry Urgency): 0-100 คะแนน
   - หมดอายุแล้ว = 100 คะแนน (บังคับ top priority)
   - เหลือ ≤ 3 วัน = 90 คะแนน
   - เหลือ 4-7 วัน = 70 คะแนน
   - เหลือ 8-14 วัน = 50 คะแนน
   - เหลือ 15-30 วัน = 30 คะแนน
   - เหลือ > 30 วัน = 0 คะแนน

3. ความเหมาะสมฤดูกาล (Seasonal Relevance): 0-100 คะแนน
   - อยู่ในฤดูกาลพอดี = 100 คะแนน
   - ใกล้สิ้นฤดู (เหลือ < 30 วัน) = 80 คะแนน
   - นอกฤดูกาล = 0 คะแนน

4. ความเหมาะสมเทศกาล (Festival Relevance): 0-100 คะแนน
   - วันเทศกาลพอดี = 100 คะแนน
   - ก่อนเทศกาล 1-7 วัน = 90 คะแนน
   - ก่อนเทศกาล 8-14 วัน = 70 คะแนน
   - ไม่ใช่ช่วงเทศกาล = 0 คะแนน

5. ความเร่งด่วนวัตถุดิบ (Ingredient Expiry): 0-100 คะแนน
   - วัตถุดิบหลักใกล้หมดอายุ ≤ 7 วัน = 100 คะแนน
   - วัตถุดิบหลักใกล้หมดอายุ 8-14 วัน = 70 คะแนน
   - ไม่มีวัตถุดิบใกล้หมดอายุ = 0 คะแนน

ส่วนลดที่แนะนำ (จากคะแนนรวม):
- คะแนน ≥ 80: ส่วนลด 30-50% (ด่วนมาก)
- คะแนน 60-79: ส่วนลด 20-30% (ด่วนปานกลาง)
- คะแนน 40-59: ส่วนลด 10-20% (ปกติ)
- คะแนน < 40: ส่วนลด 5-10% (ไม่เร่งด่วน)
```

### Implementation Approach ที่แนะนำ:
**แบบ C. Hybrid** (แนะนำ)
- SQL คำนวณคะแนนเบื้องต้น (raw scores) ผ่าน View/RPC
- Dart รวมคะแนนและปรับ weight ตาม business rule
- ข้อดี: เร็ว + ยืดหยุ่น ปรับ weight ได้ไม่ต้องแก้ SQL

Test ได้:

- ✅ เห็นรายการ High Margin พร้อมเหตุผล
- ✅ เห็นรายการ Seasonal พร้อมเหตุผล
- ✅ เห็นรายการ Festival พร้อมเหตุผล
- ✅ sort ตาม priority score ได้
- ✅ เลือกไปทำคูปอง/โปรโมชันได้

## Phase 9: Governance ✅ **เสร็จสมบูรณ์**

**สถานะ:** เสร็จสมบูรณ์ (8 พฤษภาคม 2568)  
**Priority:** ปานกลาง (รองรับการจัดการภาษีและตรวจสอบ)

เป้าหมาย: ทำให้ระบบปลอดภัยต่อรายได้และตรวจสอบย้อนหลังได้ รองรับการจัดการภาษีตามผังบัญชีที่ออกแบบไว้

### ✅ ที่ดำเนินการเสร็จแล้ว:
- ✅ Database Schema - สร้าง 7 ตาราง พร้อม functions และ triggers
- ✅ Conflict Detection Service - ตรวจสอบสินค้าซ้ำ, เวลาทับซ้อน, stock, margin
- ✅ Preview/Simulation Service - จำลองผลกระทบก่อนเปิดใช้งาน
- ✅ Approval Workflow Service - 3 ระดับ (หัวหน้าร้าน/ผู้จัดการ/ผู้บริหาร)
- ✅ Audit Log Service - บันทึกทุกการกระทำของผู้ใช้งานที่มีสิทธิ
- ✅ Override Permission Service - ตรวจสอบสิทธิตามกลุ่มผู้ใช้งาน
- ✅ Governance Page UI - หน้าจอสำหรับดู conflicts, approvals, audit logs
- ✅ Integration - เชื่อมต่อกับหน้าคูปองและโปรโมชันพร้อม permission checks
- ✅ Testing - แก้ไข compile errors และทดสอบระบบทั้งหมด

### 📁 Files ที่สร้าง:
- ✅ `lib/database/coupon_promotion_phase9_governance.sql` - Database schema
- ✅ `lib/services/promotion_governance_service.dart` - Service layer (compile ไม่มี error)
- ✅ `lib/pages/promotion_governance_page.dart` - UI page
- ✅ `lib/pages/coupon_promotion_admin_page.dart` - เพิ่ม navigation และ permission checks

### ความสามารถที่ใช้งานได้:
- ✅ ตรวจจับสินค้าซ้ำในโปรโมชันหลายอัน
- ✅ ตรวจจับช่วงเวลาทับซ้อนกัน
- ✅ ตรวจสอบ stock และวัตถุดิบก่อนเปิดโปร
- ✅ ป้องกันการส่วนลดเกิน margin
- ✅ อนุมัติ 3 ระดับตามยอดเงิน (5,000/50,000/ไม่จำกัด)
- ✅ บันทึกประวัติทุกการกระทำสำหรับการตรวจสอบภาษี
- ✅ Override ได้ตามสิทธิกลุ่มผู้ใช้งาน
- ✅ จำลองผลกระทบก่อนเปิดใช้งานจริง
- ✅ เข้าถึง governance page จากหน้าคูปองและโปรโมชัน
- ✅ ตรวจสอบสิทธิก่อนเข้าใช้งาน

### 🔧 การแก้ไขปัญหา:
- ✅ แก้ไข PostgrestTransformBuilder compile errors ทั้งหมด
- ✅ ใช้ RPC calls แทน direct queries ที่มีปัญหา
- ✅ ทำให้ service layer compile ได้ 100%

Test ได้:

- ✅ เห็น warning ก่อนเปิดโปร
- ✅ ตรวจโปรซ้อนกันได้
- ✅ ผู้ไม่มีสิทธิ์ override ไม่ได้
- ✅ ประวัติแก้ไขครบ (รองรับการตรวจสอบภาษี)

## Phase 10: Advanced Analytics 📅 **เลื่อนไปทำในอนาคต**

**สถานะ:** ⏸️ On Hold (พักไว้ก่อนเพราะยังไม่มีข้อมูลสำหรับทดสอบ)  
**Priority:** ต่ำ  
**วันที่ตัดสินใจ:** 8 พฤษภาคม 2568

**เหตุผลที่เลื่อน:**
- ยังไม่มีข้อมูลสะสมที่เพียงพอสำหรับทดสอบ Advanced Analytics อย่างน่าเชื่อถือ
- ต้องรอข้อมูลยอดขายสะสมย้อนหลังอย่างน้อย 3-6 เดือน
- ระบบหลัก Phase 0-9 เสร็จสมบูรณ์แล้ว ควรนำไปใช้งานจริงก่อน
- Analytics ไม่จำเป็นสำหรับการใช้งานระบบ Coupon & Promotion เบื้องต้น

**งานที่จะทำในอนาคต:**
- Graphs และ data visualization
- Top 10 coupon/promotion report
- Top 10 target products analysis
- Margin impact analysis
- Before/during/after campaign comparison
- Export CSV/Excel/PDF
- วิเคราะห์เชิงลึก:
  - ยอดขายที่เกิดจากโปรโมชัน
  - ปริมาณสินค้าที่ระบายได้
  - วัตถุดิบที่ใช้ไป
  - กำไรขั้นต้นหลังหักส่วนลด
  - ผลลัพธ์ตามฤดูกาลหรือเทศกาล

**เงื่อนไขที่จะกลับมาทำ:**
- มีข้อมูลยอดขายสะสมอย่างน้อย 90 วัน
- ระบบ Phase 0-9 ใช้งานเสถียรใน production
- มีความต้องการจากผู้ใช้งานจริง

---

# Open Questions (คงเหลือสำหรับอนาคต)

- จะเริ่ม Phase 10 เมื่อข้อมูลสะสมครบกี่วันระหว่าง 90 หรือ 180 วัน
- รูปแบบรายงาน Advanced Analytics ที่ต้องใช้จริงในรอบแรกคืออะไร (กราฟ, export, comparison)
- จะกำหนด KPI กลางสำหรับวัดผลคูปอง/โปรโมชันอย่างไร (เช่น uplift, margin impact, sell-through)

---

# ✅ ระบบพร้อมใช้งานจริง!

**สถานะปัจจุบัน:** ✅ Phase 0-9, 11-12 เสร็จสมบูรณ์ 100% และ ⏸️ Phase 10 อยู่ระหว่าง On Hold  
**วันที่อัปเดต:** 8 พฤษภาคม 2568

ระบบ Coupon & Promotion พร้อมใช้งานใน production แล้ว! มีความสามารถครบถ้วนตั้งแต่สร้างคูปอง ไปจนถึงวิเคราะห์การใช้งาน

## 🚀 ขั้นตอนแนะนำต่อไป:

### 1. ทดสอบระบบใน Production (สำคัญที่สุด)
- ทดสอบสร้างคูปองหลายประเภท (เปอร์เซ็นต์, จำนวนเงิน, buy X get Y)
- ทดสอบใช้คูปองผ่าน POS หน้าร้านจริง
- ทดสอบสิทธิ์การเข้าถึงกับพนักงานแต่ละระดับ
- ตรวจสอบการบันทึก usage log และ analytics

### 2. ฝึกอบรมพนักงาน
- วิธีสร้างคูปองและโปรโมชัน
- วิธีใช้ Product Picker แบบต่างๆ (แนะนำ, ใกล้หมดอายุ, กำไรสูง)
- วิธีใช้คูปองใน POS
- การดูรายงานและ analytics

### 3. เก็บ Feedback และปรับปรุง
- เก็บ feedback จากผู้ใช้งานจริง 1-2 สัปดาห์
- แก้ไข bug ที่พบ (ถ้ามี)
- ปรับ UX/UI ตาม feedback

### 4. วางแผน Phase 10 (อนาคต)
- รอสะสมข้อมูลยอดขาย 3-6 เดือน
- ค่อยกลับมาทำ Advanced Analytics เมื่อมีข้อมูลพอ

---

# Phase 11: QR Code System (8 พฤษภาคม 2568)

## เป้าหมาย
เพิ่ม QR Code support สำหรับคูปองและโปรโมชันทุกประเภท พร้อมระบบ scan และ validation ครบวงจร

## ฟีเจอร์ที่ implement

### 1. QR Code Generation
- **คูปอง:** JSON format พร้อม HMAC signature (`tlz_coupon`)
- **โปรโมชัน:** JSON format พร้อม HMAC signature (`tlz_promotion`)
- **Auto-generation:** สร้างอัตโนมัติเมื่อสร้างคูปอง/โปรโมชันใหม่
- **Unique codes:** สร้างรหัสสั้น (เช่น `PROMO_ABC12345`) จาก UUID

### 2. QR Code Display
- **Coupon Card:** แสดง QR Code ขนาด 140x140px พร้อมรหัสคูปอง
- **Promotion Card:** แสดง QR Code พร้อมรหัสโปรโมชัน
- **TLZ Logo:** แสดงโลโก้ตรงกลาง QR Code
- **Color scheme:** ใช้สี theme ของระบบ

### 3. QR Scanner & Validation
- **POS Integration:** ช่องส่วนลดรองรับ QR Scanner
- **Auto-fill:** แสกนแล้วกรอกรหัสอัตโนมัติ
- **Type Detection:** ตรวจสอบว่าเป็นคูปองหรือโปรโมชัน
- **Backend Validation:** ตรวจสอบผ่าน RPC functions ใน database

### 4. Security & Logging
- **HMAC-SHA256:** ป้องกัน QR Code ปลอม
- **Separate Logs:** แยก log การ scan (coupons vs promotions)
- **Timestamp:** เก็บเวลา scan และ device info
- **Status Tracking:** valid/invalid/expired/used

## Files ที่สร้าง/แก้ไข

| ไฟล์ | รายละเอียด |
|------|-----------|
| `lib/database/add_qr_code_to_coupons.sql` | QR Code สำหรับคูปอง |
| `lib/database/add_qr_code_to_promotions.sql` | QR Code สำหรับโปรโมชัน |
| `lib/services/pos_coupon_qr_service.dart` | QR generation + validation service |
| `lib/pages/coupon_promotion_page.dart` | แสดง QR Code ใน cards |
| `lib/models/pos_promotion_model.dart` | เพิ่ม QR fields |

## Database Schema

### Tables
- `pos_discounts` เพิ่ม: `qr_code`, `qr_signature`, `qr_generated_at`
- `pos_promotions` เพิ่ม: `qr_code`, `qr_signature`, `qr_generated_at`, `code`
- `pos_coupon_qr_scan_logs` เก็บประวัติ scan คูปอง
- `pos_promotion_qr_scan_logs` เก็บประวัติ scan โปรโมชัน

### Functions
- `generate_coupon_qr_signature()` / `generate_promotion_qr_signature()`
- `validate_coupon_by_qr()` / `validate_promotion_by_qr()`
- `auto_generate_coupon_qr()` / `auto_generate_promotion_qr()`

## การใช้งาน

### สร้าง QR Code
```sql
-- Auto-generate เมื่อสร้างคูปอง/โปรโมชันใหม่
INSERT INTO pos_coupons (name, ...) VALUES (...);
-- QR Code สร้างอัตโนมัติผ่าน trigger
```

### Scan QR Code
```dart
// ใน POS page
final result = await PosCouponQRService.validateCouponQRCode(qrData);
if (result.isValid) {
  promotionCodeCtrl.text = result.couponCode!;
}
```

### แสดง QR Code
```dart
// ใน Coupon/Promotion card
PosCouponQRService.buildCouponQRCode(coupon: coupon);
PosCouponQRService.buildPromotionQRCode(promotion: promotion);
```

## ทดสอบระบบ

1. **สร้างคูปองใหม่** → QR Code ปรากฏใน card
2. **สร้างโปรโมชันใหม่** → QR Code ปรากฏใน card  
3. **ทดสอบ QR Scanner** → แสกนแล้วกรอกรหัสอัตโนมัติ
4. **ตรวจสอบ scan logs** → ดูประวัติการใช้งาน

## ข้อดีของระบบ

✅ **ไม่ต้องพิมพ์รหัส** - แค่แสกน QR Code  
✅ **ป้องกันปลอมแปลง** - HMAC signature validation  
✅ **รองรับทุกประเภท** - คูปองและโปรโมชันทุกชนิด  
✅ **เก็บประวัติครบ** - แยก log สำหรับ analytics  
✅ **ใช้งานง่าย** - แสกนแล้วใช้งานได้ทันที  

---

# Phase 12: Coupon Visibility Control (9 พฤษภาคม 2568)

## เป้าหมาย
เพิ่มการควบคุมการแสดงคูปองในแต่ละส่วนของ UI อย่างอิสระ โดยให้ผู้ดูแลระบบสามารถกำหนดได้ว่าคูปองแต่ละรายการจะแสดงในหน้าไหนได้บ้าง

## ฟีเจอร์ที่ implement

### 1. Visibility Flags
- **show_in_coupon_tab:** ควบคุมการแสดงในหน้าคูปอง & โปรโมชัน
- **show_in_pos_discount_dialog:** ควบคุมการแสดงใน dialog เลือกส่วนลด หน้า POS
- **Default Values:** ทั้งสองค่า default เป็น `false` (ไม่แสดง)
- **Backward Compatibility:** คูปอง active ที่มีอยู่แล้วตั้งค่าเป็น `true` ทั้งสอง

### 2. UI Controls
- **Dialog สร้าง/แก้ไขคูปอง:** เพิ่ม 2 SwitchListTile พร้อม label ภาษาไทย
  - "แสดงในแถบคูปอง (หน้าคูปอง & โปรโมชัน)"
  - "แสดงใน POS (หน้าขาย)"
- **Color Coding:** ใช้สีเขียวสำหรับ ON, สีเทาสำหรับ OFF
- **State Management:** โหลดค่าเริ่มต้นจากข้อมูลคูปอง หรือ default false

### 3. Backend Integration
- **Database Schema:** เพิ่ม 2 boolean columns ใน `pos_discounts`
- **Service Methods:** อัปเดต `addDiscount` และ `updateDiscount` รับพารามิเตอร์ใหม่
- **Query Methods:** เพิ่ม 2 methods สำหรับ filter ตาม visibility
  - `getVisibleCouponsForCouponTab()` - สำหรับหน้าคูปอง
  - `getVisibleCouponsForPOS()` - สำหรับ POS

### 4. Filter Logic
- **หน้าคูปอง:** แสดงเฉพาะคูปองที่ `show_in_coupon_tab = true`
- **POS:** แสดงเฉพาะคูปองที่ `show_in_pos_discount_dialog = true`
- **User Group Filter:** รองรับการกรองตาม user group เหมือนเดิม

## Files ที่สร้าง/แก้ไข

| ไฟล์ | รายละเอียด |
|------|-----------|
| `lib/database/add_coupon_visibility_flags.sql` | SQL migration เพิ่ม 2 columns + functions |
| `lib/models/pos_discount_model.dart` | เพิ่ม 2 boolean fields |
| `lib/pages/coupon_promotion_admin_page.dart` | เพิ่ม 2 SwitchListTile ใน dialog |
| `lib/services/pos_discount_service.dart` | อัปเดต methods รองรับ visibility flags |
| `lib/pages/coupon_promotion_page.dart` | ใช้ getVisibleCouponsForCouponTab() |
| `lib/widgets/pos_discount_panel_widget.dart` | ใช้ getVisibleCouponsForPOS() |

## Database Schema

### Table Changes
```sql
ALTER TABLE pos_discounts 
ADD COLUMN show_in_coupon_tab BOOLEAN DEFAULT false,
ADD COLUMN show_in_pos_discount_dialog BOOLEAN DEFAULT false;
```

### Functions
- `get_visible_coupons_for_coupon_tab(p_user_group_id)`
- `get_visible_coupons_for_pos(p_user_group_id)`

## การใช้งาน

### สร้างคูปองพร้อม visibility
```dart
// ใน dialog สร้าง/แก้ไขคูปอง
bool showInCouponTab = false; // default
bool showInPosDiscountDialog = false; // default

// บันทึกค่าไป backend
await PosDiscountService.addDiscount(
  // ... พารามิเตอร์อื่นๆ
  showInCouponTab: showInCouponTab,
  showInPosDiscountDialog: showInPosDiscountDialog,
);
```

### ดึงคูปองตาม visibility
```dart
// หน้าคูปอง & โปรโมชัน
final coupons = await PosDiscountService.getVisibleCouponsForCouponTab();

// POS dialog
final coupons = await PosDiscountService.getVisibleCouponsForPOS();
```

## ทดสอบระบบ

1. **สร้างคูปองใหม่** → ทั้ง 2 toggles default เป็น OFF
2. **เปิด toggle แรก** → แสดงในหน้าคูปองเท่านั้น
3. **เปิด toggle สอง** → แสดงใน POS เท่านั้น
4. **เปิดทั้งสอง** → แสดงในทั้งสองที่
5. **ตรวจสอบคูปองเก่า** → ควรแสดงในทั้งสองที่ (backward compatibility)

## ข้อดีของระบบ

✅ **ควบคุมแยกกัน** - คูปองแต่ละรายการกำหนดการแสดงได้อิสระ  
✅ **Default ปลอดภัย** - ไม่แสดงโดยอัตโนมัติ ต้องเจตนาโดยเจตนา  
✅ **Backward Compatible** - คูปองเก่ายังแสดงตามเดิม  
✅ **UI ชัดเจน** - ใช้ SwitchListTile พร้อม label ภาษาไทย  
✅ **Performance** - Query ตาม visibility ลดข้อมูลที่ไม่จำเป็น  

---

# Phase 13: Daily Coupon (ส่วนลด + สิทธิ์เข้าพื้นที่) 

**สถานะ:** Planned (Specification Complete)  
**วันที่อัปเดต:** 18 พฤษภาคม 2569  
**Owner:** Coupon Platform Squad  
**Dependencies:** Phase 0-12 (schema, QR, governance, visibility)  
**Forbidden:** ห้ามใช้บริการแจ้งเตือนที่มีค่าใช้จ่ายเพิ่ม (เช่น Firebase Cloud Messaging)

## เป้าหมาย
- สร้างคูปองรายวันที่รวม "ส่วนลด" และ "สิทธิ์เข้าพื้นที่" ใน artifact เดียว
- ให้แอดมินกำหนดกติกาเองทั้งหมดผ่านแถบใหม่ (Admin-first policy) พร้อม sub-tab ประวัติการใช้งานรายวัน
- ให้ลูกค้าเห็นคูปองในแท็บเดิม (badge รายวัน) และแชร์ได้เมื่อเป็นคูปองรายกลุ่ม
- แยก log ช่องทาง Gate vs POS อย่างชัดเจน โดยส่วนลด reuse log เดิม เพื่อไม่ซ้ำซ้อน

## Scope & Admin-first Policy
- ใช้ `pos_discounts` เป็นแหล่งข้อมูลหลัก (reuse-first) พร้อม visibility flags เดิม
- ค่าใหม่เก็บใน `targeting_rule` JSON; หลีกเลี่ยง migration จนกว่าจะยืนยัน implementation
- เพิ่ม sub-tab `ประวัติการใช้คูปองรายวัน` ในหน้า Admin เพื่อดู timeline เข้า/ออกพื้นที่ (Gate) + ลิงก์ไป usage log เดิม (POS)
- ลูกค้าเห็นคูปองรายวันในแท็บคูปองเดิม โดยใช้ `show_in_coupon_tab = true` + badge "รายวัน"
- คูปองรายกลุ่มต้องแชร์ให้สมาชิกได้ (share token + QR) และลูกค้าดูประวัติการเข้า/ออกได้จากการ์ด

### ความคืบหน้าปัจจุบัน (19 พ.ค. 2569)
✅ สร้างแท็บ "คูปองรายวัน" ในหน้า Admin พร้อม FAB เปิดฟอร์ม daily-mode และเชื่อม Gate Scanner ตามสิทธิ์  
✅ Controller/Widget โหลดคูปองรายวัน, ประวัติ POS & Gate, สรุป quota, การแจ้งเตือน และเลือกช่วงวันได้  
✅ ฟอร์มคูปองเติมชื่อ "คูปองเข้าพื้นที่ & แลกซื้อ" และสร้างรหัส `TLZ` + วันที่ + 4 หลักโทรศัพท์อัตโนมัติเมื่อเป็น daily mode  
✅ Gate Scanner (beta) ตรวจ QR, แสดงข้อมูลคูปอง, บันทึก entry log และโชว์ประวัติล่าสุด พร้อม metadata nonce/key version  
✅ ฝั่งลูกค้าเห็น badge รายวัน, ปุ่มคัดลอกรหัส/แชร์พื้นฐาน และ bottom sheet ประวัติ POS + Gate  
✅ Permission Page เพิ่ม tab/action สำหรับคูปองรายวัน (view, add, history, gate scanner)

### ช่องว่างสำคัญที่ยังไม่ปิด
- ยังไม่มี share token/back-end สำหรับคูปองรายกลุ่ม (จำกัด `max_uses = group_size`, ผูก member)
- POS ยังไม่บังคับ quota/ตรวจการใช้ซ้ำต่อสมาชิก/กลุ่ม (เฉพาะ Gate เท่านั้นที่ log)
- Gate Scanner ยังไม่มี offline queue + idempotency sync ตามสเปก
- ประสบการณ์ลูกค้าสำหรับการแชร์สมาชิก/ติดตามสถานะยังเป็น MVP (ไม่แสดงเหลือ/รายชื่อชัดเจน)
- ยังไม่ทำ end-to-end test plan & documentation update สำหรับ Phase 13

### ข้อเสนอขั้นถัดไป (Next Steps)
1. **Share Token Service & Schema** – สร้างโครงสร้าง token สำหรับคูปองรายกลุ่ม (DB, RPC, client service) พร้อม expiry และ `max_uses = group_size`, รวมถึง UI ในฟอร์ม/การ์ดลูกค้า
2. **POS Quota Enforcement** – เพิ่ม validation ฝั่ง POS ให้ตรวจจำนวนสมาชิกที่ใช้สิทธิ์, share token misuse, และบันทึก log ตามกติกา group/individual
3. **Offline & Idempotent Gate Flow** – เพิ่ม offline queue ใน Gate Scanner รวมถึง hash/idempotency window เพื่อกันการยิงซ้ำและ sync เมื่อต่อเน็ต
4. **Customer Share UX** – ปรับหน้าแสดงคูปองลูกค้าให้โชว์จำนวนสมาชิกที่ใช้แล้ว/เหลือ, ปุ่มแชร์ token จริง, และประวัติ timeline บนการ์ดหรือหน้า detail
5. **E2E Testing & Documentation** – เขียน test plan ครอบคลุม flow รายวัน (สร้าง → แชร์ → สแกน Gate → ใช้ POS → ตรวจ log), อัปเดตเอกสาร Phase 13 และ checklist governance

## Field Spec (reuse-first)
| กลุ่ม | Field | แหล่งข้อมูล | หมายเหตุ |
|-------|-------|--------------|-----------|
| Identity | `name`, `description`, `coupon_code` | `pos_discounts` | แสดงบนการ์ดลูกค้า + QR |
| Discount | `discount_type`, `scope`, `value`, `max_discount`, `min_amount` | `pos_discounts` | ใช้ logic เดิม |
| Lifecycle | `lifecycle_status`, `is_active`, `start_at`, `end_at` | `pos_discounts` | daily reset ตาม timezone tenant |
| Limits | `usage_limit`, `usage_limit_per_customer`, `usage_limit_per_day`, `usage_limit_per_order`, `used_count` | `pos_discounts` | ใช้ Rule Matrix เดิม |
| Policy | `stackable`, `priority`, `require_in_stock`, `require_sufficient_ingredients`, `include_pending_procurement` | `pos_discounts` | กำหนดได้จาก Admin UI |
| Visibility | `show_in_coupon_tab`, `show_in_pos_discount_dialog` | `pos_discounts` | ลูกค้าเห็นเมื่อเปิดซ้ำ |
| QR | `qr_code`, `qr_signature`, `qr_generated_at` | `pos_discounts` | ทุกคูปองมี QR เฉพาะ |

## `targeting_rule` profile สำหรับคูปองรายวัน
| Key | Type | หมายเหตุ |
|-----|------|-----------|
| `daily_unified_enabled` | bool | ต้องเป็น true |
| `event_types` | array | `["discount","entry"]` |
| `coupon_audience` | enum | `individual` หรือ `group` |
| `group_size` | int | required เมื่อ audience = group (≥ 2) |
| `entry_zone_mode` | enum | ใช้ `single` เสมอ |
| `entry_area_name` | text | ชื่อพื้นที่เดียว |
| `entry_limit_per_day` | int | จำนวนครั้งเข้า/ออกต่อวัน |
| `discount_limit_per_day` | int | จำนวนครั้งลดราคาต่อวัน |
| `discount_limit_per_coupon` | int? | จำกัดรวมระดับคูปอง |
| `entry_requires_same_day` | bool | จำกัดสิทธิ์ให้ใช้งานภายในวันเดียว |
| `allow_entry_before_discount` | bool | ระบุได้ว่าต้องเข้าเขตก่อนใช้ส่วนลดหรือไม่ |
| `allow_discount_without_entry` | bool | ถ้า false ต้องสแกนเข้าให้สำเร็จจึงใช้ส่วนลดได้ |
| `idempotency_window_seconds` | int | ป้องกันการยิงซ้ำในระยะสั้น |
| `qr_replay_window_seconds` | int | จำกัด replay window |
| `key_version` | text | ระบุชุดคีย์ QR ตาม Phase 11 |
| `nonce_policy` | enum | เช่น `per_day` / `per_entry` |
| `reset_at_local_midnight` | bool | ใช้ timezone tenant |

### JSON Example
```json
{
  "daily_unified_enabled": true,
  "event_types": ["discount", "entry"],
  "coupon_audience": "group",
  "group_size": 8,
  "entry_zone_mode": "single",
  "entry_area_name": "Safari Dome",
  "entry_limit_per_day": 100,
  "discount_limit_per_day": 50,
  "entry_requires_same_day": true,
  "allow_entry_before_discount": true,
  "allow_discount_without_entry": false,
  "idempotency_window_seconds": 45,
  "qr_replay_window_seconds": 30,
  "key_version": "v3",
  "reset_at_local_midnight": true
}
```

## Admin UI Design (แถบ `คูปองรายวัน`)
1. **Tab Layout** – ปุ่ม `+ สร้างคูปองรายวัน`, filters (สถานะ, ช่วงวันที่, ประเภท), bulk actions (pause/archive/export/duplicate), Empty/Loading/Error states ระบุชัดเจน
2. **Card Columns** – ชื่อคูปอง, ประเภท (รายบุคคล/รายกลุ่ม + จำนวนคน), ส่วนลดที่เหลือวันนี้, เข้าพื้นที่วันนี้, สถานะ lifecycle
3. **Form Sections (A-H)** – ตรงตามแผน: ข้อมูลหลัก, ส่วนลด, สิทธิ์เข้าพื้นที่, ประเภท/โควตา, ช่วงเวลา, นโยบาย, การแสดงผล, QR & Security (มี helper text mapping field → table)
4. **Detail Drawer/Page** – สรุปยอดวันนี้, tabs: ข้อมูลคูปอง / สมาชิกกลุ่ม / ประวัติ POS / ประวัติ Gate / Audit Log / Alerts
5. **Sub-tab `ประวัติการใช้คูปองรายวัน`** – ตารางคู่ (POS vs Gate)
   - ตำแหน่ง: อยู่ในแถบคูปองรายวันฝั่ง Admin
   - POS reuse `pos_order_discounts` + ปุ่ม "ดูประวัติรวม" ไป Usage Analytics เดิม
   - Gate ใช้ log ใหม่ (coupon_id, entry_area, scanned_by, device, status, reason_code)

## Customer Experience (แอปลูกค้า)
- การ์ดคูปองจะแสดงรวมกับคูปองอื่น ผ่าน `show_in_coupon_tab`
- Badge: `รายวัน • รายบุคคล` หรือ `รายวัน • รายกลุ่ม X คน`
- คูปองรายกลุ่มมีปุ่ม "แชร์" (share token มี expiry + `max_uses = group_size`)
- ลูกค้ากด "ดูประวัติการใช้พื้นที่" เพื่อดู timeline เข้า/ออกพื้นที่ (Gate) + ลิงก์ไป usage log เดิม (POS)
- ปุ่ม "ดูประวัติส่วนลด" ลิงก์กลับหน้า usage log รวม (ข้อมูลจาก POS)

## Gate Scanner Flow
1. พนักงานเปิดหน้าสแกน → สแกน QR → ตรวจ signature + lifecycle + quota + audience
2. ถ้า valid → แสดงข้อมูลคูปอง + quota วันนี้ + ปุ่ม "ยืนยันเข้า"; ถ้า invalid → แสดง reason code ภาษาไทย
3. บันทึก entry log: coupon_id, member_id/กลุ่ม, scanned_by, area, scanned_at, status, device_info
4. Offline fallback: เก็บคิวใน local storage + hash ป้องกัน duplicate → sync เมื่อออนไลน์ภายใน `idempotency_window_seconds`

## Logging Strategy
- ส่วนลด (POS): ใช้ `pos_order_discounts` + analytic views เดิม (ไม่มีตารางใหม่)
- Gate: เพิ่ม `daily_coupon_entry_logs` (หรือ view ที่อิงจาก QR scan logs) เพื่อเก็บ channel-specific data
- Sub-tab ประวัติใน Admin ดึงข้อมูลทั้งสองช่องทาง พร้อมสรุปจำนวนรวมด้านบน
- Audit log บันทึกทุก transition + การแก้ไขค่า + ผู้กระทำ + เหตุผล

## QR Security & Monitoring
- ใช้มาตรฐาน QR Phase 11 + เพิ่มตัวเลือก daily rotation ผ่าน `key_version`
- ทุกสแกนบันทึก `nonce`, `qr_signature`, `device_info`, `reason_code`
- In-app alerts (dashboard) แจ้งเตือน: quota ใกล้เต็ม, scan ผิดปกติ, คูปองใกล้หมดอายุ
- ไม่ใช้บริการ push/premium externas; แจ้งเตือนผ่านหน้า dashboard และอีเมลภายในเท่านั้น (ถ้ามีอยู่แล้ว)

## Validation Rules (Form)
| Field | Rule |
|-------|------|
| `name` | required, ≤ 120 ตัวอักษร |
| `coupon_code` | required, unique, ตัวอักษร/ตัวเลข/ขีด |
| `discount_value` | > 0, ถ้า % ต้อง ≤ 100 |
| `entry_area_name` | required เมื่อเปิด entry |
| `entry_limit_per_day` | required เมื่อเปิด entry, ≥ 1 |
| `discount_limit_per_day` | required, ≥ 0 |
| `group_size` | required เมื่อ audience = group, ≥ 2 |
| `start_at < end_at` | ต้องไม่ผิดเพี้ยนตาม timezone |
| `targeting_rule` | ต้องตรง schema (key ครบ) |

## State Machine & Permission
- State: `draft → scheduled → active → (paused ↔ active) → expired → archived`
- ทุก transition บันทึกใน audit log (ผู้แก้ไข + เหตุผล)
- Permission Matrix: viewer (read only), editor (draft edits), publisher (publish/pause/archive), admin (ตั้งค่ามาตรฐานกลาง, override)

## Group Member Binding & Share Control
- กรอก `group_size` เมื่อ audience = group; optional ผูก member ID (ถ้ามีระบบสมาชิก)
- Share token: มี expiry, `max_uses = group_size`, ห้ามใช้ข้ามกลุ่ม, log ทุกครั้ง
- ลูกค้ากดดูรายชื่อหรือสถานะสมาชิกที่ใช้สิทธิ์ได้จากการ์ด

## In-app Alerting (ไม่มีค่าใช้จ่ายเพิ่ม)
- Dashboard แจ้งเตือน: คูปองใกล้หมดเวลา, quota ใกล้เต็ม, scan invalid ต่อเนื่อง
- ไม่ส่ง push notification ผ่านบริการที่มีค่าใช้จ่าย; ใช้เฉพาะ alert card + email ภายใน (ถ้ามีระบบเดิม)

## Operational Test Practice (เรียงตามที่ยืนยัน)
1. **เตรียมข้อมูล (Test Data Setup)** – คูปอง active/scheduled/paused, ช่องทาง POS + Gate, user group ≥ 2
2. **ตั้งค่าในแถบใหม่ (Admin Config)** – สร้างคูปองรายวัน, ตั้ง split quota, audience, group size, ช่วงเวลา
3. **ทดสอบสิทธิ์เข้าพื้นที่ (Entry Flow)** – สแกน gate, ทดสอบ quota, ช่วงเวลา, paused state, offline sync
4. **ทดสอบส่วนลด (Discount Flow)** – ใช้ QR ที่ POS, ทดสอบ stackable/conflict precedence, quota
5. **ทดสอบ Negative & Edge** – QR หมดอายุ, replay, channel ผิด, idempotency, share token misuse
6. **เกณฑ์ผ่าน (Pass/Fail)** – Rule Matrix ครบ, splitting quota ถูกต้อง, log ครบ POS & Gate, ไม่มีบริการแจ้งเตือนเสียค่าใช้จ่าย

## Acceptance Criteria
- เอกสาร Phase 13 ครอบคลุมฟิลด์, JSON schema, UI flow, customer UX, test plan ครบถ้วน
- ลูกค้าเห็นการ์ดคูปองรายวันพร้อม badge + ปุ่มแชร์ (รายกลุ่ม) + ปุ่มดูประวัติพื้นที่
- Admin UI มีแถบ/ฟอร์ม/ประวัติ/Audit log ตามสเปกนี้
- Logging strategy ชัดเจน: POS reuse, Gate log ใหม่, แยกช่องทางแต่สรุปรวมได้
- ระบุความเสี่ยงและแนวทางบรรเทา (reuse-first, offline queue, share token control)

## ความเสี่ยง & การบรรเทา
- **Reuse field semantics สับสน** → เอกสารนี้แสดง mapping + helper text ใน UI
- **ยังไม่มีตาราง log Gate** → ระบุให้สร้าง `daily_coupon_entry_logs` และเชื่อม governance audit ใน implementation
- **Offline scan backlog** → ใช้ idempotency window + hash, ทดสอบทุก edge cases
- **Share token abuse** → จำกัด `max_uses = group_size`, log ทุกครั้ง, ผูก member ID
- **Time zone reset** → ใช้ `reset_at_local_midnight` + preview ใน UI เพื่อป้องกันตั้งค่าผิด

---

# Summary: ความคืบหน้าโครงการ

| Phase | สถานะ | ความสมบูรณ์ | หมายเหตุ |
|-------|--------|------------|----------|
| Phase 0: Schema & Permission | ✅ เสร็จ | 100% | SQL migration รันแล้ว |
| Phase 1: Coupon CRUD | ✅ เสร็จ | 100% | แก้ Dialog Crash แล้ว |
| Phase 2: POS Integration | ✅ เสร็จ | 100% | Coupon validation + usage logging พร้อมใช้ |
| Phase 3: Product Picker | ✅ เสร็จ | 100% | UI + Backend API พร้อมใช้ |
| Phase 4: Availability Rules | ✅ เสร็จ | 100% | SQL RPC + Service + UI ครบ |
| Phase 5: Expiry Targeting | ✅ เสร็จ | 100% | SQL + Service + UI Tabs ครบ |
| Phase 6: Promotion CRUD | ✅ เสร็จ | 100% | รวมกับ Phase 1 |
| Phase 7: Analytics MVP | ✅ เสร็จ | 100% | Usage Analytics พร้อมใช้งาน |
| Phase 8: Business Intelligence | ✅ เสร็จ | 100% | Priority Score + Recommended Products |
| Phase 9: Governance | ✅ เสร็จ | 100% | Tax Rules + Permission System |
| Phase 10: Advanced Analytics | ⏸️ On Hold | 0% | พักไว้ก่อนเพราะยังไม่มีข้อมูลสำหรับทดสอบ |
| Phase 11: QR Code System | ✅ เสร็จ | 100% | QR Code สำหรับคูปอง + โปรโมชัน |
| Phase 12: Coupon Visibility Control | ✅ เสร็จ | 100% | ควบคุมการแสดงคูปองในแต่ละหน้า UI |
| Phase 13: Daily Unified Coupon Admin Tab | 📋 Planned | 0% | สเปก + UI/Flow พร้อม เริ่มพัฒนาแถบใหม่สำหรับส่วนลด+สิทธิ์เข้าพื้นที่ |

**สรุป:** ✅ Phase 0-9, 11-12 เสร็จสมบูรณ์ (100%) และเตรียมเริ่ม 📋 Phase 13 (Admin-driven Daily Unified Coupon)

---

# Version History

> ใช้ส่วนนี้เป็นแหล่งอ้างอิงสถานะล่าสุด (single source of truth)
> หากมีข้อความส่วนอื่นขัดแย้ง ให้ยึดรายการที่ใหม่ที่สุดในตารางนี้

| Version | วันที่ | ผู้แก้ไข | สรุปการเปลี่ยนแปลง | ผลกระทบสถานะ |
|---------|--------|----------|----------------------|----------------|
| v1.0.0 | 08 พ.ค. 2568 | ทีมพัฒนา | ปิดงาน Phase 0-9 และอัปเดตสถานะระบบพร้อมใช้งานจริง | Phase 0-9 = ✅, Phase 10 = ⏸️ |
| v1.1.0 | 09 พ.ค. 2568 | ทีมพัฒนา | เพิ่ม Phase 12: Coupon Visibility Control | เพิ่ม Phase 12 = ✅ |
| v1.1.1 | 18 พ.ค. 2569 | Cascade | ปรับเอกสารให้สถานะทุก section สอดคล้องกันทั้งฉบับ และแก้ชื่อ table QR ให้ตรง schema (`pos_discounts`) | ลดความเสี่ยงสถานะย้อนแย้ง |
| v1.1.2 | 18 พ.ค. 2569 | Cascade | เพิ่ม section Version History เพื่อกำกับการอัปเดตสถานะในอนาคต | กำหนดกระบวนการควบคุมเวอร์ชันเอกสาร |
| v1.1.3 | 18 พ.ค. 2569 | Cascade | ยืนยันมติพัก Phase 10 ไว้ก่อน เนื่องจากข้อมูลทดสอบยังไม่เพียงพอ | คงสถานะ Phase 10 = ⏸️ On Hold |
| v1.1.4 | 18 พ.ค. 2569 | Cascade | เพิ่มนโยบาย Admin-first และแถบใหม่ `คูปองรายวันแบบรวมสิทธิ์` เพื่อให้แอดมินกำหนดทุกกติกาได้เอง | เพิ่มแผน Phase 13 = 📋 Planned |
| v1.1.5 | 18 พ.ค. 2569 | Cascade | บันทึกสเปก Phase 13 (ฟิลด์, UI flow, targeting_rule, test plan, UX ลูกค้า) ครบถ้วน | Phase 13 พร้อมเข้าสู่ implementation |

## กติกาการอัปเดต

1. ทุกครั้งที่เปลี่ยนสถานะ phase ต้องเพิ่มแถวใหม่ใน `Version History` ทันที
2. ต้องอัปเดตอย่างน้อย 3 จุดให้ตรงกันเสมอ:
   - `Development Phases`
   - `Summary: ความคืบหน้าโครงการ`
   - `Version History`
3. ถ้ามีการเลื่อนงาน ให้ระบุเหตุผลและเงื่อนไขกลับมาทำในแถวเดียวกัน
4. ห้ามลบประวัติเก่า ให้เพิ่มเฉพาะรายการใหม่เพื่อเก็บ audit trail
