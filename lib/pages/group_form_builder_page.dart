import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/group_form_config_model.dart';
import '../services/group_form_config_service.dart';
import '../services/user_group_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_button.dart';

class GroupFormBuilderPage extends StatefulWidget {
  final String? groupId;
  final String? configId;

  const GroupFormBuilderPage({
    super.key,
    this.groupId,
    this.configId,
  });

  @override
  State<GroupFormBuilderPage> createState() => _GroupFormBuilderPageState();
}

class _GroupFormBuilderPageState extends State<GroupFormBuilderPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();

  final List<FormFieldConfig> _fields = [];
  final List<Map<String, dynamic>> _activeGroups = [];
  Map<String, dynamic>? _selectedGroup;
  int? _draggingIndex;
  bool _showPreview = false;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final groups = await UserGroupService.getAvailableGroups();
    _activeGroups
      ..clear()
      ..addAll(groups.map((g) => {
            'id': g.id,
            'group_name': g.groupName,
            'group_description': g.groupDescription,
            'color': g.color,
          }));

    if (widget.groupId != null) {
      _selectedGroup = _activeGroups.firstWhere(
        (g) => g['id'] == widget.groupId,
        orElse: () => _activeGroups.isNotEmpty ? _activeGroups.first : {},
      );
    }

    if (widget.groupId != null) {
      final config = await GroupFormConfigService.getFormConfigByGroupId(widget.groupId!);
      if (config != null) {
        _titleController.text = config.dialogTitle;
        _descriptionController.text = config.dialogDescription ?? '';
        _fields
          ..clear()
          ..addAll(config.fields);
      } else if (_selectedGroup != null && _selectedGroup!.isNotEmpty) {
        // Leave empty for user to fill - hint text will show
      }
    }

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredGroups {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _activeGroups;
    return _activeGroups.where((g) {
      final name = (g['group_name'] as String).toLowerCase();
      final desc = (g['group_description'] as String? ?? '').toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();
  }

  Future<void> _saveForm() async {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกกลุ่มก่อนบันทึก')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final groupId = _selectedGroup!['id'] as String;

    final config = GroupFormConfig(
      id: widget.configId ?? const Uuid().v4(),
      groupId: groupId,
      dialogTitle: _titleController.text.trim().isEmpty
          ? 'ข้อมูลสำหรับ ${_selectedGroup!['group_name']}'
          : _titleController.text.trim(),
      dialogDescription: _descriptionController.text.trim().isEmpty
          ? 'กรุณากรอกข้อมูลให้ครบถ้วนเพื่อเป็น ${_selectedGroup!['group_description'] ?? _selectedGroup!['group_name']}'
          : _descriptionController.text.trim(),
      fields: _fields,
      isRequired: true,
    );

    final existingConfig = await GroupFormConfigService.getFormConfigByGroupId(groupId);
    final saved = existingConfig == null
        ? await GroupFormConfigService.createFormConfig(config)
        : await GroupFormConfigService.updateFormConfig(
            config.copyWith(id: existingConfig.id),
          );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (saved != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกฟอร์มสำเร็จ')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกฟอร์มไม่สำเร็จ')),
      );
    }
  }

  Future<void> _showAddFieldDialog() async {
    final keyController = TextEditingController();
    final labelController = TextEditingController();
    FormFieldType selectedType = FormFieldType.text;
    bool required = true;
    final List<FieldValidationRule> validationRules = [];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มฟิลด์ใหม่'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'ชื่อฟิลด์'),
                ),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'key (เช่น company_name)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FormFieldType>(
                  value: selectedType,
                  items: FormFieldType.values
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    if (value != null) selectedType = value;
                  }),
                  decoration: const InputDecoration(labelText: 'ประเภทฟิลด์'),
                ),
                SwitchListTile(
                  value: required,
                  onChanged: (value) => setDialogState(() => required = value),
                  title: const Text('บังคับกรอก'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'กฎการตรวจสอบ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...validationRules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final rule = entry.value;
                  return Card(
                    child: ListTile(
                      title: Text(rule.displayName),
                      subtitle: rule.errorMessage != null ? Text(rule.errorMessage!) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: rule.enabled,
                            onChanged: (value) => setDialogState(() {
                              validationRules[index] = rule.copyWith(enabled: value);
                            }),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setDialogState(() => validationRules.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddValidationRuleDialog(context, validationRules, setDialogState),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มกฎการตรวจสอบ'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (labelController.text.trim().isEmpty || keyController.text.trim().isEmpty) {
                return;
              }

              setState(() {
                _fields.add(FormFieldConfig(
                  id: const Uuid().v4(),
                  key: keyController.text.trim(),
                  label: labelController.text.trim(),
                  type: selectedType,
                  required: required,
                  validationRules: validationRules,
                ));
              });

              Navigator.pop(context);
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  void _removeField(int index) {
    setState(() => _fields.removeAt(index));
  }

  void _showAddValidationRuleDialog(
    BuildContext context,
    List<FieldValidationRule> validationRules,
    StateSetter setDialogState,
  ) {
    final valueController = TextEditingController();
    final errorMessageController = TextEditingController();
    ValidationRuleType selectedType = ValidationRuleType.required;
    bool enabled = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มกฎการตรวจสอบ'),
        content: StatefulBuilder(
          builder: (context, setRuleDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ValidationRuleType>(
                value: selectedType,
                items: ValidationRuleType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        ))
                    .toList(),
                onChanged: (value) => setRuleDialogState(() {
                  if (value != null) selectedType = value;
                }),
                decoration: const InputDecoration(labelText: 'ประเภทกฎ'),
              ),
              if (_needsValue(selectedType))
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: _getValueLabel(selectedType),
                    hintText: _getValueHint(selectedType),
                  ),
                ),
              TextField(
                controller: errorMessageController,
                decoration: const InputDecoration(
                  labelText: 'ข้อความแจ้งเตือน (optional)',
                  hintText: 'เวลาผิดกฎจะแสดงข้อความนี้',
                ),
              ),
              SwitchListTile(
                value: enabled,
                onChanged: (value) => setRuleDialogState(() => enabled = value),
                title: const Text('เปิดใช้งาน'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final rule = FieldValidationRule(
                type: selectedType,
                value: valueController.text.trim().isEmpty ? null : valueController.text.trim(),
                errorMessage: errorMessageController.text.trim().isEmpty ? null : errorMessageController.text.trim(),
                enabled: enabled,
              );
              
              setDialogState(() => validationRules.add(rule));
              Navigator.pop(context);
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  bool _needsValue(ValidationRuleType type) {
    return [
      ValidationRuleType.minLength,
      ValidationRuleType.maxLength,
      ValidationRuleType.min,
      ValidationRuleType.max,
      ValidationRuleType.pattern,
    ].contains(type);
  }

  String _getValueLabel(ValidationRuleType type) {
    switch (type) {
      case ValidationRuleType.minLength:
      case ValidationRuleType.maxLength:
        return 'จำนวนตัวอักษร';
      case ValidationRuleType.min:
      case ValidationRuleType.max:
        return 'ค่า';
      case ValidationRuleType.pattern:
        return 'Regular Expression';
      default:
        return 'ค่า';
    }
  }

  String _getValueHint(ValidationRuleType type) {
    switch (type) {
      case ValidationRuleType.minLength:
      case ValidationRuleType.maxLength:
        return 'เช่น 10';
      case ValidationRuleType.min:
      case ValidationRuleType.max:
        return 'เช่น 18';
      case ValidationRuleType.pattern:
        return r'เช่น ^[A-Za-z]+$';
      default:
        return '';
    }
  }

  void _showFieldValidationRulesDialog(FormFieldConfig field) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('กฎการตรวจสอบ: ${field.label}'),
        content: SizedBox(
          width: double.maxFinite,
          child: field.validationRules == null || field.validationRules!.isEmpty
              ? const Text('ยังไม่มีกฎการตรวจสอบ')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: field.validationRules!.length,
                  itemBuilder: (context, index) {
                    final rule = field.validationRules![index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          rule.enabled ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: rule.enabled ? Colors.green : Colors.grey,
                        ),
                        title: Text(rule.displayName),
                        subtitle: rule.errorMessage != null ? Text(rule.errorMessage!) : null,
                        trailing: Text(
                          rule.enabled ? 'เปิด' : 'ปิด',
                          style: TextStyle(
                            color: rule.enabled ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  void _reorderFields(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final field = _fields.removeAt(oldIndex);
    _fields.insert(newIndex, field);
    setState(() {});
  }

  void _togglePreview() {
    setState(() => _showPreview = !_showPreview);
  }

  Widget _buildPreviewDialog() {
    return GlassDialog(
      title: _titleController.text.isEmpty 
          ? 'ข้อมูลสำหรับ ${_selectedGroup?['group_name'] ?? ''}'
          : _titleController.text,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_descriptionController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _descriptionController.text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ..._fields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            return _buildPreviewField(field, index);
          }),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  text: 'ปิด',
                  onPressed: () => _togglePreview(),
                  backgroundColor: Colors.grey[600]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewField(FormFieldConfig field, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildPreviewInput(field),
        ],
      ),
    );
  }

  Widget _buildPreviewInput(FormFieldConfig field) {
    switch (field.type) {
      case FormFieldType.text:
        return TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'กรอก${field.label.toLowerCase()}',
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white),
        );
      case FormFieldType.number:
        return TextField(
          enabled: false,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'กรอก${field.label.toLowerCase()}',
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white),
        );
      case FormFieldType.email:
        return TextField(
          enabled: false,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'กรอกอีเมล',
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white),
        );
      case FormFieldType.phone:
        return TextField(
          enabled: false,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'กรอกเบอร์โทรศัพท์',
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white),
        );
      case FormFieldType.dropdown:
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            hintText: 'เลือก${field.label.toLowerCase()}',
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          dropdownColor: const Color(0xFF2D2D44),
          style: const TextStyle(color: Colors.white),
          items: const [
            DropdownMenuItem(value: 'option1', child: Text('ตัวเลือก 1', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(value: 'option2', child: Text('ตัวเลือก 2', style: TextStyle(color: Colors.white))),
          ],
          onChanged: null,
        );
      case FormFieldType.date:
        return TextField(
          enabled: false,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            hintText: 'เลือกวันที่',
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            suffixIcon: Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white),
        );
      case FormFieldType.textarea:
        return TextField(
          enabled: false,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'กรอก${field.label.toLowerCase()}',
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white),
        );
      case FormFieldType.image:
        return Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.6), size: 32),
              const SizedBox(height: 8),
              Text(
                'แตะเพื่อเลือกรูปภาพ',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        );
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) {
      return Colors.grey;
    }
    try {
      String hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ออกแบบฟอร์มกลุ่ม'),
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
              ),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Group Title Header
                    if (_selectedGroup != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _parseColor(_selectedGroup!['color'] as String?).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.group,
                                color: _parseColor(_selectedGroup!['color'] as String?),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedGroup!['group_name'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_selectedGroup!['group_description'] != null)
                                    Text(
                                      _selectedGroup!['group_description'] as String,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text('ข้อความหัวข้อ Dialog', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      decoration: _inputDecoration(''),
                    ),
                    const SizedBox(height: 12),
                    const Text('คำอธิบาย', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: _inputDecoration(''),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ฟิลด์ที่ต้องกรอก',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            if (_fields.isNotEmpty)
                              IconButton(
                                onPressed: _togglePreview,
                                icon: const Icon(Icons.preview, color: Colors.blue),
                                tooltip: 'ดูตัวอย่าง',
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _showAddFieldDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่มฟิลด์'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_fields.isEmpty)
                      Column(
                        children: [
                          Text(
                            'ยังไม่มีฟิลด์ กรุณาเพิ่มฟิลด์',
                            style: TextStyle(color: Colors.white.withOpacity(0.6)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '💡 เคล็ดลับ: เมื่อเพิ่มฟิลด์แล้วสามารถลากเพื่อจัดลำดับได้',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: ReorderableListView.builder(
                          onReorder: _reorderFields,
                          itemCount: _fields.length,
                          itemBuilder: (context, index) {
                            final field = _fields[index];
                            return ReorderableDragStartListener(
                              key: ValueKey(field.id),
                              index: index,
                              child: Card(
                                color: const Color(0xFF2D2D44),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(Icons.drag_handle, color: Colors.white.withOpacity(0.6)),
                                  title: Text(
                                    field.label,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '${field.type.displayName} • ${field.required ? 'บังคับกรอก' : 'ไม่บังคับ'}'
                                    '${field.validationRules != null && field.validationRules!.isNotEmpty ? ' • ${field.validationRules!.length} กฎ' : ''}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (field.validationRules != null && field.validationRules!.isNotEmpty)
                                        IconButton(
                                          onPressed: () => _showFieldValidationRulesDialog(field),
                                          icon: const Icon(Icons.rule, color: Colors.blue),
                                          tooltip: 'ดูกฎการตรวจสอบ',
                                        ),
                                      IconButton(
                                        onPressed: () => _removeField(index),
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ยกเลิก'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveForm,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('บันทึกฟอร์ม'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_showPreview)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: _buildPreviewDialog(),
                ),
              ),
            if (_isSaving)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'กำลังบันทึกฟอร์ม...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'กรุณารอสักครู่',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
