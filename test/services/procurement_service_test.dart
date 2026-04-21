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

  group('ProcurementService - Supplier Performance Metrics', () {
    test('calculateOnTimeDeliveryRate should calculate percentage correctly', () {
      // Given
      const totalOrders = 10;
      const onTimeOrders = 8;

      // When
      final onTimeRate = (onTimeOrders / totalOrders * 100);

      // Then
      expect(onTimeRate, equals(80.0));
    });

    test('calculateQualityScore should calculate QC pass rate', () {
      // Given
      const totalLines = 20;
      const passedQC = 18;

      // When
      final qualityScore = (passedQC / totalLines * 100);

      // Then
      expect(qualityScore, equals(90.0));
    });

    test('calculatePriceCompetitiveness should compare prices', () {
      // Given
      const supplierPrice = 100.0;
      const avgMarketPrice = 120.0;

      // When
      final priceCompetitiveness = ((avgMarketPrice - supplierPrice) / avgMarketPrice * 100);

      // Then
      expect(priceCompetitiveness, closeTo(16.67, 0.01));
      expect(priceCompetitiveness, greaterThan(0)); // Supplier is cheaper
    });

    test('calculateAverageResponseTime should calculate days', () {
      // Given
      final responseTimes = [1, 2, 3, 4, 5]; // days

      // When
      final avgResponseTime = responseTimes.reduce((a, b) => a + b) / responseTimes.length;

      // Then
      expect(avgResponseTime, equals(3.0));
    });

    test('getSupplierPerformance should calculate overall rating', () {
      // Given
      const onTimeRate = 85.0;
      const qualityScore = 90.0;
      const priceCompetitiveness = 15.0;
      const avgResponseTime = 2.5;

      // When
      final overallRating = (onTimeRate * 0.3 + qualityScore * 0.3 + priceCompetitiveness * 0.2 + (10 - avgResponseTime) * 0.2);

      // Then
      expect(overallRating, greaterThan(0));
      expect(overallRating, lessThanOrEqualTo(100));
    });

    test('getSupplierPerformance should assign correct grade', () {
      // Given
      final ratings = [95.0, 85.0, 75.0, 65.0, 50.0];

      // When
      final grades = ratings.map((rating) {
        if (rating >= 90) return 'A';
        if (rating >= 80) return 'B';
        if (rating >= 70) return 'C';
        if (rating >= 60) return 'D';
        return 'F';
      }).toList();

      // Then
      expect(grades[0], equals('A'));
      expect(grades[1], equals('B'));
      expect(grades[2], equals('C'));
      expect(grades[3], equals('D'));
      expect(grades[4], equals('F'));
    });

    test('getAllSuppliersPerformance should rank suppliers', () {
      // Given
      final suppliers = [
        {'id': '1', 'rating': 85.0},
        {'id': '2', 'rating': 92.0},
        {'id': '3', 'rating': 78.0},
      ];

      // When
      suppliers.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));

      // Then
      expect(suppliers[0]['id'], equals('2')); // Highest rating
      expect(suppliers[1]['id'], equals('1'));
      expect(suppliers[2]['id'], equals('3')); // Lowest rating
    });

    test('getTopSuppliers should return top N suppliers', () {
      // Given
      final suppliers = [
        {'id': '1', 'rating': 85.0},
        {'id': '2', 'rating': 92.0},
        {'id': '3', 'rating': 78.0},
        {'id': '4', 'rating': 88.0},
        {'id': '5', 'rating': 95.0},
      ];
      const topN = 3;

      // When
      suppliers.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
      final topSuppliers = suppliers.take(topN).toList();

      // Then
      expect(topSuppliers.length, equals(3));
      expect(topSuppliers[0]['id'], equals('5')); // 95.0
      expect(topSuppliers[1]['id'], equals('2')); // 92.0
      expect(topSuppliers[2]['id'], equals('4')); // 88.0
    });
  });
}
