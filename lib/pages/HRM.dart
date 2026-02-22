import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/user_group_service.dart';
import '../utils/permission_helpers.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_button.dart';
import 'user_permissions_page.dart';
import 'group_form_manager_page.dart';

class HRMPage extends StatefulWidget {
  const HRMPage({super.key});

  @override
  State<HRMPage> createState() => _HRMPageState();
}

class _HRMPageState extends State<HRMPage> {
  final _groupNameController = TextEditingController();
  final _groupDescriptionController = TextEditingController();
  
  // สีที่เลือกสำหรับกลุ่ม (default สีเขียว)
  Color _selectedColor = Color(0xFF4CAF50);
  
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _userGroups = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _permissions = [];
  Map<String, dynamic>? _selectedGroup;
  int? _currentUserSortOrder;

  // รายการสีที่แนะนำ
  final List<Color> _presetColors = [
    Color(0xFF4CAF50), // เขียว
    Color(0xFF2196F3), // ฟ้า
    Color(0xFFFF9800), // ส้ม
    Color(0xFFE91E63), // ชมพู
    Color(0xFF9C27B0), // ม่วง
    Color(0xFF00BCD4), // ฟ้าอมเขียว
    Color(0xFFFF5722), // ส้มแดง
    Color(0xFF795548), // น้ำตาล
    Color(0xFF607D8B), // น้ำเงินเทา
    Color(0xFFFFEB3B), // เหลือง
    Color(0xFF8BC34A), // เขียวอ่อน
    Color(0xFF3F51B5), // น้ำเงินเข้ม
    Color(0xFF009688), // ฟ้าเขียว
    Color(0xFFCDDC39), // มะนาว
    Color(0xFF673AB7), // ม่วงเข้ม
    Color(0xFFFFC107), // ทอง
    Color(0xFF03A9F4), // ฟ้าสว่าง
    Color(0xFF9E9E9E), // เทา
    Color(0xFF424242), // เทาเข้ม
    Color(0xFFE040FB), // ม่วงสด
    Color(0xFF00E676), // เขียวสด
    Color(0xFF2979FF), // ฟ้าน้ำทะเล
    Color(0xFFFF6E40), // ส้มอิฐ
    Color(0xFFC62828), // แดงเข้ม
  ];

