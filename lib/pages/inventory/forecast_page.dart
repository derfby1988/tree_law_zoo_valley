import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../utils/responsive_helper.dart';
import '../../theme/app_design_system.dart';
import 'widgets/forecast_widget.dart';

class ForecastPage extends StatefulWidget {
  const ForecastPage({super.key});

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  List<Map<String, dynamic>> _atRiskProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTab = 'at-risk'; // 'at-risk', 'all'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final atRisk = await InventoryService.getAtRiskProducts();
      if (!mounted) return;
      setState(() {
        _atRiskProducts = atRisk;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          // Tab selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('เสี่ยงหมด (${_atRiskProducts.length})'),
                    selected: _selectedTab == 'at-risk',
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTab = 'at-risk');
                    },
                  ),
                ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _atRiskProducts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _atRiskProducts.length,
                      itemBuilder: (context, index) {
                        final product = _atRiskProducts[index];
                        return _buildProductCard(product);
                      },
                    ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('พยากรณ์สต็อก'),
        elevation: 0,
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up,
                size: 64,
                color: Colors.green.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'สินค้าทั้งหมดปลอดภัย',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'ไม่มีสินค้าที่เสี่ยงหมด',
                style: TextStyle(
                  fontSize: 14,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> forecast) {
    final productId = forecast['product_id']?.toString() ?? '';
    final currentStock = (forecast['current_stock'] as num?)?.toDouble() ?? 0;
    final avgDaily = (forecast['avg_daily_sales'] as num?)?.toDouble() ?? 0;
    final projectedStock = (forecast['projected_stock'] as num?)?.toDouble() ?? 0;
    final daysUntilStockout = (forecast['days_until_stockout'] as num?)?.toInt() ?? 999;
    final willStockout = forecast['will_stockout'] == true;
    final trend = forecast['trend_direction']?.toString() ?? 'stable';

    Color riskColor = Colors.orange;
    String riskLabel = 'ปานกลาง';

    if (willStockout) {
      riskColor = Colors.red;
      riskLabel = 'สูง';
    } else if (daysUntilStockout < 14) {
      riskColor = Colors.orange;
      riskLabel = 'ปานกลาง';
    } else {
      riskColor = Colors.yellow;
      riskLabel = 'ต่ำ';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showForecastDetail(forecast),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          forecast['product_id']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ขายต่อวัน: ${avgDaily.toStringAsFixed(2)} หน่วย',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Risk badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      riskLabel,
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stock info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ปัจจุบัน',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                        Text(
                          currentStock.toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คาดการณ์',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                        Text(
                          projectedStock.toStringAsFixed(2),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: projectedStock < 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'วันจนหมด',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppDesignSystem.textSecondary,
                          ),
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

              // Trend indicator
              if (trend != 'stable')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        trend == 'up'
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: trend == 'up' ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend == 'up' ? 'ความต้องการเพิ่มขึ้น' : 'ความต้องการลดลง',
                        style: TextStyle(
                          fontSize: 11,
                          color: trend == 'up' ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForecastDetail(Map<String, dynamic> forecast) async {
    final productId = forecast['product_id']?.toString() ?? '';
    
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ForecastWidget(
          productId: productId,
          productName: productId,
        ),
      ),
    );
  }
}
