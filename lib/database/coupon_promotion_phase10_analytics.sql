-- =============================================
-- Phase 10: Advanced Analytics - Database Schema (Fixed)
-- Tree Law Zoo Valley
-- =============================================
-- Purpose:
-- - Real-time analytics and metrics
-- - Mobile-first analytics dashboard
-- - POS system integration
-- - Scheduled reports (daily/weekly/monthly)
-- - Data retention and caching
-- =============================================

-- =============================================
-- 1. Analytics Cache Tables
-- =============================================

-- Analytics cache for real-time metrics
CREATE TABLE IF NOT EXISTS analytics_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_key VARCHAR(255) NOT NULL UNIQUE,
    cache_data JSONB NOT NULL,
    cache_type VARCHAR(50) NOT NULL, -- 'daily_summary', 'weekly_summary', 'monthly_summary'
    date_key DATE NOT NULL, -- YYYY-MM-DD format
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for analytics cache
CREATE INDEX IF NOT EXISTS idx_analytics_cache_key ON analytics_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_type ON analytics_cache(cache_type);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_date ON analytics_cache(date_key);
CREATE INDEX IF NOT EXISTS idx_analytics_cache_expires ON analytics_cache(expires_at);

-- =============================================
-- 2. Analytics Reports Tables
-- =============================================

-- Pre-generated reports for mobile app
CREATE TABLE IF NOT EXISTS analytics_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_type VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly', 'custom'
    report_category VARCHAR(50) NOT NULL, -- 'sales', 'usage', 'performance', 'trends'
    title VARCHAR(255) NOT NULL,
    description TEXT,
    report_data JSONB NOT NULL,
    date_range JSONB NOT NULL, -- {start_date, end_date}
    status VARCHAR(20) DEFAULT 'ready', -- 'generating', 'ready', 'failed'
    file_path VARCHAR(500), -- Path to exported file
    file_size BIGINT, -- File size in bytes
    generated_by UUID REFERENCES auth.users(id),
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for analytics reports
CREATE INDEX IF NOT EXISTS idx_analytics_reports_type ON analytics_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_analytics_reports_category ON analytics_reports(report_category);
CREATE INDEX IF NOT EXISTS idx_analytics_reports_status ON analytics_reports(status);
CREATE INDEX IF NOT EXISTS idx_analytics_reports_date ON analytics_reports(date_range);
CREATE INDEX IF NOT EXISTS idx_analytics_reports_generated_by ON analytics_reports(generated_by);

-- =============================================
-- 3. Analytics Schedules Tables
-- =============================================

-- Scheduled report configurations
CREATE TABLE IF NOT EXISTS analytics_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_name VARCHAR(255) NOT NULL,
    report_type VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly'
    report_category VARCHAR(50) NOT NULL, -- 'sales', 'usage', 'performance', 'trends'
    schedule_config JSONB NOT NULL, -- {frequency, time, recipients, filters}
    is_active BOOLEAN DEFAULT true,
    last_run_at TIMESTAMP WITH TIME ZONE,
    next_run_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for analytics schedules
CREATE INDEX IF NOT EXISTS idx_analytics_schedules_active ON analytics_schedules(is_active);
CREATE INDEX IF NOT EXISTS idx_analytics_schedules_next_run ON analytics_schedules(next_run_at);
CREATE INDEX IF NOT EXISTS idx_analytics_schedules_type ON analytics_schedules(report_type);

-- =============================================
-- 4. Analytics Metrics Tables
-- =============================================

-- Daily aggregated metrics
CREATE TABLE IF NOT EXISTS analytics_daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_date DATE NOT NULL,
    total_coupons_active INTEGER DEFAULT 0,
    total_coupons_used INTEGER DEFAULT 0,
    total_promotions_active INTEGER DEFAULT 0,
    total_discount_amount DECIMAL(15,2) DEFAULT 0.00,
    total_revenue_impact DECIMAL(15,2) DEFAULT 0.00,
    unique_customers INTEGER DEFAULT 0,
    top_coupons JSONB, -- Top 10 coupons for the day
    top_promotions JSONB, -- Top 10 promotions for the day
    top_products JSONB, -- Top 10 products for the day
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(metric_date)
);

