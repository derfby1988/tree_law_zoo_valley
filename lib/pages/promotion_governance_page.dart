// =============================================
// Phase 9: Promotion Governance Page
// Tree Law Zoo Valley
// =============================================
// Purpose:
// - Conflict detection viewer
// - Approval workflow management
// - Audit log viewer
// - Override permission management
// =============================================

import 'package:flutter/material.dart';
import '../services/promotion_governance_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_design_system.dart';

class PromotionGovernancePage extends StatefulWidget {
  const PromotionGovernancePage({super.key});

  @override
  State<PromotionGovernancePage> createState() => _PromotionGovernancePageState();
}

class _PromotionGovernancePageState extends State<PromotionGovernancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Conflicts
  List<Map<String, dynamic>> _conflicts = [];
  bool _isLoadingConflicts = false;
  
  // Approvals
  List<Map<String, dynamic>> _approvalRequests = [];
  bool _isLoadingApprovals = false;
  
  // Audit Logs
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoadingAuditLogs = false;
  
  // Filters
  String _conflictFilter = 'all';
  String _approvalFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadConflicts(),
      _loadApprovalRequests(),
      _loadAuditLogs(),
    ]);
  }

  Future<void> _loadConflicts() async {
    setState(() => _isLoadingConflicts = true);
    try {
      final conflicts = await PromotionGovernanceService.getConflicts(
        status: _conflictFilter == 'all' ? null : _conflictFilter,
      );
      setState(() {
        _conflicts = conflicts;
        _isLoadingConflicts = false;
      });
    } catch (e) {
      setState(() => _isLoadingConflicts = false);
    }
  }

  Future<void> _loadApprovalRequests() async {
    setState(() => _isLoadingApprovals = true);
    try {
      final requests = await PromotionGovernanceService.getApprovalRequests(
        status: _approvalFilter == 'all' ? null : _approvalFilter,
      );
      setState(() {
        _approvalRequests = requests;
        _isLoadingApprovals = false;
      });
    } catch (e) {
      setState(() => _isLoadingApprovals = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAuditLogs = true);
    try {
      final logs = await PromotionGovernanceService.getAuditLogs(
        limit: 100,
      );
      setState(() {
        _auditLogs = logs;
        _isLoadingAuditLogs = false;
      });
    } catch (e) {
      setState(() => _isLoadingAuditLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.surface,
        title: const Text(
          'การควบคุมและตรวจสอบ',
          style: TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppDesignSystem.primary,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(icon: Icon(Icons.warning), text: 'ข้อขัดแย้ง'),
            Tab(icon: Icon(Icons.approval), text: 'การอนุมัติ'),
            Tab(icon: Icon(Icons.history), text: 'ประวัติ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConflictsTab(),
          _buildApprovalsTab(),
          _buildAuditLogTab(),
        ],
      ),
    );
  }

  // =============================================
  // Conflicts Tab
  // =============================================
  Widget _buildConflictsTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('สถานะ:', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _conflictFilter,
                dropdownColor: AppDesignSystem.surface,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'open', child: Text('รอดำเนินการ')),
                  DropdownMenuItem(value: 'resolved', child: Text('แก้ไขแล้ว')),
                  DropdownMenuItem(value: 'overridden', child: Text('override')),
                ],
                onChanged: (value) {
                  setState(() {
                    _conflictFilter = value!;
                    _loadConflicts();
                  });
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadConflicts,
              ),
            ],
          ),
        ),
        
        // Conflicts List
        Expanded(
          child: _isLoadingConflicts
              ? const Center(child: CircularProgressIndicator())
              : _conflicts.isEmpty
                  ? _buildEmptyState('ไม่พบข้อขัดแย้ง')
                  : ListView.builder(
                      itemCount: _conflicts.length,
                      itemBuilder: (context, index) {
                        final conflict = _conflicts[index];
                        return _buildConflictCard(conflict);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildConflictCard(Map<String, dynamic> conflict) {
    final severity = conflict['severity'] as String;
    final severityColor = _getSeverityColor(severity);
    final conflictType = conflict['conflict_type'] as String;
    final status = conflict['status'] as String;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppDesignSystem.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor,
          child: Icon(
            _getConflictIcon(conflictType),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          _getConflictTypeText(conflictType),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict['message'] ?? '',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getSeverityText(severity),
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: status == 'open'
            ? PopupMenuButton<String>(
                onSelected: (value) => _handleConflictAction(conflict['id'], value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'resolve', child: Text('แก้ไข')),
                  const PopupMenuItem(value: 'override', child: Text('Override')),
                  const PopupMenuItem(value: 'ignore', child: Text('ละเว้น')),
                ],
              )
            : null,
        onTap: () => _showConflictDetails(conflict),
      ),
    );
  }

  // =============================================
  // Approvals Tab
  // =============================================
  Widget _buildApprovalsTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('สถานะ:', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _approvalFilter,
                dropdownColor: AppDesignSystem.surface,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'pending', child: Text('รออนุมัติ')),
                  DropdownMenuItem(value: 'approved', child: Text('อนุมัติแล้ว')),
                  DropdownMenuItem(value: 'rejected', child: Text('ถูกปฏิเสธ')),
                ],
                onChanged: (value) {
                  setState(() {
                    _approvalFilter = value!;
                    _loadApprovalRequests();
                  });
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadApprovalRequests,
              ),
            ],
          ),
        ),
        
        // Approval Requests List
        Expanded(
          child: _isLoadingApprovals
              ? const Center(child: CircularProgressIndicator())
              : _approvalRequests.isEmpty
                  ? _buildEmptyState('ไม่มีคำขออนุมัติ')
                  : ListView.builder(
                      itemCount: _approvalRequests.length,
                      itemBuilder: (context, index) {
                        final request = _approvalRequests[index];
                        return _buildApprovalCard(request);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final statusColor = _getApprovalStatusColor(status);
    final promotionName = request['promotion']?['name'] ?? 'ไม่ระบุชื่อ';
    final requesterName = request['requester']?['display_name'] ?? 'ไม่ระบุชื่อ';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppDesignSystem.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(
            _getApprovalIcon(status),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          promotionName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ขอโดย: $requesterName',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getApprovalStatusText(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: status == 'pending'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _approveRequest(request['id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _rejectRequest(request['id']),
                  ),
                ],
              )
            : null,
        onTap: () => _showApprovalDetails(request),
      ),
    );
  }

  // =============================================
  // Audit Log Tab
  // =============================================
  Widget _buildAuditLogTab() {
    return Column(
      children: [
        // Actions
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('ประวัติการกระทำ:', style: TextStyle(color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadAuditLogs,
              ),
            ],
          ),
        ),
        
        // Audit Logs List
        Expanded(
          child: _isLoadingAuditLogs
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
                  ? _buildEmptyState('ไม่มีประวัติการกระทำ')
                  : ListView.builder(
                      itemCount: _auditLogs.length,
                      itemBuilder: (context, index) {
                        final log = _auditLogs[index];
                        return _buildAuditLogCard(log);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAuditLogCard(Map<String, dynamic> log) {
    final actionType = log['action_type'] as String;
    final actorName = log['actor']?['display_name'] ?? 'ไม่ระบุชื่อ';
    final createdAt = DateTime.parse(log['created_at']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppDesignSystem.surface.withOpacity(0.5),
      child: ListTile(
        leading: Icon(
          _getAuditActionIcon(actionType),
          color: AppDesignSystem.primary,
        ),
        title: Text(
          _getAuditActionText(actionType),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          'โดย $actorName • ${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
      ),
    );
  }

  // =============================================
  // Helper Widgets & Methods
  // =============================================
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getSeverityText(String severity) {
    switch (severity) {
      case 'critical':
        return 'วิกฤต';
      case 'warning':
        return 'เตือน';
      case 'info':
        return 'ข้อมูล';
      default:
        return severity;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'overridden':
        return Colors.purple;
      case 'ignored':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'open':
        return 'รอดำเนินการ';
      case 'resolved':
        return 'แก้ไขแล้ว';
      case 'overridden':
        return 'Override';
      case 'ignored':
        return 'ละเว้น';
      default:
        return status;
    }
  }

  IconData _getConflictIcon(String conflictType) {
    switch (conflictType) {
      case 'product_overlap':
        return Icons.copy;
      case 'time_overlap':
        return Icons.schedule;
      case 'margin_exceeded':
        return Icons.trending_down;
      case 'insufficient_stock':
        return Icons.inventory_2;
      default:
        return Icons.warning;
    }
  }

  String _getConflictTypeText(String conflictType) {
    switch (conflictType) {
      case 'product_overlap':
        return 'สินค้าซ้ำซ้อน';
      case 'time_overlap':
        return 'ช่วงเวลาทับซ้อน';
      case 'margin_exceeded':
        return 'เกิน Margin';
      case 'insufficient_stock':
        return 'สต็อกไม่พอ';
      case 'ingredient_shortage':
        return 'วัตถุดิบไม่พอ';
      case 'duplicate_coupon':
        return 'คูปองซ้ำ';
      default:
        return conflictType;
    }
  }

  Color _getApprovalStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getApprovalStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รออนุมัติ';
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ถูกปฏิเสธ';
      case 'under_review':
        return 'กำลังตรวจสอบ';
      default:
        return status;
    }
  }

  IconData _getApprovalIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'under_review':
        return Icons.visibility;
      default:
        return Icons.help;
    }
  }

  IconData _getAuditActionIcon(String actionType) {
    if (actionType.contains('created')) return Icons.add_circle;
    if (actionType.contains('updated')) return Icons.edit;
    if (actionType.contains('deleted')) return Icons.delete;
    if (actionType.contains('approved')) return Icons.check_circle;
    if (actionType.contains('rejected')) return Icons.cancel;
    return Icons.history;
  }

  String _getAuditActionText(String actionType) {
    switch (actionType) {
      case 'coupon_created':
        return 'สร้างคูปอง';
      case 'coupon_updated':
        return 'แก้ไขคูปอง';
      case 'coupon_deleted':
        return 'ลบคูปอง';
      case 'promotion_created':
        return 'สร้างโปรโมชัน';
      case 'promotion_updated':
        return 'แก้ไขโปรโมชัน';
      case 'promotion_deleted':
        return 'ลบโปรโมชัน';
      case 'approval_granted':
        return 'อนุมัติ';
      case 'approval_rejected':
        return 'ปฏิเสธ';
      default:
        return actionType;
    }
  }

  // =============================================
  // Actions
  // =============================================
  Future<void> _handleConflictAction(String conflictId, String action) async {
    // TODO: Implement conflict resolution actions
  }

  Future<void> _approveRequest(String approvalId) async {
    // TODO: Implement approval
  }

  Future<void> _rejectRequest(String approvalId) async {
    // TODO: Implement rejection with reason dialog
  }

  void _showConflictDetails(Map<String, dynamic> conflict) {
    // TODO: Show conflict details dialog
  }

  void _showApprovalDetails(Map<String, dynamic> request) {
    // TODO: Show approval details dialog
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
