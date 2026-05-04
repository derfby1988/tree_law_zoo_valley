# Phase 0 & 1 Analysis Report
## Coupon & Promotion System - Tree Law Zoo Valley

**Generated:** May 4, 2026  
**Scope:** Phase 0 (Schema Baseline) and Phase 1 (Coupon CRUD)

---

## Executive Summary

| Phase | Status | Completion | Critical Issues |
|-------|--------|------------|-----------------|
| Phase 0 | ✅ Ready | 95% | SQL migration needs execution |
| Phase 1 | ⚠️ Partial | 70% | Dialog UI has rendering issues |

---

## Phase 0: Schema & Permission Baseline

### 1. Database Schema Analysis

#### Fields Already in Model + Service + SQL Migration:

| Field | Model | Service | SQL Migration | Status |
|-------|-------|---------|---------------|--------|
| `applicable_product_ids` | ✅ | ✅ | ✅ | Ready |
| `targeting_mode` | ✅ | ✅ | ✅ | Ready |
| `targeting_rule` | ✅ | ✅ | ✅ | Ready |
| `lifecycle_status` | ✅ | ✅ | ✅ | Ready |
| `usage_limit_per_customer` | ✅ | ✅ | ✅ | Ready |
| `usage_limit_per_day` | ✅ | ✅ | ✅ | Ready |
| `usage_limit_per_order` | ✅ | ✅ | ✅ | Ready |
| `applicable_channels` | ✅ | ✅ | ✅ | Ready |
| `require_in_stock` | ✅ | ✅ | ✅ | Ready |
| `require_sufficient_ingredients` | ✅ | ✅ | ✅ | Ready |
| `include_pending_procurement` | ✅ | ✅ | ✅ | Ready |
| `pos_discount_codes` table | N/A | ❌ | ✅ | Partial |

#### SQL Migration Status
- **File:** `lib/database/coupon_promotion_phase0_schema_baseline.sql`
- **Status:** Created but NOT executed
- **Action Required:** Run migration on Supabase

### 2. Permission System Analysis

| Permission Page | Status | Notes |
|-----------------|--------|-------|
| `coupon_promotion` page ID | ✅ | Added to `_systemPages` |
| `coupon_promotion_coupons` tab | ✅ | Added to `_systemTabs` |
| `coupon_promotion_promotions` tab | ✅ | Added to `_systemTabs` |
| `coupon_promotion_analytics` tab | ⚠️ | Exists but no UI implemented |
| Actions (create/edit/delete) | ❌ | Not defined in `_systemActions` |

**Finding:** Permission structure defined but action-level permissions not implemented.

---

## Phase 1: Coupon CRUD Implementation

### 1. Coupon Dialog Features Status

| Feature | Status | Implementation | Issue |
|---------|--------|----------------|-------|
| **Basic Fields** | | | |
| Name | ✅ | TextField | Working |
| Description | ✅ | TextField | Working |
| Discount Type | ✅ | Dropdown | Working |
| Value | ✅ | TextField | Working |
| Max Discount | ✅ | TextField | Working |
| Min Amount | ✅ | TextField | Working |
| **Lifecycle** | | | |
| Lifecycle Status | ✅ | Dropdown (TH) | Working |
| Start/End Date | ✅ | DatePicker | Working |
| isActive sync | ✅ | Auto-sync with lifecycle | Working |
| **Usage Limits** | | | |
| Total Usage Limit | ✅ | TextField | Working |
| Per Customer | ✅ | TextField | Working |
| Per Day | ✅ | TextField | Working |
| **Scope & Targeting** | | | |
| Scope (order/category/item) | ✅ | Dropdown | Working |
| Category Multi-select | ✅ | Dropdown + Chips | Working |
| Product Multi-select | ⚠️ | Dropdown + Chips | Layout issues in dialog |
| Coupon Code | ✅ | TextField | Working |
| Stackable | ✅ | Switch | Working |
| **Advanced (Phase 0 fields)** | | | |
| Channel Targeting | ✅ | Multi-select | Working |
| Require In Stock | ✅ | Switch | Working |
| Require Sufficient Ingredients | ✅ | Switch | Working |
| Include Pending Procurement | ✅ | Switch | Working |

### 2. Critical Issues Found

#### Issue #1: Dialog Rendering Crash (HIGH PRIORITY)
**Symptom:** Dialog freezes, turns white, then red screen when:
- Typing in product search field
- Changing dropdown values
- Dialog layout breaks with `IntrinsicWidth` error

**Root Cause:** 
- `DropdownButtonFormField` uses `IntrinsicWidth` internally
- `onChanged` callbacks calling `setState` during build cycle
- AlertDialog without `ConstrainedBox` causes infinite layout

**Current Fixes Applied:**
```dart
// 1. Added ConstrainedBox to AlertDialog content
content: ConstrainedBox(
  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
  child: SingleChildScrollView(...)
)

// 2. Wrapped onChanged with Future.microtask
onChanged: (v) => Future.microtask(() => ds(() => ...))
```

**Status:** Partially fixed, needs testing

#### Issue #2: Product Selector in Dialog (MEDIUM PRIORITY)
**Problem:** Selecting products for scope='item' uses inline search in dialog
**Roadmap Requirement:** Should use full-screen `PromotionProductPickerPage`
**Current:** Basic dropdown with search (not per roadmap design)

#### Issue #3: Missing Permission Checks (MEDIUM PRIORITY)
**Finding:** UI doesn't check permissions before showing actions
**Expected:** Use `checkPermissionAndExecute()` helper
**Current:** Direct `onPressed` without permission checks

