import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

import 'analytics_filter_panel.dart';
import 'analytics_summary_card.dart';
import 'analytics_usage_tile.dart';

typedef AnalyticsUsageTap = void Function(Map<String, dynamic> usage);

class AnalyticsTabWidget extends StatelessWidget {
  const AnalyticsTabWidget({
    super.key,
    required this.summary,
    required this.usageData,
    required this.isLoading,
    required this.startDate,
    required this.endDate,
    required this.onSelectDate,
    required this.onApplyFilter,
    required this.onUsageTap,
  });

  final Map<String, dynamic>? summary;
  final List<Map<String, dynamic>> usageData;
  final bool isLoading;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<bool> onSelectDate;
  final VoidCallback onApplyFilter;
  final AnalyticsUsageTap onUsageTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnalyticsFilterPanel(
            startDate: startDate,
            endDate: endDate,
            onDateSelect: onSelectDate,
            onSearch: onApplyFilter,
          ),
          if (summary != null)
            Container(
              margin: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final isMobile = screenWidth < 600;
                  final isTablet = screenWidth < 900;
                  final totalUsage = summary!['total_usage'] ?? 0;
                  final totalDiscount = summary!['total_discount'] ?? 0;
                  final totalOrders = summary!['total_orders'] ?? 0;
                  if (isMobile) {
                    return Column(
                      children: [
                        AnalyticsSummaryCard(title: 'จำนวนครั้งที่ใช้', value: '$totalUsage', icon: Icons.receipt),
                        const SizedBox(height: 12),
                        AnalyticsSummaryCard(title: 'ส่วนลดรวม', value: (totalDiscount as num).toStringAsFixed(2), icon: Icons.discount),
                        const SizedBox(height: 12),
                        AnalyticsSummaryCard(title: 'ออเดอร์ที่เกี่ยวข้อง', value: '$totalOrders', icon: Icons.shopping_cart),
                      ],
                    );
                  }
                  if (isTablet) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: AnalyticsSummaryCard(title: 'จำนวนครั้งที่ใช้', value: '$totalUsage', icon: Icons.receipt)),
                            const SizedBox(width: 12),
                            Expanded(child: AnalyticsSummaryCard(title: 'ส่วนลดรวม', value: (totalDiscount as num).toStringAsFixed(2), icon: Icons.discount)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: AnalyticsSummaryCard(title: 'ออเดอร์ที่เกี่ยวข้อง', value: '$totalOrders', icon: Icons.shopping_cart)),
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: AnalyticsSummaryCard(title: 'จำนวนครั้งที่ใช้', value: '$totalUsage', icon: Icons.receipt)),
                      const SizedBox(width: 12),
                      Expanded(child: AnalyticsSummaryCard(title: 'ส่วนลดรวม', value: (totalDiscount as num).toStringAsFixed(2), icon: Icons.discount)),
                      const SizedBox(width: 12),
                      Expanded(child: AnalyticsSummaryCard(title: 'ออเดอร์ที่เกี่ยวข้อง', value: '$totalOrders', icon: Icons.shopping_cart)),
                    ],
                  );
                },
              ),
            ),
          Container(
            margin: const EdgeInsets.all(16),
            height: 400,
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : usageData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text('ไม่มีข้อมูลการใช้งาน', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          itemCount: usageData.length,
                          itemBuilder: (context, index) {
                            final usage = usageData[index];
                            return AnalyticsUsageTile(
                              usage: usage,
                              onTap: () => onUsageTap(usage),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

}
