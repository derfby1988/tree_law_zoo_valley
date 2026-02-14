-- Fix missing account columns on inventory_categories
-- Root cause: update category failed with PGRST204 (missing cost_account_code)

ALTER TABLE public.inventory_categories
  ADD COLUMN IF NOT EXISTS inventory_account_code TEXT,
  ADD COLUMN IF NOT EXISTS revenue_account_code TEXT,
  ADD COLUMN IF NOT EXISTS cost_account_code TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Add FK constraints safely (skip if already exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'account_chart'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'inventory_categories_inventory_account_code_fkey'
    ) THEN
      ALTER TABLE public.inventory_categories
        ADD CONSTRAINT inventory_categories_inventory_account_code_fkey
        FOREIGN KEY (inventory_account_code) REFERENCES public.account_chart(code);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'inventory_categories_revenue_account_code_fkey'
    ) THEN
      ALTER TABLE public.inventory_categories
        ADD CONSTRAINT inventory_categories_revenue_account_code_fkey
        FOREIGN KEY (revenue_account_code) REFERENCES public.account_chart(code);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'inventory_categories_cost_account_code_fkey'
    ) THEN
      ALTER TABLE public.inventory_categories
        ADD CONSTRAINT inventory_categories_cost_account_code_fkey
        FOREIGN KEY (cost_account_code) REFERENCES public.account_chart(code);
    END IF;
  END IF;
END $$;

-- Backfill updated_at if null
UPDATE public.inventory_categories
SET updated_at = now()
WHERE updated_at IS NULL;
