import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';
import '../../../theme/app_design_system.dart';

/// Widget แสดงพยากรณ์สต็อก
class ForecastWidget extends StatefulWidget {
  final String productId;
  final String productName;
  final int historyDays;
  final int forecastDays;

  const ForecastWidget({
    super.key,
    required this.productId,
    required this.productName,
    this.historyDays = 30,
    this.forecastDays = 7,
  });

  @override
  State<ForecastWidget> createState() => _ForecastWidgetState();
}

class _ForecastWidgetState extends State<ForecastWidget> {
  Map<String, dynamic>? _forecast;
  Map<String, dynamic>? _seasonal;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        InventoryService.forecastStock(
          productId: widget.productId,
          historyDays: widget.historyDays,
          forecastDays: widget.forecastDays,
        ),
        InventoryService.analyzeSeasonalPattern(
          productId: widget.productId,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _forecast = results[0] as Map<String, dynamic>?;
        _seasonal = results[1] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadForecast,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_forecast == null) {
      return const Center(child: Text('ไม่มีข้อมูลพยากรณ์'));
    }

    final forecast = _forecast!;
    final currentStock = (forecast['current_stock'] as num?)?.toDouble() ?? 0;
    final avgDaily = (forecast['avg_daily_sales'] as num?)?.toDouble() ?? 0;
    final trend = forecast['trend_direction']?.toString() ?? 'stable';
    final trendPct = (forecast['trend_percentage'] as num?)?.toDouble() ?? 0;
    final projectedStock = (forecast['projected_stock'] as num?)?.toDouble() ?? 0;
    final daysUntilStockout = (forecast['days_until_stockout'] as num?)?.toInt() ?? 999;
    final willStockout = forecast['will_stockout'] == true;
    final needsReorder = forecast['needs_reorder'] == true;
    final confidence = forecast['confidence']?.toString() ?? 'low';

    Color trendColor = Colors.grey;
    IconData trendIcon = Icons.trending_flat;
    String trendLabel = 'ราคาคงที่';

    if (trend == 'up') {
      trendColor = Colors.green;
      trendIcon = Icons.trending_up;
      trendLabel = 'เพิ่มขึ้น';
    } else if (trend == 'down') {
      trendColor = Colors.red;
      trendIcon = Icons.trending_down;
      trendLabel = 'ลดลง';
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'พยากรณ์สต็อก: ${widget.productName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ประเมินจากข้อมูล ${widget.historyDays} วันที่ผ่านมา',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Risk Indicator
          if (willStockout || needsReorder)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ เตือน: สินค้าเสี่ยงหมด',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          willStockout
                              ? 'จะหมดในอีก $daysUntilStockout วัน'
                              : 'ต้องสั่งซื้อเพิ่มเติม',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Main Metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current vs Projected
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'สต็อกปัจจุบัน',
                        value: currentStock.toStringAsFixed(2),
                        icon: Icons.inventory_2,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'สต็อกที่คาดการณ์',
                        value: projectedStock.toStringAsFixed(2),
                        icon: Icons.trending_down,
                        color: projectedStock < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Daily Sales & Trend
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'ขายต่อวัน',
                        value: avgDaily.toStringAsFixed(2),
                        icon: Icons.shopping_cart,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: trendColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(trendIcon, color: trendColor, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              '${trendPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: trendColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trendLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: trendColor.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Days Until Stockout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'วันจนกว่าจะหมด',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        daysUntilStockout >= 999 ? '∞' : '$daysUntilStockout วัน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: daysUntilStockout < 7 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Confidence & Seasonal
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confidence Level
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ความเชื่อมั่น',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: confidence == 'high'
                                ? Colors.green.withOpacity(0.2)
                                : confidence == 'medium'
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            confidence == 'high'
                                ? 'สูง'
                                : confidence == 'medium'
                                    ? 'ปานกลาง'
                                    : 'ต่ำ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: confidence == 'high'
                                  ? Colors.green
                                  : confidence == 'medium'
                                      ? Colors.orange
                                      : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: confidence == 'high'
                            ? 1.0
                            : confidence == 'medium'
                                ? 0.6
                                : 0.3,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),

                if (_seasonal != null) ...[
                  const SizedBox(height: 16),
                  // Seasonal Pattern
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'รูปแบบตามฤดูกาล',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ยอดสูงสุด',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppDesignSystem.textSecondary,
                                  ),
                                ),
                                Text(
                                  (_seasonal!['peak_sales'] as num?)
                                      ?.toStringAsFixed(2) ??
                                      '0',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ยอดต่ำสุด',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppDesignSystem.textSecondary,
                                  ),
                                ),
                                Text(
                                  (_seasonal!['low_sales'] as num?)
                                      ?.toStringAsFixed(2) ??
                                      '0',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            if (_seasonal!['is_seasonal'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'มีฤดูกาล',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