### 3. Model-Service-UI Alignment

#### PosDiscount Model ✅
- All Phase 0 fields present
- `fromMap()` / `toMap()` correct
- `isValid` getter implemented with lifecycle logic
- `calculateDiscount()` implemented

#### PosDiscountService ✅
- `addDiscount()` with all Phase 0 fields
- `updateDiscount()` with all Phase 0 fields
- Missing: `getDiscountByCouponCode()` (removed in rollback)
- Missing: Usage logging methods (recordDiscountUsage, incrementDiscountUsage)

#### Coupon Dialog UI ⚠️
- Uses all model fields correctly
- Form validation present but basic
- Save/Edit flow working
- **Issue:** Product search rendering crash

---

## Gap Analysis: Roadmap vs Implementation

### Phase 1 Gaps

| Requirement | Roadmap Spec | Current | Gap |
|-------------|--------------|---------|-----|
| Product Picker | Full-screen page | Inline dialog search | ❌ Not per spec |
| Lifecycle Flow | draft→scheduled→active→expired→archived | UI shows all states | ⚠️ No flow enforcement |
| Validation | Comprehensive rules | Basic field checks | ⚠️ Incomplete |
| Permission | Action-level checks | Not implemented | ❌ Missing |
| Usage History | View per coupon | Removed in rollback | ❌ Not available |

### Phase 2+ Gaps

| Feature | Status | Notes |
|---------|--------|-------|
| POS Coupon Application | ❌ Removed | `_applyCouponCode()` removed from pos_page.dart |
| Usage Logging | ❌ Removed | `recordDiscountUsage()` removed |
| Discount Panel Validation | ⚠️ Partial | Basic validation only |
| Analytics Tab | ❌ Not started | UI placeholder only |

---

## Recommendations

### Immediate Actions (Priority: HIGH)

1. **Fix Dialog Rendering**
   - Test with `flutter run` after microtask fixes
   - If still failing, consider replacing `DropdownButtonFormField` with custom widget
   - Alternative: Use `showModalBottomSheet` instead of `AlertDialog` for promotion dialog

2. **Execute SQL Migration**
   ```sql
   -- Run on Supabase:
   \i lib/database/coupon_promotion_phase0_schema_baseline.sql
   ```

3. **Add Action Permissions**
   - Add to `user_permissions_page.dart`:
     ```dart
     {'id': 'coupon_promotion_coupons_create', 'name': 'สร้างคูปอง', 'tab_id': 'coupon_promotion_coupons', ...}
     {'id': 'coupon_promotion_coupons_edit', 'name': 'แก้ไขคูปอง', 'tab_id': 'coupon_promotion_coupons', ...}
     {'id': 'coupon_promotion_coupons_delete', 'name': 'ลบคูปอง', 'tab_id': 'coupon_promotion_coupons', ...}
     ```

### Short-term (Priority: MEDIUM)

4. **Implement Full-Screen Product Picker**
   - Create `PromotionProductPickerPage` per roadmap spec
   - Support tabs: ทั้งหมด, ใกล้หมดอายุ, วัตถุดิบใกล้หมดอายุ, กำไรสูง, ตามฤดูกาล, เทศกาล, แนะนำ
   - Replace inline product selector with navigation to picker

5. **Restore Phase 2 Features (Optional)**
   - If dialog issues resolved, consider restoring:
     - `_applyCouponCode()` in POS
     - Usage history dialog
     - Discount panel validation

### Long-term (Priority: LOW)

6. **Implement Analytics Tab**
   - Summary cards (usage count, total discount, sales after discount)
   - Line charts for usage trends
   - Summary table with drill-down

---

## Testing Checklist

### Phase 0 Verification
- [ ] SQL migration executed successfully
- [ ] All new columns exist in `pos_discounts`
- [ ] Indexes created
- [ ] RLS policies active on `pos_discount_codes`

### Phase 1 Verification
- [ ] Create coupon with all field types
- [ ] Edit existing coupon
- [ ] Delete coupon with confirmation
- [ ] Lifecycle status changes correctly
- [ ] Category multi-select persists
- [ ] Product multi-select persists (after fix)
- [ ] Coupon code validation (unique check)
- [ ] Date validation (start < end)
- [ ] Scope validation (category requires 1+, item requires 1+)
- [ ] Permission checks working

### Regression Testing
- [ ] POS page loads without errors
- [ ] Product page unaffected
- [ ] Other admin pages working

---

## Files Modified/Reviewed

| File | Lines | Status |
|------|-------|--------|
| `lib/models/pos_discount_model.dart` | 177 | ✅ Complete |
| `lib/services/pos_discount_service.dart` | 307 | ⚠️ Missing some methods |
| `lib/pages/coupon_promotion_admin_page.dart` | ~2000 | ⚠️ Has rendering issues |
| `lib/database/coupon_promotion_phase0_schema_baseline.sql` | 201 | ✅ Ready to run |

---

## Conclusion

**Phase 0 (Schema):** 95% complete - SQL migration ready, needs execution
**Phase 1 (Coupon CRUD):** 70% complete - Core functionality works but dialog rendering is unstable

**Recommendation:** 
1. Fix dialog rendering issues first (highest priority)
2. Execute SQL migration
3. Test complete Phase 1 flow
4. Then proceed to Phase 2 (POS integration) only after Phase 1 is stable

**Risk:** The dialog rendering issue has persisted through multiple fix attempts. Consider a UI redesign using `showModalBottomSheet` or a separate page instead of `AlertDialog` if the issue continues.
