import 'package:flutter/material.dart';
import '../../services/procurement_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_design_system.dart';

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _filterAction = 'all';
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  final List<String> _actions = [
    'all',
    'created',
    'sent',
    'approved_step',
    'approved_final',
    'rejected',
    'received_items',
  ];

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = await ProcurementService.getAuditLogs(
        action: _filterAction != 'all' ? _filterAction : null,
        fromDate: _filterFromDate,
        toDate: _filterToDate,
      );

      if (!mounted) return;
      setState(() {
        _auditLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลด Audit Trail: $e';
        _isLoading = false;
      });
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'created':
        return Colors.blue;
      case 'sent':
        return Colors.cyan;
      case 'approved_step':
        return Colors.orange;
      case 'approved_final':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'received_items':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'created':
        return 'สร้าง PO';
      case 'sent':
        return 'ส่ง PO';
      case 'approved_step':
        return 'อนุมัติขั้นตอน';
      case 'approved_final':
        return 'อนุมัติสุดท้าย';
      case 'rejected':
        return 'ปฏิเสธ';
      case 'received_items':
        return 'รับสินค้า';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.canAccessTabSync('procurement_tracking')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit Trail')),
        body: Center(
          child: Text(
            'ไม่มีสิทธิ์เข้าถึง',
            style: TextStyle(color: AppDesignSystem.danger),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAuditLogs,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ตัวกรอง',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppDesignSystem.spacingSm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._actions.map((action) => Padding(
                        padding: const EdgeInsets.only(right: AppDesignSystem.spacingSm),
                        child: FilterChip(
                          label: Text(_getActionLabel(action)),
                          selected: _filterAction == action,
                          onSelected: (selected) {
                            setState(() => _filterAction = action);
                            _loadAuditLogs();
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Audit logs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppDesignSystem.danger),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, style: TextStyle(color: AppDesignSystem.danger)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadAuditLogs, child: const Text('ลองใหม่')),
                            ],
                          ),
                        ),
                      )
                    : _auditLogs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline, size: 48, color: AppDesignSystem.textSecondary),
                                  const SizedBox(height: 8),
                                  const Text('ไม่มี Audit Trail'),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _auditLogs.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final log = _auditLogs[index];
                              final action = log['action']?.toString() ?? 'unknown';
                              final poId = log['po_id']?.toString() ?? '-';
                              final timestamp = DateTime.tryParse(log['created_at']?.toString() ?? '');
                              final actor = log['actor_user_id']?.toString() ?? 'System';
                              final message = log['message']?.toString() ?? '';
                              final color = _getActionColor(action);

                              return Padding(
                                padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.check_circle, color: color, size: 20),
                                    ),
                                    const SizedBox(width: AppDesignSystem.spacingMd),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _getActionLabel(action),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: color.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  poId,
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            message,
                                            style: TextStyle(
                                              color: AppDesignSystem.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'โดย: $actor',
                                                style: TextStyle(
                                                  color: AppDesignSystem.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Text(
                                                timestamp != null
                                                    ? '${timestamp.day}/${timestamp.month}/${timestamp.year + 543} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                                                    : '-',
                                                style: TextStyle(
                                                  color: AppDesignSystem.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
