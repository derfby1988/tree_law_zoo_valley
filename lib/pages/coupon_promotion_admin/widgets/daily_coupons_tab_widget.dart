import 'package:flutter/material.dart';

import 'package:tree_law_zoo_valley/models/pos_discount_model.dart';
import 'package:tree_law_zoo_valley/theme/app_design_system.dart';

class DailyCouponsTabWidget extends StatelessWidget {
  const DailyCouponsTabWidget({
    super.key,
    required this.coupons,
    required this.getTargetingRule,
    required this.formatDate,
    required this.isLoadingHistory,
    required this.dailyEntryLogs,
    required this.dailyPosHistory,
    required this.selectedCoupon,
    required this.onSelectCoupon,
    required this.onViewDetail,
    required this.dailyEntrySummary,
    required this.onRefreshHistory,
    required this.historyRangeDays,
    required this.onHistoryRangeChanged,
    this.dailyAlerts = const [],
  });

  final List<PosDiscount> coupons;
  final Map<String, dynamic> Function(PosDiscount coupon) getTargetingRule;
  final String Function(DateTime date) formatDate;
  final bool isLoadingHistory;
  final List<Map<String, dynamic>> dailyEntryLogs;
  final List<Map<String, dynamic>> dailyPosHistory;
  final PosDiscount? selectedCoupon;
  final ValueChanged<PosDiscount?> onSelectCoupon;
  final ValueChanged<PosDiscount>? onViewDetail;
  final Map<String, dynamic>? dailyEntrySummary;
  final Future<void> Function() onRefreshHistory;
  final int historyRangeDays;
  final ValueChanged<int> onHistoryRangeChanged;
  final List<String> dailyAlerts;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const TabBar(
              tabs: [
                Tab(text: 'รายการคูปองรายวัน'),
                Tab(text: 'ประวัติการใช้งาน'),
              ],
              indicatorColor: Colors.white,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDailyCouponList(),
                _DailyHistoryTab(
                  coupons: coupons,
                  selectedCoupon: selectedCoupon,
                  onSelectCoupon: onSelectCoupon,
                  isLoading: isLoadingHistory,
                  entryLogs: dailyEntryLogs,
                  entrySummary: dailyEntrySummary,
                  posHistory: dailyPosHistory,
                  onRefresh: onRefreshHistory,
                  historyRangeDays: historyRangeDays,
                  onHistoryRangeChanged: onHistoryRangeChanged,
                  alerts: dailyAlerts,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCouponList() {
    if (coupons.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        final rule = getTargetingRule(coupon);
        return _DailyCouponCard(
          coupon: coupon,
          rule: rule,
          formatDate: formatDate,
          onViewDetail: onViewDetail,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 72,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 20),
            Text(
              'ยังไม่มีคูปองรายวัน',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'สร้างคูปองรายวันที่รวมส่วนลดและสิทธิ์เข้าพื้นที่ได้จากปุ่ม “+ สร้างคูปองรายวัน” ด้านล่าง',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyHistoryTab extends StatelessWidget {
  const _DailyHistoryTab({
    required this.coupons,
    required this.selectedCoupon,
    required this.onSelectCoupon,
    required this.isLoading,
    required this.entryLogs,
    required this.entrySummary,
    required this.posHistory,
    required this.onRefresh,
    required this.historyRangeDays,
    required this.onHistoryRangeChanged,
    this.alerts = const [],
  });

  final List<PosDiscount> coupons;
  final PosDiscount? selectedCoupon;
  final ValueChanged<PosDiscount?> onSelectCoupon;
  final bool isLoading;
  final List<Map<String, dynamic>> entryLogs;
  final Map<String, dynamic>? entrySummary;
  final List<Map<String, dynamic>> posHistory;
  final Future<void> Function() onRefresh;
  final int historyRangeDays;
  final ValueChanged<int> onHistoryRangeChanged;
  final List<String> alerts;

  static const _rangeOptions = [1, 3, 7, 30];

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีคูปองรายวันสำหรับดูประวัติ',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<PosDiscount>(
            value: selectedCoupon,
            decoration: const InputDecoration(
              labelText: 'เลือกคูปอง',
              border: OutlineInputBorder(),
            ),
            items: coupons
                .map((coupon) => DropdownMenuItem(
                      value: coupon,
                      child: Text(coupon.name),
                    ))
                .toList(),
            onChanged: onSelectCoupon,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _rangeOptions
                .map(
                  (days) => ChoiceChip(
                    label: Text('$days วัน'),
                    selected: historyRangeDays == days,
                    onSelected: (_) => onHistoryRangeChanged(days),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (alerts.isNotEmpty)
            Column(
              children: alerts
                  .map(
                    (alert) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert,
                              style: const TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (alerts.isNotEmpty) const SizedBox(height: 8),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (selectedCoupon == null)
            const Text(
              'เลือกคูปองเพื่อดูประวัติ',
              style: TextStyle(color: Colors.white70),
            )
          else ...[
            _HistorySummaryCard(entrySummary: entrySummary),
            const SizedBox(height: 20),
            _HistorySectionTitle(title: 'ประวัติการเข้า/ออกพื้นที่ (Gate)'),
            if (entryLogs.isEmpty)
              _EmptyHistoryLabel(message: 'ยังไม่มีการเข้า/ออกในช่วงนี้')
            else
              ...entryLogs.map((log) => _EntryLogTile(log: log)),
            const SizedBox(height: 20),
            _HistorySectionTitle(title: 'ประวัติการใช้ส่วนลด (POS)'),
            if (posHistory.isEmpty)
              _EmptyHistoryLabel(message: 'ยังไม่มีการใช้ส่วนลดในช่วงนี้')
            else
              ...posHistory.map((log) => _PosHistoryTile(log: log)),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({required this.entrySummary});

  final Map<String, dynamic>? entrySummary;

  @override
  Widget build(BuildContext context) {
    final totalEntries = entrySummary?['total_entries'] ?? 0;
    final totalExits = entrySummary?['total_exits'] ?? 0;
    final totalDenied = entrySummary?['total_denied'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryMetric(label: 'เข้า', value: totalEntries.toString(), color: Colors.green),
          _SummaryMetric(label: 'ออก', value: totalExits.toString(), color: Colors.blue),
          _SummaryMetric(label: 'ถูกปฏิเสธ', value: totalDenied.toString(), color: Colors.orange),
        ],
      ),
    );
  }
}

class _HistorySectionTitle extends StatelessWidget {
  const _HistorySectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _EmptyHistoryLabel extends StatelessWidget {
  const _EmptyHistoryLabel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        message,
        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
      ),
    );
  }
}

class _EntryLogTile extends StatelessWidget {
  const _EntryLogTile({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final scannedAt = DateTime.tryParse(log['scanned_at']?.toString() ?? '');
    final status = (log['status'] ?? 'pending').toString();
    final member = log['member_identifier'] ?? '-';
    final area = log['entry_area'] ?? '-';
    final direction = (log['direction'] ?? 'enter').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(direction == 'enter' ? 'เข้า' : 'ออก', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                scannedAt != null ? _formatDateTime(scannedAt) : '-',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('สมาชิก/ผู้ใช้สิทธิ์: $member', style: const TextStyle(fontSize: 12)),
          Text('พื้นที่: $area', style: const TextStyle(fontSize: 12)),
          Text('สถานะ: ${status.toUpperCase()}', style: TextStyle(fontSize: 12, color: _statusColor(status))),
          if ((log['reason_code'] ?? '').toString().isNotEmpty)
            Text('เหตุผล: ${log['reason_code']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'valid':
        return Colors.green;
      case 'denied':
      case 'invalid':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

class _PosHistoryTile extends StatelessWidget {
  const _PosHistoryTile({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final appliedAt = DateTime.tryParse(log['applied_at']?.toString() ?? '');
    final amount = (log['discount_amount'] ?? 0).toString();
    final orderId = log['order_id']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('POS', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                appliedAt != null ? _EntryLogTile._formatDateTime(appliedAt) : '-',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Order: $orderId', style: const TextStyle(fontSize: 12)),
          Text('ลดไป: $amount บาท', style: const TextStyle(fontSize: 12, color: Colors.green)),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _DailyCouponCard extends StatelessWidget {
  const _DailyCouponCard({
    required this.coupon,
    required this.rule,
    required this.formatDate,
    this.onViewDetail,
  });

  final PosDiscount coupon;
  final Map<String, dynamic> rule;
  final String Function(DateTime date) formatDate;
  final ValueChanged<PosDiscount>? onViewDetail;

  @override
  Widget build(BuildContext context) {
    final audience = (rule['coupon_audience'] ?? 'individual').toString();
    final isGroup = audience == 'group';
    final groupSize = rule['group_size'];
    final entryArea = (rule['entry_area_name'] ?? '-').toString();
    final entryLimit = rule['entry_limit_per_day'];
    final discountLimit = rule['discount_limit_per_day'];
    final requiresSameDay = rule['entry_requires_same_day'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if ((coupon.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          coupon.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusPill(status: coupon.lifecycleStatus),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: isGroup ? 'รายวัน • รายกลุ่ม' : 'รายวัน • รายบุคคล',
                  icon: isGroup ? Icons.groups_2 : Icons.person,
                  color: AppDesignSystem.primary,
                ),
                if (isGroup && groupSize != null)
                  _InfoChip(
                    label: 'สมาชิก ${groupSize.toString()} คน',
                    icon: Icons.badge,
                    color: AppDesignSystem.secondary,
                  ),
                _InfoChip(
                  label: 'พื้นที่: $entryArea',
                  icon: Icons.place_outlined,
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuotaTile(
                    title: 'เข้าได้ต่อวัน',
                    value: entryLimit != null ? '$entryLimit ครั้ง' : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuotaTile(
                    title: 'ใช้ส่วนลดต่อวัน',
                    value: discountLimit != null ? '$discountLimit ครั้ง' : '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimelineTile(
                    label: 'เริ่ม',
                    value: coupon.startAt != null ? formatDate(coupon.startAt!) : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimelineTile(
                    label: 'สิ้นสุด',
                    value: coupon.endAt != null ? formatDate(coupon.endAt!) : 'ไม่มีกำหนด',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FlagChip(
                  icon: Icons.calendar_today_outlined,
                  label: requiresSameDay ? 'ใช้สิทธิ์ในวันเดียวกันเท่านั้น' : 'ใช้สิทธิ์ข้ามวันได้',
                ),
                _FlagChip(
                  icon: Icons.lock_clock,
                  label: coupon.stackable ? 'ซ้อนส่วนลดได้' : 'ไม่อนุญาตให้ซ้อน',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onViewDetail != null ? () => onViewDetail!(coupon) : null,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('ดูรายละเอียด'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaTile extends StatelessWidget {
  const _QuotaTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  Color get _statusColor {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'active':
        return 'ใช้งานอยู่';
      case 'scheduled':
        return 'ตั้งเวลาไว้';
      case 'paused':
        return 'หยุดชั่วคราว';
      case 'expired':
        return 'หมดอายุ';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
