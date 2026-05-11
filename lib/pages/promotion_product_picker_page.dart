import 'package:flutter/material.dart';
import 'package:tree_law_zoo_valley/services/inventory_service.dart';
import 'package:tree_law_zoo_valley/services/pos_promotion_service.dart';
import 'package:tree_law_zoo_valley/theme/app_design_system.dart';
import 'package:tree_law_zoo_valley/models/pagination_model.dart';
import 'package:tree_law_zoo_valley/models/recommended_product_model.dart';

class PromotionProductPickerPage extends StatefulWidget {
  final List<Map<String, dynamic>> initiallySelectedProducts;

  const PromotionProductPickerPage({
    super.key,
    this.initiallySelectedProducts = const [],
  });

  @override
  State<PromotionProductPickerPage> createState() => _PromotionProductPickerPageState();
}

class _PromotionProductPickerPageState extends State<PromotionProductPickerPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  
  // Selected products
  List<Map<String, dynamic>> _selectedProducts = [];
  
  // Data for each tab
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _expiringProducts = [];
  List<Map<String, dynamic>> _expiringIngredients = [];
  List<Map<String, dynamic>> _highMarginProducts = [];
  List<Map<String, dynamic>> _seasonalProducts = [];
  List<Map<String, dynamic>> _festivalProducts = [];
  List<RecommendedProduct> _recommendedProducts = [];
  
  // Loading states
  bool _isLoading = true;
  Map<String, bool> _tabLoading = {
    'all': true,
    'expiring': true,
    'ingredients': true,
    'margin': true,
    'seasonal': true,
    'festival': true,
    'recommended': true,
  };

  // Filter
  String _selectedCategory = 'all';
  String _expiringFilter = '7'; // days
  String _marginFilter = 'high'; // high, medium, low
  String _seasonFilter = 'summer'; // summer, rainy, winter
  String _searchQuery = '';
  bool _showFilters = false;
  
  // Store & Shelf filters
  String? _selectedStoreId;
  String? _selectedShelfId;
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _shelves = [];
  Map<String, List<Map<String, dynamic>>> _shelvesByStore = {};
  
  // Sorting
  String _sortBy = 'name';
  bool _sortAscending = true;
  final Map<int, String> _tabSortOptions = {
    0: 'name', // All products
    1: 'expiry_date', // Expiring
    3: 'margin_percent', // High margin
    4: 'name', // Seasonal
    5: 'festival_date', // Festival
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _selectedProducts = List.from(widget.initiallySelectedProducts);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadAllProducts(),
      _loadExpiringProducts(),
      _loadExpiringIngredients(),
      _loadHighMarginProducts(),
      _loadSeasonalProducts(),
      _loadFestivalProducts(),
      _loadRecommendedProducts(),
      _loadStores(),
      _loadShelves(),
    ]);
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadStores() async {
    try {
      final response = await InventoryService.getWarehouses();
      setState(() {
        _stores = response;
      });
    } catch (e) {
      debugPrint('Error loading stores: $e');
    }
  }
  
  Future<void> _loadShelves() async {
    try {
      final response = await InventoryService.getShelves(
        includeInactive: false,
      );
      setState(() {
        _shelves = response;
        // Group shelves by store
        _shelvesByStore = {};
        for (final shelf in response) {
          final storeId = shelf['warehouse_id']?.toString() ?? 'unknown';
          if (!_shelvesByStore.containsKey(storeId)) {
            _shelvesByStore[storeId] = [];
          }
          _shelvesByStore[storeId]!.add(shelf);
        }
      });
    } catch (e) {
      debugPrint('Error loading shelves: $e');
    }
  }

  Future<void> _loadAllProducts() async {
    try {
      // Phase 3: Use new API with filters and sorting
      final result = await InventoryService.getProductsPaginated(
        page: 1,
        limit: 100, // Load more for picker
        categoryId: _selectedCategory == 'all' ? null : _selectedCategory,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: _sortBy,
        ascending: _sortAscending,
        useCache: true,
      );
      
      // ดึง shelf_id จาก inventory_products และ join กับ inventory_shelves
      // เพื่อได้ warehouse_id ที่ถูกต้อง
      final productsWithShelf = await InventoryService.getProductsWithShelfAndWarehouse();
      
      debugPrint('📦 Loaded ${productsWithShelf.length} products with shelf/warehouse info');
      if (productsWithShelf.isNotEmpty) {
        debugPrint('🔍 First product: ${productsWithShelf.first}');
      }
      
      // Create a map of product_id to warehouse_id and shelf_id
      final productLocationMap = <String, Map<String, String?>>{};
      for (final product in productsWithShelf) {
        final productId = product['id']?.toString();
        final warehouseId = product['warehouse_id']?.toString();
        final shelfId = product['shelf_id']?.toString();
        
        if (productId != null) {
          productLocationMap[productId] = {
            'warehouse_id': warehouseId,
            'shelf_id': shelfId,
          };
          if (warehouseId != null) {
            debugPrint('✅ Mapped product $productId to warehouse $warehouseId, shelf $shelfId');
          }
        }
      }
      
      debugPrint('📊 Total products with location: ${productLocationMap.length}');
      debugPrint('📊 Total products loaded: ${result.data.length}');
      
      // Enrich product data with warehouse_id and shelf_id
      final productsWithLocation = result.data.map((product) {
        final productId = product['id']?.toString();
        final location = productLocationMap[productId];
        final productMap = Map<String, dynamic>.from(product);
        productMap['warehouse_id'] = location?['warehouse_id'];
        productMap['shelf_id'] = location?['shelf_id'];
        return productMap;
      }).toList();
      
      setState(() {
        _allProducts = productsWithLocation;
        _tabLoading['all'] = false;
      });
    } catch (e) {
      debugPrint('Error loading all products: $e');
      setState(() => _tabLoading['all'] = false);
    }
  }

  Future<void> _loadExpiringProducts() async {
    try {
      // Phase 3: Use new API with sorting
      final result = await InventoryService.getExpiringProductsPaginated(
        page: 1,
        limit: 100,
        daysThreshold: int.tryParse(_expiringFilter) ?? 7,
        sortBy: _sortBy,
        ascending: _sortAscending,
      );
      setState(() {
        _expiringProducts = result.data.cast<Map<String, dynamic>>();
        _tabLoading['expiring'] = false;
      });
    } catch (e) {
      debugPrint('Error loading expiring products: $e');
      setState(() => _tabLoading['expiring'] = false);
    }
  }

  Future<void> _loadExpiringIngredients() async {
    try {
      // Phase 3: Use batch API for ingredients
      final batches = await InventoryService.getExpiringBatches(
        daysThreshold: int.tryParse(_expiringFilter) ?? 7,
        itemType: 'ingredient',
      );
      // Group batches by ingredient
      final ingredientMap = <String, Map<String, dynamic>>{};
      for (final batch in batches) {
        final ingredientId = batch['ingredient_id']?.toString();
        if (ingredientId == null) continue;

        if (!ingredientMap.containsKey(ingredientId)) {
          ingredientMap[ingredientId] = {
            'id': ingredientId,
            'name': batch['ingredient_name'] ?? 'วัตถุดิบ #$ingredientId',
            'expiring_quantity': 0.0,
            'batches': [],
          };
        }

        final qty = (batch['quantity'] as num?)?.toDouble() ?? 0;
        ingredientMap[ingredientId]!['expiring_quantity'] =
            (ingredientMap[ingredientId]!['expiring_quantity'] as double) + qty;
        (ingredientMap[ingredientId]!['batches'] as List).add(batch);
      }

      setState(() {
        _expiringIngredients = ingredientMap.values.toList();
        _tabLoading['ingredients'] = false;
      });
    } catch (e) {
      debugPrint('Error loading expiring ingredients: $e');
      setState(() => _tabLoading['ingredients'] = false);
    }
  }

  Future<void> _loadHighMarginProducts() async {
    try {
      // Phase 3: Use new API with sorting
      final result = await InventoryService.getHighMarginProductsPaginated(
        page: 1,
        limit: 100,
        marginLevel: _marginFilter,
        sortBy: _sortBy,
        ascending: _sortAscending,
      );
      setState(() {
        _highMarginProducts = result.data.cast<Map<String, dynamic>>();
        _tabLoading['margin'] = false;
      });
    } catch (e) {
      debugPrint('Error loading high margin products: $e');
      setState(() => _tabLoading['margin'] = false);
    }
  }

  Future<void> _loadSeasonalProducts() async {
    try {
      // Phase 3: Filter products by season based on ingredient seasonality
      // For now, return products that might use seasonal ingredients
      final products = await InventoryService.getProducts();
      // TODO: Implement actual seasonal logic when ingredient season data is available
      setState(() {
        _seasonalProducts = products.take(20).toList();
        _tabLoading['seasonal'] = false;
      });
    } catch (e) {
      debugPrint('Error loading seasonal products: $e');
      setState(() => _tabLoading['seasonal'] = false);
    }
  }

  Future<void> _loadFestivalProducts() async {
    try {
      // Phase 3: Return products tagged for current festivals
      // For now, return products that might be festival-related
      final products = await InventoryService.getProducts();
      // TODO: Implement actual festival tagging when promotion_festival_tags table is ready
      setState(() {
        _festivalProducts = products.take(20).toList();
        _tabLoading['festival'] = false;
      });
    } catch (e) {
      debugPrint('Error loading festival products: $e');
      setState(() => _tabLoading['festival'] = false);
    }
  }

  Future<void> _loadRecommendedProducts() async {
    try {
      debugPrint('🔍 Loading recommended products with Priority Score...');
      
      // Phase 8: Use new Priority Score algorithm
      final recommended = await PosPromotionService.getRecommendedProducts(
        limit: 50,
        minScore: 20, // แสดงเฉพาะที่มีคะแนน >= 20
      );

      setState(() {
        _recommendedProducts = recommended;
        _tabLoading['recommended'] = false;
      });
      
      debugPrint('✅ Loaded ${recommended.length} recommended products');
    } catch (e) {
      debugPrint('❌ Error loading recommended products: $e');
      setState(() => _tabLoading['recommended'] = false);
    }
  }

  void _toggleProductSelection(Map<String, dynamic> product) {
    setState(() {
      final existingIndex = _selectedProducts.indexWhere(
        (p) => p['id'] == product['id'],
      );

      if (existingIndex >= 0) {
        _selectedProducts.removeAt(existingIndex);
      } else {
        _selectedProducts.add({
          ...product,
          'quantity': 1,
        });
      }
    });
  }

  /// เลือกสินค้าทั้งหมดในแท็บปัจจุบัน
  void _selectAllProducts() {
    final currentProducts = _getCurrentTabProducts();
    final searchQuery = _searchCtrl.text.toLowerCase();

    // กรองตามการค้นหาถ้ามี
    final filteredProducts = searchQuery.isEmpty
        ? currentProducts
        : currentProducts.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery);
          }).toList();

    setState(() {
      for (final product in filteredProducts) {
        final existingIndex = _selectedProducts.indexWhere(
          (p) => p['id'] == product['id'],
        );
        if (existingIndex < 0) {
          _selectedProducts.add({
            ...product,
            'quantity': 1,
          });
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เลือกสินค้า ${filteredProducts.length} รายการ'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// ยกเลิกการเลือกทั้งหมดในแท็บปัจจุบัน
  void _deselectAllProducts() {
    final currentProducts = _getCurrentTabProducts();
    final currentIds = currentProducts.map((p) => p['id']).toSet();

    setState(() {
      _selectedProducts.removeWhere((p) => currentIds.contains(p['id']));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ยกเลิกการเลือกทั้งหมด'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// ตรวจสอบว่าเลือกทั้งหมดแล้วหรือยัง
  bool _isAllSelected() {
    final currentProducts = _getCurrentTabProducts();
    final searchQuery = _searchCtrl.text.toLowerCase();

    final filteredProducts = searchQuery.isEmpty
        ? currentProducts
        : currentProducts.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery);
          }).toList();

    if (filteredProducts.isEmpty) return false;

    for (final product in filteredProducts) {
      final isSelected = _selectedProducts.any((p) => p['id'] == product['id']);
      if (!isSelected) return false;
    }
    return true;
  }

  /// เลือกสินค้าทั้งหมดในคลังที่ระบุ
  void _selectAllByStore(String storeId) {
    final storeProducts = _allProducts.where((p) {
      final productStoreId = p['warehouse_id']?.toString() ?? 
                           p['store_id']?.toString() ?? 
                           p['location_id']?.toString();
      return productStoreId == storeId;
    }).toList();

    setState(() {
      for (final product in storeProducts) {
        final existingIndex = _selectedProducts.indexWhere(
          (p) => p['id'] == product['id'],
        );
        if (existingIndex < 0) {
          _selectedProducts.add({
            ...product,
            'quantity': 1,
          });
        }
      }
    });

    final storeName = _stores.firstWhere(
      (s) => s['id']?.toString() == storeId,
      orElse: () => {'name': 'คลังนี้'},
    )['name'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เลือกสินค้าใน$storeName ${storeProducts.length} รายการ'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// ยกเลิกการเลือกสินค้าทั้งหมดในคลังที่ระบุ
  void _deselectAllByStore(String storeId) {
    final storeProducts = _allProducts.where((p) {
      final productStoreId = p['warehouse_id']?.toString() ?? 
                           p['store_id']?.toString() ?? 
                           p['location_id']?.toString();
      return productStoreId == storeId;
    }).toList();

    final storeProductIds = storeProducts.map((p) => p['id']).toSet();

    setState(() {
      _selectedProducts.removeWhere((p) => storeProductIds.contains(p['id']));
    });

    final storeName = _stores.firstWhere(
      (s) => s['id']?.toString() == storeId,
      orElse: () => {'name': 'คลังนี้'},
    )['name'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ยกเลิกการเลือกใน$storeName'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// เลือกสินค้าทั้งหมดในชั้นวางที่ระบุ
  void _selectAllByShelf(String shelfId) {
    final shelfProducts = _allProducts.where((p) {
      final productShelfId = p['shelf_id']?.toString() ?? 
                            p['rack_id']?.toString() ?? 
                            p['location_shelf_id']?.toString();
      return productShelfId == shelfId;
    }).toList();

    setState(() {
      for (final product in shelfProducts) {
        final existingIndex = _selectedProducts.indexWhere(
          (p) => p['id'] == product['id'],
        );
        if (existingIndex < 0) {
          _selectedProducts.add({
            ...product,
            'quantity': 1,
          });
        }
      }
    });

    final shelfName = _shelves.firstWhere(
      (s) => s['id']?.toString() == shelfId,
      orElse: () => {'name': 'ชั้นวางนี้'},
    )['name'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เลือกสินค้าในชั้น$shelfName ${shelfProducts.length} รายการ'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// ยกเลิกการเลือกสินค้าทั้งหมดในชั้นวางที่ระบุ
  void _deselectAllByShelf(String shelfId) {
    final shelfProducts = _allProducts.where((p) {
      final productShelfId = p['shelf_id']?.toString() ?? 
                            p['rack_id']?.toString() ?? 
                            p['location_shelf_id']?.toString();
      return productShelfId == shelfId;
    }).toList();

    final shelfProductIds = shelfProducts.map((p) => p['id']).toSet();

    setState(() {
      _selectedProducts.removeWhere((p) => shelfProductIds.contains(p['id']));
    });

    final shelfName = _shelves.firstWhere(
      (s) => s['id']?.toString() == shelfId,
      orElse: () => {'name': 'ชั้นวางนี้'},
    )['name'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ยกเลิกการเลือกในชั้น$shelfName'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// ตรวจสอบว่าเลือกทั้งหมดในคลังแล้วหรือยัง
  bool _isStoreAllSelected(String storeId) {
    final storeProducts = _allProducts.where((p) {
      final productStoreId = p['warehouse_id']?.toString() ?? 
                           p['store_id']?.toString() ?? 
                           p['location_id']?.toString();
      return productStoreId == storeId;
    }).toList();

    if (storeProducts.isEmpty) return false;

    for (final product in storeProducts) {
      final isSelected = _selectedProducts.any((p) => p['id'] == product['id']);
      if (!isSelected) return false;
    }
    return true;
  }

  /// ตรวจสอบว่าเลือกทั้งหมดในชั้นวางแล้วหรือยัง
  bool _isShelfAllSelected(String shelfId) {
    final shelfProducts = _allProducts.where((p) {
      final productShelfId = p['shelf_id']?.toString() ?? 
                            p['rack_id']?.toString() ?? 
                            p['location_shelf_id']?.toString();
      return productShelfId == shelfId;
    }).toList();

    if (shelfProducts.isEmpty) return false;

    for (final product in shelfProducts) {
      final isSelected = _selectedProducts.any((p) => p['id'] == product['id']);
      if (!isSelected) return false;
    }
    return true;
  }

  void _updateQuantity(String productId, int quantity) {
    setState(() {
      final index = _selectedProducts.indexWhere((p) => p['id'] == productId);
      if (index >= 0) {
        if (quantity <= 0) {
          _selectedProducts.removeAt(index);
        } else {
          _selectedProducts[index]['quantity'] = quantity;
        }
      }
    });
  }

  void _finishSelection() {
    Navigator.pop(context, _selectedProducts);
  }

  void _refreshCurrentTab() {
    setState(() {
      _tabLoading[_getTabKey(_tabController.index)] = true;
    });
    
    switch (_tabController.index) {
      case 0: _loadAllProducts(); break;
      case 1: _loadExpiringProducts(); break;
      case 2: _loadExpiringIngredients(); break;
      case 3: _loadHighMarginProducts(); break;
      case 4: _loadSeasonalProducts(); break;
      case 5: _loadFestivalProducts(); break;
      case 6: _loadRecommendedProducts(); break;
    }
  }

  String _getTabKey(int index) {
    const keys = ['all', 'expiring', 'ingredients', 'margin', 'seasonal', 'festival', 'recommended'];
    return keys[index];
  }

  Widget _buildFilterControls() {
    return Column(
      children: [
        // Tab-specific filters
        _buildTabSpecificFilters(),
        
        // Sorting controls
        _buildSortingControls(),
      ],
    );
  }
  
  Widget _buildTabSpecificFilters() {
    switch (_tabController.index) {
      case 0: // All products
        return _buildAllProductsFilters();
      case 1: // Expiring products
        return _buildExpiringFilters();
      case 3: // High margin
        return _buildMarginFilters();
      case 4: // Seasonal
        return _buildSeasonalFilters();
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildSortingControls() {
    final currentSortField = _tabSortOptions[_tabController.index] ?? 'name';
    final sortOptions = _getSortOptionsForTab(_tabController.index);
    
    if (sortOptions.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('เรียงตาม:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: const InputDecoration(
                hintText: 'เลือกการเรียง',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: sortOptions.map((option) => DropdownMenuItem(
                value: option.field,
                child: Text(option.label),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortBy = value;
                  });
                  _refreshCurrentTab();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: AppDesignSystem.primary,
            ),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
              _refreshCurrentTab();
            },
            tooltip: _sortAscending ? 'เรียงจากน้อยไปมาก' : 'เรียงจากมากไปน้อย',
          ),
        ],
      ),
    );
  }
  
  List<SortOption> _getSortOptionsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: // All products
        return SortOption.productSortOptions;
      case 1: // Expiring products
        return SortOption.expiringSortOptions;
      case 3: // High margin
        return SortOption.marginSortOptions;
      case 4: // Seasonal
        return SortOption.productSortOptions;
      case 5: // Festival
        return [
          const SortOption(field: 'festival_date', label: 'วันเทศกาล'),
          const SortOption(field: 'days_until_festival', label: 'วันที่เหลือ'),
          ...SortOption.productSortOptions,
        ];
      default:
        return [];
    }
  }

  Widget _buildAllProductsFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ค้นหาสินค้า', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'พิมพ์ชื่อสินค้า, รหัสสินค้า, หรือ SKU...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _refreshCurrentTab();
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              _searchQuery = value;
            },
            onSubmitted: (_) => _refreshCurrentTab(),
          ),
          const SizedBox(height: 16),
          const Text('หมวดหมู่', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: InventoryService.getCategories(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              final categories = snapshot.data!;
              return DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  hintText: 'เลือกหมวดหมู่',
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('ทุกหมวดหมู่')),
                  ...categories.map((cat) => DropdownMenuItem(
                    value: cat['id']?.toString(),
                    child: Text(cat['name'] ?? 'ไม่ระบุชื่อ'),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value ?? 'all';
                  });
                  _refreshCurrentTab();
                },
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Store Filter
          _buildStoreFilter(),
          
          // Shelf Filter (shown when store is selected)
          if (_selectedStoreId != null) ...[
            const SizedBox(height: 16),
            _buildShelfFilter(),
          ],
        ],
      ),
    );
  }

  /// สร้างตัวกรองคลังพร้อมปุ่มเลือกทั้งหมด
  Widget _buildStoreFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('คลังสินค้า', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (_selectedStoreId != null)
              TextButton.icon(
                onPressed: () {
                  if (_isStoreAllSelected(_selectedStoreId!)) {
                    _deselectAllByStore(_selectedStoreId!);
                  } else {
                    _selectAllByStore(_selectedStoreId!);
                  }
                },
                icon: Icon(
                  _isStoreAllSelected(_selectedStoreId!) ? Icons.deselect : Icons.select_all,
                  size: 16,
                ),
                label: Text(
                  _isStoreAllSelected(_selectedStoreId!) ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _selectedStoreId,
          decoration: const InputDecoration(
            hintText: 'เลือกคลัง',
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('ทุกคลัง')),
            ..._stores.map((store) => DropdownMenuItem(
              value: store['id']?.toString(),
              child: Row(
                children: [
                  Expanded(child: Text(store['name'] ?? 'ไม่ระบุชื่อ')),
                  if (_selectedStoreId == store['id']?.toString())
                    IconButton(
                      icon: Icon(
                        _isStoreAllSelected(store['id']!.toString()) 
                            ? Icons.check_circle 
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: AppDesignSystem.primary,
                      ),
                      onPressed: () {
                        if (_isStoreAllSelected(store['id']!.toString())) {
                          _deselectAllByStore(store['id']!.toString());
                        } else {
                          _selectAllByStore(store['id']!.toString());
                        }
                      },
                    ),
                ],
              ),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedStoreId = value;
              _selectedShelfId = null; // Reset shelf when store changes
            });
            _refreshCurrentTab();
          },
        ),
        if (_selectedStoreId != null && _isStoreAllSelected(_selectedStoreId!))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(
                  'เลือกสินค้าทั้งหมดในคลังนี้แล้ว',
                  style: TextStyle(fontSize: 12, color: Colors.green[600]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// สร้างตัวกรองชั้นวางพร้อมปุ่มเลือกทั้งหมด
  Widget _buildShelfFilter() {
    final storeShelves = _shelvesByStore[_selectedStoreId] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('ชั้นวาง', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (_selectedShelfId != null)
              TextButton.icon(
                onPressed: () {
                  if (_isShelfAllSelected(_selectedShelfId!)) {
                    _deselectAllByShelf(_selectedShelfId!);
                  } else {
                    _selectAllByShelf(_selectedShelfId!);
                  }
                },
                icon: Icon(
                  _isShelfAllSelected(_selectedShelfId!) ? Icons.deselect : Icons.select_all,
                  size: 16,
                ),
                label: Text(
                  _isShelfAllSelected(_selectedShelfId!) ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (storeShelves.isEmpty)
          Text(
            'ไม่มีชั้นวางในคลังนี้',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          )
        else
          DropdownButtonFormField<String?>(
            value: _selectedShelfId,
            decoration: const InputDecoration(
              hintText: 'เลือกชั้นวาง',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('ทุกชั้น')),
              ...storeShelves.map((shelf) => DropdownMenuItem(
                value: shelf['id']?.toString(),
                child: Row(
                  children: [
                    Expanded(child: Text(shelf['name'] ?? shelf['code'] ?? 'ไม่ระบุ')),
                    if (_selectedShelfId == shelf['id']?.toString())
                      IconButton(
                        icon: Icon(
                          _isShelfAllSelected(shelf['id']!.toString()) 
                              ? Icons.check_circle 
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: AppDesignSystem.primary,
                        ),
                        onPressed: () {
                          if (_isShelfAllSelected(shelf['id']!.toString())) {
                            _deselectAllByShelf(shelf['id']!.toString());
                          } else {
                            _selectAllByShelf(shelf['id']!.toString());
                          }
                        },
                      ),
                  ],
                ),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedShelfId = value;
              });
              _refreshCurrentTab();
            },
          ),
        if (_selectedShelfId != null && _isShelfAllSelected(_selectedShelfId!))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(
                  'เลือกสินค้าทั้งหมดในชั้นนี้แล้ว',
                  style: TextStyle(fontSize: 12, color: Colors.green[600]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Dropdown คลังแบบ Compact (สำหรับแสดงเสมอ)
  Widget _buildCompactStoreDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedStoreId,
          isDense: true,
          isExpanded: true,
          hint: const Row(
            children: [
              Icon(Icons.warehouse, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('เลือกคลัง...', style: TextStyle(fontSize: 14)),
            ],
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Row(
                children: [
                  const Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ทุกคลัง (${_allProducts.length})',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            ..._stores.map((store) {
              final storeId = store['id']?.toString() ?? '';
              final isAllSelected = _isStoreAllSelected(storeId);
              // นับจำนวนสินค้าในคลังนี้
              final productCount = _allProducts.where((p) {
                final productStoreId = p['warehouse_id']?.toString() ?? 
                                      p['store_id']?.toString() ?? 
                                      p['location_id']?.toString();
                return productStoreId == storeId;
              }).length;
              return DropdownMenuItem(
                value: storeId,
                child: Row(
                  children: [
                    Icon(
                      Icons.warehouse,
                      size: 18,
                      color: isAllSelected ? AppDesignSystem.primary : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${store['name'] ?? 'ไม่ระบุชื่อ'} ($productCount)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isAllSelected ? FontWeight.bold : FontWeight.normal,
                          color: isAllSelected ? AppDesignSystem.primary : Colors.black,
                        ),
                      ),
                    ),
                    if (isAllSelected)
                      Icon(Icons.check_circle, size: 16, color: AppDesignSystem.primary),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedStoreId = value;
              _selectedShelfId = null;
            });
          },
        ),
      ),
    );
  }

  /// Dropdown ชั้นวางแบบ Compact (สำหรับแสดงเสมอ)
  Widget _buildCompactShelfDropdown() {
    final storeShelves = _shelvesByStore[_selectedStoreId] ?? [];
    
    if (storeShelves.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.shelves, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Text('ไม่มีชั้นวาง', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedShelfId,
          isDense: true,
          isExpanded: true,
          hint: const Row(
            children: [
              Icon(Icons.shelves, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('เลือกชั้น...', style: TextStyle(fontSize: 14)),
            ],
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Row(
                children: [
                  const Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ทุกชั้น (${_selectedStoreId != null 
                          ? _allProducts.where((p) {
                              final productStoreId = p['warehouse_id']?.toString() ?? 
                                                  p['store_id']?.toString() ?? 
                                                  p['location_id']?.toString();
                              return productStoreId == _selectedStoreId;
                            }).length 
                          : _allProducts.length})',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            ...storeShelves.map((shelf) {
              final shelfId = shelf['id']?.toString() ?? '';
              final isAllSelected = _isShelfAllSelected(shelfId);
              // นับจำนวนสินค้าในชั้นนี้
              final productCount = _allProducts.where((p) {
                final productShelfId = p['shelf_id']?.toString() ?? 
                                      p['rack_id']?.toString() ?? 
                                      p['location_shelf_id']?.toString();
                return productShelfId == shelfId;
              }).length;
              return DropdownMenuItem(
                value: shelfId,
                child: Row(
                  children: [
                    Icon(
                      Icons.shelves,
                      size: 18,
                      color: isAllSelected ? AppDesignSystem.secondary : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${shelf['name'] ?? shelf['code'] ?? 'ไม่ระบุ'} ($productCount)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isAllSelected ? FontWeight.bold : FontWeight.normal,
                          color: isAllSelected ? AppDesignSystem.secondary : Colors.black,
                        ),
                      ),
                    ),
                    if (isAllSelected)
                      Icon(Icons.check_circle, size: 16, color: AppDesignSystem.secondary),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedShelfId = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildExpiringFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สินค้าที่จะหมดอายุใน', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _expiringFilter,
            decoration: const InputDecoration(
              hintText: 'เลือกช่วงเวลา',
            ),
            items: const [
              DropdownMenuItem(value: '3', child: Text('3 วัน')),
              DropdownMenuItem(value: '7', child: Text('7 วัน')),
              DropdownMenuItem(value: '14', child: Text('14 วัน')),
              DropdownMenuItem(value: '30', child: Text('30 วัน')),
            ],
            onChanged: (value) {
              setState(() {
                _expiringFilter = value ?? '7';
              });
              _refreshCurrentTab();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarginFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ระดับกำไร', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _marginFilter,
            decoration: const InputDecoration(
              hintText: 'เลือกระดับกำไร',
            ),
            items: const [
              DropdownMenuItem(value: 'high', child: Text('สูง (50%+)')),
              DropdownMenuItem(value: 'medium', child: Text('ปานกลาง (30-50%)')),
              DropdownMenuItem(value: 'low', child: Text('ต่ำ (0-30%)')),
            ],
            onChanged: (value) {
              setState(() {
                _marginFilter = value ?? 'high';
              });
              _refreshCurrentTab();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ฤดูกาล', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _seasonFilter,
            decoration: const InputDecoration(
              hintText: 'เลือกฤดูกาล',
            ),
            items: const [
              DropdownMenuItem(value: 'summer', child: Text('ฤดูร้อน (มี.ค.-พ.ค.)')),
              DropdownMenuItem(value: 'rainy', child: Text('ฤดูฝน (มิ.ย.-ต.ค.)')),
              DropdownMenuItem(value: 'winter', child: Text('ฤดูหนาว (พ.ย.-ก.พ.)')),
            ],
            onChanged: (value) {
              setState(() {
                _seasonFilter = value ?? 'summer';
              });
              _refreshCurrentTab();
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getCurrentTabProducts() {
    List<Map<String, dynamic>> products;
    switch (_tabController.index) {
      case 0:
        products = _allProducts;
        break;
      case 1:
        products = _expiringProducts;
        break;
      case 2:
        products = _expiringIngredients;
        break;
      case 3:
        products = _highMarginProducts;
        break;
      case 4:
        products = _seasonalProducts;
        break;
      case 5:
        products = _festivalProducts;
        break;
      case 6:
        products = _recommendedProducts.map((p) => p.toMap()).toList();
        break;
      default:
        products = _allProducts;
    }
    
    // Apply store filter
    if (_selectedStoreId != null) {
      products = products.where((p) {
        final productStoreId = p['warehouse_id']?.toString() ?? 
                              p['store_id']?.toString() ?? 
                              p['location_id']?.toString();
        return productStoreId == _selectedStoreId;
      }).toList();
    }
    
    // Apply shelf filter
    if (_selectedShelfId != null) {
      products = products.where((p) {
        final productShelfId = p['shelf_id']?.toString() ?? 
                              p['rack_id']?.toString() ?? 
                              p['location_shelf_id']?.toString();
        return productShelfId == _selectedShelfId;
      }).toList();
    }
    
    return products;
  }

  bool _isTabLoading() {
    final tabNames = ['all', 'expiring', 'ingredients', 'margin', 'seasonal', 'festival', 'recommended'];
    return _tabLoading[tabNames[_tabController.index]] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppDesignSystem.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'เลือกสินค้าเข้าร่วมโปรโมชัน',
          style: TextStyle(
            color: AppDesignSystem.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppDesignSystem.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppDesignSystem.primary,
          tabs: const [
            Tab(text: 'ทั้งหมด'),
            Tab(text: 'ใกล้หมดอายุ'),
            Tab(text: 'วัตถุดิบใกล้หมด'),
            Tab(text: 'กำไรสูง'),
            Tab(text: 'ตามฤดูกาล'),
            Tab(text: 'เทศกาล'),
            Tab(text: 'แนะนำ'),
          ],
          onTap: (_) => setState(() {}), // Refresh to show correct filter UI
        ),
        actions: [
          // Select All / Deselect All Button
          if (!_isTabLoading())
            IconButton(
              icon: Icon(
                _isAllSelected() ? Icons.deselect : Icons.select_all,
                color: AppDesignSystem.primary,
              ),
              onPressed: () {
                if (_isAllSelected()) {
                  _deselectAllProducts();
                } else {
                  _selectAllProducts();
                }
              },
              tooltip: _isAllSelected() ? 'ยกเลิกเลือกทั้งหมด' : 'เลือกทั้งหมด',
            ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: AppDesignSystem.primary,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: 'ตัวกรอง',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'เลือก ${_selectedProducts.length} รายการ',
                style: const TextStyle(
                  color: AppDesignSystem.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Panel (collapsible) - หมวดหมู่และการเรียง
          if (_showFilters)
            Container(
              color: Colors.grey[50],
              child: _buildFilterControls(),
            ),
          
          // Persistent Store & Shelf Filters (แสดงเสมอ)
          if (_tabController.index == 0) // เฉพาะแท็บทั้งหมด
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Filter Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCompactStoreDropdown(),
                      ),
                      const SizedBox(width: 12),
                      // Select All Store Button
                      if (_selectedStoreId != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_isStoreAllSelected(_selectedStoreId!)) {
                              _deselectAllByStore(_selectedStoreId!);
                            } else {
                              _selectAllByStore(_selectedStoreId!);
                            }
                          },
                          icon: Icon(
                            _isStoreAllSelected(_selectedStoreId!) 
                                ? Icons.deselect 
                                : Icons.select_all,
                            size: 18,
                          ),
                          label: Text(
                            _isStoreAllSelected(_selectedStoreId!) 
                                ? 'ยกเลิก' 
                                : 'เลือกทั้งคลัง',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isStoreAllSelected(_selectedStoreId!)
                                ? Colors.red[400]
                                : AppDesignSystem.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                    ],
                  ),
                  
                  // Shelf Filter (เมื่อเลือกคลังแล้ว)
                  if (_selectedStoreId != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildCompactShelfDropdown(),
                        ),
                        const SizedBox(width: 12),
                        // Select All Shelf Button
                        if (_selectedShelfId != null)
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_isShelfAllSelected(_selectedShelfId!)) {
                                _deselectAllByShelf(_selectedShelfId!);
                              } else {
                                _selectAllByShelf(_selectedShelfId!);
                              }
                            },
                            icon: Icon(
                              _isShelfAllSelected(_selectedShelfId!) 
                                  ? Icons.deselect 
                                  : Icons.select_all,
                              size: 18,
                            ),
                            label: Text(
                              _isShelfAllSelected(_selectedShelfId!) 
                                  ? 'ยกเลิก' 
                                  : 'เลือกทั้งชั้น',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isShelfAllSelected(_selectedShelfId!)
                                  ? Colors.orange[400]
                                  : AppDesignSystem.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          
          // Product List
          Expanded(
            child: _isTabLoading()
                ? const Center(child: CircularProgressIndicator())
                : _buildProductList(),
          ),
          
          // Bottom Selected Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'เลือกแล้ว ${_selectedProducts.length} รายการ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (_selectedProducts.isNotEmpty)
                          Text(
                            _selectedProducts.map((p) => p['name']).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _finishSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('เสร็จ'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    // Different filters based on current tab
    switch (_tabController.index) {
      case 0: // All
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'ทุกหมวดหมู่',
                isSelected: _selectedCategory == 'all',
                onTap: () {
                  setState(() {
                    _selectedCategory = 'all';
                    _loadAllProducts();
                  });
                },
              ),
              // TODO: Add dynamic category chips
            ],
          ),
        );
        
      case 1: // Expiring
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: '3 วัน',
                isSelected: _expiringFilter == '3',
                onTap: () => setState(() => _expiringFilter = '3'),
              ),
              _buildFilterChip(
                label: '7 วัน',
                isSelected: _expiringFilter == '7',
                onTap: () => setState(() => _expiringFilter = '7'),
              ),
              _buildFilterChip(
                label: '14 วัน',
                isSelected: _expiringFilter == '14',
                onTap: () => setState(() => _expiringFilter = '14'),
              ),
              _buildFilterChip(
                label: '30 วัน',
                isSelected: _expiringFilter == '30',
                onTap: () => setState(() => _expiringFilter = '30'),
              ),
            ],
          ),
        );
        
      case 3: // High Margin
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'กำไรสูง',
                isSelected: _marginFilter == 'high',
                onTap: () => setState(() => _marginFilter = 'high'),
              ),
              _buildFilterChip(
                label: 'กำไรกลาง',
                isSelected: _marginFilter == 'medium',
                onTap: () => setState(() => _marginFilter = 'medium'),
              ),
              _buildFilterChip(
                label: 'กำไรต่ำ',
                isSelected: _marginFilter == 'low',
                onTap: () => setState(() => _marginFilter = 'low'),
              ),
            ],
          ),
        );
        
      case 4: // Seasonal
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'ฤดูร้อน',
                isSelected: _seasonFilter == 'summer',
                onTap: () => setState(() => _seasonFilter = 'summer'),
              ),
              _buildFilterChip(
                label: 'ฤดูฝน',
                isSelected: _seasonFilter == 'rainy',
                onTap: () => setState(() => _seasonFilter = 'rainy'),
              ),
              _buildFilterChip(
                label: 'ฤดูหนาว',
                isSelected: _seasonFilter == 'winter',
                onTap: () => setState(() => _seasonFilter = 'winter'),
              ),
            ],
          ),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => onTap(),
        selectedColor: AppDesignSystem.primary.withOpacity(0.2),
        checkmarkColor: AppDesignSystem.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppDesignSystem.primary : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final products = _getCurrentTabProducts();
    final searchQuery = _searchCtrl.text.toLowerCase();
    
    final filteredProducts = searchQuery.isEmpty
        ? products
        : products.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery);
          }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'ไม่พบสินค้า',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Select All Header
        if (filteredProducts.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isAllSelected(),
                  onChanged: (_) {
                    if (_isAllSelected()) {
                      _deselectAllProducts();
                    } else {
                      _selectAllProducts();
                    }
                  },
                  activeColor: AppDesignSystem.primary,
                ),
                Expanded(
                  child: Text(
                    _isAllSelected()
                        ? 'ยกเลิกการเลือกทั้งหมด (${filteredProducts.length} รายการ)'
                        : 'เลือกทั้งหมด (${filteredProducts.length} รายการ)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    if (_isAllSelected()) {
                      _deselectAllProducts();
                    } else {
                      _selectAllProducts();
                    }
                  },
                  icon: Icon(
                    _isAllSelected() ? Icons.deselect : Icons.select_all,
                    size: 18,
                    color: AppDesignSystem.primary,
                  ),
                  label: Text(
                    _isAllSelected() ? 'ยกเลิก' : 'เลือกทั้งหมด',
                    style: TextStyle(color: AppDesignSystem.primary),
                  ),
                ),
              ],
            ),
          ),
        // Product List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              final isSelected = _selectedProducts.any((p) => p['id'] == product['id']);

              return _buildProductCard(product, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isSelected) {
    final selectedIndex = _selectedProducts.indexWhere((p) => p['id'] == product['id']);
    final quantity = selectedIndex >= 0 ? (_selectedProducts[selectedIndex]['quantity'] ?? 1) : 0;
    
    // Tab-specific info
    Widget? subtitle;
    switch (_tabController.index) {
      case 1: // Expiring
        subtitle = _buildExpiringSubtitle(product);
        break;
      case 2: // Ingredients
        subtitle = _buildIngredientSubtitle(product);
        break;
      case 3: // Margin
        subtitle = _buildMarginSubtitle(product);
        break;
      case 6: // Recommended
        subtitle = _buildRecommendedSubtitle(product);
        break;
      default:
        subtitle = Text(
          'หมวด: ${product['category']?['name'] ?? 'ไม่ระบุ'} | ฿${product['price'] ?? 0} | คงเหลือ ${product['quantity'] ?? 0}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppDesignSystem.primary : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleProductSelection(product),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleProductSelection(product),
                    activeColor: AppDesignSystem.primary,
                  ),
                  Expanded(
                    child: Text(
                      product['name'] ?? 'ไม่มีชื่อ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _updateQuantity(product['id'], quantity - 1),
                            child: const Icon(Icons.remove, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$quantity',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _updateQuantity(product['id'], quantity + 1),
                            child: const Icon(Icons.add, size: 16),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 4),
                  child: subtitle,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSubtitle(Map<String, dynamic> product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'หมดอายุ: ${product['expiry_date'] ?? 'ไม่ระบุ'}',
          style: TextStyle(fontSize: 12, color: Colors.red[600]),
        ),
        Text(
          'เหลือ ${product['expiring_quantity'] ?? 0} หน่วย | คงเหลือทั้งหมด ${product['quantity'] ?? 0}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildIngredientSubtitle(Map<String, dynamic> product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วัตถุดิบใกล้หมด: ${product['expiring_ingredients'] ?? 'ไม่ระบุ'}',
          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
        ),
        Text(
          'ทำได้ประมาณ ${product['possible_servings'] ?? 0} จาน',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMarginSubtitle(Map<String, dynamic> product) {
    final margin = product['gross_margin_percent'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'กำไร: ${margin.toStringAsFixed(1)}% | ราคา: ฿${product['price'] ?? 0}',
          style: TextStyle(
            fontSize: 12,
            color: margin > 50 ? Colors.green[700] : Colors.orange[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'คงเหลือ: ${product['quantity'] ?? 0} หน่วย',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRecommendedSubtitle(Map<String, dynamic> product) {
    // Convert back to RecommendedProduct if needed
    final recommendedProduct = RecommendedProduct.fromSupabase(product);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Priority Score and Level
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Color(int.parse(recommendedProduct.priorityLevelColor.replaceAll('#', '0xFF'))),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${recommendedProduct.priorityScore.toStringAsFixed(1)} (${recommendedProduct.priorityLevelText})',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Rank
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '#${recommendedProduct.overallRank}',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        
        // Recommendation Reasons
        if (recommendedProduct.recommendationReasons.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: recommendedProduct.recommendationReasons.map((reason) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        
        const SizedBox(height: 4),
        
        // Stock and Expiry Info
        Row(
          children: [
            Text(
              'คงเหลือ: ${recommendedProduct.stockQuantity} หน่วย',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            if (recommendedProduct.daysRemaining != null) ...[
              const SizedBox(width: 8),
              Text(
                recommendedProduct.isExpired 
                    ? 'หมดอายุแล้ว'
                    : 'เหลือ ${recommendedProduct.daysRemaining} วัน',
                style: TextStyle(
                  fontSize: 10,
                  color: recommendedProduct.isExpiringSoon 
                      ? Colors.red[600] 
                      : Colors.grey[600],
                  fontWeight: recommendedProduct.isExpiringSoon 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        
        // Suggested Discount
        const SizedBox(height: 2),
        Text(
          'ส่วนลดที่แนะนำ: ${recommendedProduct.suggestedDiscountPct.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 9,
            color: Colors.green[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
