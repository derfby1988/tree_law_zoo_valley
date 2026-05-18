import 'package:flutter/foundation.dart';

import 'package:tree_law_zoo_valley/services/daily_coupon_entry_service.dart';
import 'package:tree_law_zoo_valley/services/pos_discount_service.dart';
import 'package:tree_law_zoo_valley/services/pos_promotion_service.dart';
import 'package:tree_law_zoo_valley/services/inventory_service.dart';
import 'package:tree_law_zoo_valley/services/user_group_service.dart';
import 'package:tree_law_zoo_valley/models/pos_discount_model.dart';
import 'package:tree_law_zoo_valley/models/pos_promotion_model.dart';
import 'package:tree_law_zoo_valley/models/user_group_model.dart';
import 'package:tree_law_zoo_valley/models/pagination_model.dart';

class CouponPromotionAdminController extends ChangeNotifier {
  // Tab state
  int selectedTabIndex = 0;

  // Core data
  bool isLoading = false;
  List<PosDiscount> coupons = [];
  List<PosPromotion> promotions = [];
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> categories = [];
  List<UserGroup> userGroups = [];
  String? errorMessage;

  // Phase 5: Expiry targeting data
  List<Map<String, dynamic>> expiringProducts = [];
  List<Map<String, dynamic>> expiringIngredients = [];
  String expiryFilter = '7days';
  bool isLoadingExpiry = false;

  // Phase 7: Analytics data
  List<Map<String, dynamic>> usageData = [];
  DateTime? analyticsStartDate;
  DateTime? analyticsEndDate;
  String? selectedCouponId;
  String? selectedPromotionId;
  bool isLoadingAnalytics = false;
  Map<String, dynamic>? analyticsSummary;

  // Phase 3: Enhanced product management
  PaginationState productPagination = PaginationState();
  List<Map<String, dynamic>> filteredProducts = [];
  String productSearchQuery = '';
  String selectedCategory = 'all';
  bool showProductFilters = false;
  String productSortBy = 'name';
  bool productSortAscending = true;

  // Phase 13: Daily coupon computed data
  List<PosDiscount> get dailyCoupons =>
      coupons.where((coupon) => _isDailyCoupon(coupon)).toList();

  // Phase 13: Daily history state
  PosDiscount? selectedDailyCoupon;
  bool isLoadingDailyHistory = false;
  int dailyHistoryRangeDays = 7;
  List<Map<String, dynamic>> dailyEntryLogs = [];
  List<Map<String, dynamic>> dailyPosHistory = [];
  Map<String, dynamic>? dailyEntrySummary;
  List<String> dailyAlerts = [];

  Map<String, dynamic> getTargetingRule(PosDiscount coupon) {
    final rule = coupon.targetingRule;
    if (rule is Map<String, dynamic>) {
      return rule;
    }
    if (rule is Map) {
      return Map<String, dynamic>.from(rule);
    }
    return const {};
  }

  bool _isDailyCoupon(PosDiscount coupon) {
    final rule = getTargetingRule(coupon);
    final enabled = rule['daily_unified_enabled'];
    return enabled == true;
  }

