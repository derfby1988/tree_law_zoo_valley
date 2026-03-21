-- =============================================
-- Migration: Add PO sent/cancelled tracking columns
-- สำหรับปิด Schema Gap ของ Procurement workflow
-- =============================================

ALTER TABLE procurement_purchase_orders
  ADD COLUMN IF NOT EXISTS sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS sent_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_procurement_po_sent_at
  ON procurement_purchase_orders(sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_procurement_po_cancelled_at
  ON procurement_purchase_orders(cancelled_at DESC);

CREATE INDEX IF NOT EXISTS idx_procurement_po_sent_by
  ON procurement_purchase_orders(sent_by);

CREATE INDEX IF NOT EXISTS idx_procurement_po_cancelled_by
  ON procurement_purchase_orders(cancelled_by);