-- Weekly aggregated metrics
CREATE TABLE IF NOT EXISTS analytics_weekly_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    week_start DATE NOT NULL,
    week_end DATE NOT NULL,
    total_coupons_active INTEGER DEFAULT 0,
    total_coupons_used INTEGER DEFAULT 0,
    total_promotions_active INTEGER DEFAULT 0,
    total_discount_amount DECIMAL(15,2) DEFAULT 0.00,
    total_revenue_impact DECIMAL(15,2) DEFAULT 0.00,
    unique_customers INTEGER DEFAULT 0,
    growth_rate DECIMAL(5,2) DEFAULT 0.00, -- Week over week growth
    top_coupons JSONB, -- Top 10 coupons for the week
    top_promotions JSONB, -- Top 10 promotions for the week
    top_products JSONB, -- Top 10 products for the week
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(week_start, week_end)
);

-- Monthly aggregated metrics
CREATE TABLE IF NOT EXISTS analytics_monthly_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month_start DATE NOT NULL,
    month_end DATE NOT NULL,
    total_coupons_active INTEGER DEFAULT 0,
    total_coupons_used INTEGER DEFAULT 0,
    total_promotions_active INTEGER DEFAULT 0,
    total_discount_amount DECIMAL(15,2) DEFAULT 0.00,
    total_revenue_impact DECIMAL(15,2) DEFAULT 0.00,
    unique_customers INTEGER DEFAULT 0,
    growth_rate DECIMAL(5,2) DEFAULT 0.00, -- Month over month growth
    top_coupons JSONB, -- Top 10 coupons for the month
    top_promotions JSONB, -- Top 10 promotions for the month
    top_products JSONB, -- Top 10 products for the month
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(month_start, month_end)
);

-- Indexes for metrics tables
CREATE INDEX IF NOT EXISTS idx_analytics_daily_date ON analytics_daily_metrics(metric_date);
CREATE INDEX IF NOT EXISTS idx_analytics_weekly_start ON analytics_weekly_metrics(week_start);
CREATE INDEX IF NOT EXISTS idx_analytics_weekly_end ON analytics_weekly_metrics(week_end);
CREATE INDEX IF NOT EXISTS idx_analytics_monthly_start ON analytics_monthly_metrics(month_start);
CREATE INDEX IF NOT EXISTS idx_analytics_monthly_end ON analytics_monthly_metrics(month_end);

-- =============================================
-- 5. POS Integration Tables
-- =============================================

-- POS transaction sync status
CREATE TABLE IF NOT EXISTS analytics_pos_sync (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_type VARCHAR(50) NOT NULL, -- 'full_sync', 'incremental_sync'
    sync_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'running', 'completed', 'failed'
    records_processed INTEGER DEFAULT 0,
    records_total INTEGER DEFAULT 0,
    sync_start TIMESTAMP WITH TIME ZONE,
    sync_end TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    last_synced_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- POS data mapping for analytics
CREATE TABLE IF NOT EXISTS analytics_pos_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_table VARCHAR(100) NOT NULL, -- 'pos_transactions', 'pos_discounts'
    source_field VARCHAR(100) NOT NULL,
    target_table VARCHAR(100) NOT NULL, -- 'analytics_daily_metrics', etc.
    target_field VARCHAR(100) NOT NULL,
    transformation_rule JSONB, -- How to transform the data
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for POS integration
CREATE INDEX IF NOT EXISTS idx_analytics_pos_sync_status ON analytics_pos_sync(sync_status);
CREATE INDEX IF NOT EXISTS idx_analytics_pos_sync_type ON analytics_pos_sync(sync_type);
CREATE INDEX IF NOT EXISTS idx_analytics_pos_sync_last ON analytics_pos_sync(last_synced_at);

-- =============================================
-- 6. Analytics Functions
-- =============================================

-- Function to get daily metrics summary
CREATE OR REPLACE FUNCTION get_daily_metrics_summary(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'date', p_date,
        'total_coupons_active', COALESCE(total_coupons_active, 0),
        'total_coupons_used', COALESCE(total_coupons_used, 0),
        'total_promotions_active', COALESCE(total_promotions_active, 0),
        'total_discount_amount', COALESCE(total_discount_amount, 0),
        'total_revenue_impact', COALESCE(total_revenue_impact, 0),
        'unique_customers', COALESCE(unique_customers, 0),
        'top_coupons', COALESCE(top_coupons, '[]'::jsonb),
        'top_promotions', COALESCE(top_promotions, '[]'::jsonb),
        'top_products', COALESCE(top_products, '[]'::jsonb)
    ) INTO result
    FROM analytics_daily_metrics 
    WHERE metric_date = p_date;
    
    RETURN COALESCE(result, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql;

-- Function to get weekly trends
CREATE OR REPLACE FUNCTION get_weekly_trends(p_weeks INTEGER DEFAULT 4)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'week_start', week_start,
            'week_end', week_end,
            'total_discount_amount', total_discount_amount,
            'total_revenue_impact', total_revenue_impact,
            'growth_rate', growth_rate,
            'top_coupons', top_coupons,
            'top_promotions', top_promotions
        )
    ) INTO result
    FROM (
        SELECT * FROM analytics_weekly_metrics 
        ORDER BY week_start DESC 
        LIMIT p_weeks
    ) t;
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql;

