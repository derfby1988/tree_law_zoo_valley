// =============================================
// Phase 10: Advanced Analytics Service
// Tree Law Zoo Valley
// =============================================
// Purpose:
// - Real-time analytics and metrics
// - Mobile-first analytics dashboard
// - POS system integration
// - Scheduled reports (daily/weekly/monthly)
// - Data retention and caching
// =============================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AnalyticsService {
  static final SupabaseClient _client = SupabaseService.client;

  // =============================================
  // 1. Real-time Metrics
  // =============================================

  /// ดึงข้อมูล dashboard สำหรับ mobile app
  static Future<Map<String, dynamic>> getMobileDashboardData(String userId) async {
    try {
      // ใช้ RPC function เพื่อ performance
      final response = await _client.rpc('get_mobile_dashboard_data', params: {
        'p_user_id': userId,
      });

      return Map<String, dynamic>.from(response ?? {});
    } catch (e) {
      debugPrint('Error getting mobile dashboard data: $e');
      return {};
    }
  }

  /// ดึง daily metrics summary
  static Future<Map<String, dynamic>> getDailyMetricsSummary(DateTime date) async {
    try {
      // ตรวจสอบ cache ก่อน
      final cacheKey = 'daily_summary_${date.toIso8601String().split('T')[0]}';
      final cachedData = await getCachedAnalytics(cacheKey);
      
      if (cachedData.isNotEmpty) {
        return cachedData;
      }

      // ถ้าไม่มี cache ให้เรียก RPC
      final response = await _client.rpc('get_daily_metrics_summary', params: {
        'p_date': date.toIso8601String().split('T')[0],
      });

      final data = Map<String, dynamic>.from(response ?? {});
      
      // เก็บไว้ใน cache 24 ชั่วโมง
      await cacheAnalyticsData(cacheKey, data, 'daily_summary', date, 24);
      
      return data;
    } catch (e) {
      debugPrint('Error getting daily metrics: $e');
      return {};
    }
  }

  /// ดึง weekly trends
  static Future<List<Map<String, dynamic>>> getWeeklyTrends({int weeks = 4}) async {
    try {
      final response = await _client.rpc('get_weekly_trends', params: {
        'p_weeks': weeks,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('Error getting weekly trends: $e');
      return [];
    }
  }

  /// ดึง monthly metrics
  static Future<Map<String, dynamic>> getMonthlyMetrics(DateTime month) async {
    try {
      final cacheKey = 'monthly_summary_${month.year}_${month.month.toString().padLeft(2, '0')}';
      final cachedData = await getCachedAnalytics(cacheKey);
      
      if (cachedData.isNotEmpty) {
        return cachedData;
      }

      final response = await _client
          .from('analytics_monthly_metrics')
          .select('*')
          .eq('month_start', DateTime(month.year, month.month, 1))
          .single();

      final data = Map<String, dynamic>.from(response);
      
      // เก็บไว้ใน cache 1 สัปดาห์
      await cacheAnalyticsData(cacheKey, data, 'monthly_summary', month, 720);
      
      return data;
    } catch (e) {
      debugPrint('Error getting monthly metrics: $e');
      return {};
    }
  }

  // =============================================
  // 2. Top Analytics
  // =============================================

  /// ดึง top 10 coupons
  static Future<List<Map<String, dynamic>>> getTopCoupons({
    String? period, // 'daily', 'weekly', 'monthly'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('analytics_daily_metrics')
          .select('top_coupons, metric_date')
          .order('metric_date', ascending: false);

      if (startDate != null) {
        query = query.gte('metric_date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('metric_date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.limit(period == 'monthly' ? 30 : period == 'weekly' ? 4 : 7);
      
      List<Map<String, dynamic>> topCoupons = [];
      for (final item in response) {
        final coupons = item['top_coupons'] as List? ?? [];
        topCoupons.addAll(coupons.cast<Map<String, dynamic>>());
      }

      return topCoupons.take(10).toList();
    } catch (e) {
      debugPrint('Error getting top coupons: $e');
      return [];
    }
  }

  /// ดึง top 10 promotions
  static Future<List<Map<String, dynamic>>> getTopPromotions({
    String? period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('analytics_daily_metrics')
          .select('top_promotions, metric_date')
          .order('metric_date', ascending: false);

      if (startDate != null) {
        query = query.gte('metric_date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('metric_date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.limit(period == 'monthly' ? 30 : period == 'weekly' ? 4 : 7);
      
      List<Map<String, dynamic>> topPromotions = [];
      for (final item in response) {
        final promotions = item['top_promotions'] as List? ?? [];
        topPromotions.addAll(promotions.cast<Map<String, dynamic>>());
      }

      return topPromotions.take(10).toList();
    } catch (e) {
      debugPrint('Error getting top promotions: $e');
      return [];
    }
  }

  /// ดึง top 10 products
  static Future<List<Map<String, dynamic>>> getTopProducts({
    String? period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('analytics_daily_metrics')
          .select('top_products, metric_date')
          .order('metric_date', ascending: false);

      if (startDate != null) {
        query = query.gte('metric_date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('metric_date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.limit(period == 'monthly' ? 30 : period == 'weekly' ? 4 : 7);
      
      List<Map<String, dynamic>> topProducts = [];
      for (final item in response) {
        final products = item['top_products'] as List? ?? [];
        topProducts.addAll(products.cast<Map<String, dynamic>>());
      }

      return topProducts.take(10).toList();
    } catch (e) {
      debugPrint('Error getting top products: $e');
      return [];
    }
  }

  // =============================================
  // 3. Reports Management
  // =============================================

  /// ดึงรายการ reports ทั้งหมด
  static Future<List<Map<String, dynamic>>> getReports({
    String? reportType,
    String? reportCategory,
    String? status,
    String? userId,
    int limit = 20,
  }) async {
    try {
      var query = _client
          .from('analytics_reports')
          .select('*, user:generated_by(display_name)')
          .order('generated_at', ascending: false);

      if (reportType != null) {
        query = query.eq('report_type', reportType);
      }
      if (reportCategory != null) {
        query = query.eq('report_category', reportCategory);
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      if (userId != null) {
        query = query.eq('generated_by', userId);
      }

      final response = await query.limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting reports: $e');
      return [];
    }
  }

  /// สร้าง report ใหม่
  static Future<String?> generateReport({
    required String reportType,
    required String reportCategory,
    required String title,
    required Map<String, dynamic> reportData,
    String? description,
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _client.from('analytics_reports').insert({
        'report_type': reportType,
        'report_category': reportCategory,
        'title': title,
        'description': description,
        'report_data': reportData,
        'date_range': {
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
        },
        'generated_by': userId,
      }).select().single();

      return response['id'] as String?;
    } catch (e) {
      debugPrint('Error generating report: $e');
      return null;
    }
  }

  /// ดาวนน์ report
  static Future<bool> downloadReport(String reportId) async {
    try {
      final report = await _client
          .from('analytics_reports')
          .select('file_path, file_size')
          .eq('id', reportId)
          .single();

      if (report['file_path'] != null) {
        // ทำการดาวน์จาก file path
        debugPrint('Downloading report: ${report['file_path']}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error downloading report: $e');
      return false;
    }
  }

  /// ลบ report
  static Future<bool> deleteReport(String reportId) async {
    try {
      await _client
          .from('analytics_reports')
          .delete()
          .eq('id', reportId);
      return true;
    } catch (e) {
      debugPrint('Error deleting report: $e');
      return false;
    }
  }

  // =============================================
  // 4. POS Integration
  // =============================================

  /// ดึงสถานะ sync กับ POS system
  static Future<Map<String, dynamic>> getPOSSyncStatus() async {
    try {
      final response = await _client
          .from('analytics_pos_sync')
          .select('*')
          .order('last_synced_at', ascending: false)
          .limit(1);

      return Map<String, dynamic>.from(response.firstOrNull ?? {});
    } catch (e) {
      debugPrint('Error getting POS sync status: $e');
      return {};
    }
  }

  /// เริ่ม sync กับ POS system
  static Future<bool> startPOSSync({
    required String syncType, // 'full_sync', 'incremental_sync'
  }) async {
    try {
      await _client.from('analytics_pos_sync').insert({
        'sync_type': syncType,
        'sync_status': 'running',
        'sync_start': DateTime.now().toIso8601String(),
        'records_total': 0,
        'records_processed': 0,
      });

      // ทำการ sync จริง (จำลอง sync logic)
      // TODO: Implement actual sync logic based on syncType
      
      return true;
    } catch (e) {
      debugPrint('Error starting POS sync: $e');
      return false;
    }
  }

  /// อัปเดตสถานะ sync
  static Future<bool> updatePOSSyncStatus({
    required String syncId,
    required String status,
    int? recordsProcessed,
    int? recordsTotal,
    String? errorMessage,
  }) async {
    try {
      final updates = <String, dynamic>{
        'sync_status': status,
      };
      
      if (recordsProcessed != null) {
        updates['records_processed'] = recordsProcessed;
      }
      if (recordsTotal != null) {
        updates['records_total'] = recordsTotal;
      }
      if (errorMessage != null) {
        updates['error_message'] = errorMessage;
      }
      
      if (status == 'completed') {
        updates['sync_end'] = DateTime.now().toIso8601String();
        updates['last_synced_at'] = DateTime.now().toIso8601String();
      }

      await _client
          .from('analytics_pos_sync')
          .update(updates)
          .eq('id', syncId);

      return true;
    } catch (e) {
      debugPrint('Error updating POS sync status: $e');
      return false;
    }
  }

  // =============================================
  // 5. Caching
  // =============================================

  /// ดึงข้อมูลจาก cache
  static Future<Map<String, dynamic>> getCachedAnalytics(String cacheKey) async {
    try {
      final response = await _client.rpc('get_cached_analytics', params: {
        'p_cache_key': cacheKey,
      });

      return Map<String, dynamic>.from(response ?? {});
    } catch (e) {
      debugPrint('Error getting cached analytics: $e');
      return {};
    }
  }

  /// เก็บข้อมูลใน cache
  static Future<void> cacheAnalyticsData(
    String cacheKey,
    Map<String, dynamic> data,
    String cacheType,
    DateTime dateKey,
    int expiresHours,
  ) async {
    try {
      await _client.rpc('cache_analytics_data', params: {
        'p_cache_key': cacheKey,
        'p_cache_data': data,
        'p_cache_type': cacheType,
        'p_date_key': dateKey.toIso8601String().split('T')[0],
        'p_expires_hours': expiresHours,
      });
    } catch (e) {
      debugPrint('Error caching analytics data: $e');
    }
  }

  /// ลบข้อมูลใน cache
  static Future<bool> clearCache({
    String? cacheType,
    DateTime? olderThan,
  }) async {
    try {
      var query = _client.from('analytics_cache').delete();

      if (cacheType != null) {
        query = query.eq('cache_type', cacheType);
      }
      if (olderThan != null) {
        query = query.lt('created_at', olderThan.toIso8601String());
      }

      await query;
      return true;
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      return false;
    }
  }

  // =============================================
  // 6. Scheduled Reports
  // =============================================

  /// ดึงรายการ scheduled reports
  static Future<List<Map<String, dynamic>>> getScheduledReports({
    String? userId,
    bool? isActive,
  }) async {
    try {
      var query = _client
          .from('analytics_schedules')
          .select('*')
          .order('next_run_at', ascending: true);

      if (userId != null) {
        query = query.eq('created_by', userId);
      }
      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting scheduled reports: $e');
      return [];
    }
  }

  /// สร้าง scheduled report
  static Future<String?> createScheduledReport({
    required String scheduleName,
    required String reportType,
    required String reportCategory,
    required Map<String, dynamic> scheduleConfig,
    required String userId,
  }) async {
    try {
      final response = await _client.from('analytics_schedules').insert({
        'schedule_name': scheduleName,
        'report_type': reportType,
        'report_category': reportCategory,
        'schedule_config': scheduleConfig,
        'is_active': true,
        'next_run_at': _calculateNextRun(scheduleConfig),
        'created_by': userId,
      }).select().single();

      return response['id'] as String?;
    } catch (e) {
      debugPrint('Error creating scheduled report: $e');
      return null;
    }
  }

  /// อัปเดต scheduled report
  static Future<bool> updateScheduledReport({
    required String scheduleId,
    String? scheduleName,
    String? reportType,
    String? reportCategory,
    Map<String, dynamic>? scheduleConfig,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (scheduleName != null) {
        updates['schedule_name'] = scheduleName;
      }
      if (reportType != null) {
        updates['report_type'] = reportType;
      }
      if (reportCategory != null) {
        updates['report_category'] = reportCategory;
      }
      if (scheduleConfig != null) {
        updates['schedule_config'] = scheduleConfig;
        updates['next_run_at'] = _calculateNextRun(scheduleConfig);
      }
      if (isActive != null) {
        updates['is_active'] = isActive;
      }

      await _client
          .from('analytics_schedules')
          .update(updates)
          .eq('id', scheduleId);

      return true;
    } catch (e) {
      debugPrint('Error updating scheduled report: $e');
      return false;
    }
  }

  /// ลบ scheduled report
  static Future<bool> deleteScheduledReport(String scheduleId) async {
    try {
      await _client
          .from('analytics_schedules')
          .delete()
          .eq('id', scheduleId);
      return true;
    } catch (e) {
      debugPrint('Error deleting scheduled report: $e');
      return false;
    }
  }

  /// คำนวณเวลาถัดไป
  static DateTime _calculateNextRun(Map<String, dynamic> config) {
    try {
      final frequency = config['frequency'] as String? ?? 'daily';
      final now = DateTime.now();
      
      switch (frequency) {
        case 'daily':
          final time = config['time'] as String? ?? '08:00';
          final parts = time.split(':');
          return DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          ).add(const Duration(days: 1));
          
        case 'weekly':
          final day = config['day'] as String? ?? 'monday';
          final time = config['time'] as String? ?? '09:00';
          return _getNextWeekday(day, time);
          
        case 'monthly':
          final day = config['day'] as int? ?? 1;
          final time = config['time'] as String? ?? '10:00';
          final parts = time.split(':');
          DateTime nextMonth = DateTime(now.year, now.month + 1, day);
          return DateTime(
            nextMonth.year,
            nextMonth.month,
            nextMonth.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          
        default:
          return now.add(const Duration(days: 1));
      }
    } catch (e) {
      debugPrint('Error calculating next run: $e');
      return DateTime.now().add(const Duration(days: 1));
    }
  }

  /// หาวันถัดไปของ weekday
  static DateTime _getNextWeekday(String weekday, String time) {
    final now = DateTime.now();
    final parts = time.split(':');
    
    // หา weekday ถัดไป
    DateTime nextDate = now;
    while (nextDate.weekday != _getWeekdayNumber(weekday)) {
      nextDate = nextDate.add(const Duration(days: 1));
    }
    
    return DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// แปลง weekday เป็นตัวเลข
  static int _getWeekdayNumber(String weekday) {
    switch (weekday.toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  // =============================================
  // 7. Performance Optimization
  // =============================================

  /// รีเฟรช materialized view
  static Future<bool> refreshAnalyticsSummary() async {
    try {
      await _client.rpc('refresh_analytics_summary');
      return true;
    } catch (e) {
      debugPrint('Error refreshing analytics summary: $e');
      return false;
    }
  }

  /// ดึง performance metrics
  static Future<Map<String, dynamic>> getPerformanceMetrics() async {
    try {
      // ดึงข้อมูลจาก materialized view
      final response = await _client
          .from('mv_analytics_summary')
          .select('*')
          .order('period_start', ascending: false)
          .limit(100);

      return {
        'total_records': response.length,
        'last_updated': DateTime.now().toIso8601String(),
        'data': response,
      };
    } catch (e) {
      debugPrint('Error getting performance metrics: $e');
      return {};
    }
  }

  // =============================================
  // 8. Data Export
  // =============================================

  /// ส่งออกข้อมูล analytics
  static Future<bool> exportAnalyticsData({
    required String format, // 'csv', 'excel', 'json'
    required Map<String, dynamic> data,
    String? filename,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final defaultFilename = filename ?? 'analytics_export_$timestamp.$format';
      
      // TODO: Implement actual export logic based on format
      debugPrint('Exporting analytics data to $format: $defaultFilename');
      
      return true;
    } catch (e) {
      debugPrint('Error exporting analytics data: $e');
      return false;
    }
  }
}