  /// แปลง Color เป็น HEX string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  /// แปลง HEX string เป็น Color
  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Color(0xFF4CAF50);
    }
  }

  /// ทำให้สีเข้มขึ้น
  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// ตรวจสอบว่าสีซ้ำหรือไม่
  bool _isColorDuplicate(String colorHex, {String? excludeGroupId}) {
    for (final group in _userGroups) {
      if (excludeGroupId != null && group['id'] == excludeGroupId) continue;
      
      final existingColor = group['color'];
      if (existingColor != null) {
        final normalizedExisting = existingColor.toString().toUpperCase().replaceAll('#', '');
        final normalizedNew = colorHex.toUpperCase().replaceAll('#', '');
        if (normalizedExisting == normalizedNew) return true;
      }
    }
    return false;
  }

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
      final groupsResponse = await SupabaseService.client
          .from('user_groups')
          .select('*')
          .order('sort_order', ascending: true);

      // โหลดข้อมูลผู้ใช้ (สำหรับนับสมาชิก - ไม่กรอง is_active เพราะ user_group_members ไม่มีข้อมูล is_active)
      final usersResponse = await SupabaseService.client
          .from('user_profiles')
          .select('*');
      
      print('📋 Raw usersResponse: $usersResponse');
      print('📋 usersResponse length: ${usersResponse.length}');
      if (usersResponse.isNotEmpty) {
        print('📋 First user: ${usersResponse.first}');
      }

      // โหลดข้อมูล members (user-group mapping)
      final permissionsResponse = await SupabaseService.client
          .from('user_group_members')
          .select('*');

      print('📊 Groups: ${groupsResponse.length}, Users: ${usersResponse.length}, Permissions: ${permissionsResponse.length}');
      
      // โหลด sort_order ของกลุ่มผู้ใช้ปัจจุบัน
      final currentSortOrder = await UserGroupService.getCurrentUserSortOrder();

      setState(() {
        _userGroups = List<Map<String, dynamic>>.from(groupsResponse);
        _users = List<Map<String, dynamic>>.from(usersResponse);
        _permissions = List<Map<String, dynamic>>.from(permissionsResponse);
        _currentUserSortOrder = currentSortOrder;
        
        // เรียงลำดับกลุ่มตาม sort_order (น้อยไปมาก = สิทธิ์สูงไปต่ำ)
        _userGroups.sort((a, b) {
          final orderA = (a['sort_order'] as int?) ?? 999;
          final orderB = (b['sort_order'] as int?) ?? 999;
          return orderA.compareTo(orderB);
        });
        
        print('✅ Loaded ${_userGroups.length} groups (sorted by sort_order), current user sort_order: $currentSortOrder');
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

    // ตรวจสอบว่าสีซ้ำหรือไม่
    final colorHex = _colorToHex(_selectedColor);
    final isDuplicate = _isColorDuplicate(colorHex);
    if (isDuplicate) {
      setState(() {
        _errorMessage = 'สีนี้ถูกใช้งานโดยกลุ่มอื่นแล้ว กรุณาเลือกสีอื่น';
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

      final groupName = _groupNameController.text.trim();

      await SupabaseService.client.from('user_groups').insert({
        'group_name': groupName,
        'group_description': _groupDescriptionController.text.trim(),
        'color': colorHex,
        'created_by': currentUser.id,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });

      _groupNameController.clear();
      _groupDescriptionController.clear();
      _selectedColor = Color(0xFF4CAF50); // reset to default
      Navigator.of(context).pop();
      
      setState(() {
        _successMessage = 'สร้างกลุ่มผู้ใช้สำเร็จ';
        _isCreating = false;
      });
      
      _loadUserGroups();
      
      // แสดง success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สร้างกลุ่ม "${groupName}" สำเร็จ'),
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
    // Clear controllers for empty fields
    _groupNameController.clear();
    _groupDescriptionController.clear();
    
    setState(() {
      _errorMessage = null;
      _selectedColor = Color(0xFF4CAF50); // default color
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'สร้างกลุ่มผู้ใช้ใหม่',
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อกลุ่มผู้ใช้งาน',
                    hintText: 'เช่น แอดมิน, พนักงาน, ผู้จัดการ, ลูกค้า, Partner',
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
                    labelText: 'รายละเอียด',
                    hintText: 'อธิบายหน้าที่ / ความรับผิดชอบ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                // Color Picker Section - Show only unused colors
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เลือกสีประจำกลุ่ม (แสดงเฉพาะสีที่ยังไม่ถูกใช้)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presetColors
                            .where((color) => !_isColorDuplicate(_colorToHex(color)))
                            .map((color) {
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                _selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, color: Colors.white, size: 24)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      // แสดงสีที่เลือก
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'สีที่เลือก: ${_colorToHex(_selectedColor)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
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

  void _showSortGroupsDialog() {
    // ...
    bool isSaving = false;
    final sortableGroups = List<Map<String, dynamic>>.from(_userGroups)
      ..sort((a, b) {
        final orderA = (a['sort_order'] as int?) ?? 999;
        final orderB = (b['sort_order'] as int?) ?? 999;
        return orderA.compareTo(orderB);
      });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'จัดลำดับกลุ่มผู้ใช้',
          child: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.deepPurple[400], size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ลำดับที่สูงกว่า (ตัวเลขน้อย) = สิทธิ์มากกว่า\nลากเพื่อเปลี่ยนลำดับ',
                          style: TextStyle(fontSize: 12, color: Colors.deepPurple[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: sortableGroups.length,
                    onReorder: (oldIndex, newIndex) {
                      setDialogState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = sortableGroups.removeAt(oldIndex);
                        sortableGroups.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final group = sortableGroups[index];
                      final groupColor = _hexToColor(group['color'] ?? '#4CAF50');
                      return Container(
                        key: ValueKey(group['id']),
                        margin: EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: groupColor.withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: groupColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            group['group_name'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_getActiveMemberCount(group['id'])} สมาชิก',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Icon(Icons.drag_handle, color: Colors.grey[400]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text('ยกเลิก'),
                ),
                const SizedBox(width: 12),
                GlassButton(
                  text: isSaving ? 'กำลังบันทึก...' : 'บันทึกลำดับ',
                  onPressed: isSaving ? null : () async {
                    setDialogState(() => isSaving = true);
                    
                    // สร้าง list ของ sort_order ใหม่
                    final sortOrders = <Map<String, dynamic>>[];
                    for (int i = 0; i < sortableGroups.length; i++) {
                      sortOrders.add({
                        'id': sortableGroups[i]['id'],
                        'sort_order': i + 1,
                      });
                    }
                    
                    final success = await UserGroupService.updateGroupSortOrders(sortOrders);
                    
                    if (success) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('บันทึกลำดับกลุ่มสำเร็จ'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadUserGroups();
                    } else {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ไม่สามารถบันทึกลำดับกลุ่มได้'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  backgroundColor: Colors.deepPurple[600]!,
                  icon: Icons.save,
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

    final groupColor = _hexToColor(group['color'] ?? '#4CAF50');

    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        title: 'รายละเอียดกลุ่ม',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color indicator at top
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: groupColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: groupColor, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: groupColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: groupColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.group, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['group_name'] ?? '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: groupColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'สีประจำกลุ่ม: ${group['color'] ?? '#4CAF50'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                    checkPermissionAndExecute(context, 'user_groups_delete', 'ลบกลุ่ม', () => _deleteUserGroup(group['id']));
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

    // ตรวจสอบว่าสีซ้ำหรือไม่
    final colorHex = _colorToHex(_selectedColor);
    final isDuplicate = _isColorDuplicate(colorHex, excludeGroupId: groupId);
    if (isDuplicate) {
      setState(() {
        _errorMessage = 'สีนี้ถูกใช้งานโดยกลุ่มอื่นแล้ว กรุณาเลือกสีอื่น';
      });
      return;
    }

    try {
      await SupabaseService.client
          .from('user_groups')
          .update({
            'group_name': _groupNameController.text.trim(),
            'group_description': _groupDescriptionController.text.trim(),
            'color': colorHex,
          })
          .eq('id', groupId);

      _groupNameController.clear();
      _groupDescriptionController.clear();
      _selectedColor = Color(0xFF4CAF50);
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
    _selectedColor = _hexToColor(group['color'] ?? '#4CAF50');
    
    setState(() {
      _errorMessage = null;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassDialog(
          title: 'แก้ไขกลุ่มผู้ใช้',
          child: SingleChildScrollView(
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
                    labelText: 'รายละเอียด',
                    hintText: 'อธิบายหน้าที่และความรับผิดชอบ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                // Color Picker Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เลือกสีประจำกลุ่ม',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presetColors.map((color) {
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                _selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, color: Colors.white, size: 24)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'สีที่เลือก: ${_colorToHex(_selectedColor)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                      onPressed: () => checkPermissionAndExecute(context, 'user_groups_edit', 'แก้ไขกลุ่ม', () => _updateUserGroup(group['id'])),
                      backgroundColor: Color(0xFF2E7D32),
                      icon: Icons.save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateGroupStatus(String groupId, bool isActive) async {
    try {
      await SupabaseService.client
          .from('user_groups')
          .update({'is_active': isActive})
          .eq('id', groupId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'เปิดใช้งานกลุ่มสำเร็จ' : 'ปิดใช้งานกลุ่มสำเร็จ'),
          backgroundColor: isActive ? Colors.green : Colors.orange,
        ),
      );

      _loadUserGroups();
    } catch (e) {
      print('❌ Error updating group status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดตสถานะกลุ่ม: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.group, color: Colors.white),
              SizedBox(width: 8),
              Text('HRM', style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'สถิติ'),
              Tab(text: 'กลุ่มและสิทธิ์'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStatisticsTab(),
            _buildGroupsAndPermissionsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFE8F5E8),
            child: const TabBar(
              isScrollable: true,
              labelColor: Color(0xFF2E7D32),
              unselectedLabelColor: Colors.black54,
              indicatorColor: Color(0xFF2E7D32),
              tabs: [
                Tab(text: 'เข้า-ออกงาน'),
                Tab(text: 'ตารางงาน'),
                Tab(text: 'ค่าตอบแทน'),
                Tab(text: 'แจ้งปัญหา'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStatsPlaceholder('เข้า-ออกงาน'),
                _buildStatsPlaceholder('ตารางงาน'),
                _buildStatsPlaceholder('ค่าตอบแทน'),
                _buildStatsPlaceholder('แจ้งปัญหา'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Text(
            'ส่วน$title',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'อยู่ระหว่างพัฒนา',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsAndPermissionsTab() {
    return Container(
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
                    opacity: 0.85, // เพิ่มความทึบให้เห็นชัด
                    blurStrength: 5,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    text: 'จัดการฟอร์มกลุ่ม',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GroupFormManagerPage(),
                      ),
                    ),
                    backgroundColor: Colors.blueGrey[700]!,
                    textColor: Colors.white,
                    icon: Icons.format_list_bulleted,
                    width: double.infinity,
                    opacity: 0.85,
                    blurStrength: 5,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    text: 'จัดลำดับกลุ่ม',
                    onPressed: () => checkPermissionAndExecute(
                      context,
                      'user_groups_sort_order',
                      'จัดลำดับกลุ่ม',
                      () => _showSortGroupsDialog(),
                    ),
                    backgroundColor: Colors.deepPurple[600]!,
                    textColor: Colors.white,
                    icon: Icons.swap_vert,
                    width: double.infinity,
                    opacity: 0.85,
                    blurStrength: 5,
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoader()
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
                                itemCount: _userGroups.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: crossAxisCount == 1 ? 1.9 : 1.7,
                                ),
                                itemBuilder: (context, index) {
                                  final group = _userGroups[index];
                                  return _buildGroupCard(group);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  /// นับจำนวนสมาชิกในกลุ่ม (จาก user_group_members โดยตรง)
  int _getActiveMemberCount(String groupId) {
    // นับจำนวน user_ids ที่อยู่ในกลุ่มนี้จาก permissions (user_group_members)
    final count = _permissions
        .where((p) => p['group_id'] == groupId)
        .length;
    
    return count;
  }

  Widget _buildSkeletonLoader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1000
            ? 3
            : width >= 720
                ? 2
                : 1;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 1.9 : 1.7,
          ),
          itemBuilder: (context, index) {
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skeleton Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 60,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Skeleton Buttons
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final groupColor = _hexToColor(group['color']);
    final headerColor = _darkenColor(groupColor, 0.15);
    final groupSortOrder = (group['sort_order'] as int?) ?? 999;
    // ลำดับที่ 1 จัดการได้ทุกกลุ่ม, ลำดับอื่นจัดการได้เฉพาะกลุ่มที่ sort_order สูงกว่า
    final canManageThisGroup = _currentUserSortOrder != null && 
        (_currentUserSortOrder == 1 || groupSortOrder > _currentUserSortOrder!);

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
          // Header with gradient
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
                        '${_getActiveMemberCount(group['id'])} สมาชิก',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status dropdown in header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<bool>(
                      value: group['is_active'] == true,
                      isDense: true,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 18,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 14),
                              SizedBox(width: 6),
                              Text('ใช้งาน', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red, size: 14),
                              SizedBox(width: 6),
                              Text('ไม่ใช้งาน', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: canManageThisGroup ? (value) {
                        if (value != null) {
                          _updateGroupStatus(group['id'], value);
                        }
                      } : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Description - removed to save space
          // Members list - removed to save space, count shown in header
          // Action buttons - compact
          // Sort order badge
          if (group['sort_order'] != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.swap_vert, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    'ลำดับ: ${group['sort_order']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (!canManageThisGroup) ...[
                    Spacer(),
                    Icon(Icons.lock, size: 12, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text(
                      'ไม่สามารถจัดการได้',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ],
                ],
              ),
            ),
          // Action buttons - compact
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canManageThisGroup ? () => _showEditGroupDialog(group) : null,
                    icon: Icon(Icons.edit, size: 14, color: canManageThisGroup ? groupColor : Colors.grey[400]),
                    label: Text('แก้ไข', style: TextStyle(color: canManageThisGroup ? groupColor : Colors.grey[400], fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: canManageThisGroup ? groupColor.withOpacity(0.4) : Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canManageThisGroup ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserPermissionsPage(
                            initialGroup: group,
                          ),
                        ),
                      );
                    } : null,
                    icon: Icon(Icons.security, size: 14, color: canManageThisGroup ? headerColor : Colors.grey[400]),
                    label: Text('กำหนดสิทธิ์', style: TextStyle(color: canManageThisGroup ? headerColor : Colors.grey[400], fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: canManageThisGroup ? headerColor.withOpacity(0.4) : Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
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
