# Procurement System - แผนพัฒนา (อัปเดตล่าสุด)

อัปเดต: 21 Mar 2026 (อิงจากโค้ดปัจจุบัน)

## 1) วัตถุประสงค์

ทำระบบจัดซื้อแบบครบ workflow:

```
[สร้าง PO] → [ส่ง PO] → [อนุมัติ] → [รับสินค้า]
   Draft       Sent      Confirmed   Completed
```

และรองรับการขยายกฎอนุมัติผ่านหน้า HRM ในระยะถัดไป

## 2) สถานะปัจจุบัน (As-Is)

### ✅ สิ่งที่พร้อมใช้งานแล้ว

- โครงสร้าง DB หลักมีแล้ว: `procurement_suppliers`, `procurement_purchase_orders`, `procurement_purchase_order_lines`, `procurement_store_locations`
- Permission ของ procurement ถูกจัดตาม role (`store_manager`, `manager`, `admin`)
- Service ใน `ProcurementService` ครอบคลุม workflow หลัก:
  - `createPurchaseOrder`
  - `getPurchaseOrders`
  - `sendPurchaseOrder`
  - `approvePurchaseOrder`
  - `receivePurchaseOrder`
  - `updatePurchaseOrder`
  - `cancelPurchaseOrder`
  - `deletePurchaseOrder`
- Dialog action พร้อมใช้งาน:
  - `send_po_dialog.dart`
  - `approve_po_dialog.dart`
  - `receive_goods_dialog.dart`
- `request_tab.dart` เชื่อมข้อมูล PO จริงแล้ว (โหลด/ค้นหา/กรอง/แสดง action ตามสถานะ)

### ⚠️ ช่องว่างที่ยังต้องทำ

- หน้า Create/Edit/View Detail PO ใน `request_tab.dart` ยังเป็น Snackbar placeholder (แต่ `purchase_tab` มีฟอร์มครบแล้ว)
- แม้อนุมัติ PO จะดึงวงเงินจากตาราง `approval_hierarchy_rules` แล้ว แต่ต้องรัน migration step/audit เพิ่มเพื่อบังคับลำดับ approval chain เต็มรูปแบบ
- มี lint/info คงค้างในหลายไฟล์ (ไม่ใช่ compile blocker)

### 🚨 ช่องว่างระดับ Schema (เร่งด่วน)

สำหรับ approval chain ที่บังคับลำดับจริง ระบบต้องมีตารางเพิ่ม:

- `procurement_po_approval_steps`
- `procurement_po_approval_audit_logs`

> จำเป็นต้องรัน migration `procurement_approval_steps_migration.sql` ก่อนใช้งาน flow อนุมัติแบบลำดับขั้นเต็มรูปแบบ

## 3) ตารางสถานะ Workflow

| ขั้นตอน | Database | Service | UI | สถานะรวม |
|---|---|---|---|---|
| สร้าง PO | ✅ | ✅ | ✅ (`_showPurchaseOrderFormDialog` ใช้งานจริง) | Done |
| ส่ง PO | ✅ (`sent_*` migration มีแล้ว) | ✅ | ✅ (`SendPODialog` พร้อม) | Done |
| อนุมัติ PO | ✅ | ✅ | ✅ (`ApprovePODialog` พร้อม) | Done |
| รับสินค้า | ✅ | ✅ | ✅ (`receive_tab` เชื่อม `ReceiveGoodsDialog` แล้ว) | Done |
| ยกเลิก PO | ✅ (`cancelled_*` migration มีแล้ว) | ✅ | ✅ (`CancelPODialog` ใน `purchase_tab` แล้ว) | Done |

## 4) กฎอนุมัติ (Current Behavior)

จากโค้ดปัจจุบันใน service:

- `store_manager`: ≤ 5,000 บาท
- `manager`: ≤ 50,000 บาท
- `admin`: ไม่จำกัด

หมายเหตุ: ค่าดังกล่าวยัง hardcode และยังไม่ดึงจากฐานข้อมูล

## 5) แผน HRM สำหรับจัดการ Approval Hierarchy

เส้นทางเป้าหมาย:

```
HRM → กลุ่มและสิทธิ์ → Approval Hierarchy
```

ความสามารถที่ควรมี:

