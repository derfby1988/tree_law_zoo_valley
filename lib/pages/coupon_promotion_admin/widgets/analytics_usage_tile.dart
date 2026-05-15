import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

class AnalyticsUsageTile extends StatelessWidget {
  const AnalyticsUsageTile({
    super.key,
    required this.usage,
    required this.onTap,
  });

  final Map<String, dynamic> usage;
  final VoidCallback onTap;

  String get _lastUsed {
    final lastUsed = usage['last_used'] as String?;
    if (lastUsed == null) return '-';
    final date = DateTime.parse(lastUsed);
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    final type = usage['type'] as String? ?? 'coupon';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: type == 'coupon' ? AppDesignSystem.primary : AppDesignSystem.secondary,
        child: Icon(type == 'coupon' ? Icons.local_offer : Icons.card_giftcard, color: Colors.white, size: 20),
      ),
      title: Text(usage['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(
        'ใช้ ${usage['usage_count']} ครั้ง | ส่วนลด ${(usage['total_discount'] ?? 0).toStringAsFixed(2)}',
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
      trailing: Text(_lastUsed, style: TextStyle(color: Colors.white.withOpacity(0.7))),
      onTap: onTap,
    );
  }
}
