import 'package:flutter/material.dart';
import '../services/group_form_config_service.dart';
import '../models/user_group_model.dart';
import 'group_form_builder_page.dart';

/// หน้าจัดการฟอร์มกลุ่มผู้ใช้ - แสดงรายการกลุ่มที่มี/ไม่มีฟอร์ม
class GroupFormManagerPage extends StatefulWidget {
  const GroupFormManagerPage({super.key});

  @override
  State<GroupFormManagerPage> createState() => _GroupFormManagerPageState();
}

class _GroupFormManagerPageState extends State<GroupFormManagerPage> {
  List<Map<String, dynamic>> _groupForms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupForms();
  }

  Future<void> _loadGroupForms() async {
    setState(() => _isLoading = true);
    
    final data = await GroupFormConfigService.getAllGroupFormsWithGroupInfo();
    
    setState(() {
      _groupForms = data;
      _isLoading = false;
    });
  }

  void _navigateToBuilder({String? groupId, String? configId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupFormBuilderPage(
          groupId: groupId,
          configId: configId,
        ),
      ),
    ).then((_) => _loadGroupForms());
  }

  Future<void> _showCreateFormDialog() async {
    final groupsWithoutForm = await GroupFormConfigService.getGroupsWithoutForm();
    
    if (groupsWithoutForm.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ทุกกลุ่มมีฟอร์มแล้ว')),
      );
      return;
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เลือกกลุ่มสำหรับสร้างฟอร์ม'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groupsWithoutForm.length,
            itemBuilder: (context, index) {
              final group = groupsWithoutForm[index];
              return ListTile(
                leading: _buildGroupIcon(group),
                title: Text(group['group_name'] as String),
                subtitle: group['group_description'] != null
                    ? Text(group['group_description'] as String)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _navigateToBuilder(groupId: group['id'] as String);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupIcon(Map<String, dynamic> group) {
    final color = _parseColor(group['color'] as String?);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.group,
        color: color,
        size: 20,
      ),
    );
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
        title: const Text('จัดการฟอร์มกลุ่มผู้ใช้'),
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'กลุ่มทั้งหมด',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'แสดงเฉพาะกลุ่มที่ Active',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Horizontal scroll hint
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '← เลื่อนดูกลุ่มอื่น →',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Horizontal scrolling cards
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _groupForms.length,
                      itemBuilder: (context, index) {
                        final groupData = _groupForms[index];
                        return _buildGroupCard(groupData);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Legend
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildLegendItem(Colors.green, 'มีฟอร์มแล้ว'),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.orange, 'ยังไม่มีฟอร์ม'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> groupData) {
    final group = {
      'id': groupData['id'],
      'group_name': groupData['group_name'],
      'group_description': groupData['group_description'],
      'color': groupData['color'],
    };
    
    final formConfig = groupData['group_form_configs'];
    final hasForm = formConfig != null && formConfig is List && formConfig.isNotEmpty;
    final configId = hasForm ? formConfig[0]['id'] : null;
    final fieldCount = hasForm 
        ? (formConfig[0]['fields'] as List<dynamic>?)?.length ?? 0 
        : 0;

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: hasForm ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
            width: 2,
          ),
        ),
        color: const Color(0xFF2D2D44),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGroupIcon(group),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasForm 
                          ? Colors.green.withOpacity(0.2) 
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasForm ? 'มีฟอร์ม' : 'ยังไม่มี',
                      style: TextStyle(
                        color: hasForm ? Colors.green : Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Group name
              Text(
                group['group_name'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToBuilder(
                    groupId: group['id'] as String,
                    configId: configId,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasForm ? Colors.blue : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: Text(hasForm ? 'แก้ไข' : 'สร้างฟอร์ม'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
