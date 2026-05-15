import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

typedef DateSelectCallback = void Function(bool isStartDate);

class AnalyticsFilterPanel extends StatelessWidget {
  const AnalyticsFilterPanel({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateSelect,
    required this.onSearch,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final DateSelectCallback onDateSelect;
  final VoidCallback onSearch;

  String _formatLabel(DateTime? date, String fallback) {
    if (date == null) return fallback;
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  Widget _buildDateField(String label, DateTime? date, bool isStart) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onDateSelect(isStart),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatLabel(date, label),
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('กรองข้อมูล', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDateField('วันที่เริ่มต้น', startDate, true),
              const SizedBox(width: 12),
              _buildDateField('วันที่สิ้นสุด', endDate, false),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('ค้นหา'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
