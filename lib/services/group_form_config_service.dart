import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_form_config_model.dart';

/// Service สำหรับจัดการการตั้งค่าฟอร์มกลุ่ม
class GroupFormConfigService {
  static final _supabase = Supabase.instance.client;

  /// ดึง config ฟอร์มทั้งหมดพร้อมข้อมูลกลุ่ม
  static Future<List<Map<String, dynamic>>> getAllGroupFormsWithGroupInfo() async {
    try {
      final response = await _supabase
          .from('user_groups')
          .select('''
            id,
            group_name,
            group_description,
            color,
            is_active,
            group_form_configs!left(
              id,
              dialog_title,
              dialog_description,
              fields,
              is_required,
              created_at
            )
          ''')
          .eq('is_active', true)
          .order('group_name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching group forms: $e');
      return [];
    }
  }

  /// ดึง config ฟอร์มของกลุ่มเฉพาะ
  static Future<GroupFormConfig?> getFormConfigByGroupId(String groupId) async {
    try {
      final response = await _supabase
          .from('group_form_configs')
          .select()
          .eq('group_id', groupId)
          .maybeSingle();

      if (response == null) return null;

      return GroupFormConfig.fromJson(response);
    } catch (e) {
      print('Error fetching form config: $e');
      return null;
    }
  }

  /// สร้าง config ฟอร์มใหม่
  static Future<GroupFormConfig?> createFormConfig(GroupFormConfig config) async {
    try {
      final response = await _supabase
          .from('group_form_configs')
          .insert({
            'group_id': config.groupId,
            'dialog_title': config.dialogTitle,
            'dialog_description': config.dialogDescription,
            'fields': config.fields.map((f) => f.toJson()).toList(),
            'is_required': config.isRequired,
          })
          .select()
          .single();

      return GroupFormConfig.fromJson(response);
    } catch (e) {
      print('Error creating form config: $e');
      return null;
    }
  }

  /// อัปเดต config ฟอร์ม
  static Future<GroupFormConfig?> updateFormConfig(GroupFormConfig config) async {
    try {
      final response = await _supabase
          .from('group_form_configs')
          .update({
            'dialog_title': config.dialogTitle,
            'dialog_description': config.dialogDescription,
            'fields': config.fields.map((f) => f.toJson()).toList(),
            'is_required': config.isRequired,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', config.id)
          .select()
          .single();

      return GroupFormConfig.fromJson(response);
    } catch (e) {
      print('Error updating form config: $e');
      return null;
    }
  }

  /// ลบ config ฟอร์ม
  static Future<bool> deleteFormConfig(String configId) async {
    try {
      await _supabase
          .from('group_form_configs')
          .delete()
          .eq('id', configId);

      return true;
    } catch (e) {
      print('Error deleting form config: $e');
      return false;
    }
  }

  /// ดึงรายการกลุ่มที่ยังไม่มีฟอร์ม
  static Future<List<Map<String, dynamic>>> getGroupsWithoutForm() async {
    try {
      // ดึงกลุ่มที่มีฟอร์มแล้ว
      final configs = await _supabase
          .from('group_form_configs')
          .select('group_id');

      final existingGroupIds = configs.map((c) => c['group_id'] as String).toList();

      // ดึงกลุ่มที่ยังไม่มีฟอร์ม
      var query = _supabase
          .from('user_groups')
          .select('id, group_name, group_description, color')
          .eq('is_active', true);

      if (existingGroupIds.isNotEmpty) {
        query = query.not('id', 'in', '(${existingGroupIds.join(',')})');
      }

      final response = await query.order('group_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching groups without form: $e');
      return [];
    }
  }

  /// บันทึกข้อมูลฟอร์มที่ผู้ใช้กรอก
  static Future<bool> saveUserFormData({
    required String userId,
    required String groupId,
    required Map<String, dynamic> formData,
    bool isCompleted = true,
  }) async {
    try {
      await _supabase.from('user_group_form_data').upsert(
        {
          'user_id': userId,
          'group_id': groupId,
          'form_data': formData,
          'is_completed': isCompleted,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,group_id',
      );

      return true;
    } catch (e) {
      print('Error saving user form data: $e');
      return false;
    }
  }

  /// ตรวจสอบว่าผู้ใช้กรอกฟอร์มครบแล้วหรือไม่
  static Future<bool> hasUserCompletedForm({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _supabase
          .from('user_group_form_data')
          .select('is_completed')
          .eq('user_id', userId)
          .eq('group_id', groupId)
          .maybeSingle();

      return response?['is_completed'] ?? false;
    } catch (e) {
      print('Error checking user form completion: $e');
      return false;
    }
  }

  /// ดึงข้อมูลฟอร์มที่ผู้ใช้กรอกไว้
  static Future<Map<String, dynamic>?> getUserFormData({
    required String userId,
    required String groupId,
  }) async {
    try {
      final response = await _supabase
          .from('user_group_form_data')
          .select('form_data')
          .eq('user_id', userId)
          .eq('group_id', groupId)
          .maybeSingle();

      return response?['form_data'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching user form data: $e');
      return null;
    }
  }
}
