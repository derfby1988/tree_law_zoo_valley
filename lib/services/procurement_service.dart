import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// ProcurementService - บริการจัดการระบบจัดซื้อจัดจ้าง
/// 
/// ใช้งาน:
/// ```dart
/// // สร้าง PO
/// final po = await ProcurementService.createPurchaseOrder(supplierId, items);
/// 
/// // รับสินค้า
/// await ProcurementService.receivePurchaseOrder(poId, receivedItems);
/// 
/// // สร้างใบโอนย้าย
/// final transfer = await ProcurementService.createStockTransfer(fromId, toId, items);
/// ```
class ProcurementService {
  static SupabaseClient get _client => SupabaseService.client;

  static const String statusDraft = 'draft';
  static const String statusSent = 'sent';
  static const String statusConfirmed = 'confirmed';
  static const String statusPartialReceived = 'partial_received';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const Map<String, double> _approvalLimitsByRole = {
    'store_manager': 5000.0,
    'manager': 50000.0,
    'admin': double.infinity,
  };

  static double approvalLimitForRole(String approverRole) {
    return _approvalLimitsByRole[approverRole] ?? 0.0;
  }

  static bool canApproveAmount(String approverRole, double poAmount) {
    return poAmount <= approvalLimitForRole(approverRole);
  }

  static bool canApproveAmountByRule(Map<String, dynamic> rule, double poAmount) {
    if (rule['is_unlimited'] == true) return true;
    final amount = (rule['max_amount'] as num?)?.toDouble();
    if (amount == null) return false;
    return poAmount <= amount;
  }

  static String _normalizeRoleKey(String raw) {
    final value = raw.trim().toLowerCase();

    if (value == 'store_manager' ||
        value.contains('หัวหน้าร้าน') ||
        value.contains('store manager')) {
      return 'store_manager';
    }
    if (value == 'manager' || value.contains('ผู้จัดการ')) {
      return 'manager';
    }
    if (value == 'admin' || value.contains('ผู้บริหาร') || value.contains('แอดมิน')) {
      return 'admin';
    }

    return value;
  }

  static String _extractRoleKeyFromRule(Map<String, dynamic> rule) {
    final group = rule['group'] as Map<String, dynamic>?;
    final groupName = group?['group_name']?.toString() ?? '';
    return _normalizeRoleKey(groupName);
  }

  static List<Map<String, dynamic>> _requiredRulesForAmount(
    List<Map<String, dynamic>> rules,
    double poAmount,
  ) {
    if (rules.isEmpty) return const [];

    final eligible = rules.where((rule) => canApproveAmountByRule(rule, poAmount)).toList();
    if (eligible.isEmpty) return const [];

    eligible.sort((a, b) {
      final aPriority = (a['priority'] as num?)?.toInt() ?? 999;
      final bPriority = (b['priority'] as num?)?.toInt() ?? 999;
      return aPriority.compareTo(bPriority);
    });

    final firstRequiredPriority = (eligible.first['priority'] as num?)?.toInt() ?? 999;

    return eligible
        .where((rule) => ((rule['priority'] as num?)?.toInt() ?? 999) <= firstRequiredPriority)
        .toList();
  }

