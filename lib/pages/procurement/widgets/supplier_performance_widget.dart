import 'package:flutter/material.dart';
import '../../../services/procurement_service.dart';
import '../../../theme/app_design_system.dart';

/// Widget แสดงประเมินผลผู้ขาย
class SupplierPerformanceWidget extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final int monthsBack;

  const SupplierPerformanceWidget({
    super.key,
    required this.supplierId,
    required this.supplierName,
    this.monthsBack = 6,
  });

  @override
  State<SupplierPerformanceWidget> createState() => _SupplierPerformanceWidgetState();
}

class _SupplierPerformanceWidgetState extends State<SupplierPerformanceWidget> {
  Map<String, dynamic>? _performance;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  Future<void> _loadPerformance() async {
    setState(() => _isLoading = true);
    try {
      final performance = await ProcurementService.getSupplierPerformance(
        supplierId: widget.supplierId,
        monthsBack: widget.monthsBack,
      );

      if (!mounted) return;
      setState(() {
        _performance = performance;
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
              onPressed: _loadPerformance,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_performance == null) {
      return const Center(child: Text('ไม่มีข้อมูลประเมินผล'));
    }

    final perf = _performance!;
    final onTimeRate = (perf['on_time_delivery_rate'] as num?)?.toDouble() ?? 0;
    final qualityScore = (perf['quality_score'] as num?)?.toDouble() ?? 0;
    final responseTime = (perf['average_response_time_days'] as num?)?.toDouble() ?? 0;
    final overallRating = (perf['overall_rating'] as num?)?.toDouble() ?? 0;
    final ratingGrade = perf['rating_grade']?.toString() ?? 'N/A';

    Color gradeColor = Colors.grey;
    if (ratingGrade == 'A') {
      gradeColor = Colors.green;
    } else if (ratingGrade == 'B') {
      gradeColor = Colors.blue;
    } else if (ratingGrade == 'C') {
      gradeColor = Colors.orange;
    } else if (ratingGrade == 'D') {
      gradeColor = Colors.red;
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
                  'ประเมินผล: ${widget.supplierName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ข้อมูล ${widget.monthsBack} เดือนที่ผ่านมา',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Overall Rating Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradeColor.withOpacity(0.2), gradeColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gradeColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'คะแนนรวม',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        overallRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 48,
                          color: gradeColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: gradeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            ratingGrade,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 36,
                              color: gradeColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: overallRating / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Metrics Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รายละเอียด',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),

                // On-Time Delivery
                _buildMetricCard(
                  title: 'ส่งตรงเวลา',
                  value: onTimeRate.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.schedule,
                  color: onTimeRate >= 90 ? Colors.green : onTimeRate >= 70 ? Colors.orange : Colors.red,
                  description: '${onTimeRate >= 90 ? 'ดีเยี่ยม' : onTimeRate >= 70 ? 'ปานกลาง' : 'ต้องปรับปรุง'}',
                ),
                const SizedBox(height: 12),

                // Quality Score
                _buildMetricCard(
                  title: 'คุณภาพ',
                  value: qualityScore.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.verified,
                  color: qualityScore >= 95 ? Colors.green : qualityScore >= 80 ? Colors.orange : Colors.red,
                  description: '${qualityScore >= 95 ? 'ดีเยี่ยม' : qualityScore >= 80 ? 'ปานกลาง' : 'ต้องปรับปรุง'}',
                ),
                const SizedBox(height: 12),

                // Response Time
                _buildMetricCard(
                  title: 'เวลาตอบสนอง',
                  value: responseTime.toStringAsFixed(1),
                  unit: 'วัน',
                  icon: Icons.timer,
                  color: responseTime <= 7 ? Colors.green : responseTime <= 14 ? Colors.orange : Colors.red,
                  description: '${responseTime <= 7 ? 'รวดเร็ว' : responseTime <= 14 ? 'ปานกลาง' : 'ช้า'}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),

          // Rating Explanation
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'วิธีคำนวณคะแนน',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRatingExplanation('ส่งตรงเวลา', '40%'),
                  _buildRatingExplanation('คุณภาพ', '40%'),
                  _buildRatingExplanation('เวลาตอบสนอง', '20%'),
                  const SizedBox(height: 8),
                  Text(
                    'เกรด: A (90-100) | B (80-89) | C (70-79) | D (<70)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppDesignSystem.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingExplanation(String label, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            percentage,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
