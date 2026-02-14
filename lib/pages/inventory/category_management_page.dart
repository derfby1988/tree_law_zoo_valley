import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';

class CategoryManagementPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialCategories;
  final List<Map<String, dynamic>> initialProducts;
  final List<Map<String, dynamic>> assetAccounts;
  final List<Map<String, dynamic>> revenueAccounts;
  final List<Map<String, dynamic>> costAccounts;

  const CategoryManagementPage({
    super.key,
    required this.initialCategories,
    required this.initialProducts,
    required this.assetAccounts,
    required this.revenueAccounts,
    required this.costAccounts,
  });

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  late List<Map<String, dynamic>> _categories;
  final TextEditingController _newCatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _newInventoryAccount;
  String? _newRevenueAccount;
  String? _newCostAccount;
  String? _selectedParentCode;
  bool _isLoading = false;

  static const Map<String, String> _recommendedAccountCodes = {
    'asset': '1301',
    'revenue': '4101',
    'cogs': '5101',
  };

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.initialCategories);
    _setDefaults();
  }

  void _setDefaults() {
    _newInventoryAccount = _getDefaultAccountCode(widget.assetAccounts, 'asset');
    _newRevenueAccount = _getDefaultAccountCode(widget.revenueAccounts, 'revenue');
    _newCostAccount = _getDefaultAccountCode(widget.costAccounts, 'cogs');
  }

  @override
  void dispose() {
    _newCatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการประเภทสินค้า'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _categories),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGuideBanner(),
                  SizedBox(height: 24),
                  
                  // Add New Section
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('เพิ่มประเภทใหม่', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 16),
                          // Parent category selector
                          _buildParentCategorySelector(),
                          SizedBox(height: 12),
                          // Category name with autocomplete
                          _buildCategoryNameField(),
                          SizedBox(height: 16),
                          _buildDropdown('บัญชีสินค้าคงเหลือ (ไม่บังคับ)', 'เช่น 1301 สินค้าสำเร็จรูป', _newInventoryAccount, widget.assetAccounts, 'asset', (v) => setState(() => _newInventoryAccount = v)),
                          SizedBox(height: 12),
                          _buildDropdown('บัญชีรายได้ (ไม่บังคับ)', 'เช่น 4101 ขายสินค้า', _newRevenueAccount, widget.revenueAccounts, 'revenue', (v) => setState(() => _newRevenueAccount = v)),
                          SizedBox(height: 12),
                          _buildDropdown('บัญชีต้นทุน (ไม่บังคับ)', 'เช่น 5101 ซื้อสินค้า', _newCostAccount, widget.costAccounts, 'cogs', (v) => setState(() => _newCostAccount = v)),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleAddCategory,
                              icon: Icon(Icons.add),
                              label: Text('บันทึกประเภทใหม่'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  Divider(thickness: 1),
                  SizedBox(height: 8),
                  
                  // Warning: incomplete categories
                  if (_incompleteCategoriesCount > 0)
                    _buildIncompleteWarningBanner(),
                  
                  // Existing Categories List
                  Row(
                    children: [
                      Icon(Icons.list, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Text('ประเภทที่มีอยู่ (${_categories.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  if (_categories.isEmpty)
                    Center(child: Padding(padding: EdgeInsets.all(32), child: Text('ยังไม่มีประเภทสินค้า')))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        return _buildCategoryItem(_categories[index]);
                      },
                    ),
                  
                  SizedBox(height: 32), // Bottom padding
                ],
              ),
            ),
    );
  }

  int get _incompleteCategoriesCount => _categories.where((cat) =>
      cat['inventory_account_code'] == null ||
      cat['revenue_account_code'] == null ||
      cat['cost_account_code'] == null).length;

  Widget _buildIncompleteWarningBanner() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'มี $_incompleteCategoriesCount ประเภทที่ยังไม่ได้กำหนดบัญชี',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'กดปุ่มด้านล่างเพื่อตั้งค่าบัญชีมาตรฐาน (1301, 4101, 5101) ให้ทุกประเภทที่ยังไม่มี',
            style: TextStyle(fontSize: 13, color: Colors.orange[800]),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleBulkSetDefaults,
              icon: Icon(Icons.auto_fix_high),
              label: Text('ตั้งค่าบัญชีเริ่มต้นทั้งหมด ($_incompleteCategoriesCount รายการ)'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 10),
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkSetDefaults() async {
    final defaultInv = _getDefaultAccountCode(widget.assetAccounts, 'asset');
    final defaultRev = _getDefaultAccountCode(widget.revenueAccounts, 'revenue');
    final defaultCost = _getDefaultAccountCode(widget.costAccounts, 'cogs');

    if (defaultInv == null || defaultRev == null || defaultCost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่พบบัญชีเริ่มต้น กรุณาตรวจสอบผังบัญชี'), backgroundColor: Colors.red),
      );
      return;
    }

    final incomplete = _categories.where((cat) =>
        cat['inventory_account_code'] == null ||
        cat['revenue_account_code'] == null ||
        cat['cost_account_code'] == null).toList();

    if (incomplete.isEmpty) return;

    setState(() => _isLoading = true);

    int successCount = 0;
    int failCount = 0;

    for (final cat in incomplete) {
      final result = await InventoryService.updateCategory(cat['id'] as String, {
        'inventory_account_code': defaultInv,
        'revenue_account_code': defaultRev,
        'cost_account_code': defaultCost,
      });
      if (result != null) {
        successCount++;
      } else {
        failCount++;
        debugPrint('❌ Failed to update category: ${cat['name']}');
      }
    }

    if (!mounted) return;

    // Re-fetch from DB to verify
    final latest = await InventoryService.getCategories();
    debugPrint('📦 bulk update done: success=$successCount, fail=$failCount, total=${latest.length}');

    if (!mounted) return;

    setState(() {
      _categories = List<Map<String, dynamic>>.from(latest);
      _isLoading = false;
    });

    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ตั้งค่าบัญชีเริ่มต้นสำเร็จ $successCount รายการ (ยืนยันจากฐานข้อมูลแล้ว)'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สำเร็จ $successCount รายการ, ล้มเหลว $failCount รายการ'), backgroundColor: Colors.orange),
      );
    }
  }

  void _inheritAccountsFromParent(String? parentCode) {
    if (parentCode == null) {
      _setDefaults();
      return;
    }
    final parent = _categories.firstWhere(
      (c) => c['code'] == parentCode,
      orElse: () => <String, dynamic>{},
    );
    if (parent.isEmpty) {
      _setDefaults();
      return;
    }
    // Inherit accounts from parent
    final invCode = parent['inventory_account_code'] as String?;
    final revCode = parent['revenue_account_code'] as String?;
    final costCode = parent['cost_account_code'] as String?;

    setState(() {
      if (invCode != null && widget.assetAccounts.any((a) => a['code'] == invCode)) {
        _newInventoryAccount = invCode;
      }
      if (revCode != null && widget.revenueAccounts.any((a) => a['code'] == revCode)) {
        _newRevenueAccount = revCode;
      }
      if (costCode != null && widget.costAccounts.any((a) => a['code'] == costCode)) {
        _newCostAccount = costCode;
      }
    });
    debugPrint('📋 Inherited accounts from parent "$parentCode": inv=$invCode, rev=$revCode, cost=$costCode');
  }

  Widget _buildParentCategorySelector() {
    // Show categories that can be parents (level 1-4)
    final parentOptions = _categories.where((c) => (c['level'] as int? ?? 1) < 5).toList();
    final selectedParent = _selectedParentCode != null
        ? parentOptions.firstWhere((c) => c['code'] == _selectedParentCode, orElse: () => <String, dynamic>{})
        : null;
    final parentLabel = selectedParent != null && selectedParent.isNotEmpty
        ? '${selectedParent['code']} ${selectedParent['name']}'
        : 'ไม่มี (เป็นหมวดหลัก)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('หมวดหมู่แม่', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700])),
        SizedBox(height: 6),
        InkWell(
          onTap: () => _showParentPicker(),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, size: 20, color: Colors.teal),
                SizedBox(width: 8),
                Expanded(child: Text(parentLabel, style: TextStyle(fontSize: 14))),
                if (_selectedParentCode != null)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedParentCode = null);
                      _inheritAccountsFromParent(null);
                    },
                    child: Icon(Icons.clear, size: 18, color: Colors.grey),
                  )
                else
                  Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showParentPicker() {
    final parentOptions = _categories.where((c) => (c['level'] as int? ?? 1) < 5).toList();
    String searchText = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = searchText.isEmpty
                ? parentOptions
                : parentOptions.where((c) {
                    final name = (c['name'] as String? ?? '').toLowerCase();
                    final code = (c['code'] as String? ?? '').toLowerCase();
                    return name.contains(searchText.toLowerCase()) || code.contains(searchText.toLowerCase());
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (ctx, scrollCtrl) {
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_tree, color: Colors.teal),
                              SizedBox(width: 8),
                              Text('เลือกหมวดหมู่แม่', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 12),
                          TextField(
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'ค้นหาหมวดหมู่...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) => setSheetState(() => searchText = v),
                          ),
                        ],
                      ),
                    ),
                    // Option: no parent
                    ListTile(
                      leading: Icon(Icons.remove_circle_outline, color: Colors.grey),
                      title: Text('ไม่มี (เป็นหมวดหลัก)', style: TextStyle(color: Colors.grey[700])),
                      selected: _selectedParentCode == null,
                      onTap: () {
                        setState(() => _selectedParentCode = null);
                        _inheritAccountsFromParent(null);
                        Navigator.pop(ctx);
                      },
                    ),
                    Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final cat = filtered[i];
                          final level = (cat['level'] as int?) ?? 1;
                          final indent = (level - 1) * 16.0;
                          final isSelected = cat['code'] == _selectedParentCode;
                          final iconData = level <= 2 ? Icons.folder : Icons.folder_open;
                          final iconColor = level <= 2 ? Colors.blue : Colors.teal;

                          return ListTile(
                            contentPadding: EdgeInsets.only(left: 16 + indent, right: 16),
                            leading: Icon(iconData, size: 20, color: iconColor),
                            title: Text(
                              '${cat['code']}  ${cat['name']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: level <= 3 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: Colors.blue[50],
                            onTap: () {
                              final code = cat['code'] as String?;
                              setState(() => _selectedParentCode = code);
                              _inheritAccountsFromParent(code);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryNameField() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable.empty();
        final query = textEditingValue.text.toLowerCase();
        return _categories.where((cat) {
          final name = (cat['name'] as String? ?? '').toLowerCase();
          final code = (cat['code'] as String? ?? '').toLowerCase();
          return name.contains(query) || code.contains(query);
        }).take(8);
      },
      displayStringForOption: (cat) => cat['name'] as String? ?? '',
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 64),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final cat = options.elementAt(i);
                  final level = (cat['level'] as int?) ?? 1;
                  final indent = (level - 1) * 12.0;
                  return InkWell(
                    onTap: () => onSelected(cat),
                    child: Padding(
                      padding: EdgeInsets.only(left: 12 + indent, right: 12, top: 10, bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            level <= 2 ? Icons.folder : (level <= 4 ? Icons.folder_open : Icons.label_outline),
                            size: 16,
                            color: level <= 2 ? Colors.blue : Colors.teal,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${cat['code']}  ${cat['name']}',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          Text('Lv.${cat['level']}', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (cat) {
        // When user selects an existing category, set it as parent
        final code = cat['code'] as String?;
        setState(() => _selectedParentCode = code);
        _inheritAccountsFromParent(code);
        _newCatController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เลือก "${cat['name']}" เป็นหมวดหมู่แม่แล้ว กรุณาพิมพ์ชื่อประเภทย่อยใหม่'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 2),
          ),
        );
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sync with _newCatController
        _newCatController.addListener(() {
          if (textController.text != _newCatController.text) {
            textController.text = _newCatController.text;
          }
        });
        textController.addListener(() {
          if (_newCatController.text != textController.text) {
            _newCatController.text = textController.text;
          }
        });
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'ชื่อประเภทใหม่ *',
            hintText: 'พิมพ์เพื่อค้นหาหรือเพิ่มใหม่',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
            suffixIcon: textController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18),
                    onPressed: () {
                      textController.clear();
                      _newCatController.clear();
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildGuideBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Colors.green[700], size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('โหมดมือใหม่', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
                SizedBox(height: 4),
                Text(
                  'กรอกชื่อแล้วกดบันทึกได้เลย ไม่จำเป็นต้องเลือกบัญชี — สามารถตั้งค่าบัญชีทีหลังได้ หรือเลือก "ไม่ระบุ" เพื่อข้าม',
                  style: TextStyle(fontSize: 13, color: Colors.green[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String helper, String? value, List<Map<String, dynamic>> items, String type, ValueChanged<String?> onChanged) {
    // Ensure value exists in items, otherwise reset to null
    final validValue = (value != null && items.any((a) => a['code'] == value)) ? value : null;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label, 
        helperText: helper, 
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      value: validValue,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('— ไม่ระบุ (ตั้งค่าทีหลัง)', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
        ),
        ...items.map((acc) => DropdownMenuItem<String>(
          value: acc['code'] as String?,
          child: Text(
            '${acc['code']} - ${acc['name_th']}${(acc['code'] as String?) == _recommendedAccountCodes[type] ? ' ★' : ''}',
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      onChanged: (v) => onChanged(v),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> cat) {
    final level = (cat['level'] as int?) ?? 1;
    final code = cat['code'] as String? ?? '';
    final name = cat['name'] as String? ?? '';
    final indent = (level - 1) * 16.0;

    // Style based on level
    final isHeader = level <= 2;
    final fontSize = isHeader ? 15.0 : (level == 3 ? 14.0 : 13.0);
    final fontWeight = level <= 3 ? FontWeight.bold : FontWeight.normal;
    final bgColor = level == 1 ? Colors.blue[50] : (level == 2 ? Colors.grey[50] : null);
    final iconData = level <= 2 ? Icons.folder : (level <= 4 ? Icons.folder_open : Icons.label_outline);
    final iconColor = level <= 2 ? Colors.blue : (level <= 3 ? Colors.teal : Colors.grey[600]);

    return Container(
      key: ValueKey(cat['id']),
      margin: EdgeInsets.only(bottom: 1),
      padding: EdgeInsets.only(left: indent, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(iconData, size: 18, color: iconColor),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$code  $name',
                  style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 16, color: Colors.blue[300]),
            onPressed: () => _showEditDialog(cat),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String? _generateNextCode() {
    if (_selectedParentCode == null) {
      // Root level - find next root code
      final rootCats = _categories.where((c) => c['parent_code'] == null && c['code'] != null).toList();
      final maxNum = rootCats.fold<int>(0, (max, c) {
        final code = c['code'] as String? ?? '';
        final parts = code.split('-');
        if (parts.isNotEmpty) {
          final n = int.tryParse(parts[0]) ?? 0;
          return n > max ? n : max;
        }
        return max;
      });
      return '${maxNum + 1}-0-00-00-00';
    }

    // Find parent and its children
    final parent = _categories.firstWhere(
      (c) => c['code'] == _selectedParentCode,
      orElse: () => <String, dynamic>{},
    );
    if (parent.isEmpty) return null;

    final parentCode = parent['code'] as String;
    final parentLevel = (parent['level'] as int?) ?? 1;
    final childLevel = parentLevel + 1;

    // Find existing children of this parent
    final children = _categories.where((c) => c['parent_code'] == parentCode).toList();

    // Parse parent code parts
    final parts = parentCode.split('-');
    if (parts.length != 5) return null;

    // Find the max child number at the appropriate position
    int maxChildNum = 0;
    for (final child in children) {
      final childCode = child['code'] as String? ?? '';
      final childParts = childCode.split('-');
      if (childParts.length == 5) {
        final n = int.tryParse(childParts[childLevel - 1]) ?? 0;
        if (n > maxChildNum) maxChildNum = n;
      }
    }

    // Generate new code
    final newParts = List<String>.from(parts);
    final nextNum = maxChildNum + 1;
    newParts[childLevel - 1] = nextNum < 10 ? '0$nextNum' : '$nextNum';
    // Zero out lower levels
    for (int i = childLevel; i < 5; i++) {
      newParts[i] = '00';
    }
    return newParts.join('-');
  }

  Future<void> _handleAddCategory() async {
    if (_newCatController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('กรุณากรอกชื่อประเภท')));
      return;
    }

    setState(() => _isLoading = true);
    
    final createdName = _newCatController.text.trim();

    // Calculate level and code based on parent
    int newLevel = 1;
    if (_selectedParentCode != null) {
      final parent = _categories.firstWhere(
        (c) => c['code'] == _selectedParentCode,
        orElse: () => <String, dynamic>{},
      );
      if (parent.isNotEmpty) {
        newLevel = ((parent['level'] as int?) ?? 1) + 1;
      }
    }

    final newCode = _generateNextCode();
    final maxSortOrder = _categories.fold<int>(0, (max, c) {
      final so = (c['sort_order'] as int?) ?? 0;
      return so > max ? so : max;
    });

    debugPrint('📦 addCategory: name=$createdName, parent=$_selectedParentCode, level=$newLevel, code=$newCode');
    
    final insertedRow = await InventoryService.addCategory(
      createdName,
      inventoryAccountCode: _newInventoryAccount,
      revenueAccountCode: _newRevenueAccount,
      costAccountCode: _newCostAccount,
      code: newCode,
      parentCode: _selectedParentCode,
      level: newLevel,
      sortOrder: maxSortOrder + 1,
    );
    debugPrint('📦 addCategory insertedRow: $insertedRow');

    if (!mounted) return;

    if (insertedRow == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มประเภทไม่สำเร็จ (ไม่ได้รับข้อมูลจากฐานข้อมูล)'), backgroundColor: Colors.red));
      return;
    }

    final latest = await InventoryService.getCategories();
    debugPrint('📦 after add, getCategories returned ${latest.length} items');

    if (!mounted) return;

    final verified = latest.any((c) => c['id'] == insertedRow['id']);

    if (verified) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(latest);
        _isLoading = false;
        _selectedParentCode = null;
      });
      _newCatController.clear();
      _setDefaults();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มประเภท "$createdName" สำเร็จ (รหัส: $newCode)'), backgroundColor: Colors.green));
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มประเภทไม่สำเร็จ (ไม่พบข้อมูลในฐานข้อมูล)'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> cat) async {
    final updatedRow = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _EditCategoryDialog(
        category: cat,
        assetAccounts: widget.assetAccounts,
        revenueAccounts: widget.revenueAccounts,
        costAccounts: widget.costAccounts,
      ),
    );

    if (updatedRow == null || !mounted) return;

    // DB confirmed the update, now re-fetch to verify
    setState(() => _isLoading = true);
    final latest = await InventoryService.getCategories();
    debugPrint('📦 after edit, getCategories returned ${latest.length} items');

    if (!mounted) return;

    final verified = latest.any((c) => c['id'] == updatedRow['id']);
    debugPrint('📦 verified updated category in list: $verified');

    setState(() {
      _categories = List<Map<String, dynamic>>.from(latest);
      _isLoading = false;
    });

    if (verified) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตประเภทสำเร็จ (ยืนยันจากฐานข้อมูลแล้ว)'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตไม่สำเร็จ (ไม่พบข้อมูลในฐานข้อมูล)'), backgroundColor: Colors.red));
    }
  }



  String? _getDefaultAccountCode(List<Map<String, dynamic>> accounts, String type) {
    if (accounts.isEmpty) return null;
    final recommendedCode = _recommendedAccountCodes[type];
    final recommended = accounts.where((a) => a['code'] == recommendedCode).toList();
    if (recommended.isNotEmpty) return recommendedCode;
    return accounts.first['code'] as String?;
  }
}