1. กำหนดวงเงินอนุมัติตาม role ได้จาก UI
2. กำหนดลำดับ priority ของ role
3. รองรับผู้อนุมัติสำรอง (proxy approver)
4. กำหนดกฎเฉพาะตามประเภทเอกสาร/หมวดสินค้า
5. เก็บ audit log ทุกการแก้กฎและทุกการอนุมัติ

## 6) Data Model ที่แนะนำ (สำหรับ HRM Approval)

- `approval_hierarchy_rules`
  - `id`, `role_id`, `max_amount`, `priority`, `is_unlimited`, `is_active`, timestamps
- `approval_proxies`
  - `id`, `owner_user_id`, `proxy_user_id`, `start_at`, `end_at`, `is_active`
- `approval_audit_logs`
  - `id`, `po_id`, `action`, `actor_user_id`, `before_data`, `after_data`, `created_at`

## 7) Roadmap (เรียงตามลำดับความเสี่ยง)

### Phase A: Stabilize Production Path (เร่งด่วน)

- [x] เพิ่ม migration คอลัมน์ `sent_*` และ `cancelled_*` บน `procurement_purchase_orders`
- [x] เชื่อม `receive_goods_dialog` เข้ากับ `receive_tab`
- [x] เพิ่ม flow ยกเลิก PO ในหน้ารายการหลัก (พร้อมเหตุผลยกเลิก)
- [x] ทำฟอร์ม Create/Edit/Detail PO ให้ใช้งานจริง (ใน `purchase_tab.dart`)

### Phase B: Rule Externalization

- [ ] ย้ายวงเงินอนุมัติจาก hardcode ไป DB
- [ ] โหลด role ผู้ใช้จากข้อมูลสิทธิ์ที่เชื่อถือได้ (ไม่ fallback แบบหยาบ)
- [ ] เพิ่ม fallback/error handling เมื่อ permission โหลดไม่ครบ

### Phase C: HRM Hierarchy Management

- [ ] สร้างหน้า `ApprovalHierarchyPage` ในโมดูล HRM
- [ ] เชื่อม CRUD ของ rules/proxy/audit
- [ ] เพิ่ม permission action สำหรับ “จัดการ hierarchy”

### Phase D: Quality & Testing

- [x] เพิ่ม integration test ครบ 4 ขั้น workflow (ระดับ workflow logic)
- [x] เพิ่ม test กรณีเกินวงเงินและสิทธิ์ไม่พอ (ระดับ unit logic)
- [x] ทยอยเคลียร์ lint สำคัญที่กระทบ maintainability (ไฟล์ `procurement_service.dart`)

ผลล่าสุด:

