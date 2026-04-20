import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/approval_hierarchy_service.dart';
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
  bool _isApprovalLoading = false;
  String? _approvalErrorMessage;
  List<Map<String, dynamic>> _approvalRules = [];
  List<Map<String, dynamic>> _approvalProxies = [];
  List<Map<String, dynamic>> _approvalAuditLogs = [];
  bool _isProxyLoading = false;
  bool _isAuditLoading = false;
  String? _proxyErrorMessage;
  String? _auditErrorMessage;

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

  Future<void> _loadApprovalRules({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isApprovalLoading = true;
        _approvalErrorMessage = null;
      });
    } else {
      setState(() {
        _approvalErrorMessage = null;
      });
    }

    try {
      await ApprovalHierarchyService.seedDefaultRulesIfNeeded(_userGroups);
      final rules = await ApprovalHierarchyService.getRules();

      if (!mounted) return;
      setState(() {
        _approvalRules = rules;
        _isApprovalLoading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final isMissingTable = e.code == '42P01';
      setState(() {
        _approvalErrorMessage = isMissingTable
            ? 'ยังไม่พบตาราง approval_hierarchy_rules กรุณารัน migration ของ Approval Hierarchy ก่อนใช้งาน'
            : 'ไม่สามารถโหลดกฎอนุมัติ: ${e.message}';
        _isApprovalLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _approvalErrorMessage = 'ไม่สามารถโหลดกฎอนุมัติ: $e';
        _isApprovalLoading = false;
      });
    }
  }

  Future<void> _loadApprovalProxies({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isProxyLoading = true;
        _proxyErrorMessage = null;
      });
    } else {
      setState(() {
        _proxyErrorMessage = null;
      });
    }

    try {
      final response = await SupabaseService.client
          .from('approval_proxies')
          .select('*')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _approvalProxies = List<Map<String, dynamic>>.from(response);
        _isProxyLoading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final isMissingTable = e.code == '42P01';
      setState(() {
        _proxyErrorMessage = isMissingTable
            ? 'ยังไม่พบตาราง approval_proxies กรุณารัน migration ที่เกี่ยวข้องก่อน'
            : 'ไม่สามารถโหลด Proxy: ${e.message}';
        _isProxyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _proxyErrorMessage = 'ไม่สามารถโหลด Proxy: $e';
        _isProxyLoading = false;
      });
    }
  }

  Future<void> _loadApprovalAuditLogs({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isAuditLoading = true;
        _auditErrorMessage = null;
      });
    } else {
      setState(() {
        _auditErrorMessage = null;
      });
    }

    try {
      final response = await SupabaseService.client
          .from('procurement_po_approval_audit_logs')
          .select('''
            id,
            po_id,
            action,
            actor_user_id,
            actor_role,
            priority,
            message,
            created_at,
            po:procurement_purchase_orders(order_number)
          ''')
          .order('created_at', ascending: false)
          .limit(30);

      if (!mounted) return;
      setState(() {
        _approvalAuditLogs = List<Map<String, dynamic>>.from(response);
        _isAuditLoading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final isMissingTable = e.code == '42P01';
      setState(() {
        _auditErrorMessage = isMissingTable
            ? 'ยังไม่พบตาราง procurement_po_approval_audit_logs กรุณารัน migration ก่อน'
            : 'ไม่สามารถโหลดบันทึกการอนุมัติ: ${e.message}';
        _isAuditLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _auditErrorMessage = 'ไม่สามารถโหลดบันทึกการอนุมัติ: $e';
        _isAuditLoading = false;
      });
    }
  }

  Map<String, dynamic>? _getRuleForGroup(String groupId) {
    for (final rule in _approvalRules) {
      final mappedGroup = rule['group'] as Map<String, dynamic>?;
      final mappedGroupId = mappedGroup?['id']?.toString() ?? rule['group_id']?.toString();
      if (mappedGroupId == groupId) {
        return rule;
      }
    }
    return null;
  }

  Map<String, dynamic>? _findUserById(String? userId) {
    if (userId == null) return null;
    for (final user in _users) {
      if ((user['id']?.toString() ?? user['user_id']?.toString()) == userId) {
        return user;
      }
    }
    return null;
  }

  String _resolveUserName(String? userId) {
    final user = _findUserById(userId);
    if (user == null) {
      return userId ?? '-';
    }
    return user['full_name']?.toString() ??
        user['display_name']?.toString() ??
        user['email']?.toString() ??
        user['username']?.toString() ??
        userId ?? '-';
  }

  String _resolveUserEmail(String? userId) {
    final user = _findUserById(userId);
    if (user == null) {
      return '';
    }
    return user['email']?.toString() ?? '';
  }

  String _formatApprovalLimit(Map<String, dynamic>? rule) {
    if (rule == null) return 'ยังไม่กำหนด';
    final isUnlimited = rule['is_unlimited'] == true;
    if (isUnlimited) return 'ไม่จำกัดวงเงิน';

    final amount = (rule['max_amount'] as num?)?.toDouble();
    if (amount == null) return 'ยังไม่กำหนด';
    return '${amount.toStringAsFixed(0)} บาท';
  }

  String _buildCurrentBehaviorSummary(List<Map<String, dynamic>> groups) {
    final segments = <String>[];

    for (final group in groups) {
      final groupId = group['id']?.toString();
      if (groupId == null) continue;

      final rule = _getRuleForGroup(groupId);
      if (rule == null || rule['is_active'] != true) continue;

      final groupName = group['group_name']?.toString() ?? '-';
      final isUnlimited = rule['is_unlimited'] == true;
      final amount = (rule['max_amount'] as num?)?.toDouble();

      if (isUnlimited) {
        segments.add('$groupName ไม่จำกัด');
      } else if (amount != null) {
        segments.add('$groupName ≤ ${amount.toStringAsFixed(0)} บาท');
      }
    }

    if (segments.isEmpty) {
      return 'Current Behavior: ยังไม่พบกฎอนุมัติที่เปิดใช้งานในฐานข้อมูล';
    }

    return 'Current Behavior: ${segments.join(' · ')}';
  }

  String _buildProcurementUsageIndicator() {
    if (_approvalErrorMessage != null) {
      return 'สถานะเชื่อมโยง Procurement: ยังไม่พร้อมใช้งาน (โหลดกฎไม่สำเร็จ)';
    }

    final hasActiveRule = _approvalRules.any((rule) => rule['is_active'] == true);
    if (!hasActiveRule) {
      return 'สถานะเชื่อมโยง Procurement: ยังไม่พบกฎที่เปิดใช้งาน';
    }

    return 'สถานะเชื่อมโยง Procurement: เปิดใช้งานแล้ว (ใช้กฎจากตาราง approval_hierarchy_rules)';
  }

  Future<void> _showEditApprovalRuleDialog(Map<String, dynamic> group) async {
    final existingRule = _getRuleForGroup(group['id'] as String);
    bool isUnlimited = existingRule?['is_unlimited'] == true;
    bool isActive = existingRule == null ? true : existingRule['is_active'] == true;
    int priority = (existingRule?['priority'] as int?) ?? ((group['sort_order'] as int?) ?? 99);
    final amountController = TextEditingController(
      text: ((existingRule?['max_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('ตั้งกฎอนุมัติ: ${group['group_name'] ?? ''}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('เปิดใช้งานกฎนี้'),
                      value: isActive,
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('ไม่จำกัดวงเงิน'),
                      value: isUnlimited,
                      onChanged: (value) => setDialogState(() => isUnlimited = value),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      enabled: !isUnlimited,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'วงเงินอนุมัติสูงสุด (บาท)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'ลำดับอนุมัติ (Priority)',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(10, (index) => index + 1)
                          .map(
                            (value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('ลำดับ $value'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => priority = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final parsedAmount = double.tryParse(amountController.text.trim());
                    if (!isUnlimited && (parsedAmount == null || parsedAmount < 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณาระบุวงเงินที่ถูกต้อง'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      await ApprovalHierarchyService.upsertRule(
                        groupId: group['id'] as String,
                        isUnlimited: isUnlimited,
                        maxAmount: isUnlimited ? null : parsedAmount,
                        priority: priority,
                        isActive: isActive,
                      );

                      if (!mounted) return;
                      Navigator.of(context).pop(true);
                    } on PostgrestException catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('บันทึกไม่สำเร็จ: ${e.message}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('บันทึกไม่สำเร็จ: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await _loadApprovalRules();
    }
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

      final normalizedUsers = List<Map<String, dynamic>>.from(usersResponse).map((user) {
        final userId = user['user_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          return {
            ...user,
            'id': userId,
          };
        }
        return user;
      }).toList();

      setState(() {
        _userGroups = List<Map<String, dynamic>>.from(groupsResponse);
        _users = normalizedUsers;
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

      await _loadApprovalRules(showLoading: false);
      await _loadApprovalProxies(showLoading: false);
      await _loadApprovalAuditLogs(showLoading: false);
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

  Future<void> _updateGroupFlag(String groupId, String column, bool value) async {
    final label = column == 'is_customer_group'
        ? 'กลุ่มลูกค้า'
        : column == 'is_sales_staff_group'
            ? 'กลุ่มพนักงานขาย'
            : column;
    try {
      await SupabaseService.client
          .from('user_groups')
          .update({column: value})
          .eq('id', groupId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'เปิดใช้งาน $label สำเร็จ' : 'ปิดใช้งาน $label สำเร็จ'),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );

      _loadUserGroups();
    } catch (e) {
      print('❌ Error updating group flag: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถอัปเดต $label: $e'),
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

  Widget _buildProxySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ผู้อนุมัติสำรอง (Proxy Approver)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'รีเฟรช',
                onPressed: _isProxyLoading ? null : () => _loadApprovalProxies(),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: _showProxyDialog,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม Proxy'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'กำหนดผู้แทนอนุมัติในกรณีที่เจ้าของสิทธิติดภารกิจ โดยสามารถระบุช่วงเวลาที่อนุญาตและสถานะการใช้งาน',
            style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (_proxyErrorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Text(
                _proxyErrorMessage!,
                style: TextStyle(color: Colors.red[700]),
              ),
            )
          else if (_isProxyLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_approvalProxies.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ยังไม่มี Proxy',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'กด “เพิ่ม Proxy” เพื่อกำหนดผู้อนุมัติสำรองสำหรับแต่ละกลุ่ม',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _approvalProxies
                  .map((proxy) => _buildProxyCard(proxy))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProxyCard(Map<String, dynamic> proxy) {
    final ownerId = proxy['owner_user_id']?.toString();
    final proxyId = proxy['proxy_user_id']?.toString();
    final isActive = proxy['is_active'] != false;
    final startAt = proxy['start_at']?.toString();
    final endAt = proxy['end_at']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เจ้าของสิทธิ์: ${_resolveUserName(ownerId)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_resolveUserEmail(ownerId).isNotEmpty)
                      Text(
                        _resolveUserEmail(ownerId),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'ผู้แทน: ${_resolveUserName(proxyId)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: isActive,
                    onChanged: (value) => _toggleProxyActive(proxy, value),
                  ),
                  Text(
                    isActive ? 'เปิดใช้งาน' : 'ปิดอยู่',
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? Colors.green[800] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(Icons.calendar_today, 'เริ่ม: ${startAt != null ? _formatDate(startAt) : '-'}'),
              _buildInfoChip(Icons.event_available, 'สิ้นสุด: ${endAt != null ? _formatDate(endAt) : '-'}'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showProxyDialog(existingProxy: proxy),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('แก้ไข'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _deleteProxy(proxy),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('ลบ', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'บันทึกการอนุมัติล่าสุด',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'รีเฟรช',
                onPressed: _isAuditLoading ? null : () => _loadApprovalAuditLogs(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ตรวจสอบการเปลี่ยนสถานะการอนุมัติแต่ละขั้นเพื่อช่วยติดตามการทำงานย้อนหลังได้รวดเร็ว',
            style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (_auditErrorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Text(
                _auditErrorMessage!,
                style: TextStyle(color: Colors.red[700]),
              ),
            )
          else if (_isAuditLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_approvalAuditLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ยังไม่มีการบันทึกการอนุมัติในช่วงล่าสุด',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            Column(
              children: _approvalAuditLogs
                  .map((log) => _buildAuditLogTile(log))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAuditLogTile(Map<String, dynamic> log) {
    final poNumber = log['po']?['order_number']?.toString() ?? log['po_id']?.toString() ?? '-';
    final action = log['action']?.toString() ?? '-';
    final actorName = _resolveUserName(log['actor_user_id']?.toString());
    final message = log['message']?.toString();
    final createdAt = log['created_at']?.toString();

    IconData icon;
    Color color;
    if (action.toLowerCase().contains('approve')) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (action.toLowerCase().contains('reject') || action.toLowerCase().contains('cancel')) {
      icon = Icons.cancel;
      color = Colors.red;
    } else {
      icon = Icons.info;
      color = Colors.blueGrey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PO $poNumber • $action',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'โดย $actorName',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  createdAt != null ? _formatDate(createdAt) : '-',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProxyDialog({Map<String, dynamic>? existingProxy}) async {
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีข้อมูลผู้ใช้ กรุณาเพิ่มผู้ใช้ก่อนกำหนด Proxy')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String? ownerId = existingProxy?['owner_user_id']?.toString();
    String? proxyId = existingProxy?['proxy_user_id']?.toString();
    DateTime? startAt = existingProxy?['start_at'] != null
        ? DateTime.tryParse(existingProxy!['start_at'].toString())
        : null;
    DateTime? endAt = existingProxy?['end_at'] != null
        ? DateTime.tryParse(existingProxy!['end_at'].toString())
        : null;
    bool isActive = existingProxy?['is_active'] != false;
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingProxy == null ? 'เพิ่ม Proxy' : 'แก้ไข Proxy'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: ownerId,
                      decoration: const InputDecoration(
                        labelText: 'เจ้าของสิทธิ์ *',
                        border: OutlineInputBorder(),
                      ),
                      items: _users
                          .map(
                            (user) => DropdownMenuItem<String>(
                              value: (user['id'] ?? user['user_id']).toString(),
                              child: Text(_resolveUserName((user['id'] ?? user['user_id']).toString())),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(() => ownerId = value),
                      validator: (value) => value == null || value.isEmpty ? 'เลือกเจ้าของสิทธิ์' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: proxyId,
                      decoration: const InputDecoration(
                        labelText: 'ผู้แทน (Proxy) *',
                        border: OutlineInputBorder(),
                      ),
                      items: _users
                          .map(
                            (user) => DropdownMenuItem<String>(
                              value: (user['id'] ?? user['user_id']).toString(),
                              child: Text(_resolveUserName((user['id'] ?? user['user_id']).toString())),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(() => proxyId = value),
                      validator: (value) => value == null || value.isEmpty ? 'เลือกผู้แทน' : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('เปิดใช้งาน'),
                      value: isActive,
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                    const SizedBox(height: 8),
                    _buildDatePickerField(
                      label: 'วันที่เริ่มมีผล',
                      value: startAt,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => startAt = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDatePickerField(
                      label: 'วันที่สิ้นสุด (ถ้ามี)',
                      value: endAt,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => endAt = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          if (ownerId == proxyId) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('เจ้าของสิทธิ์และผู้แทนต้องเป็นคนละคน')),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          final data = {
                            'owner_user_id': ownerId,
                            'proxy_user_id': proxyId,
                            'start_at': startAt?.toIso8601String(),
                            'end_at': endAt?.toIso8601String(),
                            'is_active': isActive,
                          };
                          if (existingProxy != null) {
                            data['id'] = existingProxy['id'];
                          }
                          try {
                            await SupabaseService.client
                                .from('approval_proxies')
                                .upsert(data);
                            if (!mounted) return;
                            Navigator.of(context).pop(true);
                          } on PostgrestException catch (e) {
                            if (!mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('บันทึกไม่สำเร็จ: ${e.message}')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
                            );
                          }
                        },
                  child: Text(existingProxy == null ? 'บันทึก Proxy' : 'บันทึกการแก้ไข'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await _loadApprovalProxies(showLoading: false);
    }
  }

  Future<void> _deleteProxy(Map<String, dynamic> proxy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ Proxy'),
        content: Text('ต้องการลบ Proxy ของ ${_resolveUserName(proxy['owner_user_id']?.toString())} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client
          .from('approval_proxies')
          .delete()
          .eq('id', proxy['id']);
      if (!mounted) return;
      await _loadApprovalProxies(showLoading: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบ Proxy สำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถลบ Proxy: $e')),
      );
    }
  }

  Future<void> _toggleProxyActive(Map<String, dynamic> proxy, bool value) async {
    try {
      await SupabaseService.client
          .from('approval_proxies')
          .update({'is_active': value})
          .eq('id', proxy['id']);
      if (!mounted) return;
      await _loadApprovalProxies(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตสถานะ Proxy: $e')),
      );
    }
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value == null ? 'ไม่ระบุ' : _formatDate(value.toIso8601String()),
          style: TextStyle(color: value == null ? Colors.grey[500] : Colors.black87),
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
      length: 3,
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
              Tab(text: 'Approval Hierarchy'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStatisticsTab(),
            _buildGroupsAndPermissionsTab(),
            _buildApprovalHierarchyTab(),
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
                              final mobileCardAspectRatio = width < 420 ? 1.0 : 1.3;

                              return CustomScrollView(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Container(
                                      padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: GlassButton(
                                              text: 'สร้างกลุ่มใหม่',
                                              onPressed: _showCreateGroupDialog,
                                              backgroundColor: Color(0xFF2E7D32),
                                              textColor: Colors.white,
                                              icon: Icons.add,
                                              fontSize: 11,
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                              width: double.infinity,
                                              opacity: 0.85,
                                              blurStrength: 5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
                                              fontSize: 11,
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                              width: double.infinity,
                                              opacity: 0.85,
                                              blurStrength: 5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
                                              fontSize: 11,
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                              width: double.infinity,
                                              opacity: 0.85,
                                              blurStrength: 5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
                                    sliver: SliverGrid(
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: crossAxisCount == 1 ? mobileCardAspectRatio : 1.7,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final group = _userGroups[index];
                                          return _buildGroupCard(group);
                                        },
                                        childCount: _userGroups.length,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalHierarchyTab() {
    final groups = List<Map<String, dynamic>>.from(_userGroups)
      ..sort((a, b) => ((a['sort_order'] as int?) ?? 999).compareTo((b['sort_order'] as int?) ?? 999));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F5E8), Color(0xFFF1F8E9), Colors.white],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rule_folder, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approval Hierarchy',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'รีเฟรช',
                      onPressed: _isApprovalLoading ? null : () => _loadApprovalRules(),
                      icon: const Icon(Icons.refresh, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'กำหนดวงเงินอนุมัติ ลำดับการอนุมัติ และสถานะการใช้งานของแต่ละกลุ่มผู้ใช้',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isApprovalLoading
                ? const Center(child: CircularProgressIndicator())
                : _approvalErrorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[400], size: 56),
                              const SizedBox(height: 12),
                              Text(
                                _approvalErrorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _loadApprovalRules(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueGrey[100]!),
                            ),
                            child: Text(
                              _buildCurrentBehaviorSummary(groups),
                              style: TextStyle(color: Colors.blueGrey[800], fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[100]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified, size: 16, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _buildProcurementUsageIndicator(),
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildProxySection(),
                          const SizedBox(height: 16),
                          _buildAuditLogSection(),
                          const SizedBox(height: 16),
                          if (groups.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'ยังไม่มีกลุ่มผู้ใช้สำหรับกำหนด hierarchy',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ...groups.map((group) {
                            final groupId = group['id'] as String;
                            final groupColor = _hexToColor(group['color']?.toString() ?? '#4CAF50');
                            final rule = _getRuleForGroup(groupId);
                            final isActive = rule?['is_active'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: groupColor.withOpacity(0.25)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: groupColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.groups, color: groupColor, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          group['group_name']?.toString() ?? '-',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive ? Colors.green[50] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isActive ? Colors.green[800] : Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildInfoChip(Icons.payments, 'วงเงิน: ${_formatApprovalLimit(rule)}'),
                                      _buildInfoChip(Icons.format_list_numbered, 'ลำดับ: ${(rule?['priority'] as int?) ?? '-'}'),
                                      _buildInfoChip(Icons.toggle_on, 'สถานะกฎ: ${isActive ? 'เปิด' : 'ปิด'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showEditApprovalRuleDialog(group),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: Text(rule == null ? 'ตั้งค่ากฎ' : 'แก้ไขกฎ'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
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
            childAspectRatio: crossAxisCount == 1 ? 1.0 : 1.7,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('ลูกค้า'),
                  selected: group['is_customer_group'] == true,
                  avatar: Icon(
                    Icons.person,
                    size: 16,
                    color: group['is_customer_group'] == true ? groupColor : Colors.grey[700],
                  ),
                  selectedColor: groupColor.withOpacity(0.18),
                  backgroundColor: Colors.grey[100],
                  labelStyle: TextStyle(
                    color: group['is_customer_group'] == true ? groupColor : Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: canManageThisGroup
                      ? (value) => _updateGroupFlag(group['id'], 'is_customer_group', value)
                      : null,
                ),
                FilterChip(
                  label: const Text('พนักงานขาย'),
                  selected: group['is_sales_staff_group'] == true,
                  avatar: Icon(
                    Icons.badge,
                    size: 16,
                    color: group['is_sales_staff_group'] == true ? headerColor : Colors.grey[700],
                  ),
                  selectedColor: headerColor.withOpacity(0.18),
                  backgroundColor: Colors.grey[100],
                  labelStyle: TextStyle(
                    color: group['is_sales_staff_group'] == true ? headerColor : Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: canManageThisGroup
                      ? (value) => _updateGroupFlag(group['id'], 'is_sales_staff_group', value)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
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
