import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_button.dart';

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
  Map<String, dynamic>? _selectedUser;
  Map<String, dynamic>? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // โหลดข้อมูลผู้ใช้
      final usersResponse = await SupabaseService.client
          .from('user_profiles')
          .select('*')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      // โหลดข้อมูลกลุ่มผู้ใช้
      final groupsResponse = await SupabaseService.client
          .from('user_groups')
          .select('*')
          .eq('is_active', true)
          .order('group_name', ascending: true);

      // โหลดข้อมูล permissions
      final permissionsResponse = await SupabaseService.client
          .from('user_permissions')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(usersResponse);
        _userGroups = List<Map<String, dynamic>>.from(groupsResponse);
        _permissions = List<Map<String, dynamic>>.from(permissionsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserPermissions(String userId, List<String> groupIds) async {
    try {
      // ลบ permissions เก่าทั้งหมด
      await SupabaseService.client
          .from('user_permissions')
          .delete()
          .eq('user_id', userId);

      // เพิ่ม permissions ใหม่
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      for (final groupId in groupIds) {
        await SupabaseService.client.from('user_permissions').insert({
          'user_id': userId,
          'group_id': groupId,
          'assigned_by': currentUser.id,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตสิทธิ์ผู้ใช้สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดตสิทธิ์: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserPermissionDialog(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
    });

    // หากลุ่มที่ผู้ใช้มีอยู่แล้ว
    final userGroupIds = _permissions
        .where((p) => p['user_id'] == user['id'])
        .map((p) => p['group_id'].toString())
        .toSet();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'กำหนดสิทธิ์ผู้ใช้',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Info
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
                      child: Text(
                        (user['full_name'] ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['full_name'] ?? 'ไม่ระบุชื่อ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            user['email'] ?? '',
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

              // Group Selection
              Text(
                'เลือกกลุ่มที่ผู้ใช้สามารถเข้าถึงได้:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              // Group List
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _userGroups.length,
                  itemBuilder: (context, index) {
                    final group = _userGroups[index];
                    final isSelected = userGroupIds.contains(group['id'].toString());

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            userGroupIds.add(group['id'].toString());
                          } else {
                            userGroupIds.remove(group['id'].toString());
                          }
                        });
                      },
                      title: Text(
                        group['group_name'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: group['group_description'] != null
                          ? Text(
                              group['group_description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      secondary: CircleAvatar(
                        backgroundColor: Color(0xFF2E7D32).withOpacity(0.1),
                        child: Icon(
                          Icons.group,
                          color: Color(0xFF2E7D32),
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

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
                      _updateUserPermissions(user['id'], userGroupIds.toList());
                    },
                    backgroundColor: Color(0xFF2E7D32),
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
              padding: EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สิทธิ์การใช้งานผู้ใช้',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กำหนดและจัดการสิทธิ์การเข้าถึงของผู้ใช้งานแต่ละคน',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Stats Cards
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'ผู้ใช้ทั้งหมด',
                      _users.length.toString(),
                      Icons.person,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'กลุ่มผู้ใช้',
                      _userGroups.length.toString(),
                      Icons.group,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'การมอบสิทธิ์',
                      _permissions.length.toString(),
                      Icons.security,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      text: 'รีเฟรชข้อมูล',
                      onPressed: _loadData,
                      backgroundColor: Color(0xFF2E7D32),
                      icon: Icons.refresh,
                      width: double.infinity,
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
                      : DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              // Tab Bar
                              Container(
                                margin: EdgeInsets.all(20),
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
                                child: TabBar(
                                  labelColor: Color(0xFF2E7D32),
                                  unselectedLabelColor: Colors.grey[600],
                                  indicatorColor: Color(0xFF2E7D32),
                                  indicatorWeight: 3,
                                  tabs: [
                                    Tab(
                                      icon: Icon(Icons.person),
                                      text: 'ผู้ใช้',
                                    ),
                                    Tab(
                                      icon: Icon(Icons.group),
                                      text: 'กลุ่ม',
                                    ),
                                  ],
                                ),
                              ),

                              // Tab Views
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildUsersTab(),
                                    _buildGroupsTab(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildUsersTab() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: _users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีผู้ใช้ในระบบ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return _buildUserCard(user);
              },
            ),
    );
  }

  Widget _buildGroupsTab() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: _userGroups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีกลุ่มผู้ใช้',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _userGroups.length,
              itemBuilder: (context, index) {
                final group = _userGroups[index];
                return _buildGroupCard(group);
              },
            ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    // หากลุ่มที่ผู้ใช้มี
    final userPermissions = _permissions
        .where((p) => p['user_id'] == user['id'])
        .toList();

    final groupNames = userPermissions
        .map((p) {
          final group = _userGroups.firstWhere(
            (g) => g['id'] == p['group_id'],
            orElse: () => {'group_name': 'Unknown'},
          );
          return group['group_name'] as String;
        })
        .where((name) => name != 'Unknown')
        .toList();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
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
        title: Text(
          user['full_name'] ?? 'ไม่ระบุชื่อ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              user['email'] ?? '',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            if (groupNames.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: groupNames
                    .take(3) // แสดงสูงสุด 3 กลุ่ม
                    .map((groupName) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            groupName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            if (groupNames.length > 3)
              Text(
                '+${groupNames.length - 3} กลุ่มเพิ่มเติม',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            if (groupNames.isEmpty)
              Text(
                'ยังไม่มีสิทธิ์',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'permissions') {
              _showUserPermissionDialog(user);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'permissions',
              child: Row(
                children: [
                  Icon(Icons.security, size: 18),
                  SizedBox(width: 8),
                  Text('จัดการสิทธิ์'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showUserPermissionDialog(user),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    // หาผู้ใช้ที่อยู่ในกลุ่มนี้
    final groupUserIds = _permissions
        .where((p) => p['group_id'] == group['id'])
        .map((p) => p['user_id'].toString())
        .toSet();

    final groupUsers = _users
        .where((u) => groupUserIds.contains(u['id'].toString()))
        .toList();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Color(0xFF2E7D32).withOpacity(0.1),
          child: Icon(
            Icons.group,
            color: Color(0xFF2E7D32),
          ),
        ),
        title: Text(
          group['group_name'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (group['group_description'] != null)
              Text(
                group['group_description'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 4),
                Text(
                  '${groupUsers.length} ผู้ใช้',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view_users') {
              _showGroupUsersDialog(group);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view_users',
              child: Row(
                children: [
                  Icon(Icons.people, size: 18),
                  SizedBox(width: 8),
                  Text('ดูผู้ใช้ในกลุ่ม'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showGroupUsersDialog(group),
      ),
    );
  }
}
