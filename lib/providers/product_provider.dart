import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../models/stock_model.dart';
import '../repositories/product_repository.dart';
import '../services/connectivity_service.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository _repository = ProductRepository();
  
  // Consolidated state variables
  List<ProductModel> _products = [];
  ProductModel? _selectedProduct;

  // Single loading state
  bool _isLoading = false;

  // Error handling
  String? _error;

  // Pagination
  DocumentSnapshot? _lastDocument;
  bool _hasMoreProducts = true;
  final int _pageSize = 10;

  // Single subscription for all product streams
  StreamSubscription<List<ProductModel>>? _productSubscription;

  // Getters
  List<ProductModel> get products => _products;
  List<ProductModel> get lowStockProducts => _products.where((p) => p.currentStock <= p.minimumStockLevel).toList();
  List<ProductModel> get filteredProducts => _products;
  ProductModel? get selectedProduct => _selectedProduct;

  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  String? get error => _error;

  bool get hasMoreProducts => _hasMoreProducts;
  int get totalProducts => _products.length;

  // Analytics getters
  double get totalInventoryValue {
    return _products.fold(
      0.0,
      (sums, product) => sums + (product.salePrice * product.currentStock),
    );
  }

  int get lowStockCount => lowStockProducts.length;
  int get outOfStockCount => _products.where((p) => p.currentStock == 0).length;

  // Initialize and start listening to products
  Future<void> initialize() async {
    await _startProductsStream();
  }

  // Stream Management

  /// Start listening to all products
  Future<void> _startProductsStream() async {
    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      _productSubscription?.cancel();
      _productSubscription = _repository.streamAllProducts().listen(
        (products) {
          _products = products;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load products: $error');
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _setError('Failed to initialize products stream: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // CRUD Operations

  /// Create a new product
  Future<bool> createProduct(ProductModel product) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      // Check for duplicate name (case-insensitive)
      final nameExists = await _repository.isProductNameExists(
        product.name,
        product.categoryId,
      );

      if (nameExists) {
        _setError(
          'A product with the name "${product.name}" already exists in this category. Please choose a different name.',
        );
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final id = await _repository.createProduct(product);
      _isLoading = false;
      notifyListeners();

      return id.isNotEmpty;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError('Failed to create product: $e');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing product
  Future<bool> updateProduct(String id, ProductModel product) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      // Check for duplicate name (case-insensitive) excluding current product
      final nameExists = await _repository.isProductNameExists(
        product.name,
        product.categoryId,
        excludeProductId: id,
      );

      if (nameExists) {
        _setError(
          'A product with the name "${product.name}" already exists in this category. Please choose a different name.',
        );
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _repository.updateProduct(id, product);

      // Update selected product if it's the one being updated
      if (_selectedProduct?.id == id) {
        _selectedProduct = product.copyWith(id: id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError('Failed to update product: $e');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a product
  Future<bool> deleteProduct(String id) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      await _repository.deleteProduct(id);

      // Clear selected product if it's the one being deleted
      if (_selectedProduct?.id == id) {
        _selectedProduct = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError('Failed to delete product: $e');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get and set selected product
  Future<void> selectProduct(String id) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return;
    }

    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      final product = await _repository.getProductById(id);
      _selectedProduct = product;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError('Failed to load product: $e');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear selected product
  void clearSelectedProduct() {
    _selectedProduct = null;
    notifyListeners();
  }

  // Stock Management

  /// Manual stock adjustment (for admin use only)
  Future<bool> manualStockAdjustment({
    required String productId,
    required int change,
    required String createdBy,
    required bool isAddition,
  }) async {
    try {
      await _repository.manualStockAdjustment(
        productId: productId,
        change: change,
        createdBy: createdBy,
        isAddition: isAddition,
      );
      return true;
    } catch (e) {
      _setError('Failed to adjust stock: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get stock ledger for a product
  Future<List<StockModel>> getStockLedger(
    String productId, {
    int? limit,
  }) async {
    try {
      return await _repository.getStockLedger(productId, limit: limit);
    } catch (e) {
      _setError('Failed to get stock ledger: $e');
      notifyListeners();
      return [];
    }
  }

  /// Update product stock (without ledger tracking - for sales/purchases)
  Future<bool> updateStock(String productId, double newStock) async {
    try {
      await _repository.updateStock(productId, newStock);
      return true;
    } catch (e) {
      _setError('Failed to update stock: $e');
      notifyListeners();
      return false;
    }
  }

  /// Add stock to product (without ledger tracking - for purchases)
  Future<bool> addStock(String productId, double quantity) async {
    try {
      await _repository.addStock(productId, quantity);
      return true;
    } catch (e) {
      _setError('Failed to add stock: $e');
      notifyListeners();
      return false;
    }
  }

  /// Reduce stock from product (without ledger tracking - for sales)
  Future<bool> reduceStock(String productId, double quantity) async {
    try {
      final success = await _repository.reduceStock(productId, quantity);
      if (!success) {
        _setError('Insufficient stock available');
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('Failed to reduce stock: $e');
      notifyListeners();
      return false;
    }
  }

  // Barcode Operations

  /// Check if barcode is unique
  Future<bool> isBarcodeUnique(
    String barcode, {
    String? excludeProductId,
  }) async {
    try {
      return await _repository.isBarcodeUnique(
        barcode,
        excludeProductId: excludeProductId,
      );
    } catch (e) {
      _setError('Failed to check barcode uniqueness: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get product by barcode
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      return await _repository.getProductByBarcode(barcode);
    } catch (e) {
      _setError('Failed to get product by barcode: $e');
      notifyListeners();
      return null;
    }
  }

  /// Search products by barcode
  Future<List<ProductModel>> searchProductsByBarcode(String barcodeQuery) async {
    try {
      if (barcodeQuery.trim().isEmpty) {
        return [];
      }

      _isLoading = true;
      notifyListeners();

      final results = await _repository.searchProductsByBarcode(barcodeQuery);

      if (results.isEmpty) {
        _setError('No products found with barcode containing "$barcodeQuery"');
      } else {
        _clearError();
      }

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _setError('Failed to search products by barcode: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Find similar products to prevent duplicates
  Future<List<ProductModel>> findSimilarProducts(
    String name,
    String categoryId, {
    String? excludeProductId,
  }) async {
    try {
      return await _repository.findSimilarProducts(
        name,
        categoryId,
        excludeProductId: excludeProductId,
      );
    } catch (e) {
      _setError('Failed to find similar products: $e');
      notifyListeners();
      return [];
    }
  }

  // Search and Filter Operations

  /// Search products by name
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      if (query.isEmpty) {
        return _products;
      }

      // Check if there are any products to search through
      if (_products.isEmpty) {
        _setError(
          'No products available to search. Please create products first.',
        );
        notifyListeners();
        return [];
      }

      _isLoading = true;
      notifyListeners();

      final results = await _repository.searchProductsByName(query);

      // If no results found, provide helpful message
      if (results.isEmpty) {
        _setError(
          'No products found matching "$query". Try a different search term.',
        );
      } else {
        _clearError();
      }

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _setError('Failed to search products: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Filter by category
  Future<List<ProductModel>> filterByCategory(String categoryId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final results = await _repository.getProductsByCategory(categoryId);

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _setError('Failed to filter by category: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Filter by vendor
  Future<List<ProductModel>> filterByVendor(String vendorId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final results = await _repository.getProductsByVendor(vendorId);

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _setError('Failed to filter by vendor: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Filter by brand
  Future<List<ProductModel>> filterByBrand(String brand) async {
    try {
      _isLoading = true;
      notifyListeners();

      final results = await _repository.getProductsByBrand(brand);

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _setError('Failed to filter by brand: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Filter by price range
  Future<List<ProductModel>> filterByPriceRange({double? minPrice, double? maxPrice}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final results = await _repository.getProductsByPriceRange(
        minPrice: minPrice ?? 0,
        maxPrice: maxPrice ?? double.infinity,
      );

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _setError('Failed to filter by price range: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Pagination

  /// Load more products (pagination)
  Future<void> loadMoreProducts() async {
    if (!_hasMoreProducts || _isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      final newProducts = await _repository.getProductsPaginated(
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      if (newProducts.length < _pageSize) {
        _hasMoreProducts = false;
      }

      if (newProducts.isNotEmpty) {
        _products.addAll(newProducts);
        // Note: _lastDocument would need to be set from the repository
        // This requires modifying the repository method to return the last document
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load more products: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset pagination
  void resetPagination() {
    _lastDocument = null;
    _hasMoreProducts = true;
    _products.clear();
    notifyListeners();
  }

  // Analytics Methods

  /// Get most profitable products
  Future<List<ProductModel>> getMostProfitableProducts({int limit = 10}) async {
    try {
      return await _repository.getMostProfitableProducts(limit: limit);
    } catch (e) {
      _setError('Failed to get profitable products: $e');
      notifyListeners();
      return [];
    }
  }

  /// Get total inventory value
  Future<double> getTotalInventoryValue({bool useSalePrice = true}) async {
    try {
      return await _repository.getTotalInventoryValue(
        useSalePrice: useSalePrice,
      );
    } catch (e) {
      _setError('Failed to calculate inventory value: $e');
      notifyListeners();
      return 0.0;
    }
  }

  /// Get product count by category
  Future<Map<String, int>> getProductCountByCategory() async {
    try {
      return await _repository.getProductCountByCategory();
    } catch (e) {
      _setError('Failed to get category counts: $e');
      notifyListeners();
      return {};
    }
  }

  // Bulk Operations

  /// Bulk update products
  Future<bool> bulkUpdateProducts(List<Map<String, dynamic>> updates) async {
    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      await _repository.bulkUpdateProducts(updates);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to bulk update products: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Bulk create products
  Future<bool> bulkCreateProducts(List<ProductModel> products) async {
    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      await _repository.bulkCreateProducts(products);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to bulk create products: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Utility Methods

  /// Refresh all data
  Future<void> refresh() async {
    _clearError();
    await _startProductsStream();
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    debugPrint('ProductProvider Error: $error');
  }

  /// Clear error message
  void _clearError() {
    _error = null;
  }

  /// Get product by ID from current list
  ProductModel? getProductFromList(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if product exists in current list
  bool hasProduct(String id) {
    return _products.any((product) => product.id == id);
  }

  @override
  void dispose() {
    // Cancel subscription
    _productSubscription?.cancel();
    super.dispose();
  }
}