- เพิ่ม `test/services/procurement_service_test.dart` สำหรับทดสอบวงเงินอนุมัติ (`approvalLimitForRole`, `canApproveAmount`)
- เพิ่ม workflow test 4 ขั้น (`Draft → Sent → Confirmed → Completed`) และกรณี transition ไม่ถูกต้อง
- ปรับ `test/widget_test.dart` ให้ตรงกับโค้ดจริง (validation tests)
- รัน `flutter test` ผ่านแล้ว (exit code 0)
- รัน `flutter test test/services/procurement_service_test.dart` ผ่านแล้ว (exit code 0)
- รัน `flutter analyze --no-pub lib/services/procurement_service.dart test/services/procurement_service_test.dart` ผ่านแล้ว (No issues found)
- เชื่อม `receive_tab` กับ `receive_goods_dialog` แล้ว (โหลด PO detail → เปิด dialog → บันทึกสำเร็จแล้วรีเฟรชรายการ)
- รัน `flutter analyze --no-pub lib/pages/procurement/receive_tab.dart lib/pages/procurement/dialogs/receive_goods_dialog.dart` ผ่านแล้ว (No issues found)
- เพิ่ม flow ยกเลิก PO พร้อมเหตุผลใน `request_tab.dart` และ `purchase_tab.dart` แล้ว
- เพิ่ม/เชื่อม permission `procurement_purchase_cancel` ใน migration และ enforce visibility ของ action หลักใน procurement screens
- รัน `flutter analyze --no-pub lib/pages/procurement/request_tab.dart lib/pages/procurement/purchase_tab.dart lib/pages/procurement/receive_tab.dart` ผ่านระดับ compile (คงเหลือ info บางรายการ)
- เปลี่ยน `DropdownButtonFormField.value` → `initialValue` ใน `purchase_tab.dart` และแก้ `withOpacity` เป็น `withValues` ใน procurement tabs
- เพิ่ม automated widget test สำหรับปุ่มยกเลิก PO + validation เหตุผล (`cancel_po_dialog_test.dart`) ผ่านแล้ว
- เชื่อม flow `Draft → Sent` และ `Sent → Confirmed` ใน `purchase_tab.dart` ให้เรียก `SendPODialog` / `ApprovePODialog` ใช้งานจริงแล้ว
- ปรับ `ProcurementService.sendPurchaseOrder` และ `approvePurchaseOrder` ให้ตรวจว่า update สำเร็จจริง (มีแถวถูกอัปเดต) ก่อนคืนค่า success
- รัน `flutter test test/services/procurement_service_test.dart test/pages/procurement/dialogs/cancel_po_dialog_test.dart` ผ่านแล้ว (exit code 0)
- เคลียร์ lint `use_build_context_synchronously` ใน `request_tab.dart` แล้ว (เพิ่ม mounted guard หลัง async gap)
- เพิ่ม widget tests ฝั่ง UI สำหรับ `send_po_dialog.dart` และ `approve_po_dialog.dart` แล้ว
- รัน `flutter analyze --no-pub lib/pages/procurement/request_tab.dart lib/pages/procurement/dialogs/send_po_dialog.dart lib/pages/procurement/dialogs/approve_po_dialog.dart` ผ่านแล้ว (No issues found)
- รัน `flutter test test/pages/procurement/dialogs/cancel_po_dialog_test.dart test/pages/procurement/dialogs/send_po_dialog_test.dart test/pages/procurement/dialogs/approve_po_dialog_test.dart` ผ่านแล้ว (exit code 0)
- เพิ่มปุ่มลัด Procurement ในแถบสินค้า (`ProductActionButtonsCard`) แล้ว: `สั่งซื้อสินค้า` / `ติดตาม PO` / `รับสินค้า` / `อนุมัติ PO`
- ปุ่มลัดถูกผูก permission แยกตาม action/tab และนำทางเข้า `ProcurementPage` แบบระบุ `initialTabId` แล้ว
- รัน `flutter analyze lib/pages/inventory/product_tab.dart lib/pages/inventory/product_action_buttons_card.dart lib/pages/procurement_page.dart` ผ่านระดับ compile (คงเหลือ info เดิมใน `product_tab.dart`)
- ปรับ UX/UI หน้า `purchase_tab.dart` ตามลำดับ 1-5 แล้ว: แยก section ฟอร์ม create/edit, เติม status chips ให้ครบ, เพิ่ม priority badges ในการ์ด, ปรับ empty state แบบ contextual, และเพิ่มข้อมูล operational ใน detail dialog
- ปรับฟอร์ม create/edit ให้เลือกสินค้าจากระบบจริงพร้อม `product_id` เพื่อให้ flow รับสินค้าใช้งานต่อได้ครบ
- รัน `flutter analyze lib/pages/procurement/purchase_tab.dart` ผ่านแล้ว (No issues found)
- ผูก `approvePurchaseOrder` ให้ดึงวงเงินจาก `approval_hierarchy_rules` แล้ว (fallback ค่าเดิมเมื่อโหลดกฎไม่ได้)
- เพิ่มการบังคับลำดับอนุมัติตาม `priority` ด้วย approval steps (role ที่ยังไม่ถึงคิวจะถูกบล็อก)
- เพิ่ม audit log การอนุมัติรายขั้น (`approved_step`) และขั้นสุดท้าย (`approved_final`) ใน service
- เพิ่มตัวชี้วัดในหน้า HRM ว่ากฎ hierarchy ถูกเชื่อมกับ procurement service แล้ว
- เพิ่ม migration ใหม่ `lib/database/procurement_approval_steps_migration.sql` สำหรับตาราง step/audit พร้อม RLS และ index
- เพิ่ม test กรณี approval limit จาก rules DB (`canApproveAmountByRule`, `approvalLimitForRoleFromRules`) ใน `test/services/procurement_service_test.dart`
- รัน `flutter analyze lib/services/procurement_service.dart test/services/procurement_service_test.dart` ผ่านแล้ว (No issues found)
- รัน `flutter test test/services/procurement_service_test.dart` ผ่านแล้ว (All tests passed)

## 8) เช็กลิสต์ก่อนปิดงาน

