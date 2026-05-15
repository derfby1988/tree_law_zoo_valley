import 'package:flutter/foundation.dart';

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
