import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_group_model.dart';
import '../services/supabase_service.dart';

/// Service สำหรับจัดการ User Groups จาก Supabase
class UserGroupService {
  static final SupabaseClient _client = SupabaseService.client;

  /// ดึงรายการกลุ่มผู้ใช้ทั้งหมดจากตาราง user_groups
  static Future<List<UserGroup>> getAllGroups() async {
    try {
      final response = await _client
          .from('user_groups')
          .select('*')
          .eq('is_active', true)
          .order('group_name');

      return (response as List)
          .map((json) => UserGroup.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading user groups: $e');
      return [];
    }
  }

  /// ดึงกลุ่มผู้ใช้ตาม ID
  static Future<UserGroup?> getGroupById(String groupId) async {
    try {
      final response = await _client
          .from('user_groups')
          .select('*')
          .eq('id', groupId)
          .maybeSingle();

      if (response != null) {
        return UserGroup.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading user group: $e');
      return null;
    }
  }

  /// ดึงกลุ่มผู้ใช้ตามชื่อกลุ่ม
  static Future<UserGroup?> getGroupByName(String groupName) async {
    try {
      final response = await _client
          .from('user_groups')
          .select('*')
          .eq('group_name', groupName)
          .maybeSingle();

      if (response != null) {
        return UserGroup.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading user group by name: $e');
      return null;
    }
  }

  /// ดึงกลุ่ม default (customer) สำหรับการลงทะเบียนใหม่
  static Future<UserGroup?> getDefaultGroup() async {
    final possibleNames = ['customer', 'ลูกค้า', 'user', 'ผู้ใช้'];
    
    for (final name in possibleNames) {
      final group = await getGroupByName(name);
      if (group != null) return group;
    }
    
    final groups = await getAllGroups();
    if (groups.isNotEmpty) return groups.first;
    
    return null;
  }

  /// ดึง user_group_id ของผู้ใช้ปัจจุบัน
  static Future<String?> getCurrentUserGroupId() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return null;

      debugPrint('🔍 Getting group ID for user: ${currentUser.id}');

      // 1. ลองดึงจาก user_group_members table ก่อน (แหล่งข้อมูลที่ถูกต้อง)
      try {
        final memberResponse = await _client
            .from('user_group_members')
            .select('group_id')
            .eq('user_id', currentUser.id)
            .maybeSingle();

        if (memberResponse != null && memberResponse['group_id'] != null) {
          debugPrint('✅ Found group ID from user_group_members: ${memberResponse['group_id']}');
          return memberResponse['group_id'] as String;
        } else {
          debugPrint('❌ No group ID found in user_group_members');
        }
      } catch (e) {
        debugPrint('❌ Error reading from user_group_members: $e');
      }

      // 2. Fallback: ดึงจาก metadata (ถ้าไม่มีใน user_group_members)
      final metadata = currentUser.userMetadata;
      if (metadata != null && metadata['user_group_id'] != null) {
        debugPrint('✅ Found group ID from metadata: ${metadata['user_group_id']}');
        return metadata['user_group_id'] as String;
      } else {
        debugPrint('❌ No group ID found in metadata');
      }

      // 3. Fallback: ดึงจาก users table
      try {
        final response = await _client
            .from('users')
            .select('user_group_id')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (response != null && response['user_group_id'] != null) {
          debugPrint('✅ Found group ID from users table: ${response['user_group_id']}');
          return response['user_group_id'] as String?;
        } else {
          debugPrint('❌ No group ID found in users table');
        }
      } catch (e) {
        debugPrint('❌ Error reading from users table: $e');
      }

      debugPrint('❌ No group ID found anywhere');
      return null;
    } catch (e) {
      debugPrint('Error getting user group ID: $e');
      return null;
    }
  }

  /// ดึงข้อมูลกลุ่มของผู้ใช้ปัจจุบัน
  static Future<UserGroup?> getCurrentUserGroup() async {
    final groupId = await getCurrentUserGroupId();
    if (groupId == null) return null;
    return await getGroupById(groupId);
  }

  /// อัปเดต user_group_id ของผู้ใช้
  static Future<bool> updateUserGroup(String groupId) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final group = await getGroupById(groupId);
      if (group == null) {
        throw Exception('ไม่พบกลุ่มผู้ใช้ที่เลือก');
      }

      await _client.auth.updateUser(
        UserAttributes(
          data: {'user_group_id': groupId},
        ),
      );

      try {
        await _client
            .from('users')
            .update({
              'user_group_id': groupId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', currentUser.id);
      } catch (e) {
        debugPrint('Could not update users table user_group_id: $e');
      }

      // อัปเดตตาราง user_group_members
      try {
        // ลบข้อมูลเก่าของผู้ใช้ (ถ้ามี)
        await _client
            .from('user_group_members')
            .delete()
            .eq('user_id', currentUser.id);
        
        // เพิ่มข้อมูลใหม่
        await _client
            .from('user_group_members')
            .insert({
              'user_id': currentUser.id,
              'group_id': groupId,
            });
      } catch (e) {
        debugPrint('Could not update user_group_members table: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error updating user group: $e');
      return false;
    }
  }

  /// ตรวจสอบว่าผู้ใช้อยู่ในกลุ่มที่กำหนดหรือไม่
  static Future<bool> isInGroup(String groupName) async {
    final currentGroup = await getCurrentUserGroup();
    return currentGroup?.groupName.toLowerCase() == groupName.toLowerCase();
  }

  /// ตรวจสอบว่าผู้ใช้เป็นแอดมินหรือไม่
  static Future<bool> isAdmin() async {
    return await isInGroup('admin');
  }

  /// ตรวจสอบว่าผู้ใช้เป็นเจ้าของร้านหรือไม่ (รวมแอดมิน)
  static Future<bool> isOwnerOrAdmin() async {
    final group = await getCurrentUserGroup();
    if (group == null) return false;
    final name = group.groupName.toLowerCase();
    return name.contains('owner') || name.contains('เจ้าของ') || name.contains('admin');
  }

  /// ตรวจสอบว่าผู้ใช้เป็นพนักงานขึ้นไป
  static Future<bool> isStaffOrAbove() async {
    final group = await getCurrentUserGroup();
    if (group == null) return false;
    final name = group.groupName.toLowerCase();
    return name.contains('staff') || name.contains('พนักงาน') || 
           name.contains('owner') || name.contains('เจ้าของ') || 
           name.contains('admin');
  }

  /// ดึงรายการกลุ่มที่ผู้ใช้สามารถเลือกได้
  static Future<List<UserGroup>> getAvailableGroups() async {
    final allGroups = await getAllGroups();
    final currentGroup = await getCurrentUserGroup();
    
    if (currentGroup == null) return allGroups;
    
    final currentName = currentGroup.groupName.toLowerCase();
    
    if (currentName.contains('admin')) {
      return allGroups;
    }
    
    if (currentName.contains('owner') || currentName.contains('เจ้าของ')) {
      return allGroups.where((g) => !g.groupName.toLowerCase().contains('admin')).toList();
    }
    
    return allGroups.where((g) {
      final name = g.groupName.toLowerCase();
      return !name.contains('admin') && !name.contains('owner') && !name.contains('เจ้าของ');
    }).toList();
  }
}