// Reusing the Edit Dialog as it was simpler, but ensuring it returns bool
class _EditCategoryDialog extends StatefulWidget {
  final Map<String, dynamic> category;
  final List<Map<String, dynamic>> assetAccounts;
  final List<Map<String, dynamic>> revenueAccounts;
  final List<Map<String, dynamic>> costAccounts;

  const _EditCategoryDialog({
    required this.category,
    required this.assetAccounts,
    required this.revenueAccounts,
    required this.costAccounts,
  });

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late String? _inventoryCode;
  late String? _revenueCode;
  late String? _costCode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _inventoryCode = widget.category['inventory_account_code'] as String?;
    _revenueCode = widget.category['revenue_account_code'] as String?;
    _costCode = widget.category['cost_account_code'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text('แก้ไข ${widget.category['name']}'))]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdown('บัญชีสินค้าคงเหลือ', _inventoryCode, widget.assetAccounts, (v) => setState(() => _inventoryCode = v)),
            SizedBox(height: 16),
            _buildDropdown('บัญชีรายได้', _revenueCode, widget.revenueAccounts, (v) => setState(() => _revenueCode = v)),
            SizedBox(height: 16),
            _buildDropdown('บัญชีต้นทุน', _costCode, widget.costAccounts, (v) => setState(() => _costCode = v)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: Text('ยกเลิก')),
        ElevatedButton(
          onPressed: _isSaving ? null : () async {
            setState(() => _isSaving = true);
            final updatedRow = await InventoryService.updateCategory(widget.category['id'] as String, {
              'inventory_account_code': _inventoryCode,
              'revenue_account_code': _revenueCode,
              'cost_account_code': _costCode,
            });
            if (mounted) {
              if (updatedRow != null) {
                Navigator.pop(context, updatedRow);
              } else {
                setState(() => _isSaving = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ (ไม่ได้รับการยืนยันจากฐานข้อมูล)'), backgroundColor: Colors.red));
              }
            }
          },
          child: _isSaving ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('บันทึก'),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<Map<String, dynamic>> items, ValueChanged<String?> onChanged) {
    final validValue = (value != null && items.any((a) => a['code'] == value)) ? value : null;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(labelText: '$label (ไม่บังคับ)', border: OutlineInputBorder()),
      value: validValue,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('— ไม่ระบุ (ตั้งค่าทีหลัง)', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
        ),
        ...items.map((acc) => DropdownMenuItem<String>(
          value: acc['code'] as String?,
          child: Text('${acc['code']} - ${acc['name_th']}', overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (v) => onChanged(v),
    );
  }
}
