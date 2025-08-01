import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/category_model.dart';
import '../repositories/category_repository.dart';
import '../services/connectivity_service.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _categoryRepo = CategoryRepository();

  // Consolidated state variables
  bool _isLoading = false;
  List<CategoryModel> _categories = [];
  String? _error;
  StreamSubscription<List<CategoryModel>>? _subscription;

  // Getters
  bool get isLoading => _isLoading;
  List<CategoryModel> get categories => _categories;
  List<CategoryModel> get activeCategories =>
      _categories.where((c) => c.isActive).toList();
  List<CategoryModel> get inactiveCategories =>
      _categories.where((c) => !c.isActive).toList();
  String? get error => _error;

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Get categories by search
  List<CategoryModel> searchCategories(String query) {
    if (query.isEmpty) return _categories;
    return _categories
        .where(
          (category) =>
              category.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Filter categories by status
  List<CategoryModel> getFilteredCategories(String filter) {
    switch (filter.toLowerCase()) {
      case 'active':
        return _categories.where((c) => c.isActive).toList();
      case 'inactive':
        return _categories.where((c) => !c.isActive).toList();
      case 'parents':
        return _categories.where((c) => c.parentCategory == null).toList();
      case 'subcategories':
        return _categories.where((c) => c.parentCategory != null).toList();
      case 'all':
      default:
        return _categories;
    }
  }

  // Get categories with search and filter
  List<CategoryModel> getFilteredAndSearchedCategories(
    String filter,
    String searchQuery,
  ) {
    List<CategoryModel> filtered = getFilteredCategories(filter);

    if (searchQuery.isEmpty) {
      return filtered;
    }

    return filtered
        .where(
          (category) =>
              category.name.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
  }

  // Start listening to category stream
  void startListening() {
    _setLoading(true);
    _setError(null);

    _subscription?.cancel();
    _subscription = _categoryRepo.streamCategories().listen(
      (categories) {
        _categories = categories;
        _setLoading(false);
      },
      onError: (error) {
        _setError(error.toString());
        _setLoading(false);
      },
    );
  }

  // Start listening to active categories only
  void startListeningToActiveCategories() {
    _setLoading(true);
    _setError(null);

    _subscription?.cancel();
    _subscription = _categoryRepo.streamActiveCategories().listen(
      (categories) {
        _categories = categories;
        _setLoading(false);
      },
      onError: (error) {
        _setError(error.toString());
        _setLoading(false);
      },
    );
  }

  // Stop listening to stream
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  // Load all categories (fallback method)
  Future<void> loadAllCategories() async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      _categories = await _categoryRepo.getAllCategories();
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
    }
  }

  // Load only active categories (fallback method)
  Future<void> loadActiveCategories() async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      _categories = await _categoryRepo.getActiveCategories();
      _setLoading(false);
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
    }
  }

  // Create new category
  Future<bool> createCategory(CategoryModel category) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    _setError(null);

    try {
      // Check for duplicate name (case-insensitive)
      final nameExists = await _categoryRepo.isCategoryNameExists(
        category.name,
        parentCategoryId: category.parentCategory,
      );

      if (nameExists) {
        _setError(
          'A category with the name "${category.name}" already exists in this location. Please choose a different name.',
        );
        return false;
      }

      await _categoryRepo.createCategory(category);
      // Stream will automatically update the list
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      return false;
    }
  }

  // Get category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return null;
    }

    _setLoading(true);
    _setError(null);

    try {
      final category = await _categoryRepo.getCategoryById(categoryId);
      _setLoading(false);
      return category;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      _setLoading(false);
      return null;
    }
  }

  // Update category
  Future<bool> updateCategory(CategoryModel category) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    _setError(null);

    try {
      // Check for duplicate name (case-insensitive) excluding current category
      final nameExists = await _categoryRepo.isCategoryNameExists(
        category.name,
        excludeCategoryId: category.id,
        parentCategoryId: category.parentCategory,
      );

      if (nameExists) {
        _setError(
          'A category with the name "${category.name}" already exists in this location. Please choose a different name.',
        );
        return false;
      }

      await _categoryRepo.updateCategory(category);
      // Stream will automatically update the list
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      return false;
    }
  }

  // Activate category (and its products)
  Future<bool> activateCategory(String categoryId, String modifiedBy) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    _setError(null);

    try {
      await _categoryRepo.activateCategory(categoryId, modifiedBy);
      // Stream will automatically update the list
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      return false;
    }
  }

  // Deactivate category (and its products)
  Future<bool> deactivateCategory(String categoryId, String modifiedBy) async {
    // Check connectivity before proceeding
    if (!ConnectivityService().isConnected) {
      _setError(
        'No internet connection. Please check your connection and try again.',
      );
      return false;
    }

    _setError(null);

    try {
      await _categoryRepo.deactivateCategory(categoryId, modifiedBy);
      // Stream will automatically update the list
      return true;
    } catch (e) {
      // Check if error is due to connectivity
      final isConnected = await ConnectivityService().checkConnection();
      if (!isConnected) {
        _setError(
          'Connection lost. Please check your internet connection and try again.',
        );
      } else {
        _setError(e.toString());
      }
      return false;
    }
  }

  // Check if category has products
  Future<int> getProductCountInCategory(String categoryId) async {
    try {
      return await _categoryRepo.getProductsCountInCategory(categoryId);
    } catch (e) {
      _setError(e.toString());
      return 0;
    }
  }

  // Get subcategory count for a parent category
  Future<int> getSubcategoryCount(String parentCategoryId) async {
    try {
      final subcategories = await _categoryRepo.getSubcategories(
        parentCategoryId,
      );
      return subcategories.length;
    } catch (e) {
      _setError(e.toString());
      return 0;
    }
  }

  // Get subcategory count synchronously from current loaded categories
  int getSubcategoriesCountSync(String parentCategoryId) {
    return _categories
        .where((c) => c.parentCategory == parentCategoryId)
        .length;
  }

  // Delete category only if no products exist
  Future<bool> deleteCategoryIfEmpty(String categoryId) async {
    _setError(null);

    try {
      // First check if category has products
      final productCount = await _categoryRepo.getProductsCountInCategory(
        categoryId,
      );

      if (productCount > 0) {
        _setError(
          'Cannot delete category. Please delete all $productCount products from this category first.',
        );
        return false;
      }

      // If no products, proceed with deletion
      await _categoryRepo.deleteCategory(categoryId, hardDelete: true);
      // Stream will automatically update the list
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Delete category (original method - kept for backward compatibility)
  Future<bool> deleteCategory(
    String categoryId, {
    bool hardDelete = false,
  }) async {
    _setError(null);

    try {
      await _categoryRepo.deleteCategory(categoryId, hardDelete: hardDelete);
      // Stream will automatically update the list
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Get category statistics
  Future<Map<String, int>?> getCategoryStatistics() async {
    _setLoading(true);
    _setError(null);

    try {
      final stats = await _categoryRepo.getCategoryStatistics();
      _setLoading(false);
      return stats;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // Get parent categories
  Future<List<CategoryModel>> getParentCategories() async {
    _setLoading(true);
    _setError(null);

    try {
      final categories = await _categoryRepo.getParentCategories();
      _setLoading(false);
      return categories;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }

  // Get subcategories
  Future<List<CategoryModel>> getSubcategories(String parentId) async {
    _setLoading(true);
    _setError(null);

    try {
      final categories = await _categoryRepo.getSubcategories(parentId);
      _setLoading(false);
      return categories;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data
  void clearData() {
    _categories.clear();
    _error = null;
    notifyListeners();
  }

  // Dispose method to clean up subscription
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
