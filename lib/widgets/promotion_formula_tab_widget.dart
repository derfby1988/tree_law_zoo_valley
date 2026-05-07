import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_design_system.dart';
import '../models/promotion_formula_model.dart';
import '../services/promotion_formula_service.dart';
import '../utils/permission_helpers.dart';

/// Tab จัดการสูตร Priority Score
/// แยกออกมาเป็น widget เพื่อให้ maintain ง่าย
class PromotionFormulaTabWidget extends StatefulWidget {
  const PromotionFormulaTabWidget({super.key});

  @override
  State<PromotionFormulaTabWidget> createState() => _PromotionFormulaTabWidgetState();
}

class _PromotionFormulaTabWidgetState extends State<PromotionFormulaTabWidget> {
  // สถานะการโหลด
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // ข้อมูลสูตร
  List<PromotionFormulaConfig> _formulas = [];
  PromotionFormulaConfig? _selectedFormula;
  PromotionFormulaConfig? _editingFormula;

  // ประวัติการเปลี่ยนแปลง
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;

  // Controllers สำหรับฟอร์ม
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reasonController = TextEditingController(); // เหตุผลในการเปลี่ยนแปลง

  // Weights (น้ำหนักปัจจัย)
  double _weightMargin = 0.25;
  double _weightExpiry = 0.35;
  double _weightSeasonal = 0.20;
  double _weightFestival = 0.10;
  double _weightIngredient = 0.10;

  // Feature toggles
  bool _enableMargin = true;
  bool _enableExpiry = true;
  bool _enableSeasonal = true;
  bool _enableFestival = true;
  bool _enableIngredient = true;

  // Validity dates
  DateTime? _validFrom;
  DateTime? _validUntil;

  // โหมดการแก้ไข
  bool _isEditing = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // ============================================
  // Data Loading
  // ============================================

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔍 FormulaTab: Loading formulas...');
      final formulas = await PromotionFormulaService.getAllFormulas();
      debugPrint('✅ FormulaTab: Loaded ${formulas.length} formulas');
      if (formulas.isEmpty) {
        debugPrint('⚠️ FormulaTab: formulas list is empty!');
      }
      final activeFormula = await PromotionFormulaService.getActiveFormula();
      debugPrint('✅ FormulaTab: Active formula: ${activeFormula?.name ?? "none"}');

      setState(() {
        _formulas = formulas;
        _selectedFormula = activeFormula;
        _isLoading = false;
      });
      debugPrint('🔍 FormulaTab: Dropdown items: ${_formulas.map((f) => f.name).toList()}');

