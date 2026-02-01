/// Model สำหรับการตั้งค่าฟอร์มของกลุ่ม
class GroupFormConfig {
  final String id;
  final String groupId;
  final String dialogTitle;
  final String? dialogDescription;
  final List<FormFieldConfig> fields;
  final bool isRequired;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GroupFormConfig({
    required this.id,
    required this.groupId,
    required this.dialogTitle,
    this.dialogDescription,
    required this.fields,
    this.isRequired = true,
    this.createdAt,
    this.updatedAt,
  });

  factory GroupFormConfig.fromJson(Map<String, dynamic> json) {
    return GroupFormConfig(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      dialogTitle: json['dialog_title'] as String,
      dialogDescription: json['dialog_description'] as String?,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((e) => FormFieldConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isRequired: json['is_required'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'dialog_title': dialogTitle,
      'dialog_description': dialogDescription,
      'fields': fields.map((f) => f.toJson()).toList(),
      'is_required': isRequired,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  GroupFormConfig copyWith({
    String? id,
    String? groupId,
    String? dialogTitle,
    String? dialogDescription,
    List<FormFieldConfig>? fields,
    bool? isRequired,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroupFormConfig(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      dialogDescription: dialogDescription ?? this.dialogDescription,
      fields: fields ?? this.fields,
      isRequired: isRequired ?? this.isRequired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model สำหรับ config ของแต่ละฟิลด์
class FormFieldConfig {
  final String id;
  final String key;
  final String label;
  final FormFieldType type;
  final bool required;
  final Map<String, dynamic>? config;
  final List<FieldValidationRule>? validationRules;

  FormFieldConfig({
    required this.id,
    required this.key,
    required this.label,
    required this.type,
    this.required = true,
    this.config,
    this.validationRules,
  });

  factory FormFieldConfig.fromJson(Map<String, dynamic> json) {
    return FormFieldConfig(
      id: json['id'] as String,
      key: json['key'] as String,
      label: json['label'] as String,
      type: FormFieldType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FormFieldType.text,
      ),
      required: json['required'] ?? true,
      config: json['config'] as Map<String, dynamic>?,
      validationRules: (json['validation_rules'] as List<dynamic>?)
          ?.map((e) => FieldValidationRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'label': label,
      'type': type.name,
      'required': required,
      'config': config,
      'validation_rules': validationRules?.map((r) => r.toJson()).toList(),
    };
  }

  FormFieldConfig copyWith({
    String? id,
    String? key,
    String? label,
    FormFieldType? type,
    bool? required,
    Map<String, dynamic>? config,
    List<FieldValidationRule>? validationRules,
  }) {
    return FormFieldConfig(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      config: config ?? this.config,
      validationRules: validationRules ?? this.validationRules,
    );
  }
}

/// ประเภทของกฎการตรวจสอบ
enum ValidationRuleType {
  required,
  minLength,
  maxLength,
  min,
  max,
  pattern,
  email,
  phone,
  numeric,
  alphabetic,
  alphanumeric,
}

/// กฎการตรวจสอบสำหรับฟิลด์
class FieldValidationRule {
  final ValidationRuleType type;
  final String? value;
  final String? errorMessage;
  final bool enabled;

  FieldValidationRule({
    required this.type,
    this.value,
    this.errorMessage,
    this.enabled = true,
  });

  factory FieldValidationRule.fromJson(Map<String, dynamic> json) {
    return FieldValidationRule(
      type: ValidationRuleType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ValidationRuleType.required,
      ),
      value: json['value'] as String?,
      errorMessage: json['error_message'] as String?,
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
      'error_message': errorMessage,
      'enabled': enabled,
    };
  }

  /// ตรวจสอบค่าว่าผ่านกฎหรือไม่
  String? validate(String? fieldValue) {
    if (!enabled) return null;
    
    final value = fieldValue ?? '';
    
    switch (type) {
      case ValidationRuleType.required:
        if (value.isEmpty) {
          return errorMessage ?? 'กรุณากรอกข้อมูล';
        }
        break;
      
      case ValidationRuleType.minLength:
        final minLength = int.tryParse(this.value ?? '0') ?? 0;
        if (value.length < minLength) {
          return errorMessage ?? 'กรุณากรอกอย่างน้อย $minLength ตัวอักษร';
        }
        break;
      
      case ValidationRuleType.maxLength:
        final maxLength = int.tryParse(this.value ?? '0') ?? 0;
        if (value.length > maxLength) {
          return errorMessage ?? 'กรุณากรอกไม่เกิน $maxLength ตัวอักษร';
        }
        break;
      
      case ValidationRuleType.min:
        final min = double.tryParse(this.value ?? '0') ?? 0;
        final numValue = double.tryParse(value) ?? 0;
        if (numValue < min) {
          return errorMessage ?? 'ค่าต้องไม่น้อยกว่า $min';
        }
        break;
      
      case ValidationRuleType.max:
        final max = double.tryParse(this.value ?? '0') ?? 0;
        final numValue = double.tryParse(value) ?? 0;
        if (numValue > max) {
          return errorMessage ?? 'ค่าต้องไม่มากกว่า $max';
        }
        break;
      
      case ValidationRuleType.pattern:
        final pattern = RegExp(this.value ?? '');
        if (!pattern.hasMatch(value)) {
          return errorMessage ?? 'รูปแบบข้อมูลไม่ถูกต้อง';
        }
        break;
      
      case ValidationRuleType.email:
        final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailPattern.hasMatch(value)) {
          return errorMessage ?? 'รูปแบบอีเมลไม่ถูกต้อง';
        }
        break;
      
      case ValidationRuleType.phone:
        final phonePattern = RegExp(r'^0[0-9]{9}$');
        if (!phonePattern.hasMatch(value.replaceAll('-', '').replaceAll(' ', ''))) {
          return errorMessage ?? 'รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง';
        }
        break;
      
      case ValidationRuleType.numeric:
        final numericPattern = RegExp(r'^[0-9]+$');
        if (!numericPattern.hasMatch(value)) {
          return errorMessage ?? 'กรุณากรอกตัวเลขเท่านั้น';
        }
        break;
      
      case ValidationRuleType.alphabetic:
        final alphaPattern = RegExp(r'^[a-zA-Zก-๙\s]+$');
        if (!alphaPattern.hasMatch(value)) {
          return errorMessage ?? 'กรุณากรอกตัวอักษรเท่านั้น';
        }
        break;
      
      case ValidationRuleType.alphanumeric:
        final alnumPattern = RegExp(r'^[a-zA-Z0-9ก-๙\s]+$');
        if (!alnumPattern.hasMatch(value)) {
          return errorMessage ?? 'กรุณากรองตัวอักษรและตัวเลขเท่านั้น';
        }
        break;
    }
    
    return null;
  }
  
  /// ดึงข้อมูลสำหรับแสดงใน UI
  String get displayName {
    switch (type) {
      case ValidationRuleType.required:
        return 'จำเป็นต้องกรอก';
      case ValidationRuleType.minLength:
        return 'ความยาวอย่างน้อย ${value ?? '0'} ตัวอักษร';
      case ValidationRuleType.maxLength:
        return 'ความยาวไม่เกิน ${value ?? '0'} ตัวอักษร';
      case ValidationRuleType.min:
        return 'ค่าอย่างน้อย ${value ?? '0'}';
      case ValidationRuleType.max:
        return 'ค่าไม่เกิน ${value ?? '0'}';
      case ValidationRuleType.pattern:
        return 'รูปแบบ';
      case ValidationRuleType.email:
        return 'อีเมล';
      case ValidationRuleType.phone:
        return 'เบอร์โทรศัพท์';
      case ValidationRuleType.numeric:
        return 'ตัวเลขเท่านั้น';
      case ValidationRuleType.alphabetic:
        return 'ตัวอักษรเท่านั้น';
      case ValidationRuleType.alphanumeric:
        return 'ตัวอักษรและตัวเลข';
    }
  }

  FieldValidationRule copyWith({
    ValidationRuleType? type,
    String? value,
    String? errorMessage,
    bool? enabled,
  }) {
    return FieldValidationRule(
      type: type ?? this.type,
      value: value ?? this.value,
      errorMessage: errorMessage ?? this.errorMessage,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// ประเภทของฟิลด์
enum FormFieldType {
  text('text'),
  email('email'),
  phone('phone'),
  dropdown('dropdown'),
  image('image'),
  date('date'),
  number('number'),
  textarea('textarea');

  final String value;
  const FormFieldType(this.value);

  factory FormFieldType.fromString(String value) {
    return FormFieldType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FormFieldType.text,
    );
  }

  String get displayName {
    switch (this) {
      case FormFieldType.text:
        return 'ข้อความ';
      case FormFieldType.email:
        return 'อีเมล';
      case FormFieldType.phone:
        return 'เบอร์โทรศัพท์';
      case FormFieldType.dropdown:
        return 'รายการเลือก';
      case FormFieldType.image:
        return 'รูปภาพ';
      case FormFieldType.date:
        return 'วันที่';
      case FormFieldType.number:
        return 'ตัวเลข';
      case FormFieldType.textarea:
        return 'ข้อความยาว';
    }
  }
}
