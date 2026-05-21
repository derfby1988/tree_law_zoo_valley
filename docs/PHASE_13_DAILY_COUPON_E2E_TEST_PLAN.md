---
description: End-to-end test plan for Phase 13 daily coupon flows
---

# Phase 13 Daily Coupon E2E Test Plan

## Purpose
Validate the daily unified coupon flow end to end across customer, gate, and POS paths.

## Coverage Scope
- Customer coupon card visibility
- Group share-token creation and status visibility
- Gate scan success, offline queue, and replay sync
- POS usage reuse against the same coupon lifecycle
- Negative paths for invalid QR, expired token, and duplicate replay

## Primary Scenarios

### 1. Customer can view daily coupon status
- Daily coupon badge is visible in the coupon tab.
- Group coupons show share-token usage and remaining counts.
- Status badge reflects active or expired share token state.

### 2. Customer can share a group coupon
- Share action creates or refreshes a share token.
- Clipboard text includes token, uses count, group size, and expiry.
- The visible token summary updates after share.

### 3. Gate scanner can process a valid scan
- QR validation succeeds.
- Share token is consumed once.
- Entry log is created with the expected metadata.
- The recent entry timeline refreshes.

### 4. Gate scanner can queue offline failures
- If entry logging fails, the event is stored in the offline queue.
- Queue replay skips duplicate events using the idempotency key.
- Replayed events do not double-consume the share token.

### 5. POS usage remains consistent
- POS reuse logs continue to show coupon usage history.
- Gate events and POS usage remain separate but aligned by coupon id.

## Acceptance Criteria
- Customer UI shows used and remaining token counts for group coupons.
- Gate scanning supports offline queue + sync without duplicate logs.
- Replay logic is idempotent within the configured window.
- POS and Gate history can be reviewed from the customer/admin flows.

## Execution Notes
- Use `flutter test test/e2e/daily_coupon_workflow_e2e_test.dart` for the scaffolded automation check.
- Perform manual smoke testing on the customer page and gate scanner after any backend schema or RPC change.
- Capture screenshots or logs for each scenario when validating release candidates.

## Evidence Checklist
- Customer coupon card screenshot showing token status.
- Share action screenshot or clipboard capture.
- Gate scanner success screenshot.
- Offline queue file snapshot after a failed log.
- Replay confirmation showing queue drained.

## Exit Criteria
- All primary scenarios pass.
- No duplicate entry logs are produced by replay.
- Roadmap documentation matches implementation status.
