import 'package:flutter/material.dart';
import '../../services/procurement_service.dart';
import '../../theme/app_design_system.dart';
import 'widgets/supplier_performance_widget.dart';

class SupplierPerformancePage extends StatefulWidget {
  const SupplierPerformancePage({super.key});

  @override
  State<SupplierPerformancePage> createState() => _SupplierPerformancePageState();
}

class _SupplierPerformancePageState extends State<SupplierPerformancePage> {
  List<Map<String, dynamic>> _allPerformance = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortBy = 'rating'; // 'rating', 'ontime', 'quality'
  int _monthsBack = 6;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  Future<void> _loadPerformance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final performance = await ProcurementService.getAllSuppliersPerformance(
        monthsBack: _monthsBack,
      );

      if (!mounted) return;

      // Apply sorting
      _sortPerformance(performance);

      setState(() {
        _allPerformance = performance;
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

  void _sortPerformance(List<Map<String, dynamic>> performance) {
    switch (_sortBy) {
      case 'ontime':
        performance.sort((a, b) {
          final aRate = (a['on_time_delivery_rate'] as num?)?.toDouble() ?? 0;
          final bRate = (b['on_time_delivery_rate'] as num?)?.toDouble() ?? 0;
          return bRate.compareTo(aRate);
        });
        break;
      case 'quality':
        performance.sort((a, b) {
          final aScore = (a['quality_score'] as num?)?.toDouble() ?? 0;
          final bScore = (b['quality_score'] as num?)?.toDouble() ?? 0;
          return bScore.compareTo(aScore);
        });
        break;
      case 'rating':
      default:
        performance.sort((a, b) {
          final aRating = (a['overall_rating'] as num?)?.toDouble() ?? 0;
          final bRating = (b['overall_rating'] as num?)?.toDouble() ?? 0;
          return bRating.compareTo(aRating);
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
              ElevatedButton(onPressed: _loadPerformance, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: [
          // Filter & Sort
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Months selector
                Row(
                  children: [
                    const Text('ข้อมูล: '),
                    DropdownButton<int>(
                      value: _monthsBack,
                      items: [3, 6, 12].map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('$m เดือน'),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _monthsBack = value);
                          _loadPerformance();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sort chips
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('คะแนนรวม'),
                      selected: _sortBy == 'rating',
                      onSelected: (selected) {
                        setState(() => _sortBy = 'rating');
                        _loadPerformance();
                      },
                    ),
                    FilterChip(
                      label: const Text('ส่งตรงเวลา'),
                      selected: _sortBy == 'ontime',
                      onSelected: (selected) {
                        setState(() => _sortBy = 'ontime');
                        _loadPerformance();
                      },
                    ),
                    FilterChip(
                      label: const Text('คุณภาพ'),
                      selected: _sortBy == 'quality',
                      onSelected: (selected) {
                        setState(() => _sortBy = 'quality');
                        _loadPerformance();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Suppliers list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPerformance,
              child: _allPerformance.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _allPerformance.length,
                      itemBuilder: (context, index) {
                        final performance = _allPerformance[index];
                        return _buildSupplierCard(performance, index + 1);
                      },
                    ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประเมินผลผู้ขาย'),
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
                Icons.store,
                size: 64,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'ไม่มีข้อมูลผู้ขาย',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'ยังไม่มีการสั่งซื้อจากผู้ขาย',
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

  Widget _buildSupplierCard(Map<String, dynamic> performance, int rank) {
    final supplierId = performance['supplier_id']?.toString() ?? '';
    final supplierName = performance['supplier_name']?.toString() ?? 'Unknown';
    final rating = (performance['overall_rating'] as num?)?.toDouble() ?? 0;
    final grade = performance['rating_grade']?.toString() ?? 'N/A';
    final onTimeRate = (performance['on_time_delivery_rate'] as num?)?.toDouble() ?? 0;
    final qualityScore = (performance['quality_score'] as num?)?.toDouble() ?? 0;
    final responseTime = (performance['average_response_time_days'] as num?)?.toDouble() ?? 0;

    Color gradeColor = Colors.grey;
    if (grade == 'A') {
      gradeColor = Colors.green;
    } else if (grade == 'B') {
      gradeColor = Colors.blue;
    } else if (grade == 'C') {
      gradeColor = Colors.orange;
    } else if (grade == 'D') {
      gradeColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showDetailDialog(supplierId, supplierName),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with rank
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: gradeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: gradeColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplierName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: $supplierId',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Grade badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: gradeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          grade,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: gradeColor,
                          ),
                        ),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            color: gradeColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricBadge(
                    label: 'ส่งตรงเวลา',
                    value: '${onTimeRate.toStringAsFixed(0)}%',
                    color: onTimeRate >= 90 ? Colors.green : Colors.orange,
                  ),
                  _buildMetricBadge(
                    label: 'คุณภาพ',
                    value: '${qualityScore.toStringAsFixed(0)}%',
                    color: qualityScore >= 95 ? Colors.green : Colors.orange,
                  ),
                  _buildMetricBadge(
                    label: 'เวลา',
                    value: '${responseTime.toStringAsFixed(0)}d',
                    color: responseTime <= 7 ? Colors.green : Colors.orange,
                  ),
                ],
              ),

              // Progress bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rating / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppDesignSystem.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _showDetailDialog(String supplierId, String supplierName) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SupplierPerformanceWidget(
          supplierId: supplierId,
          supplierName: supplierName,
          monthsBack: _monthsBack,
        ),
      ),
    );
  }
}
