import 'package:flutter/material.dart';

/// Model สำหรับ User Group จากตาราง user_groups
class UserGroup {
  final String id;
  final String groupName;
  final String? groupDescription;
  final String? color;
  final String? createdBy;
  final DateTime? createdAt;
  final bool isActive;
  final bool requiresProfileCompletion;
  final int? sortOrder;

  UserGroup({
    required this.id,
    required this.groupName,
    this.groupDescription,
    this.color,
    this.createdBy,
    this.createdAt,
    this.isActive = true,
    this.requiresProfileCompletion = false,
    this.sortOrder,
  });

  factory UserGroup.fromJson(Map<String, dynamic> json) {
    return UserGroup(
      id: json['id'] as String,
      groupName: json['group_name'] as String,
      groupDescription: json['group_description'] as String?,
      color: json['color'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isActive: json['is_active'] ?? true,
      requiresProfileCompletion: json['requires_profile_completion'] ?? false,
      sortOrder: json['sort_order'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_name': groupName,
      'group_description': groupDescription,
      'color': color,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'is_active': isActive,
      'requires_profile_completion': requiresProfileCompletion,
      'sort_order': sortOrder,
    };
  }

  /// ดึงชื่อกลุ่มที่แสดงผล
  String get displayName => groupName;

  /// ดึงคำอธิบายที่แสดงผล
  String get displayDescription => groupDescription ?? '';

  /// ดึง Icon ตามชื่อกลุ่ม (default ตามประเภท)
  IconData get iconData {
    final name = groupName.toLowerCase();
    if (name.contains('admin')) return Icons.admin_panel_settings;
    if (name.contains('owner') || name.contains('เจ้าของ')) return Icons.store;
    if (name.contains('staff') || name.contains('พนักงาน')) return Icons.work;
    if (name.contains('customer') || name.contains('ลูกค้า')) return Icons.person;
    return Icons.group;
  }

  /// ดึงสีจาก database หรือ default ตามชื่อกลุ่ม
  Color get colorValue {
    // ถ้ามีสีจาก database ให้ใช้สีนั้น
    if (color != null && color!.isNotEmpty) {
      try {
        String hex = color!.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      } catch (e) {
        // ถ้า parse ไม่ได้ ให้ใช้ default
      }
    }
    // Default colors by group name
    final name = groupName.toLowerCase();
    if (name.contains('admin')) return const Color(0xFFE91E63);
    if (name.contains('owner') || name.contains('เจ้าของ')) return const Color(0xFFFF9800);
    if (name.contains('staff') || name.contains('พนักงาน')) return const Color(0xFF2196F3);
    if (name.contains('customer') || name.contains('ลูกค้า')) return const Color(0xFF4CAF50);
    return const Color(0xFF9E9E9E);
  }
}
