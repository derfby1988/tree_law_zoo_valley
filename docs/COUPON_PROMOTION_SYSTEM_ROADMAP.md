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
[คูปอง] [โปรโมชัน] [สินค้าใกล้หมดอายุ] [วัตถุดิบใกล้หมดอายุ] [วิเคราะห์การใช้งาน]
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

## Gaps ที่ต้องเพิ่มก่อนใช้แผนใหม่แบบครบถ้วน

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
| 7: Usage Analytics Tab | ⏳ รอดำเนินการ | 0% | มี Tab แต่ยังไม่มี UI |
| 8: Business Recommendation | 🔄 部分เสร็จ | 70% | UI + Seasonal/Festival/HighMargin APIs เสร็จแล้ว |
| 9: Governance | ⏳ รอดำเนินการ | 0% | Priority ต่ำ |

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
7. 🔄 **Phase 8:** Seasonal/Festival/HighMargin เสร็จแล้ว (รอ Priority Score)

**งานที่ยังค้าง (Priority สูง):**
1. ⏳ **Phase 7:** Analytics Tab UI
2. ⏳ **Phase 8:** Priority score calculation (รอ algorithm)

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
- ⏳ sort ตาม priority ได้ (รอ score)
- ✅ เลือกไปทำคูปอง/โปรโมชันได้

## Phase 9: Governance ⏳

**สถานะ:** รอดำเนินการ  
**Priority:** ต่ำ (ระบบใช้งานได้ก่อนแล้วค่อยเพิ่ม governance)

เป้าหมาย: ทำให้ระบบปลอดภัยต่อรายได้และตรวจสอบย้อนหลังได้

- Preview/simulation ก่อนเปิดใช้งาน
- Conflict detection:
  - สินค้าเดียวกันอยู่หลายโปร
  - ช่วงเวลาทับซ้อน
  - ส่วนลดรวมเกิน margin
  - stock/ingredient ไม่พอ
- Approval workflow
- Audit log
- Override permission

Test ได้:

- เห็น warning ก่อนเปิดโปร
- ตรวจโปรซ้อนกันได้
- ผู้ไม่มีสิทธิ์ override ไม่ได้
- ประวัติแก้ไขครบ

## Phase 10: Advanced Analytics ⏳

**สถานะ:** รอดำเนินการ  
**Priority:** ต่ำ (ทำหลังระบบใช้งานเสถียรแล้ว)

เป้าหมาย: วัดผลระดับบริหารและ export รายงานได้

- Graphs
- Top 10 coupon/promotion
- Top 10 target products
- Margin impact
- Before/during/after comparison
- Campaign comparison
- Export CSV/Excel/PDF
- วิเคราะห์:
  - ยอดขายที่เกิดจากโปรโมชัน
  - ปริมาณสินค้าที่ระบายได้
  - วัตถุดิบที่ใช้ไป
  - กำไรขั้นต้นหลังหักส่วนลด
  - ผลลัพธ์ตามฤดูกาลหรือเทศกาล

Test ได้:

- export ได้
- กราฟตรงข้อมูลจริง
- วิเคราะห์ campaign ได้

---

# Open Questions

- ตาราง batch/expiry ของสินค้าใช้ชื่ออะไร และ field expiry date ชื่ออะไร
- ตารางวัตถุดิบใช้ชื่ออะไร
- ตารางสูตรอาหารและ mapping ingredient ใช้ชื่ออะไร
- สินค้า POS กับเมนูอาหารเป็น entity เดียวกันหรือแยกกัน
- มี sales history สำหรับคำนวณ slow moving แล้วหรือไม่
- ตารางจัดซื้อและสถานะจัดซื้อใช้ชื่ออะไร
- สถานะจัดซื้อใดบ้างที่ควรถูกนับเป็น pending procurement เช่น ordered, approved, in_transit
- ต้องการให้นับ pending procurement เป็น available แบบเต็มจำนวน หรือแยกแสดงเป็น `พร้อมขายตอนนี้` กับ `กำลังมา`
- ถ้า stock/วัตถุดิบไม่พอ ตอน checkout ควร block การใช้โปรโมชัน หรือแค่เตือนผู้ใช้
- มีต้นทุนสินค้า/ต้นทุนสูตรอาหารที่แม่นยำพอสำหรับคำนวณ margin หรือไม่
- มีข้อมูลวัตถุดิบตามฤดูกาลหรือยัง และเก็บช่วงฤดูกาลแบบใด
- มีตารางเทศกาล/วันสำคัญหรือ event calendar หรือยัง
- ต้องการ mapping สินค้ากับเทศกาลแบบ manual หรือให้ระบบแนะนำจากยอดขายย้อนหลัง
- ต้องการให้ระบบ suggest discount อัตโนมัติหรือแค่เลือกสินค้าเป้าหมายก่อน

---

# Recommended Next Step

**สถานะปัจจุบัน:** Phase 0, 1, 3, 6 เสร็จสมบูรณ์ ✅

## ขั้นตอนต่อไปที่แนะนำ:

### ทางเลือก 1: ไปต่อ Phase 2 (POS Integration)
เหมาะถ้าต้องการให้คูปองใช้งานได้จริงใน POS ทันที
1. เพิ่มช่องกรอก coupon code ใน `pos_page.dart`
2. คืนค่า `_applyCouponCode()` พร้อม validation
3. คืนค่า `recordDiscountUsage()` บันทึกการใช้
4. ทดสอบใช้คูปองใน order จริง

### ทางเลือก 2: รอ API สำหรับ Phase 4-5
เหมาะถ้าต้องการให้ Product Picker แสดงข้อมูลจริง
- รอ API: stock balance, recipe ingredient balance
- รอ API: expiry dates สินค้าและวัตถุดิบ
- รอ API: priority score calculation

### ทางเลือก 3: ทดสอบและแก้ไข Phase 1 ให้เสถียร
เหมาะก่อนไป Phase 2
1. ทดสอบสร้างคูปอง/โปรโมชั่นหลายๆ อัน
2. ทดสอบเลือกสินค้าผ่าน `PromotionProductPickerPage`
3. ทดสอบ Permission กับ user ที่มีสิทธิ์ต่างกัน
4. แก้ไข bug ที่พบ (ถ้ามี)

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
| Phase 7: Analytics MVP | ⏳ รอ | 10% | มี Tab แต่ไม่มี UI |
| Phase 8: Business Intelligence | 🔄 部分เสร็จ | 70% | Seasonal/Festival/HighMargin APIs เสร็จแล้ว รอ Priority Score |
| Phase 9: Governance | ⏳ รอ | 0% | Priority ต่ำ |
| Phase 10: Advanced Analytics | ⏳ รอ | 0% | Priority ต่ำ |

**สรุป:** Phase 0-6 เสร็จสมบูรณ์ (100%) - เหลือ Phase 7 (Analytics) และ Phase 8 (Priority Score)
