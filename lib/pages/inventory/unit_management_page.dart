import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../services/inventory_service.dart';
import '../../theme/app_design_system.dart';

class UnitManagementPage extends StatefulWidget {
  const UnitManagementPage({super.key});

  @override
  State<UnitManagementPage> createState() => _UnitManagementPageState();
}

class _UnitManagementPageState extends State<UnitManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _units = [];
  Map<String, int> _usageCounts = {};
  bool _isLoading = true;
  String? _errorMessage;

  Color get _surface => AppDesignSystem.surface;
  Color get _surfaceAlt => AppDesignSystem.background;
  Color get _textPrimary => AppDesignSystem.textPrimary;
  Color get _textSecondary => AppDesignSystem.textSecondary;
  Color get _borderColor => AppDesignSystem.border;
  Color get _primaryColor => AppDesignSystem.primary;
  Color get _secondaryColor => AppDesignSystem.secondary;
  Color get _successColor => AppDesignSystem.success;
  Color get _warningColor => AppDesignSystem.warning;
  Color get _dangerColor => AppDesignSystem.danger;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final unitsResponse = await InventoryService.getUnits();
      final usageCountsResponse = await InventoryService.getUnitUsageSummary();

      final units = List<Map<String, dynamic>>.from(unitsResponse);
      final usageCounts = Map<String, int>.from(usageCountsResponse);

      units.sort((a, b) {
        final aId = a['id']?.toString() ?? '';
        final bId = b['id']?.toString() ?? '';
        final aCount = usageCounts[aId] ?? 0;
        final bCount = usageCounts[bId] ?? 0;
        if (aCount != bCount) {
          return bCount.compareTo(aCount);
        }
        return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
      });

      if (!mounted) return;
      setState(() {
        _units = units;
        _usageCounts = usageCounts;
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

  List<Map<String, dynamic>> get _filteredUnits {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return List<Map<String, dynamic>>.from(_units);
    }
    return _units.where((unit) {
      final name = unit['name']?.toString().toLowerCase() ?? '';
      final abbreviation = unit['abbreviation']?.toString().toLowerCase() ?? '';
      return name.contains(query) || abbreviation.contains(query);
    }).toList();
  }

  int get _usedUnitsCount => _units.where((unit) => (_usageCounts[unit['id']?.toString() ?? ''] ?? 0) > 0).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _surfaceAlt,
        body: _buildLoadingShimmer(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: _surfaceAlt,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: _dangerColor),
                const SizedBox(height: 8),
                Text(_errorMessage!, style: TextStyle(color: _dangerColor), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _loadData, child: const Text('ลองใหม่')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surfaceAlt,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideBanner(),
                const SizedBox(height: AppDesignSystem.spacingLg),
                _buildActionRow(),
                const SizedBox(height: AppDesignSystem.spacingMd),
                _buildSearchCard(),
                const SizedBox(height: AppDesignSystem.spacingLg),
                _buildSummaryCards(),
                const SizedBox(height: AppDesignSystem.spacingLg),
                _buildUnitsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return SafeArea(
      child: Container(
        color: _surfaceAlt,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  children: [
                    Container(height: 92, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd))),
                    const SizedBox(height: AppDesignSystem.spacingMd),
                    Container(height: 64, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd))),
                  ],
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingLg),
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingMd),
                      child: Container(
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.straighten, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จัดการหน่วยนับกลาง', style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'ใช้หน่วยนับชุดเดียวร่วมกันทั้งหน้าเพิ่มสินค้าและหน้าเพิ่มวัตถุดิบ โดยหน่วยที่กำลังถูกใช้งานจะไม่สามารถลบได้',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'หน่วยนับทั้งหมด (${_units.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showUnitFormDialog,
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มหน่วยนับ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ค้นหาชื่อหน่วย / ตัวย่อ...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm)),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final unusedUnitsCount = _units.length - _usedUnitsCount;
    final totalUsage = _usageCounts.values.fold<int>(0, (sum, value) => sum + value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('สรุปการใช้งาน', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDesignSystem.spacingMd),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ทั้งหมด', '${_units.length}', _primaryColor, Icons.inventory_2)),
            const SizedBox(width: AppDesignSystem.spacingSm),
            Expanded(child: _buildSummaryCard('ถูกใช้งาน', '$_usedUnitsCount', _successColor, Icons.check_circle)),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingSm),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('ยังไม่ถูกใช้', '$unusedUnitsCount', _warningColor, Icons.info)),
            const SizedBox(width: AppDesignSystem.spacingSm),
            Expanded(child: _buildSummaryCard('การอ้างอิงทั้งหมด', '$totalUsage', _secondaryColor, Icons.link)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: _textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsList() {
    final units = _filteredUnits;

    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        side: const BorderSide(color: AppDesignSystem.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: _textSecondary),
                const SizedBox(width: 8),
                Text('รายการหน่วยนับ (${units.length})', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingMd),
            if (units.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('ไม่พบหน่วยนับ', style: TextStyle(color: _textSecondary)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: units.length,
                separatorBuilder: (_, __) => const Divider(height: AppDesignSystem.spacingLg),
                itemBuilder: (context, index) {
                  final unit = units[index];
                  return _buildUnitItem(unit);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitItem(Map<String, dynamic> unit) {
    final unitId = unit['id']?.toString() ?? '';
    final usageCount = _usageCounts[unitId] ?? 0;
    final isUsed = usageCount > 0;
    final name = unit['name']?.toString() ?? '-';
    final abbreviation = unit['abbreviation']?.toString() ?? '-';

    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingSm),
      decoration: BoxDecoration(
        color: isUsed ? _successColor.withOpacity(0.06) : _surfaceAlt,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        border: Border.all(color: isUsed ? _successColor.withOpacity(0.18) : _borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isUsed ? _successColor.withOpacity(0.15) : _secondaryColor.withOpacity(0.15),
            child: Icon(Icons.straighten, color: isUsed ? _successColor : _secondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUsed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _successColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ใช้งานอยู่ $usageCount',
                          style: TextStyle(color: _successColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _warningColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ยังไม่ถูกใช้',
                          style: TextStyle(color: _warningColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('ตัวย่อ: $abbreviation', style: TextStyle(color: _textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _showUnitFormDialog(unit: unit),
            icon: Icon(Icons.edit, color: _secondaryColor),
          ),
          IconButton(
            tooltip: isUsed ? 'หน่วยนับนี้กำลังถูกใช้งาน' : 'ลบ',
            onPressed: isUsed ? null : () => _confirmDeleteUnit(unit),
            icon: Icon(Icons.delete, color: isUsed ? Colors.grey : _dangerColor),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnitFormDialog({Map<String, dynamic>? unit}) async {
    final isEdit = unit != null;
    final nameController = TextEditingController(text: unit?['name']?.toString() ?? '');
    final abbreviationController = TextEditingController(text: unit?['abbreviation']?.toString() ?? '');
    bool isSaving = false;
    final pageNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(isEdit ? Icons.edit : Icons.add, color: _primaryColor),
              const SizedBox(width: 8),
              Text(isEdit ? 'แก้ไขหน่วยนับ' : 'เพิ่มหน่วยนับ'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อหน่วยนับ *',
                    border: OutlineInputBorder(),
                    hintText: 'เช่น ชิ้น, กิโลกรัม, ลิตร',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: abbreviationController,
                  decoration: const InputDecoration(
                    labelText: 'ตัวย่อ',
                    border: OutlineInputBorder(),
                    hintText: 'เช่น ชิ้น, กก., ลิตร',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ถ้าเว้นตัวย่อไว้ ระบบจะใช้ชื่อหน่วยนับแทน',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final abbreviation = abbreviationController.text.trim();
                      if (name.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('กรุณากรอกชื่อหน่วยนับ')),
                        );
                        return;
                      }

                      final duplicate = _units.any((item) {
                        final sameId = item['id']?.toString() == unit?['id']?.toString();
                        final sameName = item['name']?.toString().trim().toLowerCase() == name.toLowerCase();
                        return sameName && !sameId;
                      });
                      if (duplicate) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('ชื่อหน่วยนับนี้มีอยู่แล้ว')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final ok = isEdit
                          ? await InventoryService.updateUnit(
                              unitId: unit!['id'].toString(),
                              name: name,
                              abbreviation: abbreviation.isEmpty ? null : abbreviation,
                            )
                          : await InventoryService.addUnit(
                              name,
                              abbreviation: abbreviation.isEmpty ? null : abbreviation,
                            );

                      if (!mounted) return;
                      if (ok) {
                        pageNavigator.pop();
                        await _loadData();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'แก้ไขหน่วยนับสำเร็จ' : 'เพิ่มหน่วยนับสำเร็จ'),
                            backgroundColor: _successColor,
                          ),
                        );
                      } else {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'แก้ไขหน่วยนับไม่สำเร็จ' : 'เพิ่มหน่วยนับไม่สำเร็จ'),
                            backgroundColor: _dangerColor,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUnit(Map<String, dynamic> unit) async {
    final unitId = unit['id']?.toString() ?? '';
    final unitName = unit['name']?.toString() ?? '-';
    final usageCount = _usageCounts[unitId] ?? 0;
    final messenger = ScaffoldMessenger.of(context);

    if (usageCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('ลบไม่ได้ เพราะหน่วย "$unitName" ยังถูกใช้งานอยู่ $usageCount รายการ'),
          backgroundColor: _warningColor,
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบหน่วยนับ "$unitName" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _dangerColor, foregroundColor: Colors.white),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final ok = await InventoryService.deleteUnit(unitId);
    if (!mounted) return;
    if (ok) {
      await _loadData();
      messenger.showSnackBar(
        SnackBar(content: Text('ลบหน่วยนับ "$unitName" สำเร็จ'), backgroundColor: _successColor),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('ลบหน่วยนับ "$unitName" ไม่สำเร็จ'), backgroundColor: _dangerColor),
      );
    }
  }
}