- [x] Draft PO ส่งเป็น Sent ได้จริง (รวม schema)
- [x] Sent PO อนุมัติได้ตาม role และวงเงิน
- [x] Confirmed PO รับสินค้าได้ผ่าน `receive_goods_dialog` (เชื่อม flow แล้ว)
- [x] PO ที่เกินวงเงิน role ถูกบล็อกพร้อมข้อความชัดเจน (ยืนยันด้วย unit test)
- [x] User ไม่มีสิทธิ์ไม่เห็น action ที่ไม่เกี่ยวข้อง (enforce ที่ `request_tab`/`purchase_tab`/`receive_tab`)
- [x] Flow ยกเลิก PO บันทึกผู้ยกเลิก เวลา และเหตุผลครบ (ต้องรัน migration คอลัมน์สถานะ PO แล้ว)
- [x] มีปุ่มทางลัดจากแถบสินค้าไป `สั่งซื้อ/ติดตาม/รับสินค้า/อนุมัติ` พร้อม permission guard ครบ
- [x] UX/UI หน้า `สั่งซื้อสินค้า` รองรับ mobile-first และเพิ่มความชัดเจนของ priority/empty-state/detail แล้ว
- [x] Current Behavior ในหน้า HRM แสดงจาก `approval_hierarchy_rules` จริงแล้ว
- [x] Flow อนุมัติ PO รองรับวงเงินจาก DB + บังคับลำดับ `priority` + บันทึก audit (หลังรัน migration step/audit)

## 10) วิเคราะห์ภาพรวมการดำเนินการตามแผน

- **สถานะภาพรวม:** งานหลักใน procurement workflow ปิดครบตามเช็กลิสต์ก่อนปิดงาน
- **ความพร้อมเชิง workflow:** ครอบคลุมเส้นทางหลัก `Draft → Sent → Confirmed → (Partial/Completed)` และเส้นทาง `Cancelled`
- **ความพร้อมเชิงสิทธิ์:** visibility/action ถูกผูกกับ permission ราย action ทั้ง request/purchase/receive
- **ความพร้อมเชิงการเข้าถึงเมนู:** เพิ่ม entry point จากแถบสินค้าไป workflow procurement หลัก ลดจำนวนคลิกของผู้ใช้งานหน้าสต็อก
- **ความพร้อมเชิงคุณภาพ:** มี unit/integration-like tests สำหรับ transition, วงเงินอนุมัติจาก rule, พร้อม widget tests สำหรับ `cancel/send/approve` dialogs และปรับ UX หน้า purchase ให้ใช้งานจริงได้ครบขึ้น
- **ความเสี่ยงที่เหลือ:** ต้องรัน migration `procurement_approval_steps_migration.sql` ในทุก environment ก่อนเปิดใช้ approval chain เต็มรูปแบบ; ยังไม่มี integration test ระดับ end-to-end จากหน้า `request_tab`/`purchase_tab` จนเปลี่ยนสถานะจริง และยังไม่มี widget test เฉพาะหน้า `purchase_tab`

## 9) ไฟล์อ้างอิงหลัก

- `/lib/services/procurement_service.dart`
- `/lib/services/approval_hierarchy_service.dart`
- `/lib/pages/procurement/request_tab.dart`
- `/lib/pages/procurement/purchase_tab.dart`
- `/lib/pages/procurement/receive_tab.dart`
- `/lib/pages/procurement/dialogs/send_po_dialog.dart`
- `/lib/pages/procurement/dialogs/cancel_po_dialog.dart`
- `/lib/pages/procurement/dialogs/approve_po_dialog.dart`
- `/lib/pages/procurement/dialogs/receive_goods_dialog.dart`
- `/lib/pages/inventory/product_tab.dart`
- `/lib/pages/inventory/product_action_buttons_card.dart`
- `/lib/database/procurement_migration.sql`
- `/lib/database/procurement_po_status_columns_migration.sql`
- `/lib/database/approval_hierarchy_migration.sql`
- `/lib/database/procurement_approval_steps_migration.sql`
- `/lib/database/procurement_permissions_migration.sql`
- `/lib/database/complete_procurement_setup.sql`
- `/test/services/procurement_service_test.dart`
- `/test/pages/procurement/dialogs/cancel_po_dialog_test.dart`
- `/test/pages/procurement/dialogs/send_po_dialog_test.dart`
- `/test/pages/procurement/dialogs/approve_po_dialog_test.dart`
- `/test/widget_test.dart`