      // โหลดประวัติถ้ามีสูตรที่เลือก
      if (_selectedFormula != null) {
        _loadHistory(_selectedFormula!.id);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลสูตรได้: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHistory(String formulaId) async {
    setState(() => _isLoadingHistory = true);

    try {
      final history = await PromotionFormulaService.getFormulaHistory(formulaId, limit: 20);
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  // ============================================
  // UI Builders
  // ============================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: เลือกสูตรที่ใช้งาน
          _buildFormulaSelectorSection(),

          const SizedBox(height: 16),

          // Section 2: รายละเอียดสูตรที่เลือก
          if (_selectedFormula != null && !_isEditing && !_isCreating)
            _buildFormulaDetailsSection(),

          // Section 3: ฟอร์มแก้ไข/สร้าง
          if (_isEditing || _isCreating) _buildEditFormSection(),

          const SizedBox(height: 16),

          // Section 4: ประวัติการเปลี่ยนแปลง
          if (_selectedFormula != null && !_isCreating)
            _buildHistorySection(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // Section 1: Formula Selector
  // ============================================

  Widget _buildFormulaSelectorSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions, color: Color(0xFF2AD49B)),
              const SizedBox(width: 8),
              const Text(
                'สูตรที่ใช้งานอยู่',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // ปุ่มสร้างสูตรใหม่
              if (!_isEditing && !_isCreating)
                ElevatedButton.icon(
                  onPressed: () => checkPermissionAndExecute(
                    context,
                    'formula_create',
                    'สร้างสูตรใหม่',
                    _startCreating,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('สร้างสูตรใหม่'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AD49B),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Dropdown เลือกสูตร
          if (!_isEditing && !_isCreating) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedFormula?.id,
                  dropdownColor: const Color(0xFF1B1D28),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  hint: const Text(
                    'เลือกสูตร...',
                    style: TextStyle(color: Colors.white70),
                  ),
                  selectedItemBuilder: (context) {
                    return _formulas.map((formula) {
                      final isActive = formula.isActive;
                      return Text(
                        formula.name +
                            (isActive ? ' (ใช้งานอยู่)' : '') +
                            (formula.isDefault ? ' [ค่าเริ่มต้น]' : ''),
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    }).toList();
                  },
                  items: _formulas.map((formula) {
                    final isActive = formula.isActive;
                    final isExpired = formula.isExpired;
                    return DropdownMenuItem(
                      value: formula.id,
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.check_circle : Icons.circle_outlined,
                            color: isActive
                                ? const Color(0xFF2AD49B)
                                : isExpired
                                    ? Colors.red
                                    : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formula.name +
                                  (isActive ? ' (ใช้งานอยู่)' : '') +
                                  (formula.isDefault ? ' [ค่าเริ่มต้น]' : ''),
                              style: TextStyle(
                                color: isExpired ? Colors.red : Colors.white,
                                decoration: isExpired
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFormula =
                            _formulas.firstWhere((f) => f.id == value);
                      });
                      _loadHistory(value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ข้อมูลสรุปสูตรที่เลือก
            if (_selectedFormula != null)
              _buildFormulaSummaryCard(_selectedFormula!),
          ],
        ],
      ),
    );
  }

  Widget _buildFormulaSummaryCard(PromotionFormulaConfig formula) {
    final totalWeight = formula.totalWeight;
    final isWeightValid = formula.isWeightValid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formula.isActive
            ? const Color(0xFF2AD49B).withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: formula.isActive
              ? const Color(0xFF2AD49B)
              : Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(formula),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusText(formula),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (formula.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ค่าเริ่มต้น',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // แสดงช่วงเวลา (ใช้ Expanded เพื่อป้องกันล้น)
              if (formula.validFrom != null || formula.validUntil != null)
                Expanded(
                  child: Text(
                    '${_formatDate(formula.validFrom)} - ${_formatDate(formula.validUntil) ?? 'ไม่จำกัด'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // น้ำหนักรวม
          Row(
            children: [
              Icon(
                isWeightValid ? Icons.check_circle : Icons.warning,
                color: isWeightValid ? const Color(0xFF2AD49B) : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'น้ำหนักรวม: ${(totalWeight * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: isWeightValid ? Colors.white : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isWeightValid)
                Text(
                  ' (ควรเป็น 100%)',
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ปุ่มจัดการ
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!formula.isActive)
                ElevatedButton.icon(
                  onPressed: () => checkPermissionAndExecute(
                    context,
                    'formula_activate',
                    'เปิดใช้งานสูตร',
                    () => _activateFormula(formula.id),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('เปิดใช้งาน'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AD49B),
                    foregroundColor: Colors.white,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => checkPermissionAndExecute(
                  context,
                  'formula_edit',
                  'แก้ไขสูตร',
                  () => _startEditing(formula),
                ),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('แก้ไข'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
              if (!formula.isActive && !formula.isDefault)
                OutlinedButton.icon(
                  onPressed: () => checkPermissionAndExecute(
                    context,
                    'formula_delete',
                    'ลบสูตร',
                    () => _deleteFormula(formula.id),
                  ),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('ลบ', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // Section 2: Formula Details (Read-only)
  // ============================================

  Widget _buildFormulaDetailsSection() {
    final formula = _selectedFormula!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ส่วนที่ 1: น้ำหนักปัจจัย
          _buildWeightsDisplay(formula),

          const SizedBox(height: 24),

          // ส่วนที่ 2: เกณฑ์คะแนน
          _buildThresholdsDisplay(formula),

          const SizedBox(height: 24),

          // ส่วนที่ 3: เกณฑ์ส่วนลด
          _buildDiscountRangesDisplay(formula),
        ],
      ),
    );
  }

  Widget _buildWeightsDisplay(PromotionFormulaConfig formula) {
    final weights = [
      ('กำไรสินค้า', formula.weightMargin, _getWeightColor(formula.weightMargin)),
      ('ใกล้หมดอายุ', formula.weightExpiry, _getWeightColor(formula.weightExpiry)),
      ('ฤดูกาล', formula.weightSeasonal, _getWeightColor(formula.weightSeasonal)),
      ('เทศกาล', formula.weightFestival, _getWeightColor(formula.weightFestival)),
      ('วัตถุดิบใกล้หมด', formula.weightIngredientExpiry, _getWeightColor(formula.weightIngredientExpiry)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.scale, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Text(
              'น้ำหนักปัจจัย',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...weights.map((w) {
          final label = w.$1;
          final weight = w.$2;
          final color = w.$3;
          final isEnabled = formula.enabledCriteria.contains(_getCriterionKey(label));

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // ไอคอน enabled/disabled
                Icon(
                  isEnabled ? Icons.check_circle : Icons.cancel,
                  color: isEnabled ? const Color(0xFF2AD49B) : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),

                // Label
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),

                // Progress bar
                Expanded(
                  child: LinearProgressIndicator(
                    value: weight,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isEnabled ? color : Colors.grey,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                const SizedBox(width: 12),

                // Percentage
                Text(
                  '${(weight * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isEnabled ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildThresholdsDisplay(PromotionFormulaConfig formula) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sort, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Text(
              'เกณฑ์คะแนน',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // กำไร
        _buildThresholdCard(
          'กำไรสินค้า',
          formula.marginThresholds,
          (t) => '≥${t['min_margin_pct']}% = ${t['score']} คะแนน',
          Icons.trending_up,
          Colors.green,
        ),

        const SizedBox(height: 8),

        // หมดอายุ
        _buildThresholdCard(
          'ใกล้หมดอายุ',
          formula.expiryThresholds,
          (t) {
            final days = t['days_remaining'];
            if (days == 0) return 'หมดแล้ว = ${t['score']} คะแนน';
            return 'เหลือ ≤$days วัน = ${t['score']} คะแนน';
          },
          Icons.timer,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildThresholdCard(
    String title,
    Map<String, dynamic> thresholds,
    String Function(Map<String, dynamic>) formatter,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...thresholds.entries.map((e) {
            final threshold = e.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 4),
              child: Text(
                '• ${formatter(threshold)} (${threshold['label']})',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDiscountRangesDisplay(PromotionFormulaConfig formula) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_offer, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Text(
              'เกณฑ์ส่วนลดที่แนะนำ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: formula.discountRanges.map((range) {
            final color = Color(
              int.parse((range['color'] as String).replaceFirst('#', '0xFF')),
            );
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${range['min_score']}-${range['max_score']} คะแนน',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${range['discount_min_pct']}-${range['discount_max_pct']}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    range['label'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================
  // Section 3: Edit Form
  // ============================================

  Widget _buildEditFormSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2AD49B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCreating ? Icons.add_circle : Icons.edit,
                color: const Color(0xFF2AD49B),
              ),
              const SizedBox(width: 8),
              Text(
                _isCreating ? 'สร้างสูตรใหม่' : 'แก้ไขสูตร',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _cancelEditing,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ชื่อสูตร
          _buildTextField(
            label: 'ชื่อสูตร',
            controller: _nameController,
            hint: 'เช่น สูตรมาตรฐาน 2568',
          ),

          const SizedBox(height: 12),

          // รายละเอียด
          _buildTextField(
            label: 'รายละเอียด',
            controller: _descriptionController,
            hint: 'อธิบายสูตรนี้...',
            maxLines: 2,
          ),

          const SizedBox(height: 20),

          // ช่วงเวลาใช้งาน
          _buildValidityDateSection(),

          const SizedBox(height: 20),

          // น้ำหนักปัจจัย (Sliders)
          _buildWeightSlidersSection(),

          const SizedBox(height: 20),

          // เปิด/ปิดปัจจัย (Toggles)
          _buildCriteriaTogglesSection(),

          const SizedBox(height: 20),

          // เหตุผลการเปลี่ยนแปลง (สำหรับ history)
          _buildTextField(
            label: 'เหตุผลในการ${_isCreating ? 'สร้าง' : 'แก้ไข'} (สำหรับประวัติ)',
            controller: _reasonController,
            hint: 'เช่น ปรับสูตรตามฤดูกาลใหม่',
          ),

          const SizedBox(height: 24),

          // ปุ่มบันทึก/ยกเลิก
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveFormula,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isCreating ? 'สร้างสูตร' : 'บันทึกการเปลี่ยนแปลง'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AD49B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _isSaving ? null : _cancelEditing,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
                child: const Text('ยกเลิก'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValidityDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ช่วงเวลาใช้งาน',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Valid From
            Expanded(
              child: _buildDatePicker(
                label: 'เริ่มใช้งาน',
                value: _validFrom,
                onTap: () => _pickDate(context, true),
                onClear: () => setState(() => _validFrom = null),
              ),
            ),
            const SizedBox(width: 16),

            // Valid Until
            Expanded(
              child: _buildDatePicker(
                label: 'สิ้นสุด (เว้นว่าง = ไม่จำกัด)',
                value: _validUntil,
                onTap: () => _pickDate(context, false),
                onClear: () => setState(() => _validUntil = null),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.day}/${value.month}/${value.year + 543}'
                        : 'เลือกวันที่...',
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightSlidersSection() {
    final totalWeight = _weightMargin +
        _weightExpiry +
        _weightSeasonal +
        _weightFestival +
        _weightIngredient;
    final isValid = (totalWeight - 1.0).abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'น้ำหนักปัจจัย',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(รวม: ${(totalWeight * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                color: isValid ? const Color(0xFF2AD49B) : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (!isValid)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '⚠️ น้ำหนักรวมต้องเป็น 100%',
              style: TextStyle(
                color: Colors.orange.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 12),

        _buildWeightSlider(
          label: 'กำไรสินค้า',
          value: _weightMargin,
          color: Colors.green,
          onChanged: (v) => setState(() => _weightMargin = v),
        ),
        _buildWeightSlider(
          label: 'ใกล้หมดอายุ',
          value: _weightExpiry,
          color: Colors.red,
          onChanged: (v) => setState(() => _weightExpiry = v),
        ),
        _buildWeightSlider(
          label: 'ฤดูกาล',
          value: _weightSeasonal,
          color: Colors.blue,
          onChanged: (v) => setState(() => _weightSeasonal = v),
        ),
        _buildWeightSlider(
          label: 'เทศกาล',
          value: _weightFestival,
          color: Colors.purple,
          onChanged: (v) => setState(() => _weightFestival = v),
        ),
        _buildWeightSlider(
          label: 'วัตถุดิบใกล้หมด',
          value: _weightIngredient,
          color: Colors.orange,
          onChanged: (v) => setState(() => _weightIngredient = v),
        ),

        const SizedBox(height: 8),

        // ปุ่มรีเซ็ตค่าเริ่มต้น
        TextButton.icon(
          onPressed: _resetWeightsToDefault,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('รีเซ็ตเป็นค่าเริ่มต้น'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildWeightSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                thumbColor: color,
                overlayColor: color.withOpacity(0.2),
                valueIndicatorColor: color,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 1,
                divisions: 20,
                label: '${(value * 100).toStringAsFixed(0)}%',
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaTogglesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เปิด/ปิดการใช้งานปัจจัย',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildToggleChip('กำไรสินค้า', _enableMargin, (v) => setState(() => _enableMargin = v)),
            _buildToggleChip('ใกล้หมดอายุ', _enableExpiry, (v) => setState(() => _enableExpiry = v)),
            _buildToggleChip('ฤดูกาล', _enableSeasonal, (v) => setState(() => _enableSeasonal = v)),
            _buildToggleChip('เทศกาล', _enableFestival, (v) => setState(() => _enableFestival = v)),
            _buildToggleChip('วัตถุดิบใกล้หมด', _enableIngredient, (v) => setState(() => _enableIngredient = v)),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: const Color(0xFF2AD49B).withOpacity(0.3),
      checkmarkColor: const Color(0xFF2AD49B),
      labelStyle: TextStyle(
        color: value ? Colors.white : Colors.white.withOpacity(0.7),
      ),
      backgroundColor: Colors.white.withOpacity(0.1),
    );
  }

  // ============================================
  // Section 4: History
  // ============================================

  Widget _buildHistorySection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white70),
              const SizedBox(width: 8),
              const Text(
                'ประวัติการเปลี่ยนแปลง',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isLoadingHistory)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_history.isEmpty && !_isLoadingHistory)
            Text(
              'ยังไม่มีประวัติการเปลี่ยนแปลง',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            )
          else
            ..._history.take(10).map((h) {
              final changeType = h['change_type'] as String;
              final changedAt = DateTime.parse(h['changed_at'] as String);
              final changedBy = h['changed_by']?['email'] as String? ?? 'ไม่ระบุ';
              final reason = h['reason'] as String?;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildChangeTypeBadge(changeType),
                        const SizedBox(width: 8),
                        Text(
                          '${changedAt.day}/${changedAt.month}/${changedAt.year + 543} ${changedAt.hour}:${changedAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'โดย: $changedBy',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                    if (reason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'เหตุผล: $reason',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildChangeTypeBadge(String type) {
    final Map<String, (String, Color)> types = {
      'created': ('สร้างใหม่', Colors.green),
      'updated': ('แก้ไข', Colors.blue),
      'activated': ('เปิดใช้งาน', const Color(0xFF2AD49B)),
      'deactivated': ('ปิดใช้งาน', Colors.orange),
      'deleted': ('ลบ', Colors.red),
    };

    final (label, color) = types[type] ?? ('อื่นๆ', Colors.grey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================
  // Actions
  // ============================================

  void _startCreating() {
    setState(() {
      _isCreating = true;
      _isEditing = false;
      _editingFormula = null;
      _nameController.clear();
      _descriptionController.clear();
      _reasonController.clear();
      _resetWeightsToDefault();
      _validFrom = DateTime.now();
      _validUntil = null;
    });
  }

  void _startEditing(PromotionFormulaConfig formula) {
    setState(() {
      _isCreating = false;
      _isEditing = true;
      _editingFormula = formula;
      _nameController.text = formula.name;
      _descriptionController.text = formula.description ?? '';
      _reasonController.clear();
      _weightMargin = formula.weightMargin;
      _weightExpiry = formula.weightExpiry;
      _weightSeasonal = formula.weightSeasonal;
      _weightFestival = formula.weightFestival;
      _weightIngredient = formula.weightIngredientExpiry;
      _enableMargin = formula.enabledCriteria.contains('margin');
      _enableExpiry = formula.enabledCriteria.contains('expiry');
      _enableSeasonal = formula.enabledCriteria.contains('seasonal');
      _enableFestival = formula.enabledCriteria.contains('festival');
      _enableIngredient = formula.enabledCriteria.contains('ingredient');
      _validFrom = formula.validFrom;
      _validUntil = formula.validUntil;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isCreating = false;
      _isEditing = false;
      _editingFormula = null;
    });
  }

  void _resetWeightsToDefault() {
    setState(() {
      _weightMargin = 0.25;
      _weightExpiry = 0.35;
      _weightSeasonal = 0.20;
      _weightFestival = 0.10;
      _weightIngredient = 0.10;
    });
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_validFrom ?? DateTime.now()) : (_validUntil ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2AD49B),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1D28),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _validFrom = picked;
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _saveFormula() async {
    // Validate
    final totalWeight = _weightMargin +
        _weightExpiry +
        _weightSeasonal +
        _weightFestival +
        _weightIngredient;

    if ((totalWeight - 1.0).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('น้ำหนักรวมต้องเป็น 100%'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุชื่อสูตร'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final weights = {
        'margin': _weightMargin,
        'expiry': _weightExpiry,
        'seasonal': _weightSeasonal,
        'festival': _weightFestival,
        'ingredient': _weightIngredient,
      };

      final enabledCriteria = <String>[];
      if (_enableMargin) enabledCriteria.add('margin');
      if (_enableExpiry) enabledCriteria.add('expiry');
      if (_enableSeasonal) enabledCriteria.add('seasonal');
      if (_enableFestival) enabledCriteria.add('festival');
      if (_enableIngredient) enabledCriteria.add('ingredient');

      if (_isCreating) {
        await PromotionFormulaService.createFormula(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          weights: weights,
          enabledCriteria: enabledCriteria,
          validFrom: _validFrom,
          validUntil: _validUntil,
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        );
      } else {
        await PromotionFormulaService.updateFormula(
          id: _editingFormula!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          weights: weights,
          enabledCriteria: enabledCriteria,
          validFrom: _validFrom,
          validUntil: _validUntil,
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCreating ? 'สร้างสูตรสำเร็จ' : 'บันทึกการเปลี่ยนแปลงสำเร็จ'),
          backgroundColor: const Color(0xFF2AD49B),
        ),
      );

      _cancelEditing();
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถบันทึกได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _activateFormula(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D28),
        title: const Text('ยืนยันการเปิดใช้งาน', style: TextStyle(color: Colors.white)),
        content: const Text(
          'การเปิดใช้งานสูตรนี้จะปิดสูตรอื่นที่กำลังใช้งานอยู่\nคุณต้องการดำเนินการต่อหรือไม่?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2AD49B)),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await PromotionFormulaService.activateFormula(
        id,
        reason: 'เปิดใช้งานจากหน้าจัดการสูตร',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เปิดใช้งานสูตรสำเร็จ'),
          backgroundColor: Color(0xFF2AD49B),
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเปิดใช้งานได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFormula(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D28),
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.white)),
        content: const Text(
          'การลบสูตรไม่สามารถเรียกคืนได้\nคุณต้องการดำเนินการต่อหรือไม่?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await PromotionFormulaService.deleteFormula(id, reason: 'ลบจากหน้าจัดการสูตร');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบสูตรสำเร็จ'),
          backgroundColor: Color(0xFF2AD49B),
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถลบได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================
  // Helpers
  // ============================================

  String _getCriterionKey(String label) {
    switch (label) {
      case 'กำไรสินค้า':
        return 'margin';
      case 'ใกล้หมดอายุ':
        return 'expiry';
      case 'ฤดูกาล':
        return 'seasonal';
      case 'เทศกาล':
        return 'festival';
      case 'วัตถุดิบใกล้หมด':
        return 'ingredient';
      default:
        return '';
    }
  }

  Color _getWeightColor(double weight) {
    if (weight >= 0.3) return Colors.red;
    if (weight >= 0.2) return Colors.orange;
    return Colors.blue;
  }

  String _getStatusText(PromotionFormulaConfig formula) {
    if (formula.isActive) return 'ใช้งานอยู่';
    if (formula.isExpired) return 'หมดอายุแล้ว';
    return 'ไม่ใช้งาน';
  }

  Color _getStatusColor(PromotionFormulaConfig formula) {
    if (formula.isActive) return const Color(0xFF2AD49B);
    if (formula.isExpired) return Colors.red;
    return Colors.grey;
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.day}/${date.month}/${date.year + 543}';
  }
}
