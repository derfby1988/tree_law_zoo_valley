import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseMigrationService {
  static final _client = Supabase.instance.client;

  /// Run Phase 7 Analytics migration
  static Future<bool> runPhase7AnalyticsMigration() async {
    try {
      debugPrint('Starting Phase 7 Analytics migration...');

      // Read the SQL file
      final sqlFile = await DefaultAssetBundle.of(NavigationService.navigatorKey.currentContext!)
          .loadString('lib/database/coupon_promotion_phase7_analytics.sql');
      
      // Split into individual statements
      final statements = sqlFile.split(';').where((s) => s.trim().isNotEmpty);
      
      for (final statement in statements) {
        final trimmedStatement = statement.trim();
        if (trimmedStatement.isNotEmpty) {
          try {
            await _client.rpc('exec_sql', params: {'sql': trimmedStatement});
            debugPrint('✅ Executed: ${trimmedStatement.substring(0, 50)}...');
          } catch (e) {
            debugPrint('❌ Failed to execute: ${trimmedStatement.substring(0, 50)}... Error: $e');
            // Continue with other statements
          }
        }
      }
      
      debugPrint('Phase 7 Analytics migration completed');
      return true;
    } catch (e) {
      debugPrint('Phase 7 Analytics migration failed: $e');
      return false;
    }
  }

  /// Check if analytics views exist
  static Future<bool> checkAnalyticsViewsExist() async {
    try {
      // Check if the main view exists
      final response = await _client
          .from('information_schema.views')
          .select('table_name')
          .eq('table_schema', 'public')
          .eq('table_name', 'coupon_promotion_usage_summary');
      
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking analytics views: $e');
      return false;
    }
  }

  /// Create individual view using raw SQL
  static Future<bool> createCouponPromotionUsageSummaryView() async {
    try {
      final sql = '''
        CREATE OR REPLACE VIEW coupon_promotion_usage_summary AS
        SELECT 
          CASE 
            WHEN d.id IS NOT NULL THEN 'coupon'
            WHEN p.id IS NOT NULL THEN 'promotion'
          END as type,
          COALESCE(d.id, p.id) as id,
          COALESCE(d.name, p.name) as name,
          COALESCE(d.description, p.description) as description,
          COUNT(od.id) as usage_count,
          COALESCE(SUM(od.discount_amount), 0) as total_discount,
          COUNT(DISTINCT od.order_id) as order_count,
          COUNT(DISTINCT o.customer_id) as unique_customers,
          MAX(od.applied_at) as last_used_at,
          MIN(od.applied_at) as first_used_at,
          DATE(od.applied_at) as usage_date,
          EXTRACT(MONTH FROM od.applied_at) as usage_month,
          EXTRACT(YEAR FROM od.applied_at) as usage_year,
          COALESCE(d.discount_type, 'promotion') as discount_type,
          COALESCE(d.discount_value, 0) as discount_value,
          COALESCE(p.min_quantity, 0) as min_quantity,
          COALESCE(p.free_quantity, 0) as free_quantity
        FROM pos_order_discounts od
        LEFT JOIN pos_orders o ON od.order_id = o.id
        LEFT JOIN pos_discounts d ON od.discount_id = d.id
        LEFT JOIN pos_promotions p ON od.promotion_id = p.id
        WHERE od.applied_at IS NOT NULL
        GROUP BY 
          COALESCE(d.id, p.id),
          COALESCE(d.name, p.name),
          COALESCE(d.description, p.description),
          COALESCE(d.discount_type, 'promotion'),
          COALESCE(d.discount_value, 0),
          COALESCE(p.min_quantity, 0),
          COALESCE(p.free_quantity, 0)
      ''';

      await _client.rpc('exec_sql', params: {'sql': sql});
      debugPrint('✅ Created coupon_promotion_usage_summary view');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to create coupon_promotion_usage_summary view: $e');
      return false;
    }
  }

  /// Create order details view
  static Future<bool> createOrderDetailsView() async {
    try {
      final sql = '''
        CREATE OR REPLACE VIEW order_discount_details AS
        SELECT 
          o.id as order_id,
          o.order_number,
          o.total_amount as order_total,
          o.final_amount as order_final_amount,
          o.created_at as order_date,
          o.customer_id,
          c.display_name as customer_name,
          od.id as order_discount_id,
          od.discount_id,
          od.promotion_id,
          od.discount_name,
          od.discount_type,
          od.discount_value,
          od.discount_amount,
          od.applied_at,
          od.applied_by,
          u.display_name as applied_by_name,
          CASE 
            WHEN od.discount_id IS NOT NULL THEN 'coupon'
            WHEN od.promotion_id IS NOT NULL THEN 'promotion'
          END as discount_category,
          COALESCE(d.name, p.name) as discount_full_name,
          COALESCE(d.description, p.description) as discount_description,
          ol.id as order_line_id,
          ol.product_id,
          ip.name as product_name,
          ol.quantity,
          ol.unit_price,
          ol.discount_amount as line_discount_amount,
          ol.final_line_total
        FROM pos_orders o
        LEFT JOIN pos_order_discounts od ON o.id = od.order_id
        LEFT JOIN pos_customers c ON o.customer_id = c.id
        LEFT JOIN users u ON od.applied_by = u.id
        LEFT JOIN pos_discounts d ON od.discount_id = d.id
        LEFT JOIN pos_promotions p ON od.promotion_id = p.id
        LEFT JOIN pos_order_lines ol ON od.order_line_id = ol.id
        LEFT JOIN inventory_products ip ON ol.product_id = ip.id
        WHERE o.created_at IS NOT NULL
      ''';

      await _client.rpc('exec_sql', params: {'sql': sql});
      debugPrint('✅ Created order_discount_details view');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to create order_discount_details view: $e');
      return false;
    }
  }
}

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