  // =============================================
  // Core Data Loading
  // =============================================

  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        PosDiscountService.getAllDiscounts(),
        PosPromotionService.getAllPromotions(),
        InventoryService.getProducts(useCache: true),
        InventoryService.getCategories(useCache: true),
        UserGroupService.getAllGroups(),
      ]);

      coupons = results[0] as List<PosDiscount>;
      promotions = results[1] as List<PosPromotion>;
      allProducts = results[2] as List<Map<String, dynamic>>;
      categories = results[3] as List<Map<String, dynamic>>;
      userGroups = results[4] as List<UserGroup>;
      filteredProducts = allProducts;
      if (dailyCoupons.isNotEmpty && selectedDailyCoupon == null) {
        selectedDailyCoupon = dailyCoupons.first;
      } else if (dailyCoupons.isEmpty) {
        selectedDailyCoupon = null;
        dailyEntryLogs = [];
        dailyPosHistory = [];
        dailyEntrySummary = null;
      }
      isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading data: $e');
      errorMessage = 'ไม่สามารถโหลดข้อมูล: $e';
      isLoading = false;
      notifyListeners();
    }
  }

  // Phase 3: Enhanced product loading with pagination
  Future<void> loadProductsPaginated({bool refresh = false}) async {
    if (refresh) {
      productPagination.reset();
      InventoryService.clearCachePattern('getProducts');
    }

    productPagination.setLoading(true);
    notifyListeners();

    try {
      final result = await InventoryService.getProductsPaginated(
        page: productPagination.currentPage,
        limit: productPagination.limit,
        categoryId: selectedCategory == 'all' ? null : selectedCategory,
        searchQuery: productSearchQuery.isNotEmpty ? productSearchQuery : null,
        sortBy: productSortBy,
        ascending: productSortAscending,
        useCache: !refresh,
      );

      if (refresh || productPagination.currentPage == 1) {
        filteredProducts = result.data.cast<Map<String, dynamic>>();
      } else {
        filteredProducts.addAll(result.data.cast<Map<String, dynamic>>());
      }
      productPagination.updateFromResult(result);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading products: $e');
      productPagination.setError('ไม่สามารถโหลดสินค้า: $e');
      notifyListeners();
    }
  }

  // Phase 3: Product filtering
  void filterProducts() {
    filteredProducts = allProducts.where((product) {
      if (selectedCategory != 'all' && product['category_id']?.toString() != selectedCategory) {
        return false;
      }
      if (productSearchQuery.isNotEmpty) {
        final query = productSearchQuery.toLowerCase();
        final name = (product['name'] ?? '').toString().toLowerCase();
        final code = (product['code'] ?? '').toString().toLowerCase();
        final sku = (product['sku'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !code.contains(query) && !sku.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
    notifyListeners();
  }

  // =============================================
  // Tab Selection
  // =============================================

  void selectTab(int index) {
    selectedTabIndex = index;
    notifyListeners();

    if (index == 2 || index == 3) {
      if (expiringProducts.isEmpty && expiringIngredients.isEmpty) {
        loadExpiringData();
      }
    }
    if (index == 4) {
      if (usageData.isEmpty && analyticsSummary == null) {
        loadAnalyticsData();
      }
    }
    if (index == 6) {
      if (dailyCoupons.isNotEmpty && selectedDailyCoupon == null) {
        selectedDailyCoupon = dailyCoupons.first;
      }
      if (selectedDailyCoupon != null && dailyEntryLogs.isEmpty && !isLoadingDailyHistory) {
        loadDailyCouponHistory();
      }
    }
  }

  // =============================================
  // Expiry Data
  // =============================================

  Future<void> loadExpiringData() async {
    isLoadingExpiry = true;
    notifyListeners();

    try {
      final daysMap = {
        '3days': 3,
        '7days': 7,
        '14days': 14,
        '30days': 30,
        'expired': 0,
      };
      final days = daysMap[expiryFilter] ?? 7;
      final includeExpired = expiryFilter == 'expired' || days >= 7;

      final results = await Future.wait([
        InventoryService.getExpiringProducts(
          daysThreshold: days,
          includeExpired: includeExpired,
        ),
        InventoryService.getExpiringIngredients(
          daysThreshold: days,
          includeExpired: includeExpired,
        ),
      ]);

      expiringProducts = results[0] as List<Map<String, dynamic>>;
      expiringIngredients = results[1] as List<Map<String, dynamic>>;
      isLoadingExpiry = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading expiry data: $e');
      isLoadingExpiry = false;
      notifyListeners();
    }
  }

  void setExpiryFilter(String value) {
    expiryFilter = value;
    notifyListeners();
    loadExpiringData();
  }

  // =============================================
  // Analytics Data
  // =============================================

  void setAnalyticsStartDate(DateTime? date) {
    analyticsStartDate = date;
    notifyListeners();
  }

  void setAnalyticsEndDate(DateTime? date) {
    analyticsEndDate = date;
    notifyListeners();
  }

  Future<void> loadAnalyticsData() async {
    isLoadingAnalytics = true;
    notifyListeners();

    try {
      final summary = await PosDiscountService.getAnalyticsSummary(
        startDate: analyticsStartDate,
        endDate: analyticsEndDate,
        discountId: selectedCouponId,
        promotionId: selectedPromotionId,
      );

      final usage = await PosDiscountService.getUsageAnalytics(
        startDate: analyticsStartDate,
        endDate: analyticsEndDate,
        discountId: selectedCouponId,
        promotionId: selectedPromotionId,
        limit: 100,
      );

      analyticsSummary = summary;
      usageData = usage;
      isLoadingAnalytics = false;
      notifyListeners();
    } catch (e) {
      isLoadingAnalytics = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOrderDetailsForDiscount(Map<String, dynamic> usage) async {
    return await PosDiscountService.getOrderDetailsForDiscount(
      discountId: usage['type'] == 'coupon' ? usage['id'] : null,
      promotionId: usage['type'] == 'promotion' ? usage['id'] : null,
      startDate: analyticsStartDate,
      endDate: analyticsEndDate,
    );
  }

  // =============================================
  // Coupon CRUD
  // =============================================

  Future<bool> addCoupon({
    required String name,
    required String description,
    required String discountType,
    required String scope,
    required double value,
    double? maxDiscount,
    double? minAmount,
    required bool stackable,
    required bool isActive,
    List<String> applicableCategoryIds = const [],
    List<String> applicableProductIds = const [],
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    String lifecycleStatus = 'active',
    List<String> applicableChannels = const [],
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
    bool showInCouponTab = false,
    bool showInPosDiscountDialog = false,
    DateTime? startAt,
    DateTime? endAt,
    Map<String, dynamic>? targetingRule,
  }) async {
    if (name.isEmpty) return false;
    final result = await PosDiscountService.addDiscount(
      name: name, description: description,
      discountType: discountType, scope: scope, value: value,
      maxDiscount: maxDiscount, minAmount: minAmount,
      stackable: stackable,
      isActive: isActive,
      applicableCategoryIds: applicableCategoryIds,
      applicableProductIds: applicableProductIds,
      couponCode: couponCode,
      usageLimit: usageLimit,
      usageLimitPerCustomer: usageLimitPerCustomer,
      usageLimitPerDay: usageLimitPerDay,
      lifecycleStatus: lifecycleStatus,
      applicableChannels: applicableChannels,
      requireInStock: requireInStock,
      requireSufficientIngredients: requireSufficientIngredients,
      includePendingProcurement: includePendingProcurement,
      showInCouponTab: showInCouponTab,
      showInPosDiscountDialog: showInPosDiscountDialog,
      startAt: startAt,
      endAt: endAt,
      targetingRule: targetingRule ?? const {},
    );
    if (result != null) {
      await loadData();
      return true;
    }
    return false;
  }

  Future<bool> updateCoupon({
    required String id,
    required String name,
    required String description,
    required String discountType,
    required String scope,
    required double value,
    double? maxDiscount,
    double? minAmount,
    required bool stackable,
    required bool isActive,
    List<String> applicableCategoryIds = const [],
    List<String> applicableProductIds = const [],
    String? couponCode,
    int? usageLimit,
    int? usageLimitPerCustomer,
    int? usageLimitPerDay,
    String lifecycleStatus = 'active',
    List<String> applicableChannels = const [],
    bool requireInStock = false,
    bool requireSufficientIngredients = false,
    bool includePendingProcurement = false,
    bool showInCouponTab = false,
    bool showInPosDiscountDialog = false,
    DateTime? startAt,
    DateTime? endAt,
    Map<String, dynamic>? targetingRule,
  }) async {
    if (name.isEmpty) return false;
    final result = await PosDiscountService.updateDiscount(
      id: id, name: name, description: description,
      discountType: discountType, value: value, isActive: isActive,
      scope: scope, maxDiscount: maxDiscount, minAmount: minAmount,
      stackable: stackable,
      applicableCategoryIds: applicableCategoryIds,
      applicableProductIds: applicableProductIds,
      couponCode: couponCode,
      usageLimit: usageLimit,
      usageLimitPerCustomer: usageLimitPerCustomer,
      usageLimitPerDay: usageLimitPerDay,
      lifecycleStatus: lifecycleStatus,
      applicableChannels: applicableChannels,
      requireInStock: requireInStock,
      requireSufficientIngredients: requireSufficientIngredients,
      includePendingProcurement: includePendingProcurement,
      showInCouponTab: showInCouponTab,
      showInPosDiscountDialog: showInPosDiscountDialog,
      startAt: startAt,
      endAt: endAt,
      targetingRule: targetingRule,
    );
    if (result != null) {
      await loadData();
      return true;
    }
    return false;
  }

  Future<bool> deleteCoupon(String couponId) async {
    final result = await PosDiscountService.deleteDiscount(couponId);
    if (result) {
      await loadData();
      return true;
    }
    return false;
  }

  // =============================================
  // Phase 13: Daily coupon history
  // =============================================

  void selectDailyCouponForHistory(PosDiscount? coupon) {
    selectedDailyCoupon = coupon;
    notifyListeners();
    if (coupon != null) {
      loadDailyCouponHistory();
    } else {
      dailyEntryLogs = [];
      dailyPosHistory = [];
      dailyEntrySummary = null;
      notifyListeners();
    }
  }

  void setDailyHistoryRange(int days) {
    if (dailyHistoryRangeDays == days) return;
    dailyHistoryRangeDays = days;
    notifyListeners();
    if (selectedDailyCoupon != null) {
      loadDailyCouponHistory();
    }
  }

  Future<void> loadDailyCouponHistory() async {
    final target = selectedDailyCoupon;
    if (target == null) return;
    isLoadingDailyHistory = true;
    notifyListeners();

    final now = DateTime.now();
    final start = now.subtract(Duration(days: dailyHistoryRangeDays));
    final end = now;

    try {
      final results = await Future.wait([
        DailyCouponEntryService.getEntryLogs(
          discountId: target.id,
          startDate: start,
          endDate: end,
          limit: 200,
        ),
        DailyCouponEntryService.getEntrySummary(
          discountId: target.id,
          startDate: start,
          endDate: end,
        ),
        PosDiscountService.getUsageAnalytics(
          startDate: start,
          endDate: end,
          discountId: target.id,
          limit: 120,
        ),
      ]);

      dailyEntryLogs = results[0] as List<Map<String, dynamic>>;
      dailyEntrySummary = results[1] as Map<String, dynamic>;
      dailyPosHistory = (results[2] as List).cast<Map<String, dynamic>>();
      dailyAlerts = _computeDailyAlerts(target);
      isLoadingDailyHistory = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loadDailyCouponHistory: $e');
      isLoadingDailyHistory = false;
      dailyAlerts = [];
      notifyListeners();
    }
  }

  List<String> _computeDailyAlerts(PosDiscount coupon) {
    final alerts = <String>[];
    final rule = getTargetingRule(coupon);
    final entryLimit = rule['entry_limit_per_day'];
    final rows = (dailyEntrySummary?['rows'] as List?) ?? const [];
    Map<String, dynamic>? latestRow;
    if (rows.isNotEmpty && rows.first is Map) {
      latestRow = Map<String, dynamic>.from(rows.first as Map);
    }

    if (entryLimit is int && entryLimit > 0 && latestRow != null) {
      final used = latestRow['total_entries'] is int ? latestRow['total_entries'] as int : 0;
      final remaining = entryLimit - used;
      final ratio = used / entryLimit;
      if (ratio >= 0.8) {
        alerts.add('คูปอง ${coupon.name} ใช้สิทธิ์เข้าแล้ว $used/$entryLimit ครั้งในวันนี้ (เหลือ $remaining)');
      }
    }

    final deniedCount = dailyEntryLogs.where((log) => (log['status'] ?? '') != 'valid').length;
    if (deniedCount > 0) {
      alerts.add('พบการเข้า/ออกที่ถูกปฏิเสธ $deniedCount ครั้ง กรุณาตรวจสอบเหตุผล');
    }

    final replayWindow = rule['qr_replay_window_seconds'];
    if (replayWindow is int && replayWindow < 15) {
      alerts.add('คำเตือน: QR replay window ต่ำกว่า 15 วินาที ตรวจสอบความปลอดภัยอีกครั้ง');
    }

    return alerts;
  }

  // =============================================
  // Promotion CRUD
  // =============================================

  Future<bool> addPromotion({
    required String name,
    required String description,
    required String promotionType,
    String? discountId,
    List<String> applicableUserGroupIds = const [],
    required bool isActive,
    DateTime? startAt,
    DateTime? endAt,
    List<Map<String, dynamic>> items = const [],
  }) async {
    if (name.isEmpty) return false;
    final result = await PosPromotionService.addPromotion(
      name: name, description: description,
      promotionType: promotionType, discountId: discountId,
      applicableUserGroupIds: applicableUserGroupIds,
      isActive: isActive,
      startAt: startAt, endAt: endAt,
    );
    if (result != null) {
      for (final item in items) {
        await PosPromotionService.addPromotionItem(
          promotionId: result.id,
          productId: item['product_id'] as String,
          quantityRequired: (item['quantity'] as int?) ?? 1,
        );
      }
      await loadData();
      return true;
    }
    return false;
  }

  Future<bool> updatePromotion({
    required String id,
    required String name,
    required String description,
    required String promotionType,
    String? discountId,
    List<String> applicableUserGroupIds = const [],
    required bool isActive,
    DateTime? startAt,
    DateTime? endAt,
    List<Map<String, dynamic>> items = const [],
  }) async {
    if (name.isEmpty) return false;
    final result = await PosPromotionService.updatePromotion(
      id: id, name: name, description: description,
      promotionType: promotionType, discountId: discountId,
      applicableUserGroupIds: applicableUserGroupIds,
      isActive: isActive, startAt: startAt, endAt: endAt,
    );
    if (result != null) {
      await PosPromotionService.removePromotionItemsByPromotionId(id);
      for (final item in items) {
        await PosPromotionService.addPromotionItem(
          promotionId: id,
          productId: item['product_id'] as String,
          quantityRequired: (item['quantity'] as int?) ?? 1,
        );
      }
      await loadData();
      return true;
    }
    return false;
  }

  Future<bool> deletePromotion(String promotionId) async {
    final result = await PosPromotionService.deletePromotion(promotionId);
    if (result) {
      await loadData();
      return true;
    }
    return false;
  }

  // =============================================
  // Helpers
  // =============================================

  String formatDate(DateTime date) {
    final months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
      'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
      'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  String getPromotionTypeLabel(String promotionType) {
    switch (promotionType) {
      case 'bundle':
        return 'ชุดสินค้า';
      case 'seasonal':
        return 'ตามฤดูกาล';
      case 'buy_x_get_y':
        return 'ซื้อ X แถม Y';
      default:
        return promotionType;
    }
  }
}
