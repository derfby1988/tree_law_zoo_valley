import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_button.dart';

class UserGroupsPage extends StatefulWidget {
  const UserGroupsPage({super.key});

  @override
  State<UserGroupsPage> createState() => _UserGroupsPageState();
}

class _UserGroupsPageState extends State<UserGroupsPage> {
  final _groupNameController = TextEditingController();
  final _groupDescriptionController = TextEditingController();
  
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _userGroups = [];
  Map<String, dynamic>? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 Loading user groups...');
      final response = await SupabaseService.client
          .from('user_groups')
          .select('*')
          .order('created_at', ascending: false);

      print('📊 Response: $response');
      print('📊 Response type: ${response.runtimeType}');
      
      setState(() {
        _userGroups = List<Map<String, dynamic>>.from(response);
        print('✅ Loaded ${_userGroups.length} groups');
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading user groups: $e');
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลกลุ่มผู้ใช้: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createUserGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกชื่อกลุ่ม';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      await SupabaseService.client.from('user_groups').insert({
        'group_name': _groupNameController.text.trim(),
        'group_description': _groupDescriptionController.text.trim(),
        'created_by': currentUser.id,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });

      _groupNameController.clear();
      _groupDescriptionController.clear();
      Navigator.of(context).pop();
      
      setState(() {
        _successMessage = 'สร้างกลุ่มผู้ใช้สำเร็จ';
      });
      
      _loadUserGroups();
      
      // แสดง success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สร้างกลุ่ม "${_groupNameController.text}" สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถสร้างกลุ่มผู้ใช้: $e';
        _isCreating = false;
      });
    }
  }

  Future<void> _deleteUserGroup(String groupId) async {
    try {
      await SupabaseService.client
          .from('user_groups')
          .delete()
          .eq('id', groupId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบกลุ่มผู้ใช้สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadUserGroups();
    } catch (e) {
      print('❌ Error deleting group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถลบกลุ่มผู้ใช้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateGroupDialog() {
    setState(() {
      _errorMessage = null;
    });

    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'สร้างกลุ่มผู้ใช้ใหม่',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อกลุ่ม',
                hintText: 'เช่น แอดมิน, พนักงาน, ผู้จัดการ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupDescriptionController,
              decoration: InputDecoration(
                labelText: 'รายละเอียดกลุ่ม',
                hintText: 'อธิบายหน้าที่และความรับผิดชอบ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('ยกเลิก'),
                ),
                const SizedBox(width: 12),
                GlassButton(
                  text: 'สร้างกลุ่ม',
                  onPressed: _isCreating ? null : _createUserGroup,
                  backgroundColor: Color(0xFF2E7D32),
                  icon: Icons.group_add,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDetails(Map<String, dynamic> group) {
    setState(() {
      _selectedGroup = group;
    });

    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'รายละเอียดกลุ่ม',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('ชื่อกลุ่ม', group['group_name'] ?? ''),
            _buildDetailRow('รายละเอียด', group['group_description'] ?? '-'),
            _buildDetailRow('สถานะ', group['is_active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'),
            _buildDetailRow(
              'สร้างเมื่อ',
              group['created_at'] != null 
                  ? _formatDate(group['created_at']) 
                  : '-',
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('ปิด'),
                ),
                const SizedBox(width: 12),
                GlassButton(
                  text: 'ลบกลุ่ม',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteUserGroup(group['id']);
                  },
                  backgroundColor: Colors.red,
                  icon: Icons.delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUserGroup(String groupId) async {
    if (_groupNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกชื่อกลุ่ม';
      });
      return;
    }

    try {
      await SupabaseService.client
          .from('user_groups')
          .update({
            'group_name': _groupNameController.text.trim(),
            'group_description': _groupDescriptionController.text.trim(),
          })
          .eq('id', groupId);

      _groupNameController.clear();
      _groupDescriptionController.clear();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('แก้ไขกลุ่มสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      _loadUserGroups();
    } catch (e) {
      print('❌ Error updating group: $e');
      setState(() {
        _errorMessage = 'ไม่สามารถแก้ไขกลุ่ม: $e';
      });
    }
  }

  void _showEditGroupDialog(Map<String, dynamic> group) {
    _groupNameController.text = group['group_name'] ?? '';
    _groupDescriptionController.text = group['group_description'] ?? '';
    
    setState(() {
      _errorMessage = null;
    });

    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'แก้ไขกลุ่มผู้ใช้',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อกลุ่ม',
                hintText: 'เช่น แอดมิน, พนักงาน, ผู้จัดการ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupDescriptionController,
              decoration: InputDecoration(
                labelText: 'รายละเอียดกลุ่ม',
                hintText: 'อธิบายหน้าที่และความรับผิดชอบ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
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
                  onPressed: () => _updateUserGroup(group['id']),
                  backgroundColor: Color(0xFF2E7D32),
                  icon: Icons.save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.group, color: Colors.white),
            SizedBox(width: 8),
            Text('จัดการกลุ่มผู้ใช้', style: TextStyle(color: Colors.white)),
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
                    'กลุ่มผู้ใช้งาน',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'จัดการกลุ่มและประเภทของผู้ใช้งานในระบบ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      text: 'สร้างกลุ่มใหม่',
                      onPressed: _showCreateGroupDialog,
                      backgroundColor: Color(0xFF2E7D32),
                      textColor: Colors.white,
                      icon: Icons.add,
                      width: double.infinity,
                      opacity: 0.85,  // เพิ่มความทึบให้เห็นชัด
                      blurStrength: 5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    text: 'รีเฟรช',
                    onPressed: _loadUserGroups,
                    backgroundColor: Colors.grey[700]!,
                    textColor: Colors.white,
                    icon: Icons.refresh,
                    opacity: 0.85,  // เพิ่มความทึบให้เห็นชัด
                    blurStrength: 5,
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
                                onPressed: _loadUserGroups,
                                backgroundColor: Color(0xFF2E7D32),
                              ),
                            ],
                          ),
                        )
                      : _userGroups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.group_outlined,
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
                                  const SizedBox(height: 8),
                                  Text(
                                    'กด "สร้างกลุ่มใหม่" เพื่อเริ่มต้น',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(20),
                              itemCount: _userGroups.length,
                              itemBuilder: (context, index) {
                                final group = _userGroups[index];
                                return _buildGroupCard(group);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
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
            Text(
              group['group_description'] ?? '-',
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
                  group['is_active'] == true ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: group['is_active'] == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  group['is_active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
                  style: TextStyle(
                    fontSize: 12,
                    color: group['is_active'] == true ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view') {
              _showGroupDetails(group);
            } else if (value == 'edit') {
              _showEditGroupDialog(group);
            } else if (value == 'delete') {
              _deleteUserGroup(group['id']);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 18),
                  SizedBox(width: 8),
                  Text('ดูรายละเอียด'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('แก้ไข'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('ลบ', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showGroupDetails(group),
      ),
    );
  }
}