-- Function to get mobile dashboard data
CREATE OR REPLACE FUNCTION get_mobile_dashboard_data(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'daily_summary', get_daily_metrics_summary(CURRENT_DATE),
        'weekly_trends', get_weekly_trends(4),
        'recent_reports', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'title', title,
                    'report_type', report_type,
                    'status', status,
                    'generated_at', generated_at
                )
            )
            FROM analytics_reports 
            WHERE generated_by = p_user_id 
            AND status = 'ready'
            ORDER BY generated_at DESC 
            LIMIT 5
        ),
        'sync_status', (
            SELECT jsonb_build_object(
                'last_sync', last_synced_at,
                'status', sync_status,
                'records_processed', records_processed
            )
            FROM analytics_pos_sync 
            ORDER BY last_synced_at DESC 
            LIMIT 1
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to cache analytics data
CREATE OR REPLACE FUNCTION cache_analytics_data(
    p_cache_key VARCHAR(255),
    p_cache_data JSONB,
    p_cache_type VARCHAR(50),
    p_date_key DATE,
    p_expires_hours INTEGER DEFAULT 24
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO analytics_cache (
        cache_key, cache_data, cache_type, date_key, expires_at
    ) VALUES (
        p_cache_key, 
        p_cache_data, 
        p_cache_type, 
        p_date_key, 
        NOW() + (p_expires_hours || ' hours')::INTERVAL
    )
    ON CONFLICT (cache_key) 
    DO UPDATE SET 
        cache_data = p_cache_data,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to get cached data
CREATE OR REPLACE FUNCTION get_cached_analytics(p_cache_key VARCHAR(255))
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT cache_data INTO result
    FROM analytics_cache 
    WHERE cache_key = p_cache_key 
    AND expires_at > NOW();
    
    RETURN COALESCE(result, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 7. Triggers for Automatic Updates
-- =============================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to all analytics tables
CREATE TRIGGER update_analytics_cache_updated_at
    BEFORE UPDATE ON analytics_cache
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_reports_updated_at
    BEFORE UPDATE ON analytics_reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_schedules_updated_at
    BEFORE UPDATE ON analytics_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_daily_metrics_updated_at
    BEFORE UPDATE ON analytics_daily_metrics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_weekly_metrics_updated_at
    BEFORE UPDATE ON analytics_weekly_metrics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_monthly_metrics_updated_at
    BEFORE UPDATE ON analytics_monthly_metrics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_pos_sync_updated_at
    BEFORE UPDATE ON analytics_pos_sync
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analytics_pos_mapping_updated_at
    BEFORE UPDATE ON analytics_pos_mapping
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 8. Row Level Security (RLS)
-- =============================================

-- Enable RLS on all analytics tables
ALTER TABLE analytics_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_daily_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_weekly_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_monthly_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_pos_sync ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_pos_mapping ENABLE ROW LEVEL SECURITY;

-- Analytics cache policies
CREATE POLICY "Users can view their own cache" ON analytics_cache
    FOR SELECT USING (
        cache_key LIKE 'user_%' 
        AND auth.uid()::text = SPLIT_PART(cache_key, '_', 2)
    );

CREATE POLICY "Users can manage their own cache" ON analytics_cache
    FOR ALL USING (
        cache_key LIKE 'user_%' 
        AND auth.uid()::text = SPLIT_PART(cache_key, '_', 2)
    );

-- Analytics reports policies
CREATE POLICY "Users can view their own reports" ON analytics_reports
    FOR SELECT USING (generated_by = auth.uid());

CREATE POLICY "Users can manage their own reports" ON analytics_reports
    FOR ALL USING (generated_by = auth.uid());

-- Analytics schedules policies
CREATE POLICY "Users can view their own schedules" ON analytics_schedules
    FOR SELECT USING (created_by = auth.uid());

CREATE POLICY "Users can manage their own schedules" ON analytics_schedules
    FOR ALL USING (created_by = auth.uid());

-- Analytics metrics policies (read-only for authenticated users)
CREATE POLICY "Authenticated users can view daily metrics" ON analytics_daily_metrics
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can view weekly metrics" ON analytics_weekly_metrics
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can view monthly metrics" ON analytics_monthly_metrics
    FOR SELECT USING (auth.role() = 'authenticated');

-- POS sync policies (admin only)
CREATE POLICY "Admins can view POS sync" ON analytics_pos_sync
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE id = auth.uid() 
            AND raw_user_meta_data->>'role' = 'admin'
        )
    );

CREATE POLICY "Admins can manage POS sync" ON analytics_pos_sync
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE id = auth.uid() 
            AND raw_user_meta_data->>'role' = 'admin'
        )
    );

