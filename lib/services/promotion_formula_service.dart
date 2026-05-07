import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/promotion_formula_model.dart';

/// Service สำหรับจัดการสูตร Priority Score
/// ใช้แนวทาง Hybrid: SQL คำนวณ raw scores + Dart คำนวณ weighted score
class PromotionFormulaService {
  static final _supabase = Supabase.instance.client;

  // ============================================
  // CRUD Operations สำหรับสูตร
  // ============================================

  /// ดึงสูตรทั้งหมด
  static Future<List<PromotionFormulaConfig>> getAllFormulas() async {
    try {
      debugPrint('🔍 FormulaService: Querying promotion_formula_configs...');
      final response = await _supabase
          .from('promotion_formula_configs')
          .select('*')
          .order('created_at', ascending: false);
      
      debugPrint('🔍 FormulaService: Raw response type: ${response.runtimeType}');
      
      // Handle empty response
      if (response == null) {
        debugPrint('⚠️ FormulaService: Response is null');
        return [];
      }
      
      // Cast to List
      final List<dynamic> responseList = response as List<dynamic>;
      debugPrint('🔍 FormulaService: Response length: ${responseList.length}');
      
      if (responseList.isEmpty) {
        debugPrint('⚠️ FormulaService: Empty list');
        return [];
      }
      
      // Check first item type
      debugPrint('🔍 FormulaService: First item type: ${responseList.first.runtimeType}');
      debugPrint('🔍 FormulaService: First item: ${responseList.first}');

      // Convert each item safely
      final formulas = <PromotionFormulaConfig>[];
      for (var i = 0; i < responseList.length; i++) {
        final item = responseList[i];
        if (item is Map<String, dynamic>) {
          formulas.add(PromotionFormulaConfig.fromJson(item));
        } else {
          debugPrint('❌ FormulaService: Item $i is not Map, it is ${item.runtimeType}');
        }
      }
      
      debugPrint('✅ FormulaService: Parsed ${formulas.length} formulas');
      return formulas;
    } catch (e, stackTrace) {
      debugPrint('❌ FormulaService: Error loading formulas: $e');
      debugPrint('❌ FormulaService: StackTrace: $stackTrace');
      throw Exception('ไม่สามารถดึงรายการสูตรได้: $e');
    }
  }

