/// Pagination Model for handling paginated results
/// Used across the application for consistent pagination handling

class PaginatedResult<T> {
  final List<T> data;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;
  final int? totalPages;

  PaginatedResult({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  }) : totalPages = (total / limit).ceil();

  /// Create empty result
  factory PaginatedResult.empty({
    int page = 1,
    int limit = 20,
  }) {
    return PaginatedResult(
      data: [],
      page: page,
      limit: limit,
      total: 0,
      hasMore: false,
    );
  }

  /// Create from map (for JSON serialization)
  factory PaginatedResult.fromMap(Map<String, dynamic> map, {T Function(Map<String, dynamic>)? fromMap}) {
    final dataList = (map['data'] as List?) ?? [];
    final data = fromMap != null 
        ? dataList.map((item) => fromMap(item as Map<String, dynamic>)).toList()
        : dataList.cast<T>();

    return PaginatedResult<T>(
      data: data,
      page: map['page'] as int? ?? 1,
      limit: map['limit'] as int? ?? 20,
      total: map['total'] as int? ?? 0,
      hasMore: map['hasMore'] as bool? ?? false,
    );
  }

  /// Convert to map (for JSON serialization)
  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'page': page,
      'limit': limit,
      'total': total,
      'hasMore': hasMore,
      'totalPages': totalPages,
    };
  }

  /// Get current page start index (1-based)
  int get startIndex => (page - 1) * limit + 1;

  /// Get current page end index (1-based)
  int get endIndex => (startIndex + data.length - 1).clamp(0, total);

  /// Check if this is the first page
  bool get isFirstPage => page <= 1;

  /// Check if this is the last page
  bool get isLastPage => !hasMore;

  /// Get next page number (null if no next page)
  int? get nextPage => hasMore ? page + 1 : null;

  /// Get previous page number (null if no previous page)
  int? get previousPage => isFirstPage ? null : page - 1;

  /// Copy with new values
  PaginatedResult<T> copyWith({
    List<T>? data,
    int? page,
    int? limit,
    int? total,
    bool? hasMore,
  }) {
    return PaginatedResult<T>(
      data: data ?? this.data,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  String toString() {
    return 'PaginatedResult(data: ${data.length} items, page: $page/$totalPages, total: $total)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedResult<T> &&
          runtimeType == other.runtimeType &&
          listEquals(data, other.data) &&
          page == other.page &&
          limit == other.limit &&
          total == other.total &&
          hasMore == other.hasMore;

  @override
  int get hashCode =>
      data.hashCode ^
      page.hashCode ^
      limit.hashCode ^
      total.hashCode ^
      hasMore.hashCode;
}

/// Helper function for comparing lists
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Pagination state for UI components
class PaginationState {
  int currentPage;
  int limit;
  bool isLoading;
  bool hasMore;
  String? error;

  PaginationState({
    this.currentPage = 1,
    this.limit = 20,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  /// Reset to initial state
  void reset() {
    currentPage = 1;
    isLoading = false;
    hasMore = true;
    error = null;
  }

  /// Move to next page
  void nextPage() {
    if (hasMore && !isLoading) {
      currentPage++;
      isLoading = true;
    }
  }

  /// Set loading state
  void setLoading(bool loading) {
    isLoading = loading;
  }

  /// Update pagination info from result
  void updateFromResult(PaginatedResult result) {
    hasMore = result.hasMore;
    isLoading = false;
    error = null;
  }

  /// Set error state
  void setError(String error) {
    this.error = error;
    isLoading = false;
  }

  /// Copy with new values
  PaginationState copyWith({
    int? currentPage,
    int? limit,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return PaginationState(
      currentPage: currentPage ?? this.currentPage,
      limit: limit ?? this.limit,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

/// Sorting options for paginated queries
class SortOption {
  final String field;
  final String label;
  final bool ascending;

  const SortOption({
    required this.field,
    required this.label,
    this.ascending = true,
  });

  /// Common sort options for products
  static const List<SortOption> productSortOptions = [
    SortOption(field: 'name', label: 'ชื่อสินค้า'),
    SortOption(field: 'price', label: 'ราคา'),
    SortOption(field: 'cost', label: 'ต้นทุน'),
    SortOption(field: 'quantity', label: 'จำนวน'),
    SortOption(field: 'created_at', label: 'วันที่สร้าง'),
    SortOption(field: 'updated_at', label: 'วันที่อัปเดต'),
  ];

  /// Sort options for expiring products
  static const List<SortOption> expiringSortOptions = [
    SortOption(field: 'expiry_date', label: 'วันหมดอายุ'),
    SortOption(field: 'quantity', label: 'จำนวน'),
    SortOption(field: 'days_until_expiry', label: 'วันที่เหลือ'),
  ];

  /// Sort options for margin products
  static const List<SortOption> marginSortOptions = [
    SortOption(field: 'margin_percent', label: '% กำไร', ascending: false),
    SortOption(field: 'price', label: 'ราคา'),
    SortOption(field: 'cost', label: 'ต้นทุน'),
  ];

  @override
  String toString() => '$label (${ascending ? '↑' : '↓'})';
}
