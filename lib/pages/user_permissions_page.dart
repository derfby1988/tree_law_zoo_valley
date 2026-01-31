import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_button.dart';

/// รายการหน้าทั้งหมดในระบบ พร้อมชื่อปุ่มที่เกี่ยวข้อง
final List<Map<String, dynamic>> _systemPages = [
  {'id': 'dashboard', 'name': 'หน้าหลัก', 'button': 'แดชบอร์ด', 'icon': Icons.dashboard},
  {'id': 'inventory', 'name': 'คลังสินค้า', 'button': 'สินค้า', 'icon': Icons.inventory},
  {'id': 'table_booking', 'name': 'จองโต๊ะ', 'button': 'จองโต๊ะ', 'icon': Icons.table_restaurant},
  {'id': 'room_booking', 'name': 'จองห้อง', 'button': 'จองห้อง', 'icon': Icons.meeting_room},
  {'id': 'restaurant_menu', 'name': 'เมนูร้านอาหาร', 'button': 'เมนู', 'icon': Icons.restaurant_menu},
  {'id': 'user_management', 'name': 'จัดการผู้ใช้', 'button': 'ผู้ใช้', 'icon': Icons.people},
  {'id': 'user_permissions', 'name': 'สิทธิ์ผู้ใช้', 'button': 'สิทธิ์', 'icon': Icons.security},
  {'id': 'user_groups', 'name': 'กลุ่มผู้ใช้', 'button': 'กลุ่ม', 'icon': Icons.group_work},
  {'id': 'reports', 'name': 'รายงาน', 'button': 'รายงาน', 'icon': Icons.bar_chart},
  {'id': 'settings', 'name': 'ตั้งค่า', 'button': 'ตั้งค่า', 'icon': Icons.settings},
];

class UserPermissionsPage extends StatefulWidget {
  const UserPermissionsPage({super.key});

  @override
  State<UserPermissionsPage> createState() => _UserPermissionsPageState();
}