  static List<Map<String, dynamic>> _sortByPriority(List<Map<String, dynamic>> items) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final aPriority = (a['priority'] as num?)?.toInt() ?? 999;
      final bPriority = (b['priority'] as num?)?.toInt() ?? 999;
      return aPriority.compareTo(bPriority);
    });
    return sorted;
  }

  static Future<List<Map<String, dynamic>>> _loadActiveHierarchyRules() async {
    final response = await _client
        .from('approval_hierarchy_rules')
        .select('''
          id,
          group_id,
          max_amount,
          is_unlimited,
          is_active,
          priority,
          group:user_groups(id, group_name)
        ''')
        .eq('is_active', true);

    return _sortByPriority(List<Map<String, dynamic>>.from(response));
  }

  static Future<void> _insertApprovalAuditLog({
    required String poId,
    required String action,
    required String actorUserId,
    required String actorRole,
    required String message,
  }) async {
    try {
      await _client.from('procurement_po_approval_audit_logs').insert({
        'po_id': poId,
        'action': action,
        'actor_user_id': actorUserId,
        'actor_role': actorRole,
        'message': message,
      });
    } catch (e) {
      debugPrint('ProcurementService._insertApprovalAuditLog: $e');
    }
  }

  /// ดึง Audit Logs
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    String? action,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client
          .from('procurement_po_approval_audit_logs')
          .select('*')
          .order('created_at', ascending: false);

      final response = await query;
      List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(response);

      // Apply filters in Dart
      if (action != null) {
        logs = logs.where((log) => log['action'] == action).toList();
      }
      if (fromDate != null) {
        logs = logs.where((log) {
          final logDate = DateTime.tryParse(log['created_at']?.toString() ?? '');
          return logDate != null && logDate.isAfter(fromDate.subtract(const Duration(days: 1)));
        }).toList();
      }
      if (toDate != null) {
        logs = logs.where((log) {
          final logDate = DateTime.tryParse(log['created_at']?.toString() ?? '');
          return logDate != null && logDate.isBefore(toDate.add(const Duration(days: 1)));
        }).toList();
      }

      return logs;
    } catch (e) {
      debugPrint('ProcurementService.getAuditLogs error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _ensureApprovalSteps({
    required String poId,
    required double poAmount,
    required List<Map<String, dynamic>> activeRules,
  }) async {
    try {
      final existing = await _client
          .from('procurement_po_approval_steps')
          .select('*')
          .eq('po_id', poId)
          .order('priority', ascending: true);

      final existingSteps = List<Map<String, dynamic>>.from(existing);
      if (existingSteps.isNotEmpty) {
        return existingSteps;
      }

      final requiredRules = _requiredRulesForAmount(activeRules, poAmount);
      if (requiredRules.isEmpty) {
        return const [];
      }

      final rows = requiredRules.map((rule) {
        final roleKey = _extractRoleKeyFromRule(rule);
        return {
          'po_id': poId,
          'group_id': rule['group_id'],
          'role_key': roleKey,
          'priority': (rule['priority'] as num?)?.toInt() ?? 999,
          'status': 'pending',
        };
      }).toList();

      await _client.from('procurement_po_approval_steps').insert(rows);

      final created = await _client
          .from('procurement_po_approval_steps')
          .select('*')
          .eq('po_id', poId)
          .order('priority', ascending: true);
      return List<Map<String, dynamic>>.from(created);
    } catch (e) {
      debugPrint('ProcurementService._ensureApprovalSteps fallback: $e');
      return const [];
    }
  }

  static double approvalLimitForRoleFromRules(
    String approverRole,
    List<Map<String, dynamic>> rules,
  ) {
    final normalizedRole = _normalizeRoleKey(approverRole);
    final activeRules = rules
        .where((rule) => rule['is_active'] == true)
        .toList();

    final sortedRules = _sortByPriority(activeRules);
    for (final rule in sortedRules) {
      final roleKey = _extractRoleKeyFromRule(rule);
      if (roleKey != normalizedRole) continue;
      if (rule['is_unlimited'] == true) return double.infinity;
      final amount = (rule['max_amount'] as num?)?.toDouble();
      if (amount != null) return amount;
    }

    return approvalLimitForRole(normalizedRole);
  }

  static String? nextStatusAfterSend(String currentStatus) {
    if (currentStatus == statusDraft) return statusSent;
    return null;
  }

  static String? nextStatusAfterApprove(String currentStatus) {
    if (currentStatus == statusSent) return statusConfirmed;
    return null;
  }

  static String? nextStatusAfterReceive(String currentStatus, {required bool isFullyReceived}) {
    if (currentStatus != statusConfirmed) return null;
    return isFullyReceived ? statusCompleted : statusPartialReceived;
  }

  // =============================================
  // Supplier Management
  // =============================================

  /// ดึงรายการ supplier ทั้งหมด
  static Future<List<Map<String, dynamic>>> getSuppliers({bool activeOnly = true}) async {
    try {
      final response = await _client
          .from('procurement_suppliers')
          .select('*')
          .order('code');
      
      if (activeOnly) {
        return List<Map<String, dynamic>>.from(response)
            .where((s) => s['is_active'] == true)
            .toList();
      }
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ProcurementService.getSuppliers error: $e');
      return [];
    }
  }

  /// สร้าง supplier ใหม่
  static Future<Map<String, dynamic>?> createSupplier(Map<String, dynamic> supplier) async {
    try {
      final response = await _client
          .from('procurement_suppliers')
          .insert(supplier)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('ProcurementService.createSupplier error: $e');
      return null;
    }
  }

  /// อัปเดตข้อมูล supplier
  static Future<bool> updateSupplier(String id, Map<String, dynamic> supplier) async {
    try {
      await _client
          .from('procurement_suppliers')
          .update(supplier)
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('ProcurementService.updateSupplier error: $e');
      return false;
    }
  }

  // =============================================
  // Purchase Order Management
  // =============================================

  /// ดึงรายการใบสั่งซื้อ
  static Future<List<Map<String, dynamic>>> getPurchaseOrders({
    String? status,
    String? supplierId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client
          .from('procurement_purchase_orders')
          .select('''
            *,
            supplier:procurement_suppliers(*),
            creator:auth.users(email)
          ''')
          .order('order_date', ascending: false);

      final response = await query;
      List<Map<String, dynamic>> allOrders = List<Map<String, dynamic>>.from(response);
      
      // Apply filters in Dart instead of SQL
      if (status != null) {
        allOrders = allOrders.where((order) => order['status'] == status).toList();
      }
      if (supplierId != null) {
        allOrders = allOrders.where((order) => order['supplier_id'] == supplierId).toList();
      }
      if (fromDate != null) {
        allOrders = allOrders.where((order) {
          final orderDate = DateTime.tryParse(order['order_date'] ?? '');
          return orderDate != null && orderDate.isAfter(fromDate.subtract(const Duration(days: 1)));
        }).toList();
      }
      if (toDate != null) {
        allOrders = allOrders.where((order) {
          final orderDate = DateTime.tryParse(order['order_date'] ?? '');
          return orderDate != null && orderDate.isBefore(toDate.add(const Duration(days: 1)));
        }).toList();
      }
      
      return allOrders;
    } catch (e) {
      debugPrint('ProcurementService.getPurchaseOrders error: $e');
      return [];
    }
  }

  /// ดึงรายการใบสั่งซื้อพร้อม PO lines
  static Future<List<Map<String, dynamic>>> getPurchaseOrdersWithLines({
    String? status,
    String? supplierId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final orders = await getPurchaseOrders(
        status: status,
        supplierId: supplierId,
        fromDate: fromDate,
        toDate: toDate,
      );

      for (final order in orders) {
        final poId = order['id']?.toString();
        if (poId != null) {
          final lines = await _client
              .from('procurement_purchase_order_lines')
              .select('''
                *,
                product:inventory_products(id, name, code, unit_id)
              ''')
              .eq('po_id', poId)
              .order('created_at');
          order['lines'] = lines;
        } else {
          order['lines'] = [];
        }
      }

      return orders;
    } catch (e) {
      debugPrint('ProcurementService.getPurchaseOrdersWithLines error: $e');
      return [];
    }
  }

  /// สร้าง PO ใหม่
  static Future<Map<String, dynamic>?> createPurchaseOrder({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    DateTime? expectedDate,
    String? notes,
    String? createdBy,
  }) async {
    try {
      // Generate PO number
      final orderNumberResponse = await _client.rpc('generate_po_number');
      final orderNumber = orderNumberResponse as String;

      // Calculate totals
      double subtotal = 0;
      for (final item in items) {
        final lineTotal = (item['quantity'] as num) * (item['unit_price'] as num);
        item['line_total'] = lineTotal;
        subtotal += lineTotal;
      }

      // Create PO
      final poData = {
        'order_number': orderNumber,
        'supplier_id': supplierId,
        'status': 'draft',
        'expected_date': expectedDate?.toIso8601String(),
        'subtotal': subtotal,
        'tax_amount': 0, // TODO: Calculate tax based on items
        'discount_amount': 0,
        'total_amount': subtotal,
        'notes': notes,
        'created_by': createdBy,
      };

      final poResponse = await _client
          .from('procurement_purchase_orders')
          .insert(poData)
          .select()
          .single();

      // Create PO lines
      final poLines = items.map((item) => {
        ...item,
        'po_id': poResponse['id'],
        'received_quantity': 0,
      }).toList();

      await _client
          .from('procurement_purchase_order_lines')
          .insert(poLines);

      return poResponse;
    } catch (e) {
      debugPrint('ProcurementService.createPurchaseOrder error: $e');
      return null;
    }
  }

  /// ดึงรายละเอียด PO พร้อม lines
  static Future<Map<String, dynamic>?> getPurchaseOrderDetail(String poId) async {
    try {
      final poResponse = await _client
          .from('procurement_purchase_orders')
          .select('''
            *,
            supplier:procurement_suppliers(*),
            creator:auth.users(email),
            approver:auth.users(email)
          ''')
          .eq('id', poId)
          .single();

      final linesResponse = await _client
          .from('procurement_purchase_order_lines')
          .select('''
            *,
            product:inventory_products(name, code, unit_id)
          ''')
          .eq('po_id', poId)
          .order('created_at');

      return {
        ...poResponse,
        'lines': linesResponse,
      };
    } catch (e) {
      debugPrint('ProcurementService.getPurchaseOrderDetail error: $e');
      return null;
    }
  }

  /// อัปเดตสถานะ PO
  static Future<bool> updatePurchaseOrderStatus(String poId, String status, {
    String? approvedBy,
  }) async {
    try {
      final updateData = {'status': status};
      if (approvedBy != null) {
        updateData['approved_by'] = approvedBy;
        updateData['approved_at'] = DateTime.now().toIso8601String();
      }

      await _client
          .from('procurement_purchase_orders')
          .update(updateData)
          .eq('id', poId);
      return true;
    } catch (e) {
      debugPrint('ProcurementService.updatePurchaseOrderStatus error: $e');
      return false;
    }
  }

  /// รับสินค้า PO
  static Future<bool> receivePurchaseOrder(
    String poId,
    List<Map<String, dynamic>> receivedItems, {
    String? receivedBy,
  }) async {
    try {
      // Update PO lines with received quantities
      for (final receivedItem in receivedItems) {
        await _client
            .from('procurement_purchase_order_lines')
            .update({
              'received_quantity': receivedItem['received_quantity'],
            })
            .eq('id', receivedItem['line_id']);
      }

      // Update inventory quantities and create audit trail
      for (final receivedItem in receivedItems) {
        final productId = receivedItem['product_id'];
        final quantity = receivedItem['received_quantity'];
        
        // Get current product quantity
        final productResponse = await _client
            .from('inventory_products')
            .select('quantity')
            .eq('id', productId)
            .single();

        final currentQuantity = productResponse['quantity'] as num;
        final newQuantity = currentQuantity + (quantity as num);

        // Update product quantity
        await _client
            .from('inventory_products')
            .update({'quantity': newQuantity})
            .eq('id', productId);
      }

      // Check if PO is fully received
      final poDetail = await getPurchaseOrderDetail(poId);
      if (poDetail != null) {
        final lines = poDetail['lines'] as List;
        final isFullyReceived = lines.every((line) => 
            (line['quantity'] as num) <= (line['received_quantity'] as num));

        if (isFullyReceived) {
          await updatePurchaseOrderStatus(poId, statusCompleted);
        } else {
          await updatePurchaseOrderStatus(poId, statusPartialReceived);
        }
      }

      // Record audit log
      if (receivedBy != null) {
        await _insertApprovalAuditLog(
          poId: poId,
          action: 'received_items',
          actorUserId: receivedBy,
          actorRole: 'receiver',
          message: 'รับสินค้า ${receivedItems.length} รายการ',
        );
      }

      return true;
    } catch (e) {
      debugPrint('ProcurementService.receivePurchaseOrder error: $e');
      return false;
    }
  }

  /// ส่ง PO (Draft → Sent)
  static Future<bool> sendPurchaseOrder(String poId, {String? sentBy}) async {
    try {
      final updated = await _client
          .from('procurement_purchase_orders')
          .update({
            'status': statusSent,
            'sent_at': DateTime.now().toIso8601String(),
            'sent_by': sentBy,
          })
          .eq('id', poId)
          .eq('status', statusDraft)
          .select('id')
          .maybeSingle(); // Only allow sending from draft status
      if (updated == null) {
        debugPrint('ProcurementService.sendPurchaseOrder: PO not found or not in draft status');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('ProcurementService.sendPurchaseOrder error: $e');
      return false;
    }
  }

  /// อนุมัติ PO (Sent → Confirmed) พร้อมตรวจสอบสิทธิ์ตามวงเงิน
  static Future<Map<String, dynamic>> approvePurchaseOrder(
    String poId,
    String approvedBy,
    String approverRole,
    double poAmount,
  ) async {
    try {
      final normalizedRole = _normalizeRoleKey(approverRole);
      final activeRules = await _loadActiveHierarchyRules();
      final requiredRules = _requiredRulesForAmount(activeRules, poAmount);

      final limit = approvalLimitForRoleFromRules(normalizedRole, activeRules);

      if (poAmount > limit) {
        final limitLabel = limit.isInfinite ? 'ไม่จำกัด' : '${limit.toStringAsFixed(0)} บาท';
        return {
          'success': false,
          'message': 'วงเงินอนุมัติไม่เพียงพอ (จำกัด $limitLabel)',
        };
      }

      // Enforce approval sequence by priority (when hierarchy tables are available)
      if (requiredRules.isNotEmpty) {
        final steps = await _ensureApprovalSteps(
          poId: poId,
          poAmount: poAmount,
          activeRules: activeRules,
        );

        if (steps.isNotEmpty) {
          final approverStep = steps.where((step) {
            final roleKey = step['role_key']?.toString() ?? '';
            return roleKey == normalizedRole;
          }).firstOrNull;

          if (approverStep == null) {
            return {
              'success': false,
              'message': 'บทบาทของคุณไม่อยู่ในลำดับการอนุมัติของ PO นี้',
            };
          }

          final pendingSteps = steps.where((step) => (step['status']?.toString() ?? 'pending') == 'pending').toList();
          if (pendingSteps.isNotEmpty) {
            pendingSteps.sort((a, b) {
              final aPriority = (a['priority'] as num?)?.toInt() ?? 999;
              final bPriority = (b['priority'] as num?)?.toInt() ?? 999;
              return aPriority.compareTo(bPriority);
            });

            final nextStep = pendingSteps.first;
            final nextPriority = (nextStep['priority'] as num?)?.toInt() ?? 999;
            final approverPriority = (approverStep['priority'] as num?)?.toInt() ?? 999;

            if (approverPriority != nextPriority) {
              return {
                'success': false,
                'message': 'ยังไม่ถึงลำดับอนุมัติของบทบาทนี้ (รอลำดับ $nextPriority)',
              };
            }
          }

          await _client
              .from('procurement_po_approval_steps')
              .update({
                'status': 'approved',
                'approved_by': approvedBy,
                'approved_at': DateTime.now().toIso8601String(),
              })
              .eq('id', approverStep['id']);

          final approvedPriority = (approverStep['priority'] as num?)?.toInt();
          await _insertApprovalAuditLog(
            poId: poId,
            action: 'approved_step',
            actorUserId: approvedBy,
            actorRole: normalizedRole,
            message: 'อนุมัติขั้นตอนลำดับ ${approvedPriority ?? '-'} สำเร็จ',
          );

          final remainingPending = await _client
              .from('procurement_po_approval_steps')
              .select('id')
              .eq('po_id', poId)
              .eq('status', 'pending')
              .limit(1);

          if (remainingPending.isNotEmpty) {
            return {
              'success': true,
              'message': 'อนุมัติขั้นตอนสำเร็จ และรอลำดับถัดไป',
            };
          }
        }
      }

      final updated = await _client
          .from('procurement_purchase_orders')
          .update({
            'status': statusConfirmed,
            'approved_by': approvedBy,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', poId)
          .eq('status', statusSent)
          .select('id')
          .maybeSingle(); // Only approve sent POs

      if (updated == null) {
        return {
          'success': false,
          'message': 'PO ไม่อยู่ในสถานะที่อนุมัติได้ (ต้องเป็น Sent)',
        };
      }

      await _insertApprovalAuditLog(
        poId: poId,
        action: 'approved_final',
        actorUserId: approvedBy,
        actorRole: normalizedRole,
        message: 'อนุมัติ PO สำเร็จและเปลี่ยนสถานะเป็น Confirmed',
      );

      return {'success': true, 'message': 'อนุมัติ PO สำเร็จ'};
    } catch (e) {
      debugPrint('ProcurementService.approvePurchaseOrder error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  /// แก้ไข PO (เฉพาะสถานะ Draft)
  static Future<bool> updatePurchaseOrder(
    String poId,
    Map<String, dynamic> data,
    List<Map<String, dynamic>>? items,
  ) async {
    try {
      // Check if PO is still in draft status
      final po = await getPurchaseOrderDetail(poId);
      if (po == null || po['status'] != statusDraft) {
        debugPrint('ProcurementService.updatePurchaseOrder: PO not found or not in draft status');
        return false;
      }

      // Update PO header
      data['updated_at'] = DateTime.now().toIso8601String();
      await _client
          .from('procurement_purchase_orders')
          .update(data)
          .eq('id', poId);

      // Update PO lines if provided
      if (items != null && items.isNotEmpty) {
        // Delete old lines
        await _client
            .from('procurement_purchase_order_lines')
            .delete()
            .eq('po_id', poId);

        // Insert new lines
        final poLines = items.map((item) => {
          ...item,
          'po_id': poId,
          'received_quantity': 0,
        }).toList();

        await _client
            .from('procurement_purchase_order_lines')
            .insert(poLines);
      }

      return true;
    } catch (e) {
      debugPrint('ProcurementService.updatePurchaseOrder error: $e');
      return false;
    }
  }

  /// ยกเลิก PO (Draft, Sent, Confirmed → Cancelled)
  static Future<bool> cancelPurchaseOrder(String poId, String cancelledBy, String reason) async {
    try {
      // Fetch all POs and filter in Dart instead of using .in_()
      final response = await _client
          .from('procurement_purchase_orders')
          .select('id, status, order_number')
          .eq('id', poId);
      
      final po = response.firstOrNull;
      if (po == null) return false;
      
      final currentStatus = po['status'] as String?;
      if (![statusDraft, statusSent, statusConfirmed].contains(currentStatus)) {
        debugPrint('ProcurementService.cancelPurchaseOrder: Cannot cancel PO with status $currentStatus');
        return false;
      }

      await _client
          .from('procurement_purchase_orders')
          .update({
            'status': statusCancelled,
            'cancelled_by': cancelledBy,
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason,
          })
          .eq('id', poId);
      return true;
    } catch (e) {
      debugPrint('ProcurementService.cancelPurchaseOrder error: $e');
      return false;
    }
  }

  /// ลบ PO (เฉพาะสถานะ Draft)
  static Future<bool> deletePurchaseOrder(String poId) async {
    try {
      // Check if PO is in draft status
      final po = await _client
          .from('procurement_purchase_orders')
          .select('status')
          .eq('id', poId)
          .single();

      if (po['status'] != statusDraft) {
        debugPrint('ProcurementService.deletePurchaseOrder: Can only delete draft POs');
        return false;
      }

      // Delete PO lines first (cascade)
      await _client
          .from('procurement_purchase_order_lines')
          .delete()
          .eq('po_id', poId);

      // Delete PO
      await _client
          .from('procurement_purchase_orders')
          .delete()
          .eq('id', poId);

      return true;
    } catch (e) {
      debugPrint('ProcurementService.deletePurchaseOrder error: $e');
      return false;
    }
  }

  // =============================================
  // Receive Goods Flow
  // =============================================

  /// ดึง PO lines สำหรับการรับสินค้า
  static Future<List<Map<String, dynamic>>> getReceivablePOLines({
    String? poId,
    String? productId,
  }) async {
    try {
      var query = _client
          .from('procurement_purchase_order_lines')
          .select('''
            *,
            po:procurement_purchase_orders(id, order_number, status, expected_date),
            product:inventory_products(id, name, code, unit_id)
          ''')
          .neq('received_quantity', 'quantity');

      if (poId != null) {
        query = query.eq('po_id', poId);
      }
      if (productId != null) {
        query = query.eq('product_id', productId);
      }

      final response = await query.order('created_at');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ProcurementService.getReceivablePOLines error: $e');
      return [];
    }
  }

  /// บันทึกการรับสินค้าบางส่วน (Partial Receive)
  static Future<bool> recordPartialReceive({
    required String poLineId,
    required double receivedQuantity,
    required String warehouseId,
    required String shelfId,
    String? batchNumber,
    DateTime? expiryDate,
    String? qcStatus, // 'pass', 'fail', 'pending'
    String? qcNotes,
    String? receivedBy,
  }) async {
    try {
      // Update PO line received quantity
      await _client
          .from('procurement_purchase_order_lines')
          .update({
            'received_quantity': receivedQuantity,
            'warehouse_id': warehouseId,
            'shelf_id': shelfId,
            'batch_number': batchNumber,
            'expiry_date': expiryDate?.toIso8601String(),
            'qc_status': qcStatus ?? 'pending',
            'qc_notes': qcNotes,
            'received_at': DateTime.now().toIso8601String(),
            'received_by': receivedBy,
          })
          .eq('id', poLineId);

      // Get PO line details
      final lineResponse = await _client
          .from('procurement_purchase_order_lines')
          .select('po_id, product_id, quantity')
          .eq('id', poLineId)
          .single();

      final poId = lineResponse['po_id']?.toString();
      final productId = lineResponse['product_id']?.toString();

      if (poId != null && productId != null) {
        // Create inventory adjustment for received goods
        await _client
            .from('inventory_adjustments')
            .insert({
              'product_id': productId,
              'adjustment_type': 'purchase',
              'quantity_before': 0, // Will be calculated
              'quantity_after': receivedQuantity,
              'quantity_change': receivedQuantity,
              'warehouse_id': warehouseId,
              'shelf_id': shelfId,
              'batch_number': batchNumber,
              'expiry_date': expiryDate?.toIso8601String(),
              'reason': 'รับสินค้าจาก PO: $poId',
              'notes': qcNotes,
              'po_line_id': poLineId,
              'status': qcStatus == 'fail' ? 'rejected' : 'pending',
              'created_by': receivedBy,
            });
        
        // ✅ Create batch record in inventory_item_batches (Phase 1)
        // ดึงข้อมูล supplier และ cost จาก PO
        final poResponse = await _client
            .from('procurement_purchase_orders')
            .select('supplier_name, supplier_id')
            .eq('id', poId)
            .single();
        
        final poLineResponse = await _client
            .from('procurement_purchase_order_lines')
            .select('unit_price')
            .eq('id', poLineId)
            .single();
        
        final supplierName = poResponse['supplier_name']?.toString();
        final unitCost = (poLineResponse['unit_price'] as num?)?.toDouble();
        
        // สร้าง batch
        final batchNum = batchNumber?.isNotEmpty == true 
            ? batchNumber! 
            : 'LOT${DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        
        await _client.from('inventory_item_batches').insert({
          'item_type': 'product',
          'product_id': productId,
          'batch_number': batchNum,
          'quantity': receivedQuantity,
          'expiry_date': expiryDate?.toIso8601String().split('T')[0],
          'received_date': DateTime.now().toIso8601String().split('T')[0],
          'warehouse_id': warehouseId,
          'shelf_id': shelfId,
          'unit_cost': unitCost,
          'supplier_name': supplierName,
          'received_reference': 'PO:$poId',
          'received_from_procurement_id': poLineId,
          'notes': qcNotes,
          'created_by': receivedBy,
        });
      }

      return true;
    } catch (e) {
      debugPrint('ProcurementService.recordPartialReceive error: $e');
      return false;
    }
  }

  /// ดึงสถานะการรับสินค้าของ PO
  static Future<Map<String, dynamic>?> getReceiveStatus(String poId) async {
    try {
      final poResponse = await _client
          .from('procurement_purchase_orders')
          .select('*')
          .eq('id', poId)
          .single();

      final linesResponse = await _client
          .from('procurement_purchase_order_lines')
          .select('quantity, received_quantity, qc_status')
          .eq('po_id', poId);

      final lines = List<Map<String, dynamic>>.from(linesResponse);
      
      double totalQuantity = 0;
      double totalReceived = 0;
      int passedQC = 0;
      int failedQC = 0;
      int pendingQC = 0;

      for (final line in lines) {
        totalQuantity += (line['quantity'] as num).toDouble();
        totalReceived += (line['received_quantity'] as num).toDouble();
        
        final qcStatus = line['qc_status']?.toString() ?? 'pending';
        if (qcStatus == 'pass') passedQC++;
        else if (qcStatus == 'fail') failedQC++;
        else pendingQC++;
      }

      final receivePercentage = totalQuantity > 0 ? (totalReceived / totalQuantity * 100) : 0;

      return {
        'po_id': poId,
        'po_number': poResponse['order_number'],
        'status': poResponse['status'],
        'total_quantity': totalQuantity,
        'total_received': totalReceived,
        'receive_percentage': receivePercentage,
        'passed_qc': passedQC,
        'failed_qc': failedQC,
        'pending_qc': pendingQC,
        'is_fully_received': totalReceived >= totalQuantity,
      };
    } catch (e) {
      debugPrint('ProcurementService.getReceiveStatus error: $e');
      return null;
    }
  }

  /// อัปเดตสถานะ QC สำหรับ PO line
  static Future<bool> updateQCStatus({
    required String poLineId,
    required String qcStatus, // 'pass', 'fail'
    String? qcNotes,
    String? inspectedBy,
  }) async {
    try {
      await _client
          .from('procurement_purchase_order_lines')
          .update({
            'qc_status': qcStatus,
            'qc_notes': qcNotes,
            'qc_inspected_by': inspectedBy,
            'qc_inspected_at': DateTime.now().toIso8601String(),
          })
          .eq('id', poLineId);

      return true;
    } catch (e) {
      debugPrint('ProcurementService.updateQCStatus error: $e');
      return false;
    }
  }

  // =============================================
  // Store Location Management
  // =============================================

  /// ดึงรายการสถานที่เก็บของ
  static Future<List<Map<String, dynamic>>> getStoreLocations({bool activeOnly = true}) async {
    try {
      final response = await _client
          .from('procurement_store_locations')
          .select('*')
          .order('is_main_warehouse', ascending: false)
          .order('code');
      
      if (activeOnly) {
        return List<Map<String, dynamic>>.from(response)
            .where((l) => l['is_active'] == true)
            .toList();
      }
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ProcurementService.getStoreLocations error: $e');
      return [];
    }
  }

  // =============================================
  // Supplier Performance Metrics
  // =============================================

  /// คำนวณ On-Time Delivery Rate (ส่งตรงเวลา %)
  static Future<double> calculateOnTimeDeliveryRate({
    required String supplierId,
    int monthsBack = 6,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = DateTime(now.year, now.month - monthsBack, 1);

      final response = await _client
          .from('procurement_purchase_orders')
          .select('expected_date, received_date')
          .eq('supplier_id', supplierId)
          .eq('status', 'completed')
          .gte('created_at', fromDate.toIso8601String());

      final orders = List<Map<String, dynamic>>.from(response);
      if (orders.isEmpty) return 0.0;

      int onTimeCount = 0;
      for (final order in orders) {
        final expectedDate = order['expected_date']?.toString();
        final receivedDate = order['received_date']?.toString();

        if (expectedDate != null && receivedDate != null) {
          final expected = DateTime.parse(expectedDate);
          final received = DateTime.parse(receivedDate);
          if (received.isBefore(expected) || received.isAtSameMomentAs(expected)) {
            onTimeCount++;
          }
        }
      }

      return (onTimeCount / orders.length * 100);
    } catch (e) {
      debugPrint('ProcurementService.calculateOnTimeDeliveryRate error: $e');
      return 0.0;
    }
  }

  /// คำนวณ Quality Score (คุณภาพ %)
  /// ตามจำนวน QC pass vs fail
  static Future<double> calculateQualityScore({
    required String supplierId,
    int monthsBack = 6,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = DateTime(now.year, now.month - monthsBack, 1);

      // ดึง PO IDs ของผู้ขายนี้
      final posResponse = await _client
          .from('procurement_purchase_orders')
          .select('id')
          .eq('supplier_id', supplierId)
          .gte('created_at', fromDate.toIso8601String());

      final poIds = List<Map<String, dynamic>>.from(posResponse)
          .map((p) => p['id']?.toString())
          .whereType<String>()
          .toList();

      if (poIds.isEmpty) return 100.0;

      // ดึง QC status จาก PO lines
      final linesResponse = await _client
          .from('procurement_purchase_order_lines')
          .select('qc_status')
          .inFilter('po_id', poIds);

      final lines = List<Map<String, dynamic>>.from(linesResponse)
          .where((l) => l['qc_status'] != null)
          .toList();
      if (lines.isEmpty) return 100.0;

      int passCount = 0;
      for (final line in lines) {
        if (line['qc_status']?.toString() == 'pass') {
          passCount++;
        }
      }

      return (passCount / lines.length * 100);
    } catch (e) {
      debugPrint('ProcurementService.calculateQualityScore error: $e');
      return 100.0;
    }
  }

  /// คำนวณ Price Competitiveness (ราคาแข่งขัน)
  /// เปรียบเทียบราคาเฉลี่ยกับผู้ขายอื่น
  static Future<double> calculatePriceCompetitiveness({
    required String supplierId,
    required String productId,
    int monthsBack = 6,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = DateTime(now.year, now.month - monthsBack, 1);

      // ดึงราคาของผู้ขายนี้
      final supplierResponse = await _client
          .from('procurement_purchase_order_lines')
          .select('unit_price')
          .eq('product_id', productId)
          .gte('created_at', fromDate.toIso8601String())
          .order('created_at', ascending: false)
          .limit(10);

      final supplierPrices = List<Map<String, dynamic>>.from(supplierResponse);
      if (supplierPrices.isEmpty) return 50.0;

      final supplierAvgPrice = supplierPrices
          .map((p) => (p['unit_price'] as num?)?.toDouble() ?? 0)
          .reduce((a, b) => a + b) / supplierPrices.length;

      // ดึงราคาเฉลี่ยของผู้ขายอื่น
      final otherResponse = await _client
          .from('procurement_purchase_order_lines')
          .select('unit_price')
          .eq('product_id', productId)
          .neq('supplier_id', supplierId)
          .gte('created_at', fromDate.toIso8601String())
          .order('created_at', ascending: false)
          .limit(20);

      final otherPrices = List<Map<String, dynamic>>.from(otherResponse);
      if (otherPrices.isEmpty) return 50.0;

      final otherAvgPrice = otherPrices
          .map((p) => (p['unit_price'] as num?)?.toDouble() ?? 0)
          .reduce((a, b) => a + b) / otherPrices.length;

      // คำนวณ competitiveness (100 = ราคาเท่ากับค่าเฉลี่ย)
      if (otherAvgPrice == 0) return 50.0;
      return (otherAvgPrice / supplierAvgPrice * 100).clamp(0, 200);
    } catch (e) {
      debugPrint('ProcurementService.calculatePriceCompetitiveness error: $e');
      return 50.0;
    }
  }

  /// คำนวณ Response Time (ตอบสนองเร็ว)
  /// วัดจากเวลาระหว่างสั่ง PO ถึงส่งมา
  static Future<double> calculateAverageResponseTime({
    required String supplierId,
    int monthsBack = 6,
  }) async {
    try {
      final now = DateTime.now();
      final fromDate = DateTime(now.year, now.month - monthsBack, 1);

      final response = await _client
          .from('procurement_purchase_orders')
          .select('created_at, received_date')
          .eq('supplier_id', supplierId)
          .eq('status', 'completed')
          .gte('created_at', fromDate.toIso8601String());

      final orders = List<Map<String, dynamic>>.from(response);
      if (orders.isEmpty) return 0.0;

      double totalDays = 0;
      int validCount = 0;

      for (final order in orders) {
        final createdDate = order['created_at']?.toString();
        final receivedDate = order['received_date']?.toString();

        if (createdDate != null && receivedDate != null) {
          final created = DateTime.parse(createdDate);
          final received = DateTime.parse(receivedDate);
          final days = received.difference(created).inDays;
          totalDays += days;
          validCount++;
        }
      }

      return validCount > 0 ? (totalDays / validCount) : 0.0;
    } catch (e) {
      debugPrint('ProcurementService.calculateAverageResponseTime error: $e');
      return 0.0;
    }
  }

  /// ดึงข้อมูลประเมินผลผู้ขายแบบสมบูรณ์
  static Future<Map<String, dynamic>?> getSupplierPerformance({
    required String supplierId,
    int monthsBack = 6,
  }) async {
    try {
      // ดึงข้อมูลผู้ขาย
      final supplierResponse = await _client
          .from('procurement_suppliers')
          .select('*')
          .eq('id', supplierId)
          .single();

      // คำนวณ metrics
      final results = await Future.wait([
        calculateOnTimeDeliveryRate(supplierId: supplierId, monthsBack: monthsBack),
        calculateQualityScore(supplierId: supplierId, monthsBack: monthsBack),
        calculateAverageResponseTime(supplierId: supplierId, monthsBack: monthsBack),
      ]);

      final onTimeRate = results[0] as double;
      final qualityScore = results[1] as double;
      final responseTime = results[2] as double;

      // คำนวณ overall rating (0-100)
      final overallRating = (onTimeRate * 0.4 + qualityScore * 0.4 + (100 - (responseTime / 30 * 100).clamp(0, 100)) * 0.2);

      return {
        'supplier_id': supplierId,
        'supplier_name': supplierResponse['name'],
        'on_time_delivery_rate': onTimeRate,
        'quality_score': qualityScore,
        'average_response_time_days': responseTime,
        'overall_rating': overallRating.clamp(0, 100),
        'rating_grade': overallRating >= 90 ? 'A' : overallRating >= 80 ? 'B' : overallRating >= 70 ? 'C' : 'D',
        'months_analyzed': monthsBack,
      };
    } catch (e) {
      debugPrint('ProcurementService.getSupplierPerformance error: $e');
      return null;
    }
  }

  /// ดึงข้อมูลประเมินผลผู้ขายทั้งหมด (เพื่อเปรียบเทียบ)
  static Future<List<Map<String, dynamic>>> getAllSuppliersPerformance({
    int monthsBack = 6,
  }) async {
    try {
      final suppliers = await getSuppliers();
      final performanceList = <Map<String, dynamic>>[];

      for (final supplier in suppliers) {
        final supplierId = supplier['id']?.toString();
        if (supplierId == null) continue;

        final performance = await getSupplierPerformance(
          supplierId: supplierId,
          monthsBack: monthsBack,
        );

        if (performance != null) {
          performanceList.add(performance);
        }
      }

      // เรียงตามคะแนนสูงสุด
      performanceList.sort((a, b) {
        final aRating = (a['overall_rating'] as num?)?.toDouble() ?? 0;
        final bRating = (b['overall_rating'] as num?)?.toDouble() ?? 0;
        return bRating.compareTo(aRating);
      });

      return performanceList;
    } catch (e) {
      debugPrint('ProcurementService.getAllSuppliersPerformance error: $e');
      return [];
    }
  }

  /// ดึงผู้ขายที่ดีที่สุด (Top suppliers)
  static Future<List<Map<String, dynamic>>> getTopSuppliers({
    int limit = 5,
    int monthsBack = 6,
  }) async {
    try {
      final allPerformance = await getAllSuppliersPerformance(monthsBack: monthsBack);
      return allPerformance.take(limit).toList();
    } catch (e) {
      debugPrint('ProcurementService.getTopSuppliers error: $e');
      return [];
    }
  }
}
