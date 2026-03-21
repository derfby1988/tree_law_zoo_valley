import 'package:flutter_test/flutter_test.dart';
import 'package:tree_law_zoo_valley/services/procurement_service.dart';

void main() {
  group('Procurement workflow integration', () {
    test('Draft → Sent → Confirmed → Completed', () {
      var status = ProcurementService.statusDraft;

      status = ProcurementService.nextStatusAfterSend(status)!;
      expect(status, ProcurementService.statusSent);

      expect(ProcurementService.canApproveAmount('manager', 50000), isTrue);
      status = ProcurementService.nextStatusAfterApprove(status)!;
      expect(status, ProcurementService.statusConfirmed);

      status = ProcurementService.nextStatusAfterReceive(
        status,
        isFullyReceived: true,
      )!;
      expect(status, ProcurementService.statusCompleted);
    });

    test('Workflow blocks invalid transitions', () {
      expect(
        ProcurementService.nextStatusAfterApprove(ProcurementService.statusDraft),
        isNull,
      );
      expect(
        ProcurementService.nextStatusAfterSend(ProcurementService.statusConfirmed),
        isNull,
      );
      expect(
        ProcurementService.nextStatusAfterReceive(
          ProcurementService.statusSent,
          isFullyReceived: true,
        ),
        isNull,
      );
    });

    test('Confirmed can become Partial Received', () {
      final next = ProcurementService.nextStatusAfterReceive(
        ProcurementService.statusConfirmed,
        isFullyReceived: false,
      );
      expect(next, ProcurementService.statusPartialReceived);
    });
  });

  group('Procurement approval limits', () {
    test('approvalLimitForRole returns expected values', () {
      expect(ProcurementService.approvalLimitForRole('store_manager'), 5000.0);
      expect(ProcurementService.approvalLimitForRole('manager'), 50000.0);
      expect(ProcurementService.approvalLimitForRole('admin'), double.infinity);
      expect(ProcurementService.approvalLimitForRole('unknown_role'), 0.0);
    });

    test('canApproveAmount enforces limits per role', () {
      expect(ProcurementService.canApproveAmount('store_manager', 4999.99), isTrue);
      expect(ProcurementService.canApproveAmount('store_manager', 5000.01), isFalse);

      expect(ProcurementService.canApproveAmount('manager', 50000.0), isTrue);
      expect(ProcurementService.canApproveAmount('manager', 50000.01), isFalse);

      expect(ProcurementService.canApproveAmount('admin', 999999999.0), isTrue);
      expect(ProcurementService.canApproveAmount('unknown_role', 1.0), isFalse);
    });

    test('canApproveAmountByRule respects unlimited and max_amount', () {
      final unlimitedRule = {
        'is_unlimited': true,
        'max_amount': null,
      };
      final limitedRule = {
        'is_unlimited': false,
        'max_amount': 7500.0,
      };

      expect(ProcurementService.canApproveAmountByRule(unlimitedRule, 9999999), isTrue);
      expect(ProcurementService.canApproveAmountByRule(limitedRule, 7499.99), isTrue);
      expect(ProcurementService.canApproveAmountByRule(limitedRule, 7500.01), isFalse);
    });

    test('approvalLimitForRoleFromRules resolves role limit from rules table rows', () {
      final rules = [
        {
          'is_active': true,
          'is_unlimited': false,
          'max_amount': 5000.0,
          'priority': 1,
          'group': {'group_name': 'หัวหน้าร้าน'},
        },
        {
          'is_active': true,
          'is_unlimited': false,
          'max_amount': 50000.0,
          'priority': 2,
          'group': {'group_name': 'ผู้จัดการ'},
        },
        {
          'is_active': true,
          'is_unlimited': true,
          'max_amount': null,
          'priority': 3,
          'group': {'group_name': 'ผู้บริหาร'},
        },
      ];

      expect(
        ProcurementService.approvalLimitForRoleFromRules('store_manager', rules),
        5000.0,
      );
      expect(
        ProcurementService.approvalLimitForRoleFromRules('manager', rules),
        50000.0,
      );
      expect(
        ProcurementService.approvalLimitForRoleFromRules('admin', rules),
        double.infinity,
      );
    });
  });
}
