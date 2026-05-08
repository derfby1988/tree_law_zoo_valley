// =============================================
// Phase 9: Promotion Governance Service (Fixed)
// Tree Law Zoo Valley
// =============================================
// Purpose:
// - Conflict detection
// - Approval workflow
// - Audit logging
// - Override permissions
// =============================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PromotionGovernanceService {
  static final SupabaseClient _client = SupabaseService.client;

  // =============================================
  // 1. Conflict Detection
  // =============================================

  /// ตรวจสอบ conflicts สำหรับ promotion
  static Future<List<Map<String, dynamic>>> detectConflicts(String promotionId) async {
    try {
      // เรียกใช้ database function
      final response = await _client.rpc(
        'detect_promotion_conflicts',
        params: {'p_promotion_id': promotionId},
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error detecting conflicts: $e');
      return [];
    }
  }

  /// บันทึก conflict ที่ตรวจพบ
  static Future<void> recordConflict({
    required String promotionId,
    required String conflictType,
    required String severity,
    required String message,
    String? conflictingPromotionId,
    String? conflictingCouponId,
    String? conflictingProductId,
    String? suggestedAction,
  }) async {
    try {
      await _client.from('promotion_conflicts').insert({
        'promotion_id': promotionId,
        'conflict_type': conflictType,
        'severity': severity,
        'message': message,
        'conflicting_promotion_id': conflictingPromotionId,
        'conflicting_coupon_id': conflictingCouponId,
        'conflicting_product_id': conflictingProductId,
        'suggested_action': suggestedAction,
        'status': 'open',
      });
    } catch (e) {
      debugPrint('Error recording conflict: $e');
    }
  }

  /// ดึงรายการ conflicts ทั้งหมด
  static Future<List<Map<String, dynamic>>> getConflicts({
    String? promotionId,
    String? status,
    String? severity,
  }) async {
    try {
      // Use RPC function to avoid PostgrestTransformBuilder issues
      final response = await _client.rpc('get_promotion_conflicts', params: {
        'p_promotion_id': promotionId,
        'p_status': status,
        'p_severity': severity,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('Error getting conflicts: $e');
      return [];
    }
  }

  /// แก้ไข conflict status
  static Future<void> resolveConflict(
    String conflictId, {
    required String status,
    String? resolutionNote,
    String? resolvedBy,
  }) async {
    try {
      await _client.from('promotion_conflicts').update({
        'status': status,
        'resolved_by': resolvedBy,
        'resolved_at': DateTime.now().toIso8601String(),
        'resolution_note': resolutionNote,
      }).eq('id', conflictId);
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
    }
  }

  // =============================================
  // 2. Preview/Simulation
  // =============================================

  /// จำลองผลกระทบของ promotion
  static Future<Map<String, dynamic>?> simulatePromotion({
    required String promotionId,
    required String simulatedBy,
  }) async {
    try {
      // ดึงข้อมูล promotion
      final promotion = await _client
          .from('pos_promotions')
          .select('*, target_products:pos_promotion_target_products(*)')
          .eq('id', promotionId)
          .single();

      // คำนวณผลกระทบเบื้องต้น
      final simulation = await _calculateSimulationImpact(promotion);

      // บันทึกผลการจำลอง
      await _client.from('promotion_simulations').insert({
        'promotion_id': promotionId,
        'simulated_by': simulatedBy,
        'simulation_date': DateTime.now().toIso8601String().split('T')[0],
        ...simulation,
      });

      return simulation;
    } catch (e) {
      debugPrint('Error simulating promotion: $e');
      return null;
    }
  }

  /// คำนวณผลกระทบการจำลอง
  static Future<Map<String, dynamic>> _calculateSimulationImpact(
    Map<String, dynamic> promotion,
  ) async {
    try {
      // ดึงสินค้าเป้าหมาย
      final targetProducts = promotion['target_products'] as List? ?? [];
      
      // คำนวณรายได้และส่วนลดที่ประมาณ
      double estimatedRevenueImpact = 0;
      double estimatedDiscountTotal = 0;
      int estimatedCustomerCount = 0;
      
      List<Map<String, dynamic>> productsAtRisk = [];
      List<Map<String, dynamic>> ingredientsAtRisk = [];

      for (final product in targetProducts) {
        final productId = product['product_id'];
        
        // ดึงข้อมูลสินค้าและสต็อก
        final productInfo = await _client
            .from('inventory_products')
            .select('*, stock:inventory_stock_summary(*)')
            .eq('id', productId)
            .single();

        // ตรวจสอบสต็อก
        final currentStock = productInfo['stock']?['total_quantity'] ?? 0;
        final estimatedUsage = 100; // ประมาณการขาย 100 ชิ้น
        
        if (currentStock < estimatedUsage) {
          productsAtRisk.add({
            'product_id': productId,
            'product_name': productInfo['name'],
            'current_stock': currentStock,
            'estimated_usage': estimatedUsage,
            'risk_level': currentStock < estimatedUsage * 0.5 ? 'critical' : 'warning',
          });
        }

        // คำนวณรายได้และส่วนลด
        final unitPrice = productInfo['unit_price'] ?? 0;
        final discountPercent = promotion['discount_percent'] ?? 0;
        
        estimatedRevenueImpact += unitPrice * estimatedUsage;
        estimatedDiscountTotal += (unitPrice * discountPercent / 100) * estimatedUsage;
      }

      // ประเมินความเสี่ยง
      String riskAssessment = 'low';
      if (productsAtRisk.any((p) => p['risk_level'] == 'critical')) {
        riskAssessment = 'critical';
      } else if (productsAtRisk.isNotEmpty) {
        riskAssessment = 'medium';
      }

      return {
        'estimated_revenue_impact': estimatedRevenueImpact,
        'estimated_discount_total': estimatedDiscountTotal,
        'estimated_customer_count': estimatedCustomerCount,
        'products_at_risk': productsAtRisk,
        'ingredients_at_risk': ingredientsAtRisk,
        'risk_assessment': riskAssessment,
        'recommendation': _generateRecommendation(riskAssessment, productsAtRisk),
      };
    } catch (e) {
      debugPrint('Error calculating simulation: $e');
      return {
        'estimated_revenue_impact': 0,
        'estimated_discount_total': 0,
        'estimated_customer_count': 0,
        'products_at_risk': [],
        'ingredients_at_risk': [],
        'risk_assessment': 'unknown',
        'recommendation': 'ไม่สามารถคำนวณผลกระทบได้',
      };
    }
  }

  /// สร้างคำแนะนำจากการประเมินความเสี่ยง
  static String _generateRecommendation(
    String riskAssessment,
    List<Map<String, dynamic>> productsAtRisk,
  ) {
    switch (riskAssessment) {
      case 'critical':
        return 'มีสินค้าที่อาจหมดสต็อกระดับวิกฤต แนะนำให้เติมสต็อก่อนเปิดโปรโมชัน';
      case 'medium':
        return 'มีสินค้าที่อาจหมดสต็อก ควรติดตามสต็อกใกล้ชิด';
      case 'low':
        return 'สต็อกเพียงพอสำหรับโปรโมชัน สามารถดำเนินการได้ตามปกติ';
      default:
        return 'ไม่สามารถประเมินความเสี่ยงได้';
    }
  }

  /// ดึงประวัติการจำลอง
  static Future<List<Map<String, dynamic>>> getSimulationHistory(
    String promotionId,
  ) async {
    try {
      final response = await _client
          .from('promotion_simulations')
          .select('*, user:simulated_by(display_name)')
          .eq('promotion_id', promotionId)
          .order('simulation_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting simulation history: $e');
      return [];
    }
  }

  // =============================================
  // 3. Approval Workflow
  // =============================================

  /// สร้างคำขออนุมัติ
  static Future<String?> requestApproval({
    required String promotionId,
    required String requestedBy,
    required double estimatedAmount,
  }) async {
    try {
      // กำหนดระดับการอนุมัติตามยอดเงิน
      final approvalLevels = await _determineApprovalLevels(estimatedAmount);
      
      final response = await _client.from('promotion_approvals').insert({
        'promotion_id': promotionId,
        'requested_by': requestedBy,
        'status': 'pending',
        'current_approval_level': 1,
        'total_approval_levels': approvalLevels.length,
        'auto_approve_threshold': 5000, // ยอดอนุมัติอัตโนมัติ
      }).select().single();

      // บันทึกประวัติ
      await _recordApprovalHistory(
        approvalId: response['id'],
        promotionId: promotionId,
        action: 'submitted',
        actorId: requestedBy,
        fromStatus: null,
        toStatus: 'pending',
      );

      // ถ้ายอดไม่เกิน threshold ให้อนุมัติอัตโนมัติ
      if (estimatedAmount <= 5000) {
        await autoApprove(response['id'], requestedBy);
      }

      return response['id'];
    } catch (e) {
      debugPrint('Error requesting approval: $e');
      return null;
    }
  }

  /// กำหนดระดับการอนุมัติตามยอดเงิน
  static Future<List<Map<String, dynamic>>> _determineApprovalLevels(
    double amount,
  ) async {
    try {
      final rules = await _client
          .from('promotion_governance_rules')
          .select('*')
          .eq('rule_type', 'approval_requirement')
          .eq('is_active', true)
          .order('priority');

      List<Map<String, dynamic>> levels = [];
      for (final rule in rules) {
        final config = rule['config'] as Map<String, dynamic>;
        final maxAmount = config['max_amount'] as double? ?? double.infinity;
        
        if (amount <= maxAmount) {
          levels.add({
            'level': levels.length + 1,
            'group_ids': config['required_groups'] ?? [],
            'auto_approve': config['auto_approve'] ?? false,
          });
          break;
        }
      }

      return levels;
    } catch (e) {
      debugPrint('Error determining approval levels: $e');
      return [{'level': 1, 'group_ids': [], 'auto_approve': false}];
    }
  }

  /// อนุมัติอัตโนมัติ (สำหรับยอดต่ำ)
  static Future<void> autoApprove(String approvalId, String approvedBy) async {
    try {
      await _client.from('promotion_approvals').update({
        'status': 'approved',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'is_auto_approved': true,
      }).eq('id', approvalId);

      await _recordApprovalHistory(
        approvalId: approvalId,
        action: 'approved',
        actorId: approvedBy,
        fromStatus: 'pending',
        toStatus: 'approved',
      );
    } catch (e) {
      debugPrint('Error auto-approving: $e');
    }
  }

  /// อนุมัติคำขอ
  static Future<void> approveRequest({
    required String approvalId,
    required String approvedBy,
    String? note,
  }) async {
    try {
      // ดึงข้อมูลปัจจุบัน
      final approval = await _client
          .from('promotion_approvals')
          .select('*')
          .eq('id', approvalId)
          .single();

      final currentLevel = approval['current_approval_level'] as int;
      final totalLevels = approval['total_approval_levels'] as int;

      if (currentLevel >= totalLevels) {
        // อนุมัติสมบูรณ์
        await _client.from('promotion_approvals').update({
          'status': 'approved',
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'approval_note': note,
        }).eq('id', approvalId);
      } else {
        // ยังมีระดับถัดไป
        await _client.from('promotion_approvals').update({
          'current_approval_level': currentLevel + 1,
        }).eq('id', approvalId);
      }

      await _recordApprovalHistory(
        approvalId: approvalId,
        promotionId: approval['promotion_id'],
        action: 'approved',
        actorId: approvedBy,
        fromStatus: approval['status'],
        toStatus: 'approved',
      );
    } catch (e) {
      debugPrint('Error approving request: $e');
    }
  }

  /// ปฏิเสธคำขอ
  static Future<void> rejectRequest({
    required String approvalId,
    required String rejectedBy,
    required String reason,
  }) async {
    try {
      final approval = await _client
          .from('promotion_approvals')
          .select('*')
          .eq('id', approvalId)
          .single();

      await _client.from('promotion_approvals').update({
        'status': 'rejected',
        'rejected_by': rejectedBy,
        'rejected_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      }).eq('id', approvalId);

      await _recordApprovalHistory(
        approvalId: approvalId,
        promotionId: approval['promotion_id'],
        action: 'rejected',
        actorId: rejectedBy,
        fromStatus: approval['status'],
        toStatus: 'rejected',
      );
    } catch (e) {
      debugPrint('Error rejecting request: $e');
    }
  }

  /// ดึงรายการคำขออนุมัติ
  static Future<List<Map<String, dynamic>>> getApprovalRequests({
    String? status,
    String? assignedTo,
  }) async {
    try {
      // Use RPC function to avoid PostgrestTransformBuilder issues
      final response = await _client.rpc('get_promotion_approval_requests', params: {
        'p_status': status,
        'p_assigned_to': assignedTo,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('Error getting approval requests: $e');
      return [];
    }
  }

  /// บันทึกประวัติการอนุมัติ
  static Future<void> _recordApprovalHistory({
    String? approvalId,
    String? promotionId,
    required String action,
    required String actorId,
    String? fromStatus,
    String? toStatus,
  }) async {
    try {
      await _client.from('promotion_approval_history').insert({
        'approval_id': approvalId,
        'promotion_id': promotionId,
        'action': action,
        'actor_id': actorId,
        'from_status': fromStatus,
        'to_status': toStatus,
      });
    } catch (e) {
      debugPrint('Error recording approval history: $e');
    }
  }

  // =============================================
  // 4. Audit Logging
  // =============================================

  /// บันทึก audit log
  static Future<void> logAudit({
    required String actionType,
    required String entityType,
    String? entityId,
    required String actorId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? reason,
    String? pageUrl,
  }) async {
    try {
      await _client.rpc('log_coupon_promotion_audit', params: {
        'p_action_type': actionType,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_actor_id': actorId,
        'p_old_values': oldValues,
        'p_new_values': newValues,
        'p_reason': reason,
      });
    } catch (e) {
      debugPrint('Error logging audit: $e');
    }
  }

  /// ดึง audit logs
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    String? actionType,
    String? entityType,
    String? entityId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
  }) async {
    try {
      // Use RPC function to avoid PostgrestTransformBuilder issues
      final response = await _client.rpc('get_coupon_promotion_audit_logs', params: {
        'p_action_type': actionType,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_from_date': fromDate?.toIso8601String(),
        'p_to_date': toDate?.toIso8601String(),
        'p_limit': limit,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      return [];
    }
  }

  // =============================================
  // 5. Override Permissions
  // =============================================

  /// ตรวจสอบสิทธิ override
  static Future<bool> canOverride({
    required String userId,
    required String permissionType,
    double? amount,
  }) async {
    try {
      final response = await _client.rpc('check_override_permission', params: {
        'p_user_id': userId,
        'p_permission_type': permissionType,
        'p_amount': amount,
      });

      return response as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking override permission: $e');
      return false;
    }
  }

  /// ดึงสิทธิ override ของผู้ใช้
  static Future<List<Map<String, dynamic>>> getUserOverridePermissions(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('promotion_override_permissions')
          .select('*')
          .or('user_id.eq.$userId,group_id.in.(${await _getUserGroupIds(userId)})')
          .eq('is_active', true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting override permissions: $e');
      return [];
    }
  }

  /// ดึง group IDs ของผู้ใช้
  static Future<List<String>> _getUserGroupIds(String userId) async {
    try {
      final response = await _client
          .from('user_group_members')
          .select('group_id')
          .eq('user_id', userId);

      return (response as List)
          .map((r) => r['group_id'].toString())
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// ใช้สิทธิ override
  static Future<void> useOverride({
    required String approvalId,
    required String overriddenBy,
    required String reason,
    required String permissionId,
  }) async {
    try {
      final approval = await _client
          .from('promotion_approvals')
          .select('*')
          .eq('id', approvalId)
          .single();

      await _client.from('promotion_approvals').update({
        'status': 'approved',
        'overridden_by': overriddenBy,
        'overridden_at': DateTime.now().toIso8601String(),
        'override_reason': reason,
        'override_permission_id': permissionId,
      }).eq('id', approvalId);

      await _recordApprovalHistory(
        approvalId: approvalId,
        promotionId: approval['promotion_id'],
        action: 'overridden',
        actorId: overriddenBy,
        fromStatus: approval['status'],
        toStatus: 'approved',
      );
    } catch (e) {
      debugPrint('Error using override: $e');
    }
  }

  // =============================================
  // 6. Governance Rules
  // =============================================

  /// ดึงกฎ governance ทั้งหมด
  static Future<List<Map<String, dynamic>>> getGovernanceRules({
    String? ruleType,
    bool? isActive,
  }) async {
    try {
      // Use RPC function to avoid PostgrestTransformBuilder issues
      final response = await _client.rpc('get_promotion_governance_rules', params: {
        'p_rule_type': ruleType,
        'p_is_active': isActive,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('Error getting governance rules: $e');
      return [];
    }
  }

  /// อัปเดตกฎ
  static Future<void> updateGovernanceRule(
    String ruleId, {
    required Map<String, dynamic> config,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'config': config,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (isActive != null) {
        updates['is_active'] = isActive;
      }

      await _client
          .from('promotion_governance_rules')
          .update(updates)
          .eq('id', ruleId);
    } catch (e) {
      debugPrint('Error updating governance rule: $e');
    }
  }
}