class _UserPermissionsPageState extends State<UserPermissionsPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _userGroups = [];
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _pagePermissions = [];
  Map<String, dynamic>? _selectedGroup;
  
  // Search controllers
  final TextEditingController _groupSearchController = TextEditingController();
  String _groupSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _groupSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // โหลดข้อมูลกลุ่มผู้ใช้
      final groupsResponse = await SupabaseService.client
          .from('user_groups')
          .select('*')
          .eq('is_active', true)
          .order('group_name', ascending: true);

      // โหลดข้อมูล permissions (user-group mapping)
      final permissionsResponse = await SupabaseService.client
          .from('user_permissions')
          .select('*');

      // โหลดข้อมูลผู้ใช้ (สำหรับแสดงในกลุ่ม)
      final usersResponse = await SupabaseService.client
          .from('user_profiles')
          .select('*')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      // โหลดข้อมูลสิทธิ์การเข้าถึงหน้า (group_page_permissions)
      final pagePermissionsResponse = await SupabaseService.client
          .from('group_page_permissions')
          .select('*');

      setState(() {
        _userGroups = List<Map<String, dynamic>>.from(groupsResponse);
        _permissions = List<Map<String, dynamic>>.from(permissionsResponse);
        _pagePermissions = List<Map<String, dynamic>>.from(pagePermissionsResponse);
        _users = List<Map<String, dynamic>>.from(usersResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateGroupUsers(String groupId, List<String> userIds) async {
    try {
      await SupabaseService.client
          .from('user_permissions')
          .delete()
          .eq('group_id', groupId);

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      for (final userId in userIds) {
        await SupabaseService.client.from('user_permissions').insert({
          'user_id': userId,
          'group_id': groupId,
          'assigned_by': currentUser.id,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตสมาชิกกลุ่มสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดตสมาชิกกลุ่ม: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showGroupPermissionDialog(Map<String, dynamic> group) {
    final groupUserIds = _permissions
        .where((p) => p['group_id'] == group['id'])
        .map((p) => p['user_id'].toString())
        .toSet();

    final groupColor = _hexToColor(group['color']);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'จัดการสมาชิกกลุ่ม',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: groupColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: groupColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['group_name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _darkenColor(groupColor, 0.2),
                            ),
                          ),
                          if (group['group_description'] != null)
                            Text(
                              group['group_description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'เลือกผู้ใช้ที่อยู่ในกลุ่มนี้:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isSelected = groupUserIds.contains(user['id'].toString());
                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: groupColor,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            groupUserIds.add(user['id'].toString());
                          } else {
                            groupUserIds.remove(user['id'].toString());
                          }
                        });
                      },
                      title: Text(user['full_name'] ?? 'ไม่ระบุชื่อ'),
                      subtitle: Text(user['email'] ?? ''),
                      secondary: CircleAvatar(
                        backgroundColor: groupColor.withOpacity(0.15),
                        child: Text(
                          (user['full_name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(color: groupColor),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    text: 'บันทึก',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updateGroupUsers(group['id'], groupUserIds.toList());
                    },
                    backgroundColor: groupColor,
                    icon: Icons.save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// แปลง HEX string เป็น Color
  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4CAF50);
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return const Color(0xFF4CAF50);
    }
  }

  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }


  void _showGroupUsersDialog(Map<String, dynamic> group) {
    setState(() {
      _selectedGroup = group;
    });

    // หาผู้ใช้ที่อยู่ในกลุ่มนี้
    final groupUserIds = _permissions
        .where((p) => p['group_id'] == group['id'])
        .map((p) => p['user_id'].toString())
        .toSet();

    final groupUsers = _users
        .where((u) => groupUserIds.contains(u['id'].toString()))
        .toList();

    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'ผู้ใช้ในกลุ่ม',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Group Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFF2E7D32),
                    child: Icon(
                      Icons.group,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['group_name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (group['group_description'] != null)
                          Text(
                            group['group_description'],
                            style: TextStyle(
                              color: Colors.grey[600],
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

            // Users List
            Text(
              'ผู้ใช้ที่มีสิทธิ์ในกลุ่มนี้ (${groupUsers.length} คน):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              constraints: BoxConstraints(maxHeight: 300),
              child: groupUsers.isEmpty
                  ? Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ยังไม่มีผู้ใช้ในกลุ่มนี้',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: groupUsers.length,
                      itemBuilder: (context, index) {
                        final user = groupUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(0xFF2E7D32).withOpacity(0.1),
                            child: Text(
                              (user['full_name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(user['full_name'] ?? 'ไม่ระบุชื่อ'),
                          subtitle: Text(user['email'] ?? ''),
                          trailing: Icon(Icons.person, color: Color(0xFF2E7D32)),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),

            // Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassButton(
                  text: 'ปิด',
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// แสดง Dialog จัดการสิทธิ์การเข้าถึงหน้าต่างๆ ของกลุ่ม
  void _showPagePermissionsDialog(Map<String, dynamic> group) {
    final groupColor = _hexToColor(group['color']);
    
    // โหลดสิทธิ์ปัจจุบันของกลุ่มจาก _pagePermissions
    final groupPagePermissions = _pagePermissions
        .where((p) => p['group_id'] == group['id'] && p['can_access'] == true)
        .map((p) => p['page_id'] as String)
        .toList();
    final selectedPages = Set<String>.from(groupPagePermissions);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'กำหนดสิทธิ์การเข้าถึง',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group Info Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: groupColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: groupColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['group_name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _darkenColor(groupColor, 0.2),
                            ),
                          ),
                          Text(
                            'เลือกหน้าที่กลุ่มนี้สามารถเข้าถึงได้',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Page List with Checkboxes
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _systemPages.length,
                  itemBuilder: (context, index) {
                    final page = _systemPages[index];
                    final hasPermission = selectedPages.contains(page['id']);
                    
                    return CheckboxListTile(
                      value: hasPermission,
                      activeColor: groupColor,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedPages.add(page['id'] as String);
                          } else {
                            selectedPages.remove(page['id']);
                          }
                        });
                      },
                      title: Text(
                        page['name'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'ปุ่ม: ${page['button']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      secondary: hasPermission 
                        ? Icon(Icons.check_circle, color: groupColor)
                        : Icon(Icons.circle_outlined, color: Colors.grey[400]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    text: 'บันทึก',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _updatePagePermissions(
                        group['id'], 
                        selectedPages.toList(),
                      );
                    },
                    backgroundColor: groupColor,
                    icon: Icons.save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// อัปเดตสิทธิ์การเข้าถึงหน้าต่างๆ ของกลุ่ม
  /// ใช้ตาราง group_page_permissions
  Future<void> _updatePagePermissions(String groupId, List<String> pageIds) async {
    try {
      // ลบสิทธิ์เดิมทั้งหมดของกลุ่มนี้
      await SupabaseService.client
          .from('group_page_permissions')
          .delete()
          .eq('group_id', groupId);

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      // เพิ่มสิทธิ์ใหม่
      for (final pageId in pageIds) {
        await SupabaseService.client.from('group_page_permissions').insert({
          'group_id': groupId,
          'page_id': pageId,
          'can_access': true,
          'assigned_by': currentUser.id,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกสิทธิ์การเข้าถึงสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถบันทึกสิทธิ์: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.white),
            SizedBox(width: 8),
            Text('จัดการสิทธิ์ผู้ใช้', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Color(0xFF2E7D32),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFF1F8E9),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'บทบาทและสิทธิ์',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'จัดการบทบาทและกำหนดสิทธิ์การเข้าถึง',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showGroupPermissionDialog(
                      _userGroups.isNotEmpty ? _userGroups.first : {},
                    ),
                    icon: Icon(Icons.add, size: 18),
                    label: Text('เพิ่มบทบาท'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8E24AA),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              GlassButton(
                                text: 'ลองใหม่',
                                onPressed: _loadData,
                                backgroundColor: Color(0xFF2E7D32),
                              ),
                            ],
                          ),
                        )
                      : _buildGroupsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab() {
    // Filter groups based on search query
    final filteredGroups = _userGroups.where((group) {
      final searchLower = _groupSearchQuery.toLowerCase();
      final groupName = (group['group_name'] ?? '').toLowerCase();
      final description = (group['group_description'] ?? '').toLowerCase();
      return groupName.contains(searchLower) || description.contains(searchLower);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextField(
            controller: _groupSearchController,
            onChanged: (value) {
              setState(() {
                _groupSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'ค้นหากลุ่ม...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              suffixIcon: _groupSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _groupSearchController.clear();
                        setState(() {
                          _groupSearchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        // Results count
        if (filteredGroups.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'พบ ${filteredGroups.length} กลุ่ม',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // Group Cards Grid
        Expanded(
          child: filteredGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _groupSearchQuery.isEmpty ? Icons.group_off : Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _groupSearchQuery.isEmpty
                            ? 'ยังไม่มีกลุ่มผู้ใช้'
                            : 'ไม่พบกลุ่มที่ค้นหา',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 1000
                        ? 3
                        : width >= 720
                            ? 2
                            : 1;
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: filteredGroups.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: crossAxisCount == 1 ? 1.8 : 1.5,
                      ),
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        return _buildGroupCard(group);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final groupUserIds = _permissions
        .where((p) => p['group_id'] == group['id'])
        .map((p) => p['user_id'].toString())
        .toSet();
    final groupUsers = _users
        .where((u) => groupUserIds.contains(u['id'].toString()))
        .toList();

    final groupColor = _hexToColor(group['color']);
    final headerColor = _darkenColor(groupColor, 0.15);
    final userItems = groupUsers
        .map((user) => (user['full_name'] ?? user['email'] ?? 'ไม่ระบุชื่อ').toString())
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [headerColor, groupColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.group, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['group_name'] ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${groupUsers.length} ผู้ใช้',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'ผู้ใช้ในกลุ่ม:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: userItems.isEmpty
                ? Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'ยังไม่มีผู้ใช้ในกลุ่ม',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...userItems
                          .take(3)
                          .map(
                            (item) => Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: groupColor, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      if (userItems.length > 3)
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            '+${userItems.length - 3} คนเพิ่มเติม',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPagePermissionsDialog(group),
                    icon: Icon(Icons.edit, size: 16, color: groupColor),
                    label: Text('แก้ไข', style: TextStyle(color: groupColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: groupColor.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showGroupUsersDialog(group),
                    icon: Icon(Icons.people, size: 16, color: headerColor),
                    label: Text('สมาชิก', style: TextStyle(color: headerColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: headerColor.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
