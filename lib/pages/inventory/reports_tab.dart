import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_design_system.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _data = {};
  bool get _canViewReports => PermissionService.canAccessActionSync('inventory_reports_view');

  Color get _surface => AppDesignSystem.surface;
  Color get _surfaceAlt => AppDesignSystem.background;
  Color get _textPrimary => AppDesignSystem.textPrimary;
  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _border => AppDesignSystem.border;
  Color get _primary => AppDesignSystem.primary;
  Color get _secondary => AppDesignSystem.secondary;
  Color get _warning => AppDesignSystem.warning;
  Color get _success => AppDesignSystem.success;

  @override
  void initState() {
    super.initState();
    if (_canViewReports) {
      _loadData();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await InventoryService.getInventoryReportsDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดรายงาน: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewReports) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: _textSecondary, size: 48),
              const SizedBox(height: 12),
              const Text('บัญชีนี้ไม่มีสิทธิ์ดูรายงานคลังสินค้า'),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber, color: _warning, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildCategoryBreakdown(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildTurnoverSection(),
              const SizedBox(height: AppDesignSystem.spacingLg),
              _buildSlowMovers(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final valuation = _data['valuation'] as Map<String, dynamic>? ?? {};
    final turnover = _data['turnover'] as Map<String, dynamic>? ?? {};
    final totalValue = (valuation['totalValue'] as num?)?.toDouble() ?? 0;
    final totalQty = (valuation['totalQuantity'] as num?)?.toDouble() ?? 0;
    final avgCost = (valuation['avgCost'] as num?)?.toDouble() ?? 0;
    final turnoverRatio = (turnover['turnoverRatio'] as num?)?.toDouble() ?? 0;
    final totalOut = (turnover['totalOut'] as num?)?.toDouble() ?? 0;

    final cards = [
      _SummaryCardData(
        title: 'มูลค่าสินค้าคงคลัง',
        value: _formatCurrency(totalValue),
        subtitle: 'รวมทุกหมวดหมู่',
        color: _primary,
        icon: Icons.attach_money,
      ),
      _SummaryCardData(
        title: 'จำนวนคงเหลือ',
        value: _formatNumber(totalQty),
        subtitle: 'ชิ้นทั้งหมดในคลัง',
        color: _secondary,
        icon: Icons.inventory_2,
      ),
      _SummaryCardData(
        title: 'ต้นทุนเฉลี่ยต่อหน่วย',
        value: _formatCurrency(avgCost),
        subtitle: 'ต้นทุนถ่วงน้ำหนัก',
        color: _success,
        icon: Icons.balance,
      ),
      _SummaryCardData(
        title: 'Turnover (90 วัน)',
        value: turnoverRatio.isNaN ? '-' : '${turnoverRatio.toStringAsFixed(2)}x',
        subtitle: 'จ่ายออก ${_formatNumber(totalOut)} หน่วย',
        color: _warning,
        icon: Icons.autorenew,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        double itemWidth;
        if (maxWidth >= 1000) {
          itemWidth = (maxWidth - AppDesignSystem.spacingSm * 3) / 4;
        } else if (maxWidth >= 700) {
          itemWidth = (maxWidth - AppDesignSystem.spacingSm * 1) / 2;
        } else {
          itemWidth = maxWidth;
        }

        return Wrap(
          spacing: AppDesignSystem.spacingSm,
          runSpacing: AppDesignSystem.spacingSm,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: _SummaryCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCategoryBreakdown() {
    final valuation = _data['valuation'] as Map<String, dynamic>? ?? {};
    final categories = (valuation['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: _primary),
                const SizedBox(width: 8),
                Text('มูลค่าตามหมวดหมู่', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (categories.isEmpty)
              Text('ยังไม่มีข้อมูลมูลค่าต่อหมวดหมู่', style: TextStyle(color: _textSecondary))
            else
              Column(
                children: categories.take(6).map((category) {
                  final label = category['label']?.toString() ?? '-';
                  final value = (category['value'] as num?)?.toDouble() ?? 0;
                  final percent = (category['percent'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text(_formatCurrency(value), style: TextStyle(color: _textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                          child: LinearProgressIndicator(
                            value: percent.clamp(0.0, 1.0),
                            minHeight: 8,
                            color: _primary,
                            backgroundColor: _surfaceAlt,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoverSection() {
    final turnover = _data['turnover'] as Map<String, dynamic>? ?? {};
    final trend = (turnover['trend'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final maxValue = trend.fold<double>(0, (max, item) => math.max(max, (item['value'] as num?)?.toDouble() ?? 0));

    return Card(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: _secondary),
                const SizedBox(width: 8),
                Text('แนวโน้มการจ่ายออก (สัปดาห์)', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (trend.isEmpty)
              Text('ยังไม่มีการจ่ายสินค้าออกในช่วงที่ผ่านมา', style: TextStyle(color: _textSecondary))
            else
              SizedBox(
                height: 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: trend.map((point) {
                    final value = (point['value'] as num?)?.toDouble() ?? 0;
                    final height = maxValue > 0 ? (value / maxValue) * 140.0 : 0.0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              value == 0 ? '-' : _formatNumber(value),
                              style: TextStyle(fontSize: 12, color: _textSecondary),
                            ),
                            const SizedBox(height: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: height,
                              decoration: BoxDecoration(
                                color: _secondary.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              point['label']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlowMovers() {
    final slowMovers = (_data['slowMovers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Card(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_bottom, color: _warning),
                const SizedBox(width: 8),
                Text('สินค้าเคลื่อนไหวช้า', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (slowMovers.isEmpty)
              Text('ยังไม่มีสินค้าที่เข้าเกณฑ์เคลื่อนไหวช้า', style: TextStyle(color: _textSecondary))
            else
              Column(
                children: slowMovers.map((item) {
                  final days = item['days'] as int? ?? 0;
                  final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                  final value = (item['value'] as num?)?.toDouble() ?? 0;
                  final unit = item['unit']?.toString() ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingSm),
                    padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                      border: Border.all(color: _border.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inbox, color: _textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('คงเหลือ ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} $unit | มูลค่า ${_formatCurrency(value)}',
                                  style: TextStyle(fontSize: 12, color: _textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                          ),
                          child: Text('ไม่ขยับ $days วัน', style: TextStyle(color: _warning, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M ฿';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K ฿';
    return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} ฿';
  }

  String _formatNumber(double value) {
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }
}

class _SummaryCardData {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  _SummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: data.color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: BorderSide(color: data.color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: data.color.withOpacity(0.2),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(height: AppDesignSystem.spacingSm),
            Text(data.title, style: TextStyle(color: data.color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              data.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppDesignSystem.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(data.subtitle, style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