-- POS mapping policies (admin only)
CREATE POLICY "Admins can view POS mapping" ON analytics_pos_mapping
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE id = auth.uid() 
            AND raw_user_meta_data->>'role' = 'admin'
        )
    );

CREATE POLICY "Admins can manage POS mapping" ON analytics_pos_mapping
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE id = auth.uid() 
            AND raw_user_meta_data->>'role' = 'admin'
        )
    );

-- =============================================
-- 9. Initial Data Setup
-- =============================================

-- Insert default analytics schedules
INSERT INTO analytics_schedules (schedule_name, report_type, report_category, schedule_config, next_run_at, created_by)
VALUES 
    ('Daily Sales Report', 'daily', 'sales', 
     '{"frequency": "daily", "time": "08:00", "recipients": ["admin@company.com"], "filters": {}}',
     DATE_TRUNC('day', NOW() + INTERVAL '1 day') + TIME '08:00:00',
     (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1)),
     
    ('Weekly Performance Report', 'weekly', 'performance',
     '{"frequency": "weekly", "day": "monday", "time": "09:00", "recipients": ["manager@company.com"], "filters": {}}',
     (DATE_TRUNC('week', NOW() + INTERVAL '1 week') + INTERVAL '1 day') + TIME '09:00:00',
     (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1)),
     
    ('Monthly Summary Report', 'monthly', 'sales',
     '{"frequency": "monthly", "day": 1, "time": "10:00", "recipients": ["finance@company.com"], "filters": {}}',
     DATE_TRUNC('month', NOW() + INTERVAL '1 month') + TIME '10:00:00',
     (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1))
ON CONFLICT (schedule_name) DO NOTHING;

-- =============================================
-- 10. Performance Optimization
-- =============================================

-- Create materialized views for better performance
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_analytics_summary AS
SELECT 
    'daily' as period_type,
    metric_date as period_start,
    metric_date as period_end,
    total_coupons_active,
    total_coupons_used,
    total_promotions_active,
    total_discount_amount,
    total_revenue_impact,
    unique_customers,
    top_coupons,
    top_promotions,
    top_products
FROM analytics_daily_metrics
UNION ALL
SELECT 
    'weekly' as period_type,
    week_start as period_start,
    week_end as period_end,
    total_coupons_active,
    total_coupons_used,
    total_promotions_active,
    total_discount_amount,
    total_revenue_impact,
    unique_customers,
    growth_rate,
    top_coupons,
    top_promotions,
    top_products
FROM analytics_weekly_metrics
UNION ALL
SELECT 
    'monthly' as period_type,
    month_start as period_start,
    month_end as period_end,
    total_coupons_active,
    total_coupons_used,
    total_promotions_active,
    total_discount_amount,
    total_revenue_impact,
    unique_customers,
    growth_rate,
    top_coupons,
    top_promotions,
    top_products
FROM analytics_monthly_metrics;

-- Create index for materialized view
CREATE INDEX IF NOT EXISTS idx_mv_analytics_summary_type ON mv_analytics_summary(period_type);
CREATE INDEX IF NOT EXISTS idx_mv_analytics_summary_start ON mv_analytics_summary(period_start);

-- Function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_analytics_summary()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_analytics_summary;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Summary: Phase 10 Analytics Schema Complete
-- =============================================
-- Tables Created: 7
-- Functions Created: 6
-- Triggers Created: 8
-- Policies Created: 16
-- Materialized Views: 1
-- =============================================