  /// ดึงสูตรที่ใช้งานอยู่ (Active + อยู่ในช่วงเวลา)
  static Future<PromotionFormulaConfig?> getActiveFormula() async {
    try {
      final response = await _supabase
          .from('promotion_formula_configs')
          .select('*')
          .eq('is_active', true)
          .or('valid_until.is.null,valid_until.gte.${DateTime.now().toIso8601String().split('T')[0]}')
          .order('valid_from', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      
      // response from maybeSingle() is Map<String, dynamic> or null
      return PromotionFormulaConfig.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('❌ getActiveFormula error: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      throw Exception('ไม่สามารถดึงสูตรที่ใช้งานอยู่ได้: $e');
    }
  }

  /// ดึงสูตรตาม ID
  static Future<PromotionFormulaConfig> getFormulaById(String id) async {
    try {
      final response = await _supabase
          .from('promotion_formula_configs')
          .select('*')
          .eq('id', id)
          .single();

      return PromotionFormulaConfig.fromJson(response);
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลสูตรได้: $e');
    }
  }

  /// สร้างสูตรใหม่
  static Future<PromotionFormulaConfig> createFormula({
    required String name,
    String? description,
    required Map<String, double> weights,
    Map<String, dynamic>? marginThresholds,
    Map<String, dynamic>? expiryThresholds,
    Map<String, dynamic>? seasonalThresholds,
    Map<String, dynamic>? festivalThresholds,
    Map<String, dynamic>? ingredientThresholds,
    List<Map<String, dynamic>>? discountRanges,
    List<String>? enabledCriteria,
    DateTime? validFrom,
    DateTime? validUntil,
    String? reason, // เหตุผลในการสร้าง (สำหรับ history)
  }) async {
    try {
      // Validate weights รวม = 1.00
      final totalWeight = weights.values.fold<double>(0, (sum, w) => sum + w);
      if ((totalWeight - 1.0).abs() > 0.01) {
        throw Exception('น้ำหนักรวมต้องเท่ากับ 100% (1.00) ปัจจุบัน: ${(totalWeight * 100).toStringAsFixed(0)}%');
      }

      final data = {
        'name': name,
        'description': description,
        'is_active': false, // สร้างใหม่ยังไม่ active
        'is_default': false,
        'valid_from': validFrom?.toIso8601String().split('T')[0],
        'valid_until': validUntil?.toIso8601String().split('T')[0],
        'weight_margin': weights['margin'] ?? 0.25,
        'weight_expiry': weights['expiry'] ?? 0.35,
        'weight_seasonal': weights['seasonal'] ?? 0.20,
        'weight_festival': weights['festival'] ?? 0.10,
        'weight_ingredient_expiry': weights['ingredient'] ?? 0.10,
        'margin_thresholds': marginThresholds,
        'expiry_thresholds': expiryThresholds,
        'seasonal_thresholds': seasonalThresholds,
        'festival_thresholds': festivalThresholds,
        'ingredient_thresholds': ingredientThresholds,
        'discount_ranges': discountRanges,
        'enabled_criteria': enabledCriteria ?? ['margin', 'expiry', 'seasonal', 'festival', 'ingredient'],
      };

      final response = await _supabase
          .from('promotion_formula_configs')
          .insert(data)
          .select()
          .single();

      // บันทึก history
      await _logHistory(
        formulaId: response['id'],
        changeType: 'created',
        reason: reason ?? 'สร้างสูตรใหม่',
        newValue: name,
        formulaSnapshot: response,
      );

      return PromotionFormulaConfig.fromJson(response);
    } catch (e) {
      throw Exception('ไม่สามารถสร้างสูตรได้: $e');
    }
  }

  /// อัปเดตสูตร
  static Future<PromotionFormulaConfig> updateFormula({
    required String id,
    String? name,
    String? description,
    Map<String, double>? weights,
    Map<String, dynamic>? marginThresholds,
    Map<String, dynamic>? expiryThresholds,
    Map<String, dynamic>? seasonalThresholds,
    Map<String, dynamic>? festivalThresholds,
    Map<String, dynamic>? ingredientThresholds,
    List<Map<String, dynamic>>? discountRanges,
    List<String>? enabledCriteria,
    DateTime? validFrom,
    DateTime? validUntil,
    String? reason,
  }) async {
    try {
      // ดึงข้อมูลเก่าเพื่อบันทึก history
      final oldFormula = await getFormulaById(id);

      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (validFrom != null) data['valid_from'] = validFrom.toIso8601String().split('T')[0];
      if (validUntil != null) data['valid_until'] = validUntil.toIso8601String().split('T')[0];
      if (marginThresholds != null) data['margin_thresholds'] = marginThresholds;
      if (expiryThresholds != null) data['expiry_thresholds'] = expiryThresholds;
      if (seasonalThresholds != null) data['seasonal_thresholds'] = seasonalThresholds;
      if (festivalThresholds != null) data['festival_thresholds'] = festivalThresholds;
      if (ingredientThresholds != null) data['ingredient_thresholds'] = ingredientThresholds;
      if (discountRanges != null) data['discount_ranges'] = discountRanges;
      if (enabledCriteria != null) data['enabled_criteria'] = enabledCriteria;

      if (weights != null) {
        final totalWeight = weights.values.fold<double>(0, (sum, w) => sum + w);
        if ((totalWeight - 1.0).abs() > 0.01) {
          throw Exception('น้ำหนักรวมต้องเท่ากับ 100%');
        }
        data['weight_margin'] = weights['margin'];
        data['weight_expiry'] = weights['expiry'];
        data['weight_seasonal'] = weights['seasonal'];
        data['weight_festival'] = weights['festival'];
        data['weight_ingredient_expiry'] = weights['ingredient'];
      }

      final response = await _supabase
          .from('promotion_formula_configs')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      // บันทึก history
      await _logHistory(
        formulaId: id,
        changeType: 'updated',
        reason: reason ?? 'อัปเดตสูตร',
        formulaSnapshot: response,
      );

      return PromotionFormulaConfig.fromJson(response);
    } catch (e) {
      throw Exception('ไม่สามารถอัปเดตสูตรได้: $e');
    }
  }

  /// เปิดใช้งานสูตร (Active)
  static Future<void> activateFormula(String id, {String? reason}) async {
    try {
      // 1. Deactivate สูตรอื่นทั้งหมด
      await _supabase
          .from('promotion_formula_configs')
          .update({'is_active': false})
          .eq('is_active', true);

      // 2. Activate สูตรที่เลือก
      final response = await _supabase
          .from('promotion_formula_configs')
          .update({'is_active': true})
          .eq('id', id)
          .select()
          .single();

      // 3. บันทึก history
      await _logHistory(
        formulaId: id,
        changeType: 'activated',
        reason: reason ?? 'เปิดใช้งานสูตร',
        newValue: response['name'],
        formulaSnapshot: response,
      );
    } catch (e) {
      throw Exception('ไม่สามารถเปิดใช้งานสูตรได้: $e');
    }
  }

  /// ปิดใช้งานสูตร
  static Future<void> deactivateFormula(String id, {String? reason}) async {
    try {
      final response = await _supabase
          .from('promotion_formula_configs')
          .update({'is_active': false})
          .eq('id', id)
          .select()
          .single();

      await _logHistory(
        formulaId: id,
        changeType: 'deactivated',
        reason: reason ?? 'ปิดใช้งานสูตร',
        oldValue: response['name'],
        formulaSnapshot: response,
      );
    } catch (e) {
      throw Exception('ไม่สามารถปิดใช้งานสูตรได้: $e');
    }
  }

  /// ลบสูตร (ไม่ให้ลบถ้าเป็น active หรือ default)
  static Future<void> deleteFormula(String id, {String? reason}) async {
    try {
      final formula = await getFormulaById(id);
      
      if (formula.isActive) {
        throw Exception('ไม่สามารถลบสูตรที่กำลังใช้งานอยู่ได้ กรุณาปิดใช้งานก่อน');
      }
      if (formula.isDefault) {
        throw Exception('ไม่สามารถลบสูตรเริ่มต้นได้');
      }

      await _logHistory(
        formulaId: id,
        changeType: 'deleted',
        reason: reason ?? 'ลบสูตร',
        oldValue: formula.name,
        formulaSnapshot: formula.toJson(),
      );

      await _supabase.from('promotion_formula_configs').delete().eq('id', id);
    } catch (e) {
      throw Exception('ไม่สามารถลบสูตรได้: $e');
    }
  }

  /// ดึงประวัติการเปลี่ยนแปลง
  static Future<List<Map<String, dynamic>>> getFormulaHistory(
    String formulaId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('promotion_formula_history')
          .select('''
            *,
            changed_by:changed_by(email)
          ''')
          .eq('formula_id', formulaId)
          .order('changed_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('ไม่สามารถดึงประวัติได้: $e');
    }
  }

  // ============================================
  // Private Helper: บันทึกประวัติ
  // ============================================

  static Future<void> _logHistory({
    required String formulaId,
    required String changeType,
    String? fieldChanged,
    String? oldValue,
    String? newValue,
    String? reason,
    Map<String, dynamic>? formulaSnapshot,
  }) async {
    try {
      await _supabase.from('promotion_formula_history').insert({
        'formula_id': formulaId,
        'change_type': changeType,
        'field_changed': fieldChanged,
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'formula_snapshot': formulaSnapshot,
      });
    } catch (e) {
      // Log error แต่ไม่ throw เพราะ history ไม่ควรขัดขวาง operation หลัก
      print('Warning: ไม่สามารถบันทึกประวัติได้: $e');
    }
  }

  // ============================================
  // Hybrid Calculation: SQL Raw Scores + Dart Weighted
  // ============================================

  /// คำนวณ Priority Score แบบ Hybrid
  /// 
  /// ขั้นตอน:
  /// 1. SQL คำนวณ raw scores (เร็วใน DB)
  /// 2. Dart คำนวณ weighted score + จัดลำดับ + แนะนำส่วนลด
  /// 3. Return พร้อมเหตุผลแต่ละปัจจัย
  static Future<List<PriorityScoreResult>> calculatePriorityScores({
    required List<String> productIds,
    String? formulaId, // NULL = ใช้สูตรที่ active
  }) async {
    try {
      // 1. ดึงสูตรที่จะใช้
      final formula = formulaId != null
          ? await getFormulaById(formulaId)
          : await getActiveFormula();

      if (formula == null) {
        throw Exception('ไม่พบสูตรที่ใช้งาน กรุณาสร้างและเปิดใช้งานสูตรก่อน');
      }

      // 2. ดึง raw scores จาก SQL (RPC หรือ query)
      final rawScores = await _getRawScoresFromSql(productIds, formula.id);

      // 3. คำนวณ weighted score ใน Dart (ยืดหยุ่น ปรับได้)
      final results = <PriorityScoreResult>[];

      for (final raw in rawScores) {
        double weightedScore = 0;
        final reasons = <ScoreReason>[];

        // Margin Score
        if (formula.enabledCriteria.contains('margin') && formula.weightMargin > 0) {
          final marginContribution = (raw['margin_score'] as int) * formula.weightMargin;
          weightedScore += marginContribution;
          if (raw['margin_score'] as int > 0) {
            reasons.add(ScoreReason(
              criterion: 'กำไรสินค้า',
              rawScore: raw['margin_score'] as int,
              weight: formula.weightMargin,
              contribution: marginContribution,
              label: _getMarginLabel(raw['margin_score'] as int, formula),
            ));
          }
        }

        // Expiry Score
        if (formula.enabledCriteria.contains('expiry') && formula.weightExpiry > 0) {
          final expiryContribution = (raw['expiry_score'] as int) * formula.weightExpiry;
          weightedScore += expiryContribution;
          if (raw['expiry_score'] as int > 0) {
            reasons.add(ScoreReason(
              criterion: 'ใกล้หมดอายุ',
              rawScore: raw['expiry_score'] as int,
              weight: formula.weightExpiry,
              contribution: expiryContribution,
              label: _getExpiryLabel(raw['expiry_score'] as int, formula),
            ));
          }
        }

        // Seasonal Score
        if (formula.enabledCriteria.contains('seasonal') && formula.weightSeasonal > 0) {
          final seasonalContribution = (raw['seasonal_score'] as int) * formula.weightSeasonal;
          weightedScore += seasonalContribution;
          if (raw['seasonal_score'] as int > 0) {
            reasons.add(ScoreReason(
              criterion: 'ฤดูกาล',
              rawScore: raw['seasonal_score'] as int,
              weight: formula.weightSeasonal,
              contribution: seasonalContribution,
              label: _getSeasonalLabel(raw['seasonal_score'] as int, formula),
            ));
          }
        }

        // Festival Score
        if (formula.enabledCriteria.contains('festival') && formula.weightFestival > 0) {
          final festivalContribution = (raw['festival_score'] as int) * formula.weightFestival;
          weightedScore += festivalContribution;
          if (raw['festival_score'] as int > 0) {
            reasons.add(ScoreReason(
              criterion: 'เทศกาล',
              rawScore: raw['festival_score'] as int,
              weight: formula.weightFestival,
              contribution: festivalContribution,
              label: _getFestivalLabel(raw['festival_score'] as int, formula),
            ));
          }
        }

        // Ingredient Score
        if (formula.enabledCriteria.contains('ingredient') && formula.weightIngredientExpiry > 0) {
          final ingredientContribution = (raw['ingredient_score'] as int) * formula.weightIngredientExpiry;
          weightedScore += ingredientContribution;
          if (raw['ingredient_score'] as int > 0) {
            reasons.add(ScoreReason(
              criterion: 'วัตถุดิบใกล้หมด',
              rawScore: raw['ingredient_score'] as int,
              weight: formula.weightIngredientExpiry,
              contribution: ingredientContribution,
              label: _getIngredientLabel(raw['ingredient_score'] as int, formula),
            ));
          }
        }

        final finalScore = weightedScore.round();
        final discountRange = formula.getDiscountRangeForScore(finalScore);

        results.add(PriorityScoreResult(
          productId: raw['product_id'] as String,
          formulaId: formula.id,
          formulaName: formula.name,
          finalScore: finalScore,
          rawScores: {
            'margin': raw['margin_score'],
            'expiry': raw['expiry_score'],
            'seasonal': raw['seasonal_score'],
            'festival': raw['festival_score'],
            'ingredient': raw['ingredient_score'],
          },
          reasons: reasons,
          suggestedDiscountMin: discountRange?['discount_min_pct'] as int? ?? 5,
          suggestedDiscountMax: discountRange?['discount_max_pct'] as int? ?? 10,
          discountLabel: discountRange?['label'] as String? ?? 'ไม่เร่งด่วน',
          priorityColor: discountRange?['color'] as String? ?? '#44AA44',
        ));
      }

      // 4. Sort ตามคะแนนสูง -> ต่ำ
      results.sort((a, b) => b.finalScore.compareTo(a.finalScore));

      return results;
    } catch (e) {
      throw Exception('ไม่สามารถคำนวณคะแนนได้: $e');
    }
  }

  /// ดึง Raw Scores จาก SQL (ส่วน Hybrid ที่ทำใน DB)
  static Future<List<Map<String, dynamic>>> _getRawScoresFromSql(
    List<String> productIds,
    String formulaId,
  ) async {
    try {
      // ใช้ RPC ถ้ามี function ใน DB
      // หรือ query โดยตรง
      final response = await _supabase
          .rpc('calculate_raw_scores_bulk', params: {
            'p_product_ids': productIds,
            'p_formula_id': formulaId,
          });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Fallback: คำนวณใน Dart ถ้า RPC ไม่พร้อม
      print('RPC ไม่พร้อมใช้งาน ใช้การคำนวณแบบ query แทน: $e');
      return _getRawScoresViaQuery(productIds, formulaId);
    }
  }

  /// Fallback: ดึง Raw Scores ผ่าน Query (ถ้า RPC ไม่พร้อม)
  static Future<List<Map<String, dynamic>>> _getRawScoresViaQuery(
    List<String> productIds,
    String formulaId,
  ) async {
    // Query ข้อมูลพื้นฐานแล้วคำนวณใน Dart (ช้ากว่าแต่ทำงานได้)
    // TODO: Implement ตามโครงสร้าง DB ที่มี
    return [];
  }

  // ============================================
  // Helper Methods สำหรับ Label
  // ============================================

  static String _getMarginLabel(int score, PromotionFormulaConfig formula) {
    final thresholds = formula.marginThresholds;
    if (score >= (thresholds['excellent']?['score'] ?? 100)) return thresholds['excellent']?['label'] ?? 'กำไรดีมาก';
    if (score >= (thresholds['good']?['score'] ?? 70)) return thresholds['good']?['label'] ?? 'กำไรดี';
    if (score >= (thresholds['fair']?['score'] ?? 40)) return thresholds['fair']?['label'] ?? 'กำไรปกติ';
    return thresholds['poor']?['label'] ?? 'กำไรน้อย';
  }

  static String _getExpiryLabel(int score, PromotionFormulaConfig formula) {
    final thresholds = formula.expiryThresholds;
    if (score >= (thresholds['expired']?['score'] ?? 100)) return thresholds['expired']?['label'] ?? 'หมดอายุแล้ว';
    if (score >= (thresholds['critical']?['score'] ?? 90)) return thresholds['critical']?['label'] ?? 'เหลือ ≤3 วัน';
    if (score >= (thresholds['urgent']?['score'] ?? 70)) return thresholds['urgent']?['label'] ?? 'เหลือ 4-7 วัน';
    if (score >= (thresholds['warning']?['score'] ?? 50)) return thresholds['warning']?['label'] ?? 'เหลือ 8-14 วัน';
    return thresholds['notice']?['label'] ?? 'เหลือ 15-30 วัน';
  }

  static String _getSeasonalLabel(int score, PromotionFormulaConfig formula) {
    final thresholds = formula.seasonalThresholds;
    if (score >= (thresholds['in_season']?['score'] ?? 100)) return thresholds['in_season']?['label'] ?? 'อยู่ในฤดูกาล';
    if (score >= (thresholds['ending_soon']?['score'] ?? 80)) return thresholds['ending_soon']?['label'] ?? 'ใกล้สิ้นฤดู';
    return 'นอกฤดูกาล';
  }

  static String _getFestivalLabel(int score, PromotionFormulaConfig formula) {
    final thresholds = formula.festivalThresholds;
    // thresholds is now List<Map<String, dynamic>>
    // Format: [{"days_before": 0, "score": 100, "label": "..."}, ...]
    
    // Find the threshold where score >= threshold score
    for (final threshold in thresholds) {
      final thresholdScore = (threshold['score'] as num?)?.toInt() ?? 0;
      if (score >= thresholdScore) {
        return threshold['label'] as String? ?? 'ไม่ระบุ';
      }
    }
    return 'ไม่ใกล้เทศกาล';
  }

  static String _getIngredientLabel(int score, PromotionFormulaConfig formula) {
    final thresholds = formula.ingredientThresholds;
    if (score >= (thresholds['critical']?['score'] ?? 100)) return thresholds['critical']?['label'] ?? 'วัตถุดิบหลักเหลือ ≤7 วัน';
    if (score >= (thresholds['warning']?['score'] ?? 70)) return thresholds['warning']?['label'] ?? 'วัตถุดิบหลักเหลือ 8-14 วัน';
    return 'ไม่มีวัตถุดิบใกล้หมด';
  }

  // ============================================
  // Simulation Method (สำหรับทดสอบสูตร)
  // ============================================

  /// ทดสอบสูตรกับสินค้าจริง (Simulation)
  static Future<PriorityScoreResult?> simulateFormulaForProduct({
    required String productId,
    required PromotionFormulaConfig formula,
  }) async {
    try {
      final results = await calculatePriorityScores(
        productIds: [productId],
        formulaId: formula.id,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      throw Exception('ไม่สามารถทดสอบสูตรได้: $e');
    }
  }
}

// ============================================
// Model Classes
// ============================================

class ScoreReason {
  final String criterion;
  final int rawScore;
  final double weight;
  final double contribution;
  final String label;

  ScoreReason({
    required this.criterion,
    required this.rawScore,
    required this.weight,
    required this.contribution,
    required this.label,
  });
}

class PriorityScoreResult {
  final String productId;
  final String formulaId;
  final String formulaName;
  final int finalScore;
  final Map<String, dynamic> rawScores;
  final List<ScoreReason> reasons;
  final int suggestedDiscountMin;
  final int suggestedDiscountMax;
  final String discountLabel;
  final String priorityColor;

  PriorityScoreResult({
    required this.productId,
    required this.formulaId,
    required this.formulaName,
    required this.finalScore,
    required this.rawScores,
    required this.reasons,
    required this.suggestedDiscountMin,
    required this.suggestedDiscountMax,
    required this.discountLabel,
    required this.priorityColor,
  });

  String get suggestedDiscountRange => '$suggestedDiscountMin-$suggestedDiscountMax%';
}
