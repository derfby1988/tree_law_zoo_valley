-- Create account_chart table for Chart of Accounts
CREATE TABLE IF NOT EXISTS public.account_chart (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name_th VARCHAR(255) NOT NULL,
  name_en VARCHAR(255),
  type VARCHAR(50) NOT NULL CHECK (type IN ('asset', 'liability', 'equity', 'revenue', 'expense', 'cogs')),
  parent_id UUID REFERENCES public.account_chart(id),
  level INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.account_chart ENABLE ROW LEVEL SECURITY;

-- Create RLS policy
CREATE POLICY "Users can view account_chart" ON public.account_chart
  FOR SELECT USING (auth.role() = 'authenticated');

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_account_chart_code ON public.account_chart(code);
CREATE INDEX IF NOT EXISTS idx_account_chart_type ON public.account_chart(type);
CREATE INDEX IF NOT EXISTS idx_account_chart_parent_id ON public.account_chart(parent_id);

-- Insert sample accounts
INSERT INTO public.account_chart (code, name_th, name_en, type, level) VALUES
-- Asset accounts
('1001', 'สินค้าคงเหลือ', 'Inventory', 'asset', 1),
('1002', 'ค่าเสื่อมสะสม', 'Accumulated Depreciation', 'asset', 1),
('1003', 'เงินสด', 'Cash', 'asset', 1),
('1004', 'บัญชีธนาคาร', 'Bank Accounts', 'asset', 1),

-- Revenue accounts  
('4001', 'รายได้จากการขายสินค้า', 'Sales Revenue', 'revenue', 1),
('4002', 'รายได้จากบริการ', 'Service Revenue', 'revenue', 1),
('4003', 'ส่วนลดหัก', 'Discounts', 'revenue', 1),

-- COGS accounts
('5001', 'ต้นทุนสินค้า', 'Cost of Goods Sold', 'cogs', 1),
('5002', 'ต้นทุนวัตถุดิบ', 'Material Costs', 'cogs', 1),
('5003', 'ค่าแรงงานตรง', 'Direct Labor', 'cogs', 1),

-- Expense accounts
('6001', 'ค่าเช่า', 'Rent Expense', 'expense', 1),
('6002', 'ค่าจ้าง', 'Salaries', 'expense', 1),
('6003', 'ค่าสาธารณูปโภค', 'Utilities', 'expense', 1)

ON CONFLICT (code) DO NOTHING;

-- Update trigger
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_account_chart_updated_at
  BEFORE UPDATE ON public.account_chart
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.account_chart TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
